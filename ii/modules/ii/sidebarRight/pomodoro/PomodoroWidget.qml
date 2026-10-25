import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"}
    ]

    // These are keybinds for stopwatch and pomodoro
    Keys.onPressed: (event) => {
        if (pomodoroTimerTab.editorOpen) {
            if (event.key === Qt.Key_Escape) {
                pomodoroTimerTab.editorOpen = false;
                event.accepted = true;
            }
            return;
        }

        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) { // Pause/resume with Space or S
            if (tabBar.currentIndex === 0) {
                TimerService.togglePomodoro()
            } else {
                TimerService.toggleStopwatch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_R) { // Reset with R
            if (tabBar.currentIndex === 0) {
                TimerService.resetPomodoro()
            } else {
                TimerService.stopwatchReset()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) { // Record lap with L
            TimerService.stopwatchRecordLap()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: 0

            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        Item {
            id: contentArea
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            PomodoroTimer {
                id: pomodoroTimerTab
                anchors.fill: parent
                visible: opacity > 0
                opacity: tabBar.currentIndex === 0 ? 1 : 0
                Behavior on opacity {
                    enabled: Config.options?.sidebar?.tabAnimations ?? true
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }

            Stopwatch {
                id: stopwatchTab
                anchors.fill: parent
                visible: opacity > 0
                opacity: tabBar.currentIndex === 1 ? 1 : 0
                Behavior on opacity {
                    enabled: Config.options?.sidebar?.tabAnimations ?? true
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }

            TimerControlRow {
                id: timerControlRow
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                currentIndex: tabBar.currentIndex
                visible: !(tabBar.currentIndex === 0 && pomodoroTimerTab.editorOpen)
                z: 1
            }
        }
    }
}
