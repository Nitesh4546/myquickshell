pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string filePath: Directories.clipboardPinsPath
    property string dirPath: Directories.clipboardPinsDir
    property var pins: []
    readonly property int count: pins ? pins.length : 0
    readonly property bool hasPins: count > 0
    property bool isLoaded: false

    property var pinQueue: []
    property bool isProcessingPin: false

    function isPinned(entry) {
        if (!entry) return false;
        const clean = StringUtils.cleanCliphistEntry(entry);
        for (let i = 0; i < root.pins.length; i++) {
            if (root.pins[i].preview === clean) {
                return true;
            }
        }
        return false;
    }

    function pin(entry) {
        if (!entry) return;
        if (root.count >= 30) {
            Quickshell.execDetached(["notify-send", Translation.tr("Clipboard"), Translation.tr("Pin limit reached"), "-a", "Shell"]);
            return;
        }
        const clean = StringUtils.cleanCliphistEntry(entry);
        if (root.pins.some(p => p.preview === clean)) {
            return;
        }
        pinQueue.push({
            entry: entry,
            preview: clean,
            isImage: Cliphist.entryIsImage(entry)
        });
        processPinQueue();
    }

    function processPinQueue() {
        if (root.isProcessingPin || root.pinQueue.length === 0) return;
        if (root.count >= 30) {
            root.pinQueue = [];
            Quickshell.execDetached(["notify-send", Translation.tr("Clipboard"), Translation.tr("Pin limit reached"), "-a", "Shell"]);
            return;
        }
        const item = root.pinQueue.shift();
        root.isProcessingPin = true;

        const pinId = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
        const targetFile = `${root.dirPath}/${pinId}`;
        const tempFile = `${root.dirPath}/.tmp_${pinId}`;
        const kind = item.isImage ? "image" : "text";

        decodeProc.currentPin = {
            id: pinId,
            entry: item.entry,
            preview: item.preview,
            kind: kind,
            file: targetFile,
            tempFile: tempFile,
            createdAt: Date.now()
        };

        decodeProc.outputBuffer = "";
        decodeProc.command = [
            "bash", "-c",
            `ENTRY="$1"
TARGET="$2"
TMP="$3"
KIND="$4"
BIN="$5"

mkdir -p "$(dirname "$TARGET")"
if [[ "$BIN" == *"cliphist"* ]]; then
    printf '%s' "$ENTRY" | "$BIN" decode > "$TMP"
else
    NUM=$(printf '%s' "$ENTRY" | cut -f1)
    "$BIN" decode "$NUM" > "$TMP"
fi
RC=$?
if [ $RC -ne 0 ] || [ ! -s "$TMP" ]; then
    rm -f "$TMP"
    exit 1
fi

SIZE=$(wc -c < "$TMP")
if [ "$KIND" = "text" ] && [ "$SIZE" -gt 1048576 ]; then
    rm -f "$TMP"
    echo "ERROR:SIZE_EXCEEDED"
    exit 2
fi

HASH=$(sha1sum "$TMP" | cut -d" " -f1)
if [ "$KIND" = "image" ]; then
    MIME=$(file --mime-type -b "$TMP")
    if [ -z "$MIME" ]; then
        MIME="image/png"
    fi
else
    MIME="text/plain;charset=utf-8"
fi

mv "$TMP" "$TARGET"
echo "OK $HASH $MIME $SIZE"`,
            "--",
            item.entry,
            targetFile,
            tempFile,
            kind,
            Cliphist.cliphistBinary
        ];
        decodeProc.running = true;
    }

    Process {
        id: decodeProc
        property var currentPin: null
        property string outputBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                decodeProc.outputBuffer += data + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            const pinInfo = decodeProc.currentPin;
            decodeProc.currentPin = null;

            if (exitCode === 0 && pinInfo) {
                const out = decodeProc.outputBuffer.trim();
                const parts = out.split(" ");
                if (parts[0] === "OK") {
                    const hash = parts[1];
                    const mime = parts[2] || (pinInfo.kind === "image" ? "image/png" : "text/plain");

                    // Check if hash already exists in pins
                    const isDup = root.pins.some(p => p.hash === hash);
                    if (isDup) {
                        Quickshell.execDetached(["rm", "-f", pinInfo.file]);
                    } else {
                        const newPin = {
                            id: pinInfo.id,
                            kind: pinInfo.kind,
                            mime: mime,
                            preview: pinInfo.preview,
                            file: pinInfo.file,
                            createdAt: pinInfo.createdAt,
                            hash: hash
                        };
                        root.pins = [newPin, ...root.pins];
                        root.save();
                    }
                }
            } else if (exitCode === 2) {
                console.warn("[ClipboardPins] Pin skipped: text exceeds 1 MB limit");
            } else {
                console.error("[ClipboardPins] Failed to decode clipboard entry for pinning. ExitCode:", exitCode);
            }

            root.isProcessingPin = false;
            if (root.pinQueue.length > 0) {
                root.processPinQueue();
            }
        }
    }

    function unpin(id) {
        const pin = root.pins.find(p => p.id === id);
        if (pin && pin.file) {
            Quickshell.execDetached(["rm", "-f", pin.file]);
        }
        root.pins = root.pins.filter(p => p.id !== id);
        root.save();
    }

    function clearAll() {
        for (let i = 0; i < root.pins.length; i++) {
            const pin = root.pins[i];
            if (pin && pin.file) {
                Quickshell.execDetached(["rm", "-f", pin.file]);
            }
        }
        root.pins = [];
        root.save();
    }

    function copy(pin) {
        if (!pin || !pin.file) return;
        if (pin.kind === "image") {
            const mime = pin.mime || "image/png";
            Quickshell.execDetached(["bash", "-c", `wl-copy --type '${StringUtils.shellSingleQuoteEscape(mime)}' < '${StringUtils.shellSingleQuoteEscape(pin.file)}'`]);
        } else {
            Quickshell.execDetached(["bash", "-c", `wl-copy < '${StringUtils.shellSingleQuoteEscape(pin.file)}'`]);
        }
    }

    function save() {
        pinsFileView.setText(JSON.stringify(root.pins));
    }

    function refresh() {
        pinsFileView.reload();
    }

    Component.onCompleted: {
        refresh();
    }

    FileView {
        id: pinsFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: root.refresh()
        onLoaded: {
            try {
                const fileContents = pinsFileView.text();
                let parsed = JSON.parse(fileContents);
                if (!Array.isArray(parsed)) parsed = [];
                root.pins = parsed;
                root.isLoaded = true;
                console.log("[ClipboardPins] Loaded pins count:", root.pins.length, "hasPins:", root.hasPins);
            } catch (e) {
                console.warn("[ClipboardPins] Error parsing file: " + e);
                root.pins = [];
                root.isLoaded = true;
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.pins = [];
                pinsFileView.setText(JSON.stringify(root.pins));
            } else {
                console.warn("[ClipboardPins] Error loading file: " + error);
            }
            root.isLoaded = true;
        }
    }

    IpcHandler {
        target: "clipboardPins"

        function pin(entry: string): void {
            root.pin(entry);
        }

        function unpin(id: string): void {
            root.unpin(id);
        }

        function clearAll(): void {
            root.clearAll();
        }

        function copy(id: string): void {
            const pin = root.pins.find(p => p.id === id);
            if (pin) root.copy(pin);
        }
    }
}
