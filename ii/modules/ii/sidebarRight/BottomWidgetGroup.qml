pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.todo
import qs.modules.ii.sidebarRight.pomodoro
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true
    implicitHeight: collapsed ? collapsedBottomWidgetGroupRow.implicitHeight : 350
    property int selectedTab: Persistent.states.sidebar.bottomGroup.tab
    property int previousIndex: selectedTab
    property bool readyForTabAnimation: false
    property bool collapsed: Persistent.states.sidebar.bottomGroup.collapsed
    property var tabs: [
        {
            "type": "calendar",
            "name": Translation.tr("Calendar"),
            "icon": "calendar_month",
            "widget": "calendar/CalendarWidget.qml"
        },
        {
            "type": "todo",
            "name": Translation.tr("To Do"),
            "icon": "done_outline",
            "widget": "todo/TodoWidget.qml"
        },
        {
            "type": "timer",
            "name": Translation.tr("Timer"),
            "icon": "schedule",
            "widget": "pomodoro/PomodoroWidget.qml"
        },
    ]

    function switchToTab(index) {
        if (index === root.selectedTab) return;
        root.previousIndex = root.selectedTab;
        root.selectedTab = index;
        Persistent.states.sidebar.bottomGroup.tab = index;
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    property bool contentVisible: !collapsed
    property bool collapsedPillVisible: collapsed

    function setCollapsed(state) {
        Persistent.states.sidebar.bottomGroup.collapsed = state;
        if (state) {
            bottomWidgetGroupFadeInTimer.stop();
            root.contentVisible = false;
            collapseFadeInTimer.start();
        } else {
            collapseFadeInTimer.stop();
            root.collapsedPillVisible = false;
            bottomWidgetGroupFadeInTimer.start();
        }
    }

    Timer {
        id: bottomWidgetGroupFadeInTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (!root.collapsed)
                root.contentVisible = true;
        }
    }

    Timer {
        id: collapseFadeInTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.collapsed)
                root.collapsedPillVisible = true;
        }
    }

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                root.switchToTab(Math.min(root.selectedTab + 1, root.tabs.length - 1));
            } else if (event.key === Qt.Key_PageUp) {
                root.switchToTab(Math.max(root.selectedTab - 1, 0));
            }
            event.accepted = true;
        }
    }

    // The thing when collapsed
    RowLayout {
        id: collapsedBottomWidgetGroupRow
        opacity: root.collapsedPillVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                id: collapsedBottomWidgetGroupRowFade
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        spacing: 15

        CalendarHeaderButton {
            Layout.margins: 10
            Layout.rightMargin: 0
            forceCircle: true
            downAction: () => {
                root.setCollapsed(false);
            }
            contentItem: MaterialSymbol {
                text: "keyboard_arrow_up"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnLayer1
            }
        }

        StyledText {
            property int remainingTasks: Todo.list.filter(task => !task.done).length
            Layout.margins: 10
            Layout.leftMargin: 0
            text: Translation.tr("%1   •   %2 tasks").arg(DateTime.collapsedCalendarFormat).arg(remainingTasks)
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
        }
    }

    // The thing when expanded
    RowLayout {
        id: bottomWidgetGroupRow

        opacity: root.contentVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                id: bottomWidgetGroupRowFade
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        anchors.fill: parent
        spacing: 20

        // Navigation rail
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.leftMargin: 10
            Layout.topMargin: 10
            implicitWidth: tabBar.implicitWidth
            // Navigation rail buttons
            NavigationRailTabArray {
                id: tabBar
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 5
                currentIndex: root.selectedTab
                expanded: false
                Repeater {
                    model: root.tabs
                    NavigationRailButton {
                        required property int index
                        required property var modelData
                        showToggledHighlight: false
                        toggled: root.selectedTab == index
                        buttonText: modelData.name
                        buttonIcon: modelData.icon
                        onPressed: {
                            root.switchToTab(index);
                        }
                    }
                }
            }
            // Collapse button
            CalendarHeaderButton {
                anchors.left: parent.left
                anchors.top: parent.top
                forceCircle: true
                downAction: () => {
                    root.setCollapsed(true);
                }
                contentItem: MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // Content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Repeater {
                id: tabRepeater
                model: root.tabs
                delegate: Item {
                    id: tabWrapper
                    required property int index
                    required property var modelData

                    anchors.fill: parent
                    property bool loaded: index === root.selectedTab
                    visible: opacity > 0
                    opacity: (index === root.selectedTab) ? 1 : 0

                    transform: Translate {
                        id: tabTranslate
                        y: 0
                    }

                    Loader {
                        id: tabLoader
                        anchors.fill: parent
                        active: tabWrapper.loaded
                        source: modelData.widget
                    }

                    Connections {
                        target: root
                        function onSelectedTabChanged() {
                            let enabled = Config.options?.sidebar?.tabAnimations ?? true;
                            if (index === root.selectedTab) {
                                tabWrapper.loaded = true;
                                if (root.readyForTabAnimation && enabled) {
                                    let goingDown = root.selectedTab > root.previousIndex;
                                    enterAnim.fromY = goingDown ? 12 : -12;
                                    enterAnim.restart();
                                } else {
                                    tabWrapper.opacity = 1;
                                    tabTranslate.y = 0;
                                }
                            } else if (index === root.previousIndex) {
                                if (root.readyForTabAnimation && enabled) {
                                    let goingDown = root.selectedTab > root.previousIndex;
                                    exitAnim.toY = goingDown ? -12 : 12;
                                    exitAnim.restart();
                                } else {
                                    tabWrapper.opacity = 0;
                                    tabTranslate.y = 0;
                                }
                            } else {
                                tabWrapper.opacity = 0;
                                tabTranslate.y = 0;
                            }
                        }
                    }

                    ParallelAnimation {
                        id: enterAnim
                        property real fromY: 12
                        PropertyAnimation {
                            target: tabTranslate
                            property: "y"
                            from: enterAnim.fromY
                            to: 0
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                        }
                        PropertyAnimation {
                            target: tabWrapper
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    ParallelAnimation {
                        id: exitAnim
                        property real toY: -12
                        PropertyAnimation {
                            target: tabTranslate
                            property: "y"
                            from: 0
                            to: exitAnim.toY
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                        }
                        PropertyAnimation {
                            target: tabWrapper
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }

            Timer {
                id: preloadTimer
                interval: 500
                running: true
                repeat: false
                onTriggered: {
                    for (let i = 0; i < tabRepeater.count; i++) {
                        let item = tabRepeater.itemAt(i);
                        if (item) item.loaded = true;
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            root.readyForTabAnimation = true;
        });
    }
}
