import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property var markerData: null

    readonly property int eventCount: markerData?.eventCount ?? 0
    readonly property var eventTitles: markerData?.eventTitles ?? []
    readonly property int taskCount: markerData?.taskCount ?? 0
    readonly property int overdueCount: markerData?.overdueCount ?? 0
    readonly property bool hasMarkers: eventCount > 0 || taskCount > 0

    function formatTooltip() {
        if (!hasMarkers) return "";
        let lines = [];
        if (eventTitles && eventTitles.length > 0) {
            for (let t of eventTitles) {
                lines.push(t);
            }
        } else if (eventCount > 0) {
            lines.push(eventCount === 1 ? Translation.tr("%1 event").arg(eventCount) : Translation.tr("%1 events").arg(eventCount));
        }
        if (taskCount > 0) {
            lines.push(taskCount === 1 ? Translation.tr("%1 task").arg(taskCount) : Translation.tr("%1 tasks").arg(taskCount));
        }
        if (overdueCount > 0) {
            lines.push(overdueCount === 1 ? Translation.tr("%1 overdue").arg(overdueCount) : Translation.tr("%1 overdue").arg(overdueCount));
        }
        return lines.join("\n");
    }

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small
    
    contentItem: Item {
        anchors.fill: parent

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: button.hasMarkers ? -3 : 0
            text: button.day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: button.bold ? Font.DemiBold : Font.Normal
            color: (button.isToday == 1) ? Appearance.m3colors.m3onPrimary : 
                (button.isToday == 0) ? Appearance.colors.colOnLayer1 : 
                Appearance.colors.colOutlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        Row {
            visible: button.hasMarkers
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 2
            opacity: (button.isToday == -1) ? 0.5 : 1.0

            Rectangle {
                visible: button.eventCount > 0
                width: 5
                height: 5
                radius: 2.5
                color: (button.isToday == 1) ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary
            }

            Rectangle {
                visible: button.taskCount > 0
                width: 5
                height: 5
                radius: 2.5
                color: (button.isToday == 1) ? Appearance.colors.colOnPrimary : 
                    (button.overdueCount > 0 ? Appearance.colors.colError : Appearance.colors.colTertiary)
            }
        }
    }

    hoverEnabled: true
    HoverHandler {
        id: hoverHandler
    }

    StyledToolTip {
        text: button.formatTooltip()
        extraVisibleCondition: button.hasMarkers
        alternativeVisibleCondition: button.hasMarkers && hoverHandler.hovered
    }
}

