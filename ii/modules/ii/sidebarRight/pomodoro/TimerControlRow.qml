import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: root

    property int currentIndex: 0 // 0 for Pomodoro, 1 for Stopwatch

    spacing: 10
    implicitHeight: 35
    implicitWidth: 190

    // Button 1: Primary button (Start / Pause / Resume)
    RippleButton {
        id: primaryBtn
        implicitWidth: 90
        implicitHeight: 35
        font.pixelSize: Appearance.font.pixelSize.larger

        readonly property bool isPomodoro: root.currentIndex === 0
        readonly property bool isRunning: isPomodoro ? TimerService.pomodoroRunning : TimerService.stopwatchRunning
        readonly property bool isPausedOrMidway: isPomodoro
            ? (TimerService.pomodoroSecondsLeft < TimerService.focusTime && !TimerService.pomodoroRunning)
            : (TimerService.stopwatchTime > 0 && !TimerService.stopwatchRunning)

        onClicked: {
            if (isPomodoro) {
                TimerService.togglePomodoro();
            } else {
                TimerService.toggleStopwatch();
            }
        }

        colBackground: isRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
        colBackgroundHover: isRunning ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryHover
        colRipple: isRunning ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colPrimaryActive

        contentItem: StyledText {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: primaryBtn.isRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
            text: {
                if (primaryBtn.isRunning) {
                    return Translation.tr("Pause");
                }
                if (primaryBtn.isPomodoro) {
                    return (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume");
                } else {
                    return (TimerService.stopwatchTime === 0) ? Translation.tr("Start") : Translation.tr("Resume");
                }
            }
        }
    }

    // Button 2: Reset button
    RippleButton {
        id: resetBtn
        implicitWidth: 90
        implicitHeight: 35
        font.pixelSize: Appearance.font.pixelSize.larger

        readonly property bool isPomodoro: root.currentIndex === 0

        enabled: {
            if (isPomodoro) {
                return (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration) || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak;
            } else {
                return !TimerService.stopwatchRunning && (TimerService.stopwatchTime > 0 || Persistent.states.timer.stopwatch.laps.length > 0);
            }
        }

        onClicked: {
            if (isPomodoro) {
                TimerService.resetPomodoro();
            } else {
                TimerService.stopwatchReset();
            }
        }

        colBackground: Appearance.colors.colErrorContainer
        colBackgroundHover: Appearance.colors.colErrorContainerHover
        colRipple: Appearance.colors.colErrorContainerActive

        contentItem: StyledText {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("Reset")
            color: Appearance.colors.colOnErrorContainer
        }
    }
}
