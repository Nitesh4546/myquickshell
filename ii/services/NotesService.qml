pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string filePath: Directories.notesPath
    property string text: ""
    property bool isLoaded: false
    property bool isSaving: saveDebounce.running

    signal textModified(var source)

    Timer {
        id: saveDebounce
        interval: 500
        repeat: false
        onTriggered: root.saveNow()
    }

    function updateText(newText, source) {
        if (root.text === newText)
            return;
        root.text = newText;
        saveDebounce.restart();
        root.textModified(source);
    }

    function saveNow() {
        saveDebounce.stop();
        if (noteFile) {
            noteFile.setText(root.text);
        }
    }

    Component.onCompleted: {
        noteFile.reload();
    }

    FileView {
        id: noteFile
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            noteFile.reload();
        }
        onLoaded: {
            const fileText = noteFile.text();
            if (!root.isLoaded) {
                root.text = fileText;
                root.isLoaded = true;
                root.textModified(null);
            } else if (fileText !== root.text && !saveDebounce.running) {
                root.text = fileText;
                root.textModified(null);
            }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.text = "";
                noteFile.setText(root.text);
                root.isLoaded = true;
                root.textModified(null);
            } else {
                console.log("[Notes Service] Error loading file: " + error);
            }
        }
    }
}
