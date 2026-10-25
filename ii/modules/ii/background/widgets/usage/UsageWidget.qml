import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "usage"

    implicitWidth: 280
    implicitHeight: cardRect.implicitHeight
    width: implicitWidth
    height: implicitHeight

    readonly property bool compact: Config.options.background.widgets.usage.compact ?? false
    readonly property bool trackingPaused: UsageTracker.runtimePaused
    readonly property bool trackingEnabled: Config.options?.usage?.enable ?? true

    visible: opacity > 0 && trackingEnabled

    readonly property var colorPalette: [
        Appearance.colors.colPrimary,
        Appearance.colors.colSecondary,
        Appearance.colors.colTertiary,
        Appearance.colors.colSecondaryContainer,
        Appearance.colors.colOutlineVariant
    ]

    property real pressX: 0
    property real pressY: 0

    cursorShape: (draggable && containsPress) ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    onPressed: (mouse) => {
        root.pressX = mouse.x;
        root.pressY = mouse.y;
    }

    onReleased: (mouse) => {
        root.targetX = root.x;
        root.targetY = root.y;
        if (root.configEntry) {
            root.configEntry.x = root.targetX;
            root.configEntry.y = root.targetY;
        }

        const dx = Math.abs(mouse.x - root.pressX);
        const dy = Math.abs(mouse.y - root.pressY);
        if (dx < 6 && dy < 6) {
            UsageTracker.openUsageSettings();
        }
    }

    StyledDropShadow {
        target: cardRect
    }

    Rectangle {
        id: cardRect
        anchors.fill: parent
        implicitHeight: contentCol.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: (root.containsMouse && !root.drag.active)
            ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, Appearance.backgroundTransparency)
            : ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.backgroundTransparency)
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: contentCol
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 10

            // Header row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: "bar_chart"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: Translation.tr("Screen time")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    font.weight: Font.Medium
                }

                // Paused icon
                Item {
                    visible: root.trackingPaused
                    implicitWidth: pausedIcon.implicitWidth
                    implicitHeight: pausedIcon.implicitHeight
                    Layout.alignment: Qt.AlignVCenter

                    MaterialSymbol {
                        id: pausedIcon
                        text: "pause_circle"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colTertiary
                    }

                    StyledToolTip {
                        extraVisibleCondition: false
                        alternativeVisibleCondition: root.containsMouse
                        text: Translation.tr("Tracking paused")
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: Translation.tr("Today")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            // Empty state (when totalSec === 0)
            ColumnLayout {
                visible: UsageTracker.todayTotalSec === 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "hourglass_empty"
                    iconSize: 24
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No usage recorded yet today")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            // Normal state (totalSec > 0)
            ColumnLayout {
                visible: UsageTracker.todayTotalSec > 0
                Layout.fillWidth: true
                spacing: 10

                // Big total + 7-day sparkline
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: UsageTracker.formatDuration(UsageTracker.todayTotalSec)
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }

                    Item { Layout.fillWidth: true }

                    // Mini 7-day sparkline
                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4

                        Repeater {
                            model: UsageTracker.last7DaysList
                            delegate: Item {
                                required property var modelData
                                required property int index

                                implicitWidth: 5
                                implicitHeight: 28

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 5
                                    height: {
                                        const maxSec = Math.max(UsageTracker.last7DaysMaxSec, 1);
                                        const val = modelData.totalSec || 0;
                                        if (val <= 0) return 3;
                                        return Math.max(4, Math.round((val / maxSec) * 26));
                                    }
                                    radius: 2.5
                                    color: {
                                        if (modelData.isToday) return Appearance.colors.colPrimary;
                                        if (modelData.totalSec > 0) return Appearance.colors.colSecondaryContainer;
                                        return Appearance.colors.colLayer2;
                                    }
                                }
                            }
                        }
                    }
                }

                // Split horizontal bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Appearance.colors.colLayer2
                        clip: true

                        Row {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: {
                                    const top = UsageTracker.todayTopApps || [];
                                    return top.slice(0, 5);
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    height: parent.height
                                    width: {
                                        const total = UsageTracker.todayTotalSec;
                                        if (total <= 0 || !modelData.seconds) return 0;
                                        return Math.max(3, Math.round((modelData.seconds / total) * parent.width));
                                    }
                                    color: root.colorPalette[index % root.colorPalette.length]
                                }
                            }
                        }
                    }
                }

                // Top 3 apps list (hidden in compact mode)
                ColumnLayout {
                    visible: !root.compact
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: {
                            const top = UsageTracker.todayTopApps || [];
                            return top.slice(0, 3);
                        }
                        delegate: RowLayout {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: root.colorPalette[index % root.colorPalette.length]
                            }

                            AppIcon {
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 20
                                animated: false
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                text: UsageTracker.formatDuration(modelData.seconds)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }
        }
    }
}
