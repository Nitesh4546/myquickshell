pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple Pomodoro time manager.
 */
Singleton {
    id: root

    property int focusTime: Config.options.time.pomodoro.focus
    property int breakTime: Config.options.time.pomodoro.breakTime
    property int longBreakTime: Config.options.time.pomodoro.longBreak
    property int cyclesBeforeLongBreak: Config.options.time.pomodoro.cyclesBeforeLongBreak

    property bool pomodoroRunning: Persistent.states.timer.pomodoro.running
    property bool pomodoroBreak: Persistent.states.timer.pomodoro.isBreak
    property bool pomodoroLongBreak: Persistent.states.timer.pomodoro.isBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak);
    readonly property int targetLapDuration: pomodoroLongBreak ? longBreakTime : pomodoroBreak ? breakTime : focusTime
    property int pomodoroLapDuration: (Persistent.states.timer.pomodoro.phaseDuration > 0) ? Persistent.states.timer.pomodoro.phaseDuration : targetLapDuration
    property int pomodoroSecondsLeft: pomodoroLapDuration // Reasonable init value, to be changed
    property int pomodoroCycle: Persistent.states.timer.pomodoro.cycle

    onPomodoroLapDurationChanged: {
        if (!pomodoroRunning && Persistent.states.timer.pomodoro.phaseDuration <= 0) {
            pomodoroSecondsLeft = pomodoroLapDuration;
        }
    }

    property bool stopwatchRunning: Persistent.states.timer.stopwatch.running
    property int stopwatchTime: 0
    property int stopwatchStart: Persistent.states.timer.stopwatch.start
    property var stopwatchLaps: Persistent.states.timer.stopwatch.laps

    // General
    Component.onCompleted: {
        if (!stopwatchRunning)
            stopwatchReset();

        if (pomodoroRunning) {
            refreshPomodoro();
        } else if (Persistent.states.timer.pomodoro.pausedSecondsLeft > 0 && Persistent.states.timer.pomodoro.phaseDuration > 0) {
            pomodoroSecondsLeft = Math.max(0, Math.min(pomodoroLapDuration, Persistent.states.timer.pomodoro.pausedSecondsLeft));
        } else {
            Persistent.states.timer.pomodoro.phaseDuration = 0;
            Persistent.states.timer.pomodoro.pausedSecondsLeft = 0;
            pomodoroSecondsLeft = pomodoroLapDuration;
        }
    }

    function getCurrentTimeInSeconds() {  // Pomodoro uses Seconds
        return Math.floor(Date.now() / 1000);
    }

    function getCurrentTimeIn10ms() {  // Stopwatch uses 10ms
        return Math.floor(Date.now() / 10);
    }

    // Pomodoro
    function refreshPomodoro() {
        // Work <-> break ?
        if (getCurrentTimeInSeconds() >= Persistent.states.timer.pomodoro.start + pomodoroLapDuration) {
            // Reset counts
            Persistent.states.timer.pomodoro.isBreak = !Persistent.states.timer.pomodoro.isBreak;
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();

            if (!pomodoroBreak) {
                Persistent.states.timer.pomodoro.cycle = (Persistent.states.timer.pomodoro.cycle + 1) % root.cyclesBeforeLongBreak;
            }

            // Lock in the new phase duration using current config
            let isLong = Persistent.states.timer.pomodoro.isBreak && (Persistent.states.timer.pomodoro.cycle + 1 == root.cyclesBeforeLongBreak);
            let nextDuration = isLong ? root.longBreakTime : (Persistent.states.timer.pomodoro.isBreak ? root.breakTime : root.focusTime);
            Persistent.states.timer.pomodoro.phaseDuration = nextDuration;
            Persistent.states.timer.pomodoro.pausedSecondsLeft = 0;

            // Send notification
            let notificationMessage;
            if (isLong) {
                notificationMessage = Translation.tr(`🌿 Long break: %1 minutes`).arg(Math.floor(longBreakTime / 60));
            } else if (Persistent.states.timer.pomodoro.isBreak) {
                notificationMessage = Translation.tr(`☕ Break: %1 minutes`).arg(Math.floor(breakTime / 60));
            } else {
                notificationMessage = Translation.tr(`🔴 Focus: %1 minutes`).arg(Math.floor(focusTime / 60));
            }

            Quickshell.execDetached(["notify-send", "Pomodoro", notificationMessage, "-a", "Shell"]);
            if (Config.options.sounds.pomodoro) {
                Audio.playSystemSound("alarm-clock-elapsed")
            }
        }

        pomodoroSecondsLeft = Math.max(0, pomodoroLapDuration - (getCurrentTimeInSeconds() - Persistent.states.timer.pomodoro.start));
    }

    Timer {
        id: pomodoroTimer
        interval: 200
        running: root.pomodoroRunning
        repeat: true
        onTriggered: refreshPomodoro()
    }

    function togglePomodoro() {
        Persistent.states.timer.pomodoro.running = !pomodoroRunning;
        if (Persistent.states.timer.pomodoro.running) {
            // Start/Resume
            if (Persistent.states.timer.pomodoro.phaseDuration <= 0) {
                Persistent.states.timer.pomodoro.phaseDuration = root.targetLapDuration;
            }
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds() + pomodoroSecondsLeft - pomodoroLapDuration;
            Persistent.states.timer.pomodoro.pausedSecondsLeft = 0;
        } else {
            // Paused
            Persistent.states.timer.pomodoro.pausedSecondsLeft = pomodoroSecondsLeft;
        }
    }

    function resetPomodoro() {
        Persistent.states.timer.pomodoro.running = false;
        Persistent.states.timer.pomodoro.isBreak = false;
        Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();
        Persistent.states.timer.pomodoro.cycle = 0;
        Persistent.states.timer.pomodoro.phaseDuration = 0;
        Persistent.states.timer.pomodoro.pausedSecondsLeft = 0;
        pomodoroSecondsLeft = focusTime;
        refreshPomodoro();
    }

    // Stopwatch
    function refreshStopwatch() {  // Stopwatch stores time in 10ms
        stopwatchTime = getCurrentTimeIn10ms() - stopwatchStart;
    }

    Timer {
        id: stopwatchTimer
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            stopwatchPause();
        else
            stopwatchResume();
    }

    function stopwatchPause() {
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchResume() {
        if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = true;
        Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
    }

    function stopwatchReset() {
        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchRecordLap() {
        Persistent.states.timer.stopwatch.laps.push(stopwatchTime);
    }
}
