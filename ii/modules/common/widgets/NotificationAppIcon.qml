import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

MaterialShape { // App icon
    id: root
    property var appIcon: ""
    property var appName: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool isUrgent: urgency === NotificationUrgency.Critical
    property var image: ""
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    property real smallAppIconScale: 0.49
    property real materialIconSize: implicitSize * materialIconScale
    property real appIconSize: implicitSize * appIconScale
    property real smallAppIconSize: implicitSize * smallAppIconScale

    implicitSize: 38 * scale
    property list<var> urgentShapes: [
        MaterialShape.Shape.VerySunny,
        MaterialShape.Shape.SoftBurst,
    ]
    shape: isUrgent ? urgentShapes[Math.floor(Math.random() * urgentShapes.length)] : MaterialShape.Shape.Circle

    color: isUrgent ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer

    readonly property bool isCalendarApp: (root.appIcon === "calendar_month" || root.appIcon === "calendar" || String(root.appName).toLowerCase().includes("calendar") || String(root.image).includes("calendar_month"))
    readonly property bool isTodoApp: (root.appIcon === "done_outline" || root.appIcon === "task_alt" || root.appIcon === "todo" || String(root.appName).toLowerCase().includes("to do") || String(root.appName).toLowerCase().includes("todo") || String(root.image).includes("done_outline") || String(root.image).includes("task_alt"))
    readonly property bool hasRealImage: root.image != "" && !String(root.image).includes("calendar_month") && !String(root.image).includes("office-calendar") && !String(root.image).includes("done_outline") && !String(root.image).includes("task_alt")
    readonly property bool hasValidSystemIcon: root.appIcon != "" && !isCalendarApp && !isTodoApp && Quickshell.iconPath(root.appIcon, "").length > 0
    readonly property bool isMaterialSymbol: !hasRealImage && (!hasValidSystemIcon || isCalendarApp || isTodoApp)

    Loader {
        id: materialSymbolLoader
        active: root.isMaterialSymbol
        anchors.fill: parent
        sourceComponent: MaterialSymbol {
            text: {
                if (root.isCalendarApp || root.appIcon === "calendar_month" || root.appIcon === "calendar") {
                    return "calendar_month";
                }
                if (root.isTodoApp || root.appIcon === "done_outline" || root.appIcon === "task_alt" || root.appIcon === "todo") {
                    return "done_outline";
                }
                const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("", root.appName)
                const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary, root.appName)
                return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                    "priority_high" : guessedIcon
            }
            anchors.fill: parent
            color: isUrgent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            iconSize: root.materialIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Loader {
        id: appIconLoader
        active: !root.isMaterialSymbol && !root.hasRealImage && root.appIcon != ""
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: (root.isMaterialSymbol || root.isCalendarApp || root.isTodoApp) ? "" : Quickshell.iconPath(root.appIcon, "image-missing")
        }
    }
    Loader {
        id: notifImageLoader
        active: root.hasRealImage
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            StyledImage {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width

                source: root.image
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.size
                        height: notifImage.size
                        radius: Appearance.rounding.full
                    }
                }
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.appIcon != "" || root.isCalendarApp || root.isTodoApp
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: (root.isCalendarApp || root.isTodoApp || !root.hasValidSystemIcon) ? notifSmallMaterialSymbolComponent : notifSmallAppIconComponent
            }
            Component {
                id: notifSmallMaterialSymbolComponent
                MaterialSymbol {
                    text: root.isCalendarApp ? "calendar_month" : (root.isTodoApp ? "done_outline" : NotificationUtils.findSuitableMaterialSymbol(root.summary, root.appName))
                    iconSize: root.smallAppIconSize
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Component {
                id: notifSmallAppIconComponent
                IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: (root.isCalendarApp || !root.hasValidSystemIcon) ? "" : Quickshell.iconPath(root.appIcon, "image-missing")
                }
            }
        }
    }
}