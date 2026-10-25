pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * Android-style privacy service: monitors microphone and camera usage.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.options?.bar?.privacyIndicator ?? true

    // Kept for backward compatibility
    property bool screenSharing: Pipewire.linkGroups.values.filter(pwlg => pwlg.source?.type === PwNodeType.VideoSource).map(pwlg => pwlg.target).length > 0

    // Internal raw detection states
    property bool rawMicActive: false
    property bool rawCameraActive: false
    property var rawMicApps: []
    property var rawCameraApps: []

    // Debounced public states
    property bool micActive: false
    property bool cameraActive: false
    readonly property bool anyActive: enabled && (micActive || cameraActive)

    property var micApps: []
    property var cameraApps: []

    function cleanAppNames(list) {
        if (!list || list.length === 0) return [];
        let unique = [];
        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            if (typeof item !== "string") continue;
            item = item.trim();
            if (item.length === 0) continue;
            let match = item.match(/\[(.*?)\]/);
            if (match && match[1]) {
                item = match[1].trim();
            }
            if (item.length > 0 && unique.indexOf(item) === -1) {
                unique.push(item);
            }
        }
        return unique;
    }

    // --- 1. PipeWire Detection (Microphone & Camera via portal) ---
    function updatePipewireDetection() {
        if (!root.enabled) {
            root.rawMicActive = false;
            root.rawMicApps = [];
            root.pipewireCameraActive = false;
            root.pipewireCameraApps = [];
            return;
        }

        let micDetected = false;
        let detectedMicApps = [];
        let camDetected = false;
        let detectedCamApps = [];

        let lgs = Pipewire.linkGroups?.values ?? [];
        for (let i = 0; i < lgs.length; i++) {
            let lg = lgs[i];
            if (!lg || !lg.source || !lg.target) continue;

            // Mic detection: AudioSource linked to AudioInStream
            if (lg.source.type === PwNodeType.AudioSource && lg.target.type === PwNodeType.AudioInStream) {
                let props = lg.target.properties ?? {};
                let isSinkCapture = props["stream.capture.sink"] === "true" ||
                                    (props["media.name"] || "").toLowerCase().includes("monitor") ||
                                    (props["node.name"] || "").toLowerCase().includes("monitor");
                if (!isSinkCapture) {
                    let bin = props["application.process.binary"] || "";
                    if (bin === "quickshell" && props["media.role"] !== "Communication") {
                        continue;
                    }
                    micDetected = true;
                    let appName = props["application.name"] || bin || lg.target.description || lg.target.name || Translation.tr("Unknown");
                    detectedMicApps.push(appName);
                }
            }

            // Camera detection: VideoSource linked to VideoInStream (verify camera, not screenshare)
            if (lg.source.type === PwNodeType.VideoSource && lg.target.type === PwNodeType.VideoInStream) {
                let sourceProps = lg.source.properties ?? {};
                let isCamera = sourceProps["media.role"] === "Camera" ||
                               (sourceProps["node.name"] || "").toLowerCase().includes("v4l2") ||
                               (sourceProps["node.nick"] || "").toLowerCase().includes("webcam") ||
                               (sourceProps["node.nick"] || "").toLowerCase().includes("camera");
                if (isCamera) {
                    camDetected = true;
                    let props = lg.target.properties ?? {};
                    let appName = props["application.name"] || props["application.process.binary"] || lg.target.description || lg.target.name || Translation.tr("Camera");
                    detectedCamApps.push(appName);
                }
            }
        }

        root.rawMicActive = micDetected;
        root.rawMicApps = cleanAppNames(detectedMicApps);

        root.pipewireCameraActive = camDetected;
        root.pipewireCameraApps = cleanAppNames(detectedCamApps);
    }

    property bool pipewireCameraActive: false
    property var pipewireCameraApps: []

    // --- 2. V4L2 Device Polling Fallback (/dev/video0) ---
    property bool v4l2CameraActive: false
    property var v4l2CameraApps: []

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: {
            if (!fuserProc.running) {
                fuserProc.running = true;
            }
        }
    }

    Process {
        id: fuserProc
        property string outputBuffer: ""
        command: ["bash", "-c", "if [ -e /dev/video0 ]; then PIDS=$(fuser /dev/video0 2>/dev/null); if [ -n \"$PIDS\" ]; then ps -p $PIDS -o comm= 2>/dev/null | sort -u | tr '\\n' ',' | sed 's/,$//'; else exit 1; fi; else exit 1; fi"]
        stdout: SplitParser {
            onRead: data => {
                fuserProc.outputBuffer += data;
            }
        }
        onStarted: {
            fuserProc.outputBuffer = "";
        }
        onExited: (exitCode) => {
            if (exitCode === 0 && fuserProc.outputBuffer.trim().length > 0) {
                let trimmed = fuserProc.outputBuffer.trim();
                let apps = trimmed.split(",").map(s => s.trim()).filter(s => s.length > 0 && s !== "pipewire" && s !== "wireplumber");
                if (apps.length > 0) {
                    root.v4l2CameraActive = true;
                    root.v4l2CameraApps = apps;
                    return;
                }
            }
            root.v4l2CameraActive = false;
            root.v4l2CameraApps = [];
        }
    }

    // Combine camera sources
    readonly property bool combinedRawCameraActive: pipewireCameraActive || v4l2CameraActive
    readonly property var combinedRawCameraApps: cleanAppNames([...pipewireCameraApps, ...v4l2CameraApps])

    onCombinedRawCameraActiveChanged: {
        rawCameraActive = combinedRawCameraActive;
        rawCameraApps = combinedRawCameraApps;
    }

    // PipeWire reactivity
    Connections {
        target: Pipewire
        function onLinkGroupsChanged() {
            root.updatePipewireDetection();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.enabled
        onTriggered: root.updatePipewireDetection()
    }

    // Debouncing: immediate ON, ~1.5s delayed OFF
    Timer {
        id: micDebounceTimer
        interval: 1500
        onTriggered: {
            if (!root.rawMicActive) {
                root.micActive = false;
                root.micApps = [];
            }
        }
    }

    onRawMicActiveChanged: {
        if (rawMicActive) {
            micDebounceTimer.stop();
            micActive = true;
            micApps = rawMicApps;
        } else {
            micDebounceTimer.restart();
        }
    }

    onRawMicAppsChanged: {
        if (micActive && rawMicApps.length > 0) {
            micApps = rawMicApps;
        }
    }

    Timer {
        id: cameraDebounceTimer
        interval: 1500
        onTriggered: {
            if (!root.rawCameraActive) {
                root.cameraActive = false;
                root.cameraApps = [];
            }
        }
    }

    onRawCameraActiveChanged: {
        if (rawCameraActive) {
            cameraDebounceTimer.stop();
            cameraActive = true;
            cameraApps = rawCameraApps;
        } else {
            cameraDebounceTimer.restart();
        }
    }

    onRawCameraAppsChanged: {
        if (cameraActive && rawCameraApps.length > 0) {
            cameraApps = rawCameraApps;
        }
    }

    onEnabledChanged: {
        if (!enabled) {
            pollTimer.stop();
            micDebounceTimer.stop();
            cameraDebounceTimer.stop();
            rawMicActive = false;
            rawCameraActive = false;
            micActive = false;
            cameraActive = false;
            micApps = [];
            cameraApps = [];
        } else {
            pollTimer.start();
            updatePipewireDetection();
        }
    }
}
