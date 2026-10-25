import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: stopwatchTab
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Top-right Lap button
    RippleButton {
        id: lapBtn
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 2
            rightMargin: 2
        }
        z: 2
        implicitHeight: 32
        implicitWidth: lapContentRow.implicitWidth + 24
        buttonRadius: Appearance.rounding.full
        enabled: TimerService.stopwatchRunning

        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colRipple: Appearance.colors.colLayer2Active

        contentItem: RowLayout {
            id: lapContentRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "flag"
                iconSize: 18
                color: lapBtn.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Lap")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: lapBtn.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
            }
        }

        StyledToolTip {
            text: Translation.tr("Record lap (L)")
        }

        onClicked: {
            TimerService.stopwatchRecordLap();
        }
    }

    Item {
        anchors {
            fill: parent
            topMargin: 8
            leftMargin: 16
            rightMargin: 16
        }

        RowLayout { // Elapsed
            id: elapsedIndicator
            
            anchors {
                top: undefined
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: -20
                horizontalCenter: parent.horizontalCenter
            }

            states: State {
                name: "hasLaps"
                when: TimerService.stopwatchLaps.length > 0
                AnchorChanges {
                    target: elapsedIndicator
                    anchors.top: parent.top
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            spacing: 0
            StyledText {
                // Layout.preferredWidth: elapsedIndicator.width * 0.6 // Prevent shakiness
                font.pixelSize: 40
                color: Appearance.m3colors.m3onSurface
                text: {
                    let totalSeconds = Math.floor(TimerService.stopwatchTime) / 100
                    let minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                    let seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                    return `${minutes}:${seconds}`
                }
            }
            StyledText {
                Layout.fillWidth: true
                font.pixelSize: 40
                color: Appearance.colors.colSubtext
                text: {
                    return `:<sub>${(Math.floor(TimerService.stopwatchTime) % 100).toString().padStart(2, '0')}</sub>`
                }
            }
        }

        // Laps
        StyledListView {
            id: lapsList
            anchors {
                top: elapsedIndicator.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                topMargin: 16
                bottomMargin: 47
            }
            spacing: 4
            clip: true
            popin: true

            model: ScriptModel {
                values: TimerService.stopwatchLaps.map((v, i, arr) => arr[arr.length - 1 - i])
            }

            delegate: Rectangle {
                id: lapItem
                required property int index
                required property var modelData
                property var horizontalPadding: 10
                property var verticalPadding: 6
                width: lapsList.width
                implicitHeight: lapRow.implicitHeight + verticalPadding * 2
                implicitWidth: lapRow.implicitWidth + horizontalPadding * 2
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                RowLayout {
                    id: lapRow
                    anchors {
                        fill: parent
                        leftMargin: lapItem.horizontalPadding
                        rightMargin: lapItem.horizontalPadding
                        topMargin: lapItem.verticalPadding
                        bottomMargin: lapItem.verticalPadding
                    }

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        text: `${TimerService.stopwatchLaps.length - lapItem.index}.`
                    }

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        text: {
                            const lapTime = lapItem.modelData
                            const _10ms = (Math.floor(lapTime) % 100).toString().padStart(2, '0')
                            const totalSeconds = Math.floor(lapTime) / 100
                            const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                            const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                            return `${minutes}:${seconds}.${_10ms}`
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                        text: {
                            const originalIndex = TimerService.stopwatchLaps.length - lapItem.index - 1
                            const lastTime = originalIndex > 0 ? TimerService.stopwatchLaps[originalIndex - 1] : 0
                            const lapTime = lapItem.modelData - lastTime
                            const _10ms = (Math.floor(lapTime) % 100).toString().padStart(2, '0')
                            const totalSeconds = Math.floor(lapTime) / 100
                            const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0')
                            const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0')
                            return `+${minutes == "00" ? "" : minutes + ":"}${seconds}.${_10ms}`
                        }
                    }
                }
            }
        }
    }
}