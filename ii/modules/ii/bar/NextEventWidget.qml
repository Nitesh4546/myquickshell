pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property bool vertical: false
    property int useShortenedForm: 0

    property var currentItem: null
    property var allUpcoming: []
    property bool hasItem: currentItem !== null
    property bool isUrgent: false
    property string displayText: ""
    property string verticalBadgeText: ""
    property string iconName: "event"
    property string tooltipText: ""

    readonly property real configuredMaxWidth: Config.options?.bar?.nextEvent?.maxWidth ?? 220
    readonly property bool borderless: Config.options?.bar?.borderless ?? false

    // Appearance colors
    readonly property color colBg: isUrgent
        ? Appearance.colors.colPrimaryContainer
        : (borderless ? "transparent" : Appearance.colors.colLayer1)

    readonly property color colBgHover: isUrgent
        ? Appearance.colors.colPrimaryContainerHover
        : Appearance.colors.colLayer1Hover

    readonly property color colRipple: isUrgent
        ? Appearance.colors.colPrimaryContainerActive
        : Appearance.colors.colLayer1Active

    readonly property color colForeground: isUrgent
        ? Appearance.colors.colOnPrimaryContainer
        : Appearance.colors.colOnLayer1

    implicitHeight: {
        if (!hasItem) return 0;
        if (vertical) return 42;
        return Appearance.sizes.barHeight;
    }
    implicitWidth: {
        if (!hasItem) return 0;
        if (vertical) return Appearance.sizes.baseVerticalBarWidth - 16;
        return Math.min(configuredMaxWidth, contentRow.implicitWidth + 24);
    }

    visible: (hasItem || implicitWidth > 0) && (vertical || useShortenedForm === 0)
    opacity: hasItem ? 1.0 : 0.0
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Refresh synchronization
    Timer {
        id: alignTimer
        interval: Math.max(100, 30000 - (Date.now() % 30000))
        repeat: false
        running: true
        onTriggered: {
            root.updateItems();
            refreshTimer.start();
        }
    }

    Timer {
        id: refreshTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: {
            root.updateItems();
            let drift = Date.now() % 30000;
            if (drift > 1000 && drift < 29000) {
                interval = 30000 - drift;
            } else if (interval !== 30000) {
                interval = 30000;
            }
        }
    }

    Connections {
        target: CalendarService
        function onLocalEventsChanged() { root.updateItems(); }
    }

    Connections {
        target: Todo
        function onListChanged() { root.updateItems(); }
    }

    Connections {
        target: DateTime.clock
        function onDateChanged() { root.updateItems(); }
    }

    Component.onCompleted: root.updateItems()

    function handleClick() {
        if (!root.currentItem) return;
        if (root.currentItem.itemType === "event") {
            let timetableEnabled = Config.options?.cheatsheet?.showTimetable ?? true;
            if (timetableEnabled) {
                GlobalStates.openCheatsheetTab(2);
            } else {
                if (GlobalStates.sidebarRightOpen && Persistent.states.sidebar.bottomGroup.tab === 0 && !Persistent.states.sidebar.bottomGroup.collapsed) {
                    GlobalStates.sidebarRightOpen = false;
                } else {
                    Persistent.states.sidebar.bottomGroup.tab = 0;
                    Persistent.states.sidebar.bottomGroup.collapsed = false;
                    GlobalStates.sidebarRightOpen = true;
                }
            }
        } else if (root.currentItem.itemType === "task") {
            if (GlobalStates.sidebarRightOpen && Persistent.states.sidebar.bottomGroup.tab === 1 && !Persistent.states.sidebar.bottomGroup.collapsed) {
                GlobalStates.sidebarRightOpen = false;
            } else {
                Persistent.states.sidebar.bottomGroup.tab = 1;
                Persistent.states.sidebar.bottomGroup.collapsed = false;
                GlobalStates.sidebarRightOpen = true;
            }
        }
    }

    function updateItems() {
        let now = new Date();
        let nowMs = now.getTime();
        let hours = Config.options?.bar?.nextEvent?.lookaheadHours ?? 12;
        hours = Math.max(1, Math.min(24, hours));
        let lookaheadMs = hours * 3600 * 1000;
        let endMs = nowMs + lookaheadMs;
        let includeAllDay = Config.options?.bar?.nextEvent?.includeAllDay ?? false;
        let includeTasks = Config.options?.bar?.nextEvent?.includeTasks ?? true;
        let tf = Config.options?.time?.format ?? "hh:mm";

        let events = CalendarService ? CalendarService.nextItems(now, lookaheadMs, includeAllDay) : [];

        let tasks = [];
        if (includeTasks && Todo && Todo.list && Todo.list.length > 0) {
            for (let t of Todo.list) {
                if (!t || t.done || !t.due) continue;
                let d = Todo.dueDate(t);
                if (!d || isNaN(d.getTime())) continue;
                let dMs = d.getTime();

                // Exclude overdue tasks
                if (dMs < nowMs) continue;

                // Must be within lookahead window
                if (dMs > endMs) continue;

                let isDateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.test(String(t.due).trim());

                tasks.push({
                    "id": t.id,
                    "title": t.content || Translation.tr("Task"),
                    "content": t.content || Translation.tr("Task"),
                    "dueTime": d,
                    "isDateOnly": isDateOnly,
                    "itemType": "task",
                    "inProgress": false,
                    "start": d,
                    "end": d,
                    "relevantTime": dMs
                });
            }
        }

        let candidates = [];
        for (let ev of events) {
            candidates.push({
                "id": ev.id,
                "title": ev.title,
                "description": ev.description,
                "start": ev.start,
                "end": ev.end,
                "allDay": ev.allDay,
                "inProgress": ev.inProgress,
                "itemType": "event",
                "color": ev.color,
                "recurring": ev.recurring,
                "relevantTime": ev.inProgress ? 0 : ev.start.getTime()
            });
        }

        for (let tk of tasks) {
            candidates.push(tk);
        }

        // Sort candidates:
        // When events or tasks overlap, prioritize the one that is about to start over the one that will end.
        candidates.sort((a, b) => {
            let aStart = a.start.getTime();
            let bStart = b.start.getTime();
            let aEnd = a.end.getTime();
            let bEnd = b.end.getTime();

            // Case 1: Both already started (both in-progress)
            if (a.inProgress && b.inProgress) {
                // The one ending sooner comes first
                if (aEnd !== bEnd) return aEnd - bEnd;
                return (a.itemType === "event" ? 0 : 1) - (b.itemType === "event" ? 0 : 1);
            }

            // Case 2: One in-progress, one upcoming
            if (a.inProgress && !b.inProgress) {
                // If they overlap (b starts at or before a ends), b is about to start -> b wins
                if (bStart <= aEnd) return 1;
                // No overlap: a is active now and ends before b starts -> a wins
                return -1;
            }

            if (!a.inProgress && b.inProgress) {
                // If they overlap (a starts at or before b ends), a is about to start -> a wins
                if (aStart <= bEnd) return -1;
                // No overlap: b is active now and ends before a starts -> b wins
                return 1;
            }

            // Case 3: Both upcoming
            // Earliest start / due time comes first (the one about to start sooner)
            if (aStart !== bStart) {
                return aStart - bStart;
            }
            // If starting at the same time, earlier end time comes first
            if (aEnd !== bEnd) {
                return aEnd - bEnd;
            }
            return (a.itemType === "event" ? 0 : 1) - (b.itemType === "event" ? 0 : 1);
        });

        root.allUpcoming = candidates;

        if (candidates.length === 0) {
            root.currentItem = null;
            root.displayText = "";
            root.verticalBadgeText = "";
            root.iconName = "event";
            root.isUrgent = false;
            root.tooltipText = "";
            return;
        }

        let item = candidates[0];
        root.currentItem = item;

        // Build display text and icon
        if (item.itemType === "event") {
            if (item.inProgress) {
                if (item.allDay) {
                    root.iconName = "event";
                    root.displayText = Translation.tr("Today: %1").arg(item.title);
                    root.verticalBadgeText = Translation.tr("Today");
                    root.isUrgent = false;
                } else {
                    root.iconName = "play_circle";
                    root.isUrgent = false;
                    let diffMs = item.end.getTime() - nowMs;
                    let minsLeft = Math.max(1, Math.round(diffMs / 60000));
                    if (minsLeft <= 60) {
                        root.displayText = Translation.tr("%1 · ends in %2m").arg(item.title).arg(minsLeft);
                        root.verticalBadgeText = `${minsLeft}m`;
                    } else {
                        root.displayText = Translation.tr("%1 · ends at %2").arg(item.title).arg(Qt.formatTime(item.end, tf));
                        root.verticalBadgeText = Qt.formatTime(item.end, tf);
                    }
                }
            } else {
                root.iconName = "event";
                let startDiffMs = item.start.getTime() - nowMs;
                let minsUntil = Math.max(1, Math.round(startDiffMs / 60000));
                let isToday = (item.start.toDateString() === now.toDateString());

                root.isUrgent = (startDiffMs <= 10 * 60 * 1000 && startDiffMs >= 0);

                if (item.allDay) {
                    root.isUrgent = false;
                    if (isToday) {
                        root.displayText = Translation.tr("Today: %1").arg(item.title);
                        root.verticalBadgeText = Translation.tr("Today");
                    } else {
                        root.displayText = Translation.tr("Tomorrow · %1").arg(item.title);
                        root.verticalBadgeText = Translation.tr("Tmw");
                    }
                } else if (minsUntil < 60) {
                    root.displayText = Translation.tr("%1 in %2 min").arg(item.title).arg(minsUntil);
                    root.verticalBadgeText = `${minsUntil}m`;
                } else if (isToday) {
                    root.displayText = Translation.tr("%1 at %2").arg(item.title).arg(Qt.formatTime(item.start, tf));
                    root.verticalBadgeText = Qt.formatTime(item.start, tf);
                } else {
                    root.displayText = Translation.tr("Tomorrow %1 · %2").arg(Qt.formatTime(item.start, tf)).arg(item.title);
                    root.verticalBadgeText = Translation.tr("Tmw");
                }
            }
        } else if (item.itemType === "task") {
            root.iconName = "task_alt";
            let dueDiffMs = item.dueTime.getTime() - nowMs;
            let minsUntil = Math.max(1, Math.round(dueDiffMs / 60000));
            let isToday = (item.dueTime.toDateString() === now.toDateString());
            root.isUrgent = (!item.isDateOnly && dueDiffMs <= 10 * 60 * 1000 && dueDiffMs >= 0);

            if (item.isDateOnly) {
                root.displayText = Translation.tr("Task: %1 · today").arg(item.content);
                root.verticalBadgeText = isToday ? Translation.tr("Today") : Translation.tr("Due");
            } else if (minsUntil < 60) {
                root.displayText = Translation.tr("Task: %1 · %2m").arg(item.content).arg(minsUntil);
                root.verticalBadgeText = `${minsUntil}m`;
            } else if (isToday) {
                root.displayText = Translation.tr("Task: %1 · %2").arg(item.content).arg(Qt.formatTime(item.dueTime, tf));
                root.verticalBadgeText = Qt.formatTime(item.dueTime, tf);
            } else {
                root.displayText = Translation.tr("Task: %1 · %2").arg(item.content).arg(Qt.formatTime(item.dueTime, tf));
                root.verticalBadgeText = Translation.tr("Tmw");
            }
        }

        // Build hover tooltip
        let lines = [];
        let mainTitle = item.itemType === "task" ? item.content : item.title;
        lines.push(mainTitle);

        if (item.itemType === "event") {
            if (item.allDay) {
                lines.push(Translation.tr("All day"));
            } else {
                let isTomorrow = item.start.toDateString() !== now.toDateString();
                let prefix = isTomorrow ? (Translation.tr("Tomorrow") + " ") : "";
                lines.push(`${prefix}${Qt.formatTime(item.start, tf)} – ${Qt.formatTime(item.end, tf)}`);
            }
        } else {
            if (item.isDateOnly) {
                lines.push(Translation.tr("Due today"));
            } else {
                lines.push(Translation.tr("Due at %1").arg(Qt.formatTime(item.dueTime, tf)));
            }
        }

        if (candidates.length > 1) {
            lines.push("");
            lines.push(Translation.tr("Upcoming:"));
            let maxNext = Math.min(3, candidates.length);
            for (let i = 1; i < maxNext; i++) {
                let c = candidates[i];
                let timeStr = "";
                if (c.itemType === "event") {
                    timeStr = c.allDay ? Translation.tr("All day") : Qt.formatTime(c.start, tf);
                    lines.push(`• ${c.title} (${timeStr})`);
                } else {
                    timeStr = c.isDateOnly ? Translation.tr("today") : Qt.formatTime(c.dueTime, tf);
                    lines.push(`• [Task] ${c.content} (${timeStr})`);
                }
            }
        }

        root.tooltipText = lines.join("\n");
    }

    property bool tooltipTimedOut: false

    Timer {
        id: tooltipTimer
        interval: 450
        repeat: false
        running: mouseArea.containsMouse && root.hasItem && !Config.options.bar.tooltips.clickToShow
        onTriggered: root.tooltipTimedOut = true
    }

    // Entire widget area is 100% clickable with no deadzones
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.tooltipTimedOut = false;
            root.handleClick();
        }

        onContainsMouseChanged: {
            if (!containsMouse) {
                root.tooltipTimedOut = false;
            }
        }

        onPressedChanged: {
            if (pressed) {
                root.tooltipTimedOut = false;
            }
        }

        Rectangle {
            id: pillBackground
            anchors {
                fill: parent
                topMargin: root.vertical ? 0 : 4
                bottomMargin: root.vertical ? 0 : 4
            }
            radius: Appearance.rounding.small
            color: mouseArea.pressed
                ? root.colRipple
                : (mouseArea.containsMouse ? root.colBgHover : root.colBg)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                }
            }

            RowLayout {
                id: contentRow
                visible: !root.vertical
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: root.iconName
                    iconSize: Appearance.font.pixelSize.large
                    color: root.colForeground
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }
                }

                StyledText {
                    id: labelText
                    visible: !root.vertical
                    text: root.displayText
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.colForeground
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                    Layout.maximumWidth: Math.max(50, root.configuredMaxWidth - 40)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }
                }
            }

            ColumnLayout {
                id: verticalContentCol
                visible: root.vertical
                anchors.centerIn: parent
                spacing: 0

                MaterialSymbol {
                    text: root.iconName
                    iconSize: 18
                    color: root.colForeground
                    Layout.alignment: Qt.AlignHCenter

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }
                }

                StyledText {
                    visible: root.verticalBadgeText.length > 0
                    text: root.verticalBadgeText
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: root.colForeground
                    Layout.alignment: Qt.AlignHCenter
                    maximumLineCount: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                        }
                    }
                }
            }
        }

        readonly property var calculatedAnchorEdges: {
            if (Config.options.bar.vertical) {
                return Config.options.bar.bottom ? Edges.Left : Edges.Right;
            } else {
                return Config.options.bar.bottom ? Edges.Top : Edges.Bottom;
            }
        }

        // Click-through popup tooltip anchored beside the bar (never blocks mouse clicks)
        PopupToolTip {
            id: tooltip
            text: root.tooltipText
            extraVisibleCondition: root.hasItem && root.tooltipText.length > 0 && root.tooltipTimedOut && !mouseArea.pressed
            alternativeVisibleCondition: extraVisibleCondition
            anchorEdges: mouseArea.calculatedAnchorEdges
            anchorGravity: mouseArea.calculatedAnchorEdges
        }
    }
}
