pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var scale
    property bool restrictToWorkspace: true
    property real widthRatio: {
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale);
    }
    property real heightRatio: {
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale);
    }
    property real initX: {
        return Math.max((windowData?.at[0] - (monitorData?.x ?? 0) - monitorData?.reserved[0]) * widthRatio * root.scale, 0) + xOffset;
    }

    property real initY: {
        return Math.max((windowData?.at[1] - (monitorData?.y ?? 0) - monitorData?.reserved[1]) * heightRatio * root.scale, 0) + yOffset;
    }
    property real xOffset: 0
    property real yOffset: 0
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor.id

    property var targetWindowWidth: windowData?.size[0] * scale * widthRatio
    property var targetWindowHeight: windowData?.size[1] * scale * heightRatio
    property bool hovered: false
    property bool pressed: false

    readonly property bool restrictedMode: (Config?.options.overview.privacyMode ?? false) && !GlobalStates.overviewShowFull

    property bool centerIcons: Config.options.overview.centerIcons
    property real iconGapRatio: 0.06
    property real iconToWindowRatio: centerIcons ? 0.35 : 0.15
    property real xwaylandIndicatorToIconRatio: 0.35
    property real iconToWindowRatioCompact: 0.6
    property string iconPath: Quickshell.iconPath(AppSearch.guessIcon(windowData?.class), "image-missing")
    property bool compactMode: Appearance.font.pixelSize.smaller * 4 > targetWindowHeight || Appearance.font.pixelSize.smaller * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: windowData.monitor == widgetMonitorId ? 1 : 0.4

    property real topLeftRadius
    property real topRightRadius
    property real bottomLeftRadius
    property real bottomRightRadius

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
        }
    }

    Behavior on x {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    Rectangle {
        id: baseTile
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        color: Appearance.colors.colLayer2
    }

    Loader {
        id: previewLoader
        anchors.fill: parent
        active: !root.restrictedMode && GlobalStates.overviewOpen
        opacity: root.restrictedMode ? 0 : 1
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        sourceComponent: ScreencopyView {
            captureSource: (GlobalStates.overviewOpen && !root.restrictedMode) ? root.toplevel : null
            live: true
        }
    }

    // Color overlay for interactions and restricted mode themed tile
    Rectangle {
        id: windowTile
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        color: root.restrictedMode ? (
            pressed ? Appearance.colors.colLayer2Active : 
            hovered ? Appearance.colors.colLayer2Hover : 
            Appearance.colors.colLayer2
        ) : (
            pressed ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.5) : 
            hovered ? ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.7) : 
            ColorUtils.transparentize(Appearance.colors.colLayer2)
        )
        border.color: root.restrictedMode ? 
            Appearance.colors.colLayer2Hover : 
            ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.88)
        border.width: 1

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on border.color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    StyledImage {
        id: windowIcon
        property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
        property bool shouldCenter: root.restrictedMode || root.centerIcons
        anchors {
            top: windowIcon.shouldCenter ? undefined : parent.top
            left: windowIcon.shouldCenter ? undefined : parent.left
            centerIn: windowIcon.shouldCenter ? parent : undefined
            margins: baseSize * root.iconGapRatio
        }
        property var iconSize: {
            if (root.restrictedMode) {
                return Math.max(16, Math.min(baseSize * 0.5, 96));
            }
            return baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio);
        }
        mipmap: true
        Layout.alignment: Qt.AlignHCenter
        source: root.iconPath
        width: iconSize
        height: iconSize

        Behavior on width {
            animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
        }
        Behavior on height {
            animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
        }
    }
}
