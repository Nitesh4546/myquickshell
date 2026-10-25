pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: false

    readonly property bool active: (Config.options?.bar?.privacyIndicator ?? true) && Privacy.anyActive

    implicitWidth: 10
    implicitHeight: 10

    Rectangle {
        id: greenDot
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: "#3ddc84"

        SequentialAnimation on opacity {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        }
    }

    onActiveChanged: {
        if (!active) {
            greenDot.opacity = 1.0;
        }
    }

}
