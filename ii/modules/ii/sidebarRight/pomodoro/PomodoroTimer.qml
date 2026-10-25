import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool editorOpen: false

    property bool entered: !(Config.options?.sidebar?.tabAnimations ?? true)
    property bool labelsEntered: !(Config.options?.sidebar?.tabAnimations ?? true)

    Timer {
        id: labelsTimer
        interval: 40
        running: (Config.options?.sidebar?.tabAnimations ?? true) && root.entered
        repeat: false
        onTriggered: root.labelsEntered = true
    }

    Component.onCompleted: {
        if (Config.options?.sidebar?.tabAnimations ?? true) {
            Qt.callLater(() => {
                root.entered = true;
            });
        }
    }

    implicitHeight: Math.max(contentColumn.implicitHeight, 250)
    implicitWidth: Math.max(contentColumn.implicitWidth, 250)

    focus: editorOpen
    Keys.onPressed: (event) => {
        if (root.editorOpen) {
            if (event.key === Qt.Key_Escape) {
                root.editorOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S || event.key === Qt.Key_R || event.key === Qt.Key_L || event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                event.accepted = true;
            }
        }
    }

    // Top-right tune button to open editor
    RippleButton {
        id: tuneButton
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 2
            rightMargin: 2
        }
        z: 2
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        visible: !root.editorOpen
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: "tune"
            iconSize: 18
            color: Appearance.colors.colOnLayer2
        }

        StyledToolTip {
            text: Translation.tr("Edit durations")
        }

        onClicked: {
            root.editorOpen = true;
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: 47
        }
        spacing: 0
        opacity: root.editorOpen ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            enabled: Config.options?.sidebar?.tabAnimations ?? true
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // The Pomodoro timer circle
        CircularProgress {
            id: progressRing
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            lineWidth: 8
            value: {
                return TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration;
            }
            implicitSize: 200
            enableAnimation: true
            scale: root.entered ? 1.0 : 0.96
            opacity: root.entered ? 1.0 : 0.0

            Behavior on scale {
                enabled: Config.options?.sidebar?.tabAnimations ?? true
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
            }
            Behavior on opacity {
                enabled: Config.options?.sidebar?.tabAnimations ?? true
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            ColumnLayout {
                id: timeLabelsColumn
                anchors.centerIn: parent
                spacing: 0
                opacity: root.labelsEntered ? 1.0 : 0.0
                transform: Translate {
                    y: root.labelsEntered ? 0 : 4
                    Behavior on y {
                        enabled: Config.options?.sidebar?.tabAnimations ?? true
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                        }
                    }
                }
                Behavior on opacity {
                    enabled: Config.options?.sidebar?.tabAnimations ?? true
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        let minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, '0');
                        let seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, '0');
                        return `${minutes}:${seconds}`;
                    }
                    font.pixelSize: 40
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.pomodoroLongBreak ? Translation.tr("Long break") : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                implicitWidth: 36
                implicitHeight: implicitWidth

                StyledText {
                    id: cycleText
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnLayer2
                    text: TimerService.pomodoroCycle + 1
                }
            }
        }
    }

    // Inline duration editor panel
    Rectangle {
        id: editorPanel
        anchors.fill: parent
        color: Appearance.colors.colLayer1
        opacity: root.editorOpen ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Config.options?.sidebar?.tabAnimations ?? true
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        radius: Appearance.rounding.normal
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 12
            spacing: 8

            // Header row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: "tune"
                    iconSize: 18
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
                    text: Translation.tr("Edit durations")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                RippleButton {
                    id: closeBtn
                    implicitWidth: 28
                    implicitHeight: 28
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colRipple: "transparent"
                    rippleEnabled: false

                    contentItem: MaterialSymbol {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "close"
                        iconSize: 18
                        color: closeBtn.hovered ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                    onClicked: {
                        root.editorOpen = false;
                    }
                }
            }

            // Subtle note when changes defer until next phase
            StyledText {
                Layout.fillWidth: true
                visible: TimerService.pomodoroRunning || Persistent.states.timer.pomodoro.phaseDuration > 0
                text: Translation.tr("Changes apply from the next phase")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }

            // Focus row: 1–180 min
            SettingRow {
                label: Translation.tr("Focus")
                value: Math.round(Config.options.time.pomodoro.focus / 60)
                minValue: 1
                maxValue: 180
                suffix: " " + Translation.tr("min")
                onValueModified: (newVal) => {
                    Config.options.time.pomodoro.focus = newVal * 60;
                }
            }

            // Break row: 1–60 min
            SettingRow {
                label: Translation.tr("Break")
                value: Math.round(Config.options.time.pomodoro.breakTime / 60)
                minValue: 1
                maxValue: 60
                suffix: " " + Translation.tr("min")
                onValueModified: (newVal) => {
                    Config.options.time.pomodoro.breakTime = newVal * 60;
                }
            }

            // Long break row: 1–120 min
            SettingRow {
                label: Translation.tr("Long break")
                value: Math.round(Config.options.time.pomodoro.longBreak / 60)
                minValue: 1
                maxValue: 120
                suffix: " " + Translation.tr("min")
                onValueModified: (newVal) => {
                    Config.options.time.pomodoro.longBreak = newVal * 60;
                }
            }

            // Cycles row: 1–10
            SettingRow {
                label: Translation.tr("Cycles before long break")
                value: Config.options.time.pomodoro.cyclesBeforeLongBreak
                minValue: 1
                maxValue: 10
                suffix: ""
                onValueModified: (newVal) => {
                    Config.options.time.pomodoro.cyclesBeforeLongBreak = newVal;
                }
            }

            Item { Layout.fillHeight: true }

            // Action buttons: Reset to defaults (left) & Done (right)
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 8

                RippleButton {
                    id: resetBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 34
                    implicitWidth: resetContentRow.implicitWidth + 8
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colRipple: "transparent"
                    rippleEnabled: false
                    onClicked: {
                        Config.options.time.pomodoro.focus = 1500;
                        Config.options.time.pomodoro.breakTime = 300;
                        Config.options.time.pomodoro.longBreak = 900;
                        Config.options.time.pomodoro.cyclesBeforeLongBreak = 4;
                    }

                    contentItem: RowLayout {
                        id: resetContentRow
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "restart_alt"
                            iconSize: 16
                            color: resetBtn.hovered ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Reset")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: resetBtn.hovered ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                RippleButton {
                    id: doneBtn
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 34
                    implicitWidth: 80
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    onClicked: {
                        root.editorOpen = false;
                    }

                    contentItem: StyledText {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("Done")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    component SettingRow: RowLayout {
        id: row
        required property string label
        required property int value
        property int minValue: 1
        property int maxValue: 100
        property string suffix: ""
        signal valueModified(int newVal)

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        spacing: 6

        function stepBy(delta) {
            let next = Math.max(row.minValue, Math.min(row.maxValue, row.value + delta));
            if (next !== row.value) {
                row.valueModified(next);
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            verticalAlignment: Text.AlignVCenter
            text: row.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight

            MouseArea {
                anchors.fill: parent
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) row.stepBy(1);
                    else if (wheel.angleDelta.y < 0) row.stepBy(-1);
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            // Minus button
            RippleButton {
                id: minusBtn
                implicitWidth: 30
                implicitHeight: 30
                padding: 0
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0
                Layout.alignment: Qt.AlignVCenter
                buttonRadius: Appearance.rounding.verysmall
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                enabled: row.value > row.minValue

                Timer {
                    id: minusRepeatTimer
                    interval: 400
                    repeat: true
                    running: false
                    onTriggered: {
                        interval = 60;
                        row.stepBy(-1);
                    }
                }

                onDownChanged: {
                    if (down && enabled) {
                        row.stepBy(-1);
                        minusRepeatTimer.interval = 400;
                        minusRepeatTimer.start();
                    } else {
                        minusRepeatTimer.stop();
                    }
                }

                contentItem: MaterialSymbol {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "remove"
                    iconSize: 16
                    color: minusBtn.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                }
            }

            // Value box with wheel handler
            Item {
                implicitWidth: 60
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) row.stepBy(1);
                        else if (wheel.angleDelta.y < 0) row.stepBy(-1);
                    }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: row.value
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        visible: row.suffix.trim().length > 0
                        Layout.alignment: Qt.AlignVCenter
                        text: row.suffix.trim()
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Plus button
            RippleButton {
                id: plusBtn
                implicitWidth: 30
                implicitHeight: 30
                padding: 0
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0
                Layout.alignment: Qt.AlignVCenter
                buttonRadius: Appearance.rounding.verysmall
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                enabled: row.value < row.maxValue

                Timer {
                    id: plusRepeatTimer
                    interval: 400
                    repeat: true
                    running: false
                    onTriggered: {
                        interval = 60;
                        row.stepBy(1);
                    }
                }

                onDownChanged: {
                    if (down && enabled) {
                        row.stepBy(1);
                        plusRepeatTimer.interval = 400;
                        plusRepeatTimer.start();
                    } else {
                        plusRepeatTimer.stop();
                    }
                }

                contentItem: MaterialSymbol {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "add"
                    iconSize: 16
                    color: plusBtn.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
                }
            }
        }
    }
}
