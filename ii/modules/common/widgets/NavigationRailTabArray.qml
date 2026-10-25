import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    property bool animationEnabled: false
    default property alias tabData: tabBarColumn.data  
    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25

    readonly property Item currentButton: {
        for (let i = 0; i < tabBarColumn.children.length; i++) {
            let child = tabBarColumn.children[i];
            if (child && typeof child.itemAt === "function") {
                let item = child.itemAt(root.currentIndex);
                if (item) return item;
            }
        }
        let buttons = [];
        for (let i = 0; i < tabBarColumn.children.length; i++) {
            let child = tabBarColumn.children[i];
            if (child && child.visualWidth !== undefined) {
                buttons.push(child);
            }
        }
        return buttons[root.currentIndex] ?? null;
    }

    Rectangle {
        property real itemHeight: root.currentButton?.baseSize ?? 56
        property real baseHighlightHeight: root.currentButton?.baseHighlightHeight ?? 32
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: ((root.currentButton && root.currentButton.y > 0) ? root.currentButton.y : (itemHeight * root.currentIndex)) + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: Appearance.rounding.full
        color: Appearance.colors.colSecondaryContainer
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: root.currentButton?.visualWidth ?? (root.expanded ? 100 : (root.currentButton?.baseSize ?? 56))

        Behavior on anchors.topMargin {
            enabled: root.animationEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: 0
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            root.animationEnabled = true;
        });
    }
}
