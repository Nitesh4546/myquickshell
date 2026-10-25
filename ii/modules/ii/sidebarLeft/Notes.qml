import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property real padding: 4

    function focusInput() {
        textArea.forceActiveFocus();
    }

    onFocusChanged: (focus) => {
        if (focus) {
            root.focusInput();
        }
    }

    onVisibleChanged: {
        if (visible) {
            root.focusInput();
        } else {
            NotesService.saveNow();
        }
    }

    Component.onCompleted: {
        if (NotesService.text.length > 0 || NotesService.isLoaded) {
            textArea.text = NotesService.text;
        }
        if (visible) {
            root.focusInput();
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen) {
                NotesService.saveNow();
            } else if (root.visible) {
                Qt.callLater(root.focusInput);
            }
        }
    }

    Connections {
        target: NotesService
        function onTextModified(source) {
            if (source !== textArea && textArea.text !== NotesService.text) {
                const previousCursor = textArea.cursorPosition;
                const previousStart = textArea.selectionStart;
                const previousEnd = textArea.selectionEnd;
                textArea.text = NotesService.text;
                if (textArea.activeFocus) {
                    const textLen = textArea.text.length;
                    const cursor = Math.max(0, Math.min(previousCursor, textLen));
                    const anchor = Math.max(0, Math.min(previousStart, textLen));
                    textArea.select(anchor, cursor);
                    if (cursor === anchor)
                        textArea.deselect();
                }
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 6

        Rectangle {
            id: editorContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: textArea.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant
            clip: true

            Behavior on border.color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            ScrollView {
                id: editorScrollView
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                StyledTextArea {
                    id: textArea
                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    wrapMode: TextEdit.Wrap
                    placeholderText: Translation.tr("Write your notes here...")
                    selectByMouse: true
                    persistentSelection: true
                    textFormat: TextEdit.PlainText
                    background: null
                    padding: 12
                    color: Appearance.colors.colOnLayer0

                    onTextChanged: {
                        if (textArea.activeFocus) {
                            NotesService.updateText(textArea.text, textArea);
                        }
                    }

                    onActiveFocusChanged: {
                        if (!textArea.activeFocus) {
                            NotesService.saveNow();
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.modifiers === Qt.ControlModifier) {
                            if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                                event.accepted = false;
                                return;
                            }
                        } else if (event.modifiers === Qt.NoModifier) {
                            if (event.key === Qt.Key_Escape) {
                                event.accepted = false;
                                return;
                            } else if (event.key === Qt.Key_PageUp) {
                                editorScrollView.ScrollBar.vertical.decrease();
                                event.accepted = true;
                                return;
                            } else if (event.key === Qt.Key_PageDown) {
                                editorScrollView.ScrollBar.vertical.increase();
                                event.accepted = true;
                                return;
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 8

            RippleButton {
                id: copyAllButton
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: height / 2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                property bool justCopied: false

                Timer {
                    id: copyResetTimer
                    interval: 1000
                    onTriggered: copyAllButton.justCopied = false
                }

                onClicked: {
                    Quickshell.clipboardText = textArea.text;
                    justCopied = true;
                    copyResetTimer.restart();
                }

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: Appearance.font.pixelSize.normal
                    text: copyAllButton.justCopied ? "check" : "content_copy"
                    color: copyAllButton.justCopied ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }

                StyledToolTip {
                    text: copyAllButton.justCopied ? Translation.tr("Copied!") : Translation.tr("Copy all")
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                id: statusIndicator
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: NotesService.isSaving ? Translation.tr("Saving...") : Translation.tr("Saved")
            }
        }
    }
}
