import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: button
    property string buttonText: ""
    property string tooltipText: ""

    implicitHeight: 30
    implicitWidth: implicitHeight

    Behavior on implicitWidth {
        SmoothedAnimation {
            velocity: Appearance.animation.elementMove.velocity
        }
    }

    buttonRadius: Appearance.rounding.small

    contentItem: StyledText {
        text: buttonText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnLayer1
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    StyledToolTip {
        text: tooltipText
        extraVisibleCondition: tooltipText.length > 0 && hoverArea.containsMouse
    }
}