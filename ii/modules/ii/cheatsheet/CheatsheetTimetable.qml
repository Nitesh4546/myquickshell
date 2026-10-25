import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common.functions

Item {
    id: root
    property real spacing: 8
    property color backgroundColor: "transparent"
    property bool showAddDialog: false
    property bool showViewDialog: false
    property var viewingEvent: null
    property var viewingDayDate: null
    property int dialogMargins: 20
    property int fabSize: 48
    property int fabMargins: 14

    property int startHour: 0
    property int startMinute: 0
    property int endHour: 24
    property int slotDuration: 60 // in minutes
    property int slotHeight: 60 // in pixels
    property int timeColumnWidth: 100
    property real maxContentWidth: 2000

    readonly property int totalSlots: Math.floor(((endHour * 60) - (startHour * 60 + startMinute)) / slotDuration)
    readonly property real pixelsPerMinute: slotHeight / slotDuration
    readonly property int contentHeight: totalSlots * slotHeight

    property real maxHeight: 700
    property real toolbarHeight: 48
    property real headerHeight: 64 // Material 3 standard header height
    property real currentTimeY: -1
    property bool initialScrollApplied: false
    readonly property real dayColumnWidth: Math.min(180, (maxContentWidth - timeColumnWidth - (days.length + 1) * spacing) / days.length)
    readonly property int currentDayIndex: CalendarService.weekOffset === 0 ? (DateTime.clock.date.getDay() - root.firstDayOfWeek + 7) % 7 : -1
    readonly property int firstDayOfWeek: {
        let opt = Config.options?.time?.firstDayOfWeek;
        return (opt !== undefined && opt >= 1 && opt <= 7) ? opt : 1;
    }

    // Drag & Drop / Resize state
    property bool isDraggingEvent: false
    property string dragMode: "" // "" | "move" | "resize"
    property var activeDragEvent: null
    property string activeDragEventId: ""
    property date dragSourceDayDate: new Date()
    property int dragSourceDayIndex: 0
    property int dragTargetDayIndex: 0
    property int dragInitialStartMin: 0
    property int dragInitialEndMin: 0
    property int dragDurationMin: 60
    property int dragTargetStartMin: 0
    property int dragTargetEndMin: 60
    property real dragGhostX: 0
    property real dragGhostY: 0
    property real dragGhostWidth: 100
    property real dragGhostHeight: 48
    property real dragGrabOffsetX: 0
    property real dragGrabOffsetY: 0
    property real lastScenePointerX: 0
    property real lastScenePointerY: 0

    implicitWidth: Math.min(maxContentWidth, timeColumnWidth + (dayColumnWidth * days.length) + ((days.length + 1) * spacing))
    implicitHeight: Math.min(toolbarHeight + headerHeight + dateTasksStripHeight + contentHeight, maxHeight)
    property var days: CalendarService.eventsInWeek
    readonly property var tasksByDay: root.computeTasksByDay(Todo.list, root.days, Config.options?.cheatsheet?.showTasksInTimetable)
    readonly property bool hasDateOnlyTasks: {
        if (!Config.options?.cheatsheet?.showTasksInTimetable) return false;
        if (!root.tasksByDay || root.tasksByDay.length === 0) return false;
        for (let i = 0; i < root.tasksByDay.length; i++) {
            if (root.tasksByDay[i].dateTasks && root.tasksByDay[i].dateTasks.length > 0)
                return true;
        }
        return false;
    }
    readonly property int maxDateOnlyChipsCount: {
        if (!hasDateOnlyTasks) return 0;
        let maxC = 0;
        for (let i = 0; i < root.tasksByDay.length; i++) {
            let len = root.tasksByDay[i].dateTasks ? root.tasksByDay[i].dateTasks.length : 0;
            let chips = len <= 2 ? len : 3;
            if (chips > maxC) maxC = chips;
        }
        return maxC;
    }
    readonly property real dateTasksStripContentHeight: {
        if (maxDateOnlyChipsCount === 1) return 26;
        if (maxDateOnlyChipsCount === 2) return 56;
        if (maxDateOnlyChipsCount >= 3) return 82;
        return 0;
    }
    readonly property real dateTasksStripHeight: hasDateOnlyTasks ? (dateTasksStripContentHeight + 8) : 0

    onHasDateOnlyTasksChanged: {
        Qt.callLater(root.scrollToCurrentTime);
    }

    function computeTasksByDay(todoList, daysList, showTasksEnabled) {
        if (!showTasksEnabled || !todoList || !daysList || daysList.length === 0) {
            return [];
        }

        let result = [];
        for (let i = 0; i < daysList.length; i++) {
            result.push({
                "date": daysList[i].date,
                "dateTasks": [],
                "timedTasks": []
            });
        }

        for (let idx = 0; idx < todoList.length; idx++) {
            let task = todoList[idx];
            if (!task || task.done || !task.due) continue;

            let dueStr = String(task.due).trim();
            if (!dueStr) continue;

            let dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dueStr);
            let isDateOnly = !!dateOnlyMatch;
            let dueYear, dueMonth, dueDateNum, dueDt;
            let dueMinutes = 0;

            if (isDateOnly) {
                dueYear = parseInt(dateOnlyMatch[1], 10);
                dueMonth = parseInt(dateOnlyMatch[2], 10) - 1;
                dueDateNum = parseInt(dateOnlyMatch[3], 10);
                dueDt = new Date(dueYear, dueMonth, dueDateNum, 23, 59, 59, 999);
            } else {
                dueDt = new Date(dueStr);
                if (isNaN(dueDt.getTime())) continue;
                dueYear = dueDt.getFullYear();
                dueMonth = dueDt.getMonth();
                dueDateNum = dueDt.getDate();
                dueMinutes = dueDt.getHours() * 60 + dueDt.getMinutes();
            }

            for (let d = 0; d < daysList.length; d++) {
                let dayEntry = daysList[d];
                if (!dayEntry || !dayEntry.date) continue;
                let dayDate = (dayEntry.date instanceof Date) ? dayEntry.date : new Date(dayEntry.date);
                if (isNaN(dayDate.getTime())) continue;

                if (dayDate.getFullYear() === dueYear &&
                    dayDate.getMonth() === dueMonth &&
                    dayDate.getDate() === dueDateNum) {

                    let isOverdue = Todo.isOverdue(task);
                    let isToday = Todo.isDueToday(task);

                    let entry = {
                        "task": task,
                        "originalIndex": idx,
                        "id": task.id || "",
                        "content": task.content || "",
                        "due": task.due,
                        "dueDt": dueDt,
                        "dueMinutes": dueMinutes,
                        "isDateOnly": isDateOnly,
                        "isOverdue": isOverdue,
                        "isToday": isToday,
                        "offsetCol": 0
                    };

                    if (isDateOnly) {
                        result[d].dateTasks.push(entry);
                    } else {
                        result[d].timedTasks.push(entry);
                    }
                    break;
                }
            }
        }

        for (let d = 0; d < result.length; d++) {
            let timed = result[d].timedTasks;
            timed.sort(function(a, b) { return a.dueMinutes - b.dueMinutes; });
            for (let i = 0; i < timed.length; i++) {
                if (i > 0 && Math.abs(timed[i].dueMinutes - timed[i - 1].dueMinutes) < 25) {
                    timed[i].offsetCol = (timed[i - 1].offsetCol === 0) ? 1 : 0;
                } else {
                    timed[i].offsetCol = 0;
                }
            }
        }

        return result;
    }

    function formatTaskTooltip(taskItem) {
        if (!taskItem) return "";
        let lines = [taskItem.content || Translation.tr("Task")];

        let tf = Config.options?.time?.format ?? "hh:mm";
        if (taskItem.isDateOnly) {
            let loc = Qt.locale();
            let dateStr = taskItem.dueDt ? `${taskItem.dueDt.getDate()} ${loc.monthName(taskItem.dueDt.getMonth(), Locale.ShortFormat)}` : taskItem.due;
            lines.push(Translation.tr("Due %1").arg(dateStr));
        } else if (taskItem.dueDt) {
            let loc = Qt.locale();
            let dateStr = `${taskItem.dueDt.getDate()} ${loc.monthName(taskItem.dueDt.getMonth(), Locale.ShortFormat)}`;
            let timeStr = Qt.formatTime(taskItem.dueDt, tf);
            lines.push(Translation.tr("Due %1, %2").arg(dateStr, timeStr));
        }

        if (taskItem.task && taskItem.task.priority) {
            let pName = taskItem.task.priority === 3 ? Translation.tr("High") :
                        taskItem.task.priority === 2 ? Translation.tr("Medium") :
                        Translation.tr("Low");
            lines.push(Translation.tr("Priority: %1").arg(pName));
        }

        lines.push(Translation.tr("Edit in the To Do sidebar"));
        return lines.join("\n");
    }

    function formatDateTasksTooltip(dayTasks) {
        if (!dayTasks || dayTasks.length === 0) return "";
        let lines = [Translation.tr("Tasks for this day:")];
        for (let i = 0; i < dayTasks.length; i++) {
            lines.push("• " + (dayTasks[i].content || Translation.tr("Task")));
        }
        lines.push(Translation.tr("Edit in the To Do sidebar"));
        return lines.join("\n");
    }
    readonly property int allDayChipHeight: 36
    readonly property int allDayChipSpacing: 6
    readonly property int maxAllDayEventCount: {
        if (!root.days || root.days.length === 0)
            return 0;

        var maxCount = 0;
        for (var i = 0; i < root.days.length; i++) {
            var day = root.days[i];
            if (!day || !day.events)
                continue;

            var count = 0;
            for (var j = 0; j < day.events.length; j++) {
                if (root.isAllDayEvent(day.events[j]))
                    count++;
            }
            if (count > maxCount)
                maxCount = count;
        }
        return maxCount;
    }
    readonly property bool hasAllDayEvents: maxAllDayEventCount > 0
    readonly property color todayHighlightFill: withOpacity(Appearance.colors.colPrimary, 0.12)
    readonly property color todayHighlightBorder: withOpacity(Appearance.colors.colPrimary, 0.28)

    function updateCurrentTimeLine() {
        let time = DateTime.clock.date;
        let hours = time.getHours();
        let minutes = time.getMinutes();

        let baseTotalMinutes = root.startHour * 60 + root.startMinute;
        let currentTotalMinutes = hours * 60 + minutes;
        let diffMinutes = currentTotalMinutes - baseTotalMinutes;

        currentTimeY = diffMinutes * root.pixelsPerMinute;
    }

    function isSameDate(d1, d2) {
        if (!d1 || !d2) return false;
        let a = new Date(d1);
        let b = new Date(d2);
        return a.getFullYear() === b.getFullYear() &&
               a.getMonth() === b.getMonth() &&
               a.getDate() === b.getDate();
    }

    function withOpacity(colorValue, alpha) {
        if (!colorValue)
            return Qt.rgba(0, 0, 0, alpha);

        let color = Qt.color(colorValue);
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function isAllDayEvent(event) {
        if (!event)
            return false;

        if (event.allDay)
            return true;

        let start = event.start || "";
        let end = event.end || "";

        return (start === "00:00" && end === "23:59") ||
               (start === "00:00" && end === "00:00") ||
               (!event.start && !event.end);
    }

    function getAllDayEvents(events) {
        if (!events || !events.length)
            return [];

        return events.filter(function(evt) { return root.isAllDayEvent(evt); });
    }

    function getTimedEvents(events) {
        if (!events || !events.length)
            return [];

        return events.filter(function(evt) { return !root.isAllDayEvent(evt); });
    }

    // Groups overlapping events into clusters, then greedily assigns each
    // event a column within its cluster (classic "meeting rooms" layout,
    // same technique Google Calendar uses). Returns each event annotated
    // with .col (its column index) and .cols (total columns in its cluster).
    function layoutOverlaps(events) {
        if (!events || events.length === 0)
            return [];

        let items = events.map(function(e) {
            return { "ref": e, "startMin": root.parseTimeToMinutes(e.start), "endMin": root.parseTimeToMinutes(e.end) };
        }).filter(function(e) { return e.startMin !== null && e.endMin !== null; });

        items.sort(function(a, b) { return a.startMin - b.startMin; });

        let clusters = [];
        let current = [];
        let clusterEnd = -1;
        for (const item of items) {
            if (current.length === 0 || item.startMin < clusterEnd) {
                current.push(item);
                clusterEnd = Math.max(clusterEnd, item.endMin);
            } else {
                clusters.push(current);
                current = [item];
                clusterEnd = item.endMin;
            }
        }
        if (current.length > 0) clusters.push(current);

        let results = [];
        for (const cluster of clusters) {
            let columnEnds = []; // end time currently occupying each column
            let placements = [];
            for (const item of cluster) {
                let placedCol = -1;
                for (let c = 0; c < columnEnds.length; c++) {
                    if (columnEnds[c] <= item.startMin) {
                        placedCol = c;
                        break;
                    }
                }
                if (placedCol === -1) {
                    placedCol = columnEnds.length;
                    columnEnds.push(item.endMin);
                } else {
                    columnEnds[placedCol] = item.endMin;
                }
                placements.push({ "item": item, "col": placedCol });
            }
            const totalCols = columnEnds.length;
            for (const p of placements) {
                let merged = Object.assign({}, p.item.ref);
                merged.col = p.col;
                merged.cols = totalCols;
                results.push(merged);
            }
        }
        return results;
    }

    function formatEventTooltip(event) {
        if (!event)
            return "";

        let title = event.title || qsTr("Event");
        if (root.isAllDayEvent(event))
            return title + "\n" + qsTr("All day");

        let startTotal = root.parseTimeToMinutes(event.start);
        let endTotal = root.parseTimeToMinutes(event.end);

        let formatTime = (totalMinutes) => {
            if (totalMinutes === null)
                return "";
            let hour = Math.floor(totalMinutes / 60);
            let minute = totalMinutes % 60;
            let date = new Date();
            date.setHours(hour, minute, 0, 0);
            return Qt.formatTime(date, Config.options?.time.format ?? "hh:mm");
        };

        let startStr = formatTime(startTotal) || event.start || "";
        let endStr = formatTime(endTotal) || event.end || "";
        let range = startStr && endStr ? startStr + " - " + endStr : startStr || endStr;
        return range ? title + "\n" + range : title;
    }

    function parseTimeToMinutes(timeStr) {
        if (!timeStr)
            return null;
        let parts = timeStr.split(":");
        if (parts.length < 2)
            return null;
        let hour = parseInt(parts[0]);
        let minute = parseInt(parts[1]);
        if (isNaN(hour) || isNaN(minute))
            return null;
        return hour * 60 + minute;
    }

    function scrollToCurrentTime() {
        if (!styledFlickable)
            return;

        if (styledFlickable.height <= 0) {
            Qt.callLater(root.scrollToCurrentTime);
            return;
        }

        root.updateCurrentTimeLine();

        let targetY = root.currentTimeY - 24;
        let maxScroll = Math.max(0, styledFlickable.contentHeight - styledFlickable.height);
        let finalY = Math.max(0, Math.min(targetY, maxScroll));

        styledFlickable.contentY = finalY;
        if (styledFlickable.scrollTargetY !== undefined) {
            styledFlickable.scrollTargetY = finalY;
        }
    }

    function maybeApplyInitialScroll() {
        if (root.initialScrollApplied)
            return;

        if (SwipeView.view && !SwipeView.isCurrentItem)
            return;

        if (!styledFlickable || styledFlickable.height <= 0) {
            Qt.callLater(root.maybeApplyInitialScroll);
            return;
        }

        root.scrollToCurrentTime();
        root.initialScrollApplied = true;
    }

    SwipeView.onIsCurrentItemChanged: {
        if (SwipeView.isCurrentItem) {
            CalendarService.goToToday();
            root.initialScrollApplied = false;
            Qt.callLater(root.maybeApplyInitialScroll);
        }
    }

    Connections {
        target: DateTime.clock
        function onDateChanged() {
            root.updateCurrentTimeLine();
        }
    }

    Component.onCompleted: {
        CalendarService.goToToday();
        root.updateCurrentTimeLine();
        if (typeof Todo.refresh === "function") {
            Todo.refresh();
        }
        Qt.callLater(root.maybeApplyInitialScroll);
    }

    function formatTimeMinutes(totalMinutes) {
        if (totalMinutes === null || totalMinutes === undefined) return "";
        let hour = Math.floor(totalMinutes / 60);
        let minute = totalMinutes % 60;
        if (hour === 24 && minute === 0) return "24:00";
        let date = new Date();
        date.setHours(hour, minute, 0, 0);
        return Qt.formatTime(date, Config.options?.time.format ?? "hh:mm");
    }

    function formattedDragRange() {
        return formatTimeMinutes(root.dragTargetStartMin) + " - " + formatTimeMinutes(root.dragTargetEndMin);
    }

    Timer {
        id: dragAutoScrollTimer
        interval: 25
        repeat: true
        running: root.isDraggingEvent
        onTriggered: {
            if (!root.isDraggingEvent || !styledFlickable) return;
            let ptInFlick = styledFlickable.mapFromItem(null, root.lastScenePointerX, root.lastScenePointerY);
            let edgeZone = 48;
            let scrollStep = 12;
            let maxScroll = Math.max(0, styledFlickable.contentHeight - styledFlickable.height);

            if (ptInFlick.y < edgeZone && styledFlickable.contentY > 0) {
                styledFlickable.contentY = Math.max(0, styledFlickable.contentY - scrollStep);
                root.updateDragFromPointer(root.lastScenePointerX, root.lastScenePointerY);
            } else if (ptInFlick.y > styledFlickable.height - edgeZone && styledFlickable.contentY < maxScroll) {
                styledFlickable.contentY = Math.min(maxScroll, styledFlickable.contentY + scrollStep);
                root.updateDragFromPointer(root.lastScenePointerX, root.lastScenePointerY);
            }
        }
    }

    function startMoveDrag(chipItem, eventData, dayDate, centroid) {
        if (!eventData || !eventData.id) return;
        if (root.showAddDialog || root.showViewDialog) return;

        let startMin = root.parseTimeToMinutes(eventData.start);
        let endMin = root.parseTimeToMinutes(eventData.end);
        if (startMin === null || endMin === null) return;
        let duration = Math.max(15, endMin - startMin);

        root.isDraggingEvent = true;
        root.dragMode = "move";
        root.activeDragEvent = eventData;
        root.activeDragEventId = eventData.id;
        root.dragSourceDayDate = new Date(dayDate);
        root.dragInitialStartMin = startMin;
        root.dragInitialEndMin = endMin;
        root.dragDurationMin = duration;
        root.dragTargetStartMin = startMin;
        root.dragTargetEndMin = endMin;

        let srcIdx = root.days.findIndex(function(d) { return root.isSameDate(d.date, dayDate); });
        root.dragSourceDayIndex = srcIdx >= 0 ? srcIdx : 0;
        root.dragTargetDayIndex = root.dragSourceDayIndex;

        let chipPos = chipItem.mapToItem(styledFlickable.contentItem, 0, 0);
        root.dragGhostWidth = chipItem.width;
        root.dragGhostHeight = chipItem.height;

        let scenePos = centroid.scenePosition;
        root.lastScenePointerX = scenePos.x;
        root.lastScenePointerY = scenePos.y;

        let ptInContent = styledFlickable.contentItem.mapFromItem(null, scenePos.x, scenePos.y);
        root.dragGrabOffsetX = ptInContent.x - chipPos.x;
        root.dragGrabOffsetY = ptInContent.y - chipPos.y;

        root.dragGhostX = chipPos.x;
        root.dragGhostY = chipPos.y;

        styledFlickable.interactive = false;
    }

    function updateMoveDrag(centroid) {
        if (!root.isDraggingEvent || root.dragMode !== "move") return;
        let scenePos = centroid.scenePosition;
        root.lastScenePointerX = scenePos.x;
        root.lastScenePointerY = scenePos.y;
        root.updateDragFromPointer(scenePos.x, scenePos.y);
    }

    function updateDragFromPointer(sceneX, sceneY) {
        if (!root.isDraggingEvent || !root.activeDragEvent) return;
        let ptInContent = styledFlickable.contentItem.mapFromItem(null, sceneX, sceneY);

        if (root.dragMode === "move") {
            let ptInEvents = eventsRow.mapFromItem(null, sceneX, sceneY);
            let colStride = root.dayColumnWidth + root.spacing;
            let colIdx = Math.floor(ptInEvents.x / colStride);
            root.dragTargetDayIndex = Math.max(0, Math.min(colIdx, root.days.length - 1));

            let desiredTopY = ptInContent.y - root.dragGrabOffsetY;
            let baseTotalMinutes = root.startHour * 60 + root.startMinute;
            let rawMinutes = baseTotalMinutes + (desiredTopY / root.pixelsPerMinute);
            let snappedStart = Math.round(rawMinutes / 15) * 15;
            snappedStart = Math.max(0, Math.min(snappedStart, 1440 - root.dragDurationMin));

            root.dragTargetStartMin = snappedStart;
            root.dragTargetEndMin = snappedStart + root.dragDurationMin;

            let eventsRowInContent = eventsRow.mapToItem(styledFlickable.contentItem, 0, 0);
            let minGhostX = eventsRowInContent.x;
            let maxGhostX = eventsRowInContent.x + eventsRow.width - root.dragGhostWidth;
            root.dragGhostX = Math.max(minGhostX, Math.min(ptInContent.x - root.dragGrabOffsetX, maxGhostX));
            root.dragGhostY = (snappedStart - baseTotalMinutes) * root.pixelsPerMinute;
        } else if (root.dragMode === "resize") {
            let baseTotalMinutes = root.startHour * 60 + root.startMinute;
            let rawMinutes = baseTotalMinutes + (ptInContent.y / root.pixelsPerMinute);
            let snappedEnd = Math.round(rawMinutes / 15) * 15;
            snappedEnd = Math.max(root.dragTargetStartMin + 15, Math.min(snappedEnd, 1440));

            root.dragTargetEndMin = snappedEnd;
            let dur = snappedEnd - root.dragTargetStartMin;
            root.dragGhostHeight = Math.max(dur * root.pixelsPerMinute - 4, 48);
        }
    }

    function finishMoveDrag(translation) {
        if (!root.isDraggingEvent || root.dragMode !== "move") {
            root.cancelDrag();
            return;
        }

        let dayChanged = root.dragTargetDayIndex !== root.dragSourceDayIndex;
        let timeChanged = root.dragTargetStartMin !== root.dragInitialStartMin;

        if (dayChanged || timeChanged) {
            let targetDay = root.days[root.dragTargetDayIndex];
            if (targetDay && targetDay.date) {
                let targetDate = new Date(targetDay.date);
                let sH = Math.floor(root.dragTargetStartMin / 60);
                let sM = root.dragTargetStartMin % 60;
                let eH = Math.floor(root.dragTargetEndMin / 60);
                let eM = root.dragTargetEndMin % 60;

                let newStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), sH, sM, 0, 0);
                let newEnd = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), eH, eM, 0, 0);

                CalendarService.updateLocalEvent(
                    root.activeDragEvent.id,
                    root.activeDragEvent.title,
                    root.activeDragEvent.description,
                    newStart,
                    newEnd,
                    root.activeDragEvent.color,
                    root.activeDragEvent.allDay,
                    root.activeDragEvent.repeat || "none",
                    root.activeDragEvent.repeatUntil || "",
                    root.activeDragEvent.reminder !== undefined ? root.activeDragEvent.reminder : -1
                );
            }
        }

        root.cancelDrag();
    }

    function startResizeDrag(chipItem, eventData, dayDate, mouse) {
        if (!eventData || !eventData.id) return;
        if (root.showAddDialog || root.showViewDialog) return;

        let startMin = root.parseTimeToMinutes(eventData.start);
        let endMin = root.parseTimeToMinutes(eventData.end);
        if (startMin === null || endMin === null) return;

        root.isDraggingEvent = true;
        root.dragMode = "resize";
        root.activeDragEvent = eventData;
        root.activeDragEventId = eventData.id;
        root.dragSourceDayDate = new Date(dayDate);
        root.dragInitialStartMin = startMin;
        root.dragInitialEndMin = endMin;
        root.dragTargetStartMin = startMin;
        root.dragTargetEndMin = endMin;

        let srcIdx = root.days.findIndex(function(d) { return root.isSameDate(d.date, dayDate); });
        root.dragSourceDayIndex = srcIdx >= 0 ? srcIdx : 0;
        root.dragTargetDayIndex = root.dragSourceDayIndex;

        let chipPos = chipItem.mapToItem(styledFlickable.contentItem, 0, 0);
        root.dragGhostX = chipPos.x;
        root.dragGhostY = chipPos.y;
        root.dragGhostWidth = chipItem.width;
        root.dragGhostHeight = chipItem.height;

        let scenePos = chipItem.mapToItem(null, mouse.x, mouse.y);
        root.lastScenePointerX = scenePos.x;
        root.lastScenePointerY = scenePos.y;

        styledFlickable.interactive = false;
    }

    function updateResizeDrag(chipItem, mouse) {
        if (!root.isDraggingEvent || root.dragMode !== "resize") return;
        let scenePos = chipItem.mapToItem(null, mouse.x, mouse.y);
        root.lastScenePointerX = scenePos.x;
        root.lastScenePointerY = scenePos.y;
        root.updateDragFromPointer(scenePos.x, scenePos.y);
    }

    function finishResizeDrag() {
        if (!root.isDraggingEvent || root.dragMode !== "resize") {
            root.cancelDrag();
            return;
        }

        let timeChanged = root.dragTargetEndMin !== root.dragInitialEndMin;
        if (timeChanged) {
            let targetDay = root.days[root.dragTargetDayIndex];
            if (targetDay && targetDay.date) {
                let targetDate = new Date(targetDay.date);
                let sH = Math.floor(root.dragTargetStartMin / 60);
                let sM = root.dragTargetStartMin % 60;
                let eH = Math.floor(root.dragTargetEndMin / 60);
                let eM = root.dragTargetEndMin % 60;

                let newStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), sH, sM, 0, 0);
                let newEnd = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), eH, eM, 0, 0);

                CalendarService.updateLocalEvent(
                    root.activeDragEvent.id,
                    root.activeDragEvent.title,
                    root.activeDragEvent.description,
                    newStart,
                    newEnd,
                    root.activeDragEvent.color,
                    root.activeDragEvent.allDay,
                    root.activeDragEvent.repeat || "none",
                    root.activeDragEvent.repeatUntil || "",
                    root.activeDragEvent.reminder !== undefined ? root.activeDragEvent.reminder : -1
                );
            }
        }

        root.cancelDrag();
    }

    function cancelDrag() {
        root.isDraggingEvent = false;
        root.dragMode = "";
        root.activeDragEvent = null;
        root.activeDragEventId = "";
        if (styledFlickable) styledFlickable.interactive = true;
    }

    // Material 3 surface container
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainer
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            id: toolbarRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.toolbarHeight
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 12

            StyledText {
                text: { CalendarService.weekOffset; return CalendarService.weekRangeLabel(); }
                font.pixelSize: Appearance.font.pixelSize.title
                font.weight: Font.SemiBold
                color: Appearance.colors.colOnSurface
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                RippleButton {
                    id: prevWeekButton
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: CalendarService.prevWeek()

                    ToolTip {
                        visible: prevWeekButton.hovered
                        delay: 250
                        timeout: 0
                        text: Translation.tr("Previous week")
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.title
                        color: Appearance.colors.colOnSurface
                    }
                }

                RippleButton {
                    id: todayButton
                    implicitWidth: todayText.implicitWidth + 24
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    enabled: CalendarService.weekOffset !== 0
                    colBackground: enabled ? Appearance.colors.colSecondaryContainer : "transparent"
                    onClicked: {
                        CalendarService.goToToday();
                        root.scrollToCurrentTime();
                    }

                    ToolTip {
                        visible: todayButton.hovered && todayButton.enabled
                        delay: 250
                        timeout: 0
                        text: Translation.tr("Today")
                    }

                    StyledText {
                        id: todayText
                        anchors.centerIn: parent
                        text: Translation.tr("Today")
                        font.weight: Font.Medium
                        color: todayButton.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOutline
                    }
                }

                RippleButton {
                    id: nextWeekButton
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.rounding.full
                    onClicked: CalendarService.nextWeek()

                    ToolTip {
                        visible: nextWeekButton.hovered
                        delay: 250
                        timeout: 0
                        text: Translation.tr("Next week")
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.title
                        color: Appearance.colors.colOnSurface
                    }
                }
            }
        }

        Row {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            spacing: root.spacing

            Item {
                width: root.timeColumnWidth
                height: root.headerHeight

                // Current time indicator
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(timeHeaderText.implicitWidth + 16, parent.width - 4)
                    height: 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSecondaryContainer

                    StyledText {
                        id: timeHeaderText
                        anchors.centerIn: parent
                        text: DateTime.time
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                    }
                }
            }

            Repeater {
                model: root.days
                delegate: Item {
                    id: dayHeaderItem
                    width: root.dayColumnWidth
                    height: root.headerHeight

                    property date dayDate: modelData.date
                    property var allDayEvents: root.getAllDayEvents(modelData.events)
                    property bool isToday: root.isSameDate(modelData.date, DateTime.clock.date)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 40
                        radius: Appearance.rounding.large
                        border.width: allDayEvents.length > 0 ? 2 : 0
                        border.color: Appearance.colors.colPrimary
                        color: isToday ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHigh
                        StyledText {
                            id: dayTitle
                            anchors.centerIn: parent
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurfaceVariant
                            text: modelData.name
                            elide: Text.ElideRight
                          }
                            
                         HoverHandler {
                                        id: allDayHover
                          }
        

                         Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 4
                            spacing: root.allDayChipSpacing

                            Repeater {
                                model: allDayEvents
                                delegate: Rectangle {
                                    width: parent.width
                                    height: root.allDayChipHeight
                                    color: 'transparent'

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.viewingEvent = modelData;
                                            root.viewingDayDate = dayHeaderItem.dayDate;
                                            root.showViewDialog = true;
                                        }
                                    }

                                    ToolTip {
                                        visible: allDayHover.hovered
                                        delay: 250
                                        timeout: 0
                                        text: root.formatEventTooltip(modelData)
                                    }

                                }
                            }
                        }
                    }
                    }
            }
        }

     

        // Subtle separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Appearance.colors.colOutlineVariant
            Layout.bottomMargin: 8
        }

        // Date-only tasks strip
        Row {
            id: dateTasksStrip
            visible: root.hasDateOnlyTasks
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? root.dateTasksStripHeight : 0
            height: root.dateTasksStripHeight
            Layout.bottomMargin: visible ? 8 : 0
            spacing: root.spacing

            Item {
                width: root.timeColumnWidth
                height: root.dateTasksStripContentHeight

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    StyledText {
                        text: "task_alt"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Translation.tr("Tasks")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            Repeater {
                model: root.tasksByDay
                delegate: Item {
                    id: dayTasksColItem
                    width: root.dayColumnWidth
                    height: root.dateTasksStripContentHeight

                    property var dateTasks: modelData.dateTasks || []

                    HoverHandler {
                        id: stripColHover
                    }

                    ToolTip {
                        visible: stripColHover.hovered && dayTasksColItem.dateTasks.length > 0 && !root.isDraggingEvent
                        delay: 350
                        timeout: 0
                        text: root.formatDateTasksTooltip(dayTasksColItem.dateTasks)
                    }

                    Column {
                        id: dateTasksCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4

                        Repeater {
                            model: dayTasksColItem.dateTasks.slice(0, 2)
                            delegate: Rectangle {
                                id: dateTaskChip
                                width: parent.width
                                height: 26
                                radius: Appearance.rounding.small
                                color: modelData.isOverdue ? Appearance.colors.colErrorContainer :
                                       modelData.isToday ? Appearance.colors.colPrimaryContainer :
                                       Appearance.colors.colSecondaryContainer
                                border.width: 1
                                border.color: modelData.isOverdue ? Appearance.colors.colError :
                                              modelData.isToday ? Appearance.colors.colPrimary :
                                              Appearance.colors.colSecondary

                                readonly property color colContent: modelData.isOverdue ? Appearance.colors.colOnErrorContainer :
                                                                     modelData.isToday ? Appearance.colors.colOnPrimaryContainer :
                                                                     Appearance.colors.colOnSecondaryContainer

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => { mouse.accepted = true; }
                                }

                                HoverHandler {
                                    id: dateChipHover
                                }

                                ToolTip {
                                    visible: dateChipHover.hovered && !root.isDraggingEvent
                                    delay: 200
                                    timeout: 0
                                    text: root.formatTaskTooltip(modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 6
                                    spacing: 4

                                    Item {
                                        implicitWidth: 18
                                        implicitHeight: 18

                                        StyledText {
                                            id: chipCheckIcon
                                            anchors.centerIn: parent
                                            text: "task_alt"
                                            font.family: Appearance.font.family.iconMaterial
                                            font.pixelSize: 15
                                            color: dateTaskChip.colContent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: chipCheckIcon.text = "check"
                                            onExited: chipCheckIcon.text = "task_alt"
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                if (modelData.originalIndex !== undefined && modelData.originalIndex >= 0) {
                                                    Todo.markDone(modelData.originalIndex);
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: !!(modelData.task && modelData.task.priority && Todo.priorityColors && Todo.priorityColors[modelData.task.priority])
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: (Todo.priorityColors && modelData.task && Todo.priorityColors[modelData.task.priority]) ? Todo.priorityColors[modelData.task.priority] : "transparent"
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.content
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: dateTaskChip.colContent
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }

                        // "+N" chip if > 2 tasks
                        Rectangle {
                            visible: dayTasksColItem.dateTasks.length > 2
                            width: parent.width
                            height: 22
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colSurfaceContainerHigh
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant

                            HoverHandler {
                                id: moreChipHover
                            }

                            ToolTip {
                                visible: moreChipHover.hovered && !root.isDraggingEvent
                                delay: 200
                                timeout: 0
                                text: root.formatDateTasksTooltip(dayTasksColItem.dateTasks)
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("+%1 more").arg(dayTasksColItem.dateTasks.length - 2)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }
                }
            }
        }

        // TODO: replace or check for StyledScrollBar
        StyledFlickable {
            id: styledFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: root.contentHeight
            topMargin: 20
            bottomMargin: 20

            Row {
                id: contentRow
                spacing: root.spacing

                Column {
                    id: timeColumn
                    width: root.timeColumnWidth

                    Repeater {
                        model: root.totalSlots
                        delegate: Item {
                            width: parent.width
                            height: root.slotHeight

                            StyledText {
                                text: {
                                    let totalMinutes = root.startMinute + (index * root.slotDuration);
                                    let hour = root.startHour + Math.floor(totalMinutes / 60);
                                    let minute = totalMinutes % 60;

                                    // Format time based on DateTime format
                                    let testDate = new Date();
                                    testDate.setHours(hour, minute, 0);
                                    return Qt.formatTime(testDate, Config.options?.time.format ?? "hh:mm");
                                }
                                anchors.top: parent.top
                                anchors.topMargin: -font.pixelSize / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Row {
                    id: eventsRow
                    height: root.contentHeight
                    spacing: root.spacing

                    Repeater {
                        model: root.days
                        delegate: Item {
                            width: root.dayColumnWidth
                            height: parent.height
                            clip: true
                            property bool isToday: root.isSameDate(modelData.date, DateTime.clock.date)
                            property var timedEvents: root.getTimedEvents(modelData.events)
                            property var dayModel: modelData

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.large
                                color: (root.isDraggingEvent && root.dragMode === "move" && root.dragTargetDayIndex === index) ?
                                       ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85) :
                                       (isToday ? root.todayHighlightFill : Qt.rgba(0, 0, 0, 0))
                                border.width: (root.isDraggingEvent && root.dragMode === "move" && root.dragTargetDayIndex === index) ? 2 : (isToday ? 1 : 0)
                                border.color: (root.isDraggingEvent && root.dragMode === "move" && root.dragTargetDayIndex === index) ?
                                              Appearance.colors.colPrimary :
                                              (isToday ? root.todayHighlightBorder : Qt.rgba(0, 0, 0, 0))
                                z: -1
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.showAddDialog && !root.showViewDialog && !root.isDraggingEvent
                                onClicked: function(mouse) {
                                    if (root.showAddDialog || root.showViewDialog || root.isDraggingEvent)
                                        return;
                                    let minutes = root.startHour * 60 + root.startMinute + (mouse.y / root.pixelsPerMinute);
                                    let rounded = Math.floor(minutes / 30) * 30;
                                    let startMinutes = Math.max(0, Math.min(rounded, 1410));
                                    addEventDialog.openForNew(dayModel.date, startMinutes);
                                }
                            }

                            Repeater {
                                model: root.layoutOverlaps(timedEvents)
                                Rectangle {
                                    id: eventChipRect
                                    readonly property bool isDraggable: !!modelData.id && !modelData.recurring && !root.showAddDialog && !root.showViewDialog
                                    property real trackWidth: parent.width - 10
                                    property real colWidth: trackWidth / modelData.cols
                                    width: colWidth - (modelData.cols > 1 ? 3 : 0)
                                    x: 5 + modelData.col * colWidth
                                    radius: Appearance.rounding.large
                                    clip: true
                                    y: {
                                        let startMin = root.parseTimeToMinutes(modelData.start);
                                        let baseTotalMinutes = root.startHour * 60 + root.startMinute;
                                        let diffMinutes = (startMin !== null ? startMin : 0) - baseTotalMinutes;
                                        return diffMinutes * root.pixelsPerMinute;
                                    }
                                    height: {
                                        let startMin = root.parseTimeToMinutes(modelData.start);
                                        let endMin = root.parseTimeToMinutes(modelData.end);
                                        let totalMins = (endMin !== null && startMin !== null) ? (endMin - startMin) : 60;
                                        return Math.max(totalMins * root.pixelsPerMinute - 4, 48); // Minimum height for touch targets
                                    }

                                    color: modelData.color || Appearance.colors.colTertiaryContainer
                                    opacity: (root.isDraggingEvent && root.activeDragEventId === modelData.id) ? 0.35 : 1.0

                                    Row {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 4

                                        StyledText {
                                            visible: modelData.reminder !== undefined && modelData.reminder !== null && modelData.reminder >= 0
                                            text: "notifications"
                                            font.family: Appearance.font.family.iconMaterial
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            opacity: 0.85
                                        }

                                        StyledText {
                                            visible: !!modelData.recurring
                                            text: "repeat"
                                            font.family: Appearance.font.family.iconMaterial
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            opacity: 0.85
                                        }
                                    }

                                    HoverHandler {
                                        id: eventHover
                                    }

                                    DragHandler {
                                        id: chipDragHandler
                                        target: null
                                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType | PointerHandler.TakeOverForbidden
                                        enabled: eventChipRect.isDraggable && !resizeMouseArea.pressed && (!root.isDraggingEvent || root.activeDragEventId === modelData.id)
                                        onActiveChanged: {
                                            if (active) {
                                                root.startMoveDrag(eventChipRect, modelData, dayModel.date, centroid);
                                            } else {
                                                root.finishMoveDrag(translation);
                                            }
                                        }
                                        onTranslationChanged: {
                                            if (active) {
                                                root.updateMoveDrag(centroid);
                                            }
                                        }
                                    }

                                    TapHandler {
                                        enabled: !root.isDraggingEvent
                                        onTapped: {
                                            if (root.isDraggingEvent) return;
                                            root.viewingEvent = modelData;
                                            root.viewingDayDate = dayModel.date;
                                            root.showViewDialog = true;
                                        }
                                    }

                                    ToolTip {
                                        visible: eventHover.hovered && !root.isDraggingEvent
                                        delay: 200
                                        timeout: 0
                                        text: root.formatEventTooltip(modelData)
                                    }

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 4

                                        Text {
                                            text: {
                                                let startMin = root.parseTimeToMinutes(modelData.start);
                                                let endMin = root.parseTimeToMinutes(modelData.end);
                                                return root.formatTimeMinutes(startMin) + " - " + root.formatTimeMinutes(endMin);
                                            }
                                            font.weight: Font.Medium
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                            elide: Text.ElideRight
                                            lineHeight: 1.2
                                        }

                                        Text {
                                            id: eventTitle
                                            text: modelData.title
                                            font.weight: Font.Medium
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            width: parent.width
                                            color: ColorUtils.getContrastingTextColor(modelData.color)
                                            lineHeight: 1.1
                                            visible: !truncated
                                        }
                                    }

                                    // Resize handle on bottom edge
                                    Item {
                                        id: resizeHandle
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: 8
                                        visible: eventChipRect.isDraggable
                                        z: 20

                                        MouseArea {
                                            id: resizeMouseArea
                                            anchors.fill: parent
                                            cursorShape: Qt.SizeVerCursor
                                            preventStealing: true
                                            onPressed: (mouse) => {
                                                root.startResizeDrag(eventChipRect, modelData, dayModel.date, mouse);
                                            }
                                            onPositionChanged: (mouse) => {
                                                if (pressed) {
                                                    root.updateResizeDrag(eventChipRect, mouse);
                                                }
                                            }
                                            onReleased: (mouse) => {
                                                root.finishResizeDrag();
                                            }
                                            onCanceled: {
                                                root.cancelDrag();
                                            }
                                        }
                                    }
                                }
                            }

                            // Timed tasks markers
                            Repeater {
                                model: (Config.options?.cheatsheet?.showTasksInTimetable && root.tasksByDay[index]) ? root.tasksByDay[index].timedTasks : []
                                delegate: Rectangle {
                                    id: timedTaskMarker
                                    z: 5
                                    property real trackWidth: parent.width - 10
                                    width: modelData.offsetCol === 1 ? (trackWidth - 10) : trackWidth
                                    height: 28
                                    x: modelData.offsetCol === 1 ? 15 : 5
                                    y: Math.max(0, Math.min(parent.height - 28, (modelData.dueMinutes - (root.startHour * 60 + root.startMinute)) * root.pixelsPerMinute))
                                    radius: Appearance.rounding.small
                                    clip: true

                                    color: modelData.isOverdue ? Appearance.colors.colErrorContainer :
                                           modelData.isToday ? Appearance.colors.colPrimaryContainer :
                                           Appearance.colors.colSecondaryContainer
                                    border.width: 1
                                    border.color: modelData.isOverdue ? Appearance.colors.colError :
                                                  modelData.isToday ? Appearance.colors.colPrimary :
                                                  Appearance.colors.colSecondary

                                    readonly property color colContent: modelData.isOverdue ? Appearance.colors.colOnErrorContainer :
                                                                         modelData.isToday ? Appearance.colors.colOnPrimaryContainer :
                                                                         Appearance.colors.colOnSecondaryContainer

                                    // Absorb clicks so empty-slot click handler does not trigger
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            mouse.accepted = true;
                                        }
                                    }

                                    HoverHandler {
                                        id: timedTaskHover
                                    }

                                    ToolTip {
                                        visible: timedTaskHover.hovered && !root.isDraggingEvent
                                        delay: 200
                                        timeout: 0
                                        text: root.formatTaskTooltip(modelData)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 6
                                        spacing: 4

                                        Item {
                                            implicitWidth: 18
                                            implicitHeight: 18

                                            StyledText {
                                                id: timedTaskCheckIcon
                                                anchors.centerIn: parent
                                                text: "task_alt"
                                                font.family: Appearance.font.family.iconMaterial
                                                font.pixelSize: 15
                                                color: timedTaskMarker.colContent
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onEntered: timedTaskCheckIcon.text = "check"
                                                onExited: timedTaskCheckIcon.text = "task_alt"
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true;
                                                    if (modelData.originalIndex !== undefined && modelData.originalIndex >= 0) {
                                                        Todo.markDone(modelData.originalIndex);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: !!(modelData.task && modelData.task.priority && Todo.priorityColors && Todo.priorityColors[modelData.task.priority])
                                            width: 6
                                            height: 6
                                            radius: 3
                                            color: (Todo.priorityColors && modelData.task && Todo.priorityColors[modelData.task.priority]) ? Todo.priorityColors[modelData.task.priority] : "transparent"
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: modelData.content
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: timedTaskMarker.colContent
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Drag preview ghost
            Rectangle {
                id: dragGhost
                visible: root.isDraggingEvent && !!root.activeDragEvent
                z: 999
                x: root.dragGhostX
                y: root.dragGhostY
                width: root.dragGhostWidth
                height: root.dragGhostHeight
                radius: Appearance.rounding.large
                color: root.activeDragEvent ? (root.activeDragEvent.color || Appearance.colors.colTertiaryContainer) : "transparent"
                opacity: 0.92
                border.width: 2
                border.color: Appearance.colors.colPrimary

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2

                    Text {
                        text: root.formattedDragRange() + (root.dragMode === "move" && root.dragTargetDayIndex !== root.dragSourceDayIndex && root.days[root.dragTargetDayIndex] ? " (" + root.days[root.dragTargetDayIndex].name + ")" : "")
                        font.weight: Font.Bold
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.activeDragEvent ? ColorUtils.getContrastingTextColor(root.activeDragEvent.color) : Appearance.m3colors.m3onSurface
                        width: parent.width
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.activeDragEvent ? root.activeDragEvent.title : ""
                        font.weight: Font.Medium
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.activeDragEvent ? ColorUtils.getContrastingTextColor(root.activeDragEvent.color) : Appearance.m3colors.m3onSurface
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }

            Rectangle {
                id: currentTimeLine
                width: contentRow.width
                height: 3
                color: Appearance.colors.colPrimary
                y: root.currentTimeY
                visible: root.currentTimeY >= 0 && root.currentTimeY <= contentRow.height
                z: 10
                radius: Appearance.rounding.unsharpen

                // Material 3 time chip
                Rectangle {
                    x: (timeColumn.width / 2) - (width / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(timeText.implicitWidth + 20, timeColumn.width - 4)
                    height: 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colPrimary

                    Text {
                        id: timeText
                        anchors.centerIn: parent
                        text: DateTime.time
                        color: Appearance.colors.colOnPrimary
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
    // + FAB to add an event
    StyledRectangularShadow {
        target: addEventFab
        radius: addEventFab.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    FloatingActionButton {
        id: addEventFab
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        onClicked: {
            addEventDialog.resetFields()
            addEventDialog.editingEventId = ""
            root.showAddDialog = true
        }
        iconText: "add"
    }

    Item {
        anchors.fill: parent
        z: 9999
        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible && !root.showAddDialog) {
                addEventDialog.resetFields()
                addEventFab.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
                onClicked: root.showAddDialog = false
            }
        }

        Rectangle { // The dialog
            id: addEventDialog
            anchors.centerIn: parent
            width: Math.min(420, parent.width - root.dialogMargins * 2)
            implicitHeight: Math.max(addEventColumnLayout.implicitHeight, (addEventDialog.activeDatePicker !== "" ? 380 : 0))
            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            MouseArea { // Absorb clicks so they don't fall through to the scrim below
                anchors.fill: parent
                preventStealing: true
            }

            property string errorText: ""
            property string editingEventId: ""
            property date startDateTime: new Date()
            property date endDateTime: new Date(Date.now() + 3600000)
            property bool allDay: false

            // Date picker popup state
            property string activeDatePicker: "" // "" | "start" | "end" | "repeatUntil"
            property int pickerYear: new Date().getFullYear()
            property int pickerMonth: new Date().getMonth()

            // Recurrence state
            property string repeatMode: "none" // "none" | "daily" | "weekdays" | "weekly" | "monthly"
            property string repeatEnds: "never" // "never" | "date"
            property date repeatUntilDate: new Date(Date.now() + 30 * 86400000)

            // Reminder state (-1 = none, 0 = at start, 5, 10, 15, 30, 60 mins before)
            property int reminderMinutes: -1

            property var colorOptions: [
                { "name": Translation.tr("Blue"), "hex": "#039be5" },
                { "name": Translation.tr("Green"), "hex": "#33b679" },
                { "name": Translation.tr("Yellow"), "hex": "#f6bf26" },
                { "name": Translation.tr("Red"), "hex": "#d50000" }
            ]
            property string selectedColor: colorOptions[0].hex
            property bool customMode: false
            readonly property var hexPattern: /^#[0-9a-fA-F]{6}$/

            function formattedIsoDate(d) {
                if (!d) return "";
                let dt = new Date(d);
                let y = dt.getFullYear();
                let m = String(dt.getMonth() + 1).padStart(2, "0");
                let day = String(dt.getDate()).padStart(2, "0");
                return `${y}-${m}-${day}`;
            }

            function isPreset(hex) {
                return addEventDialog.colorOptions.some(function(o) { return o.hex === hex; });
            }

            function setStartDateTime(newStart) {
                let oldDuration = addEventDialog.endDateTime.getTime() - addEventDialog.startDateTime.getTime();
                if (isNaN(oldDuration) || oldDuration <= 0) {
                    oldDuration = 3600000;
                }
                addEventDialog.startDateTime = new Date(newStart);
                let newEnd = new Date(addEventDialog.startDateTime.getTime() + oldDuration);
                if (newEnd <= addEventDialog.startDateTime) {
                    newEnd = new Date(addEventDialog.startDateTime.getTime() + 3600000);
                }
                addEventDialog.endDateTime = newEnd;
            }

            function setEndDateTime(newEnd) {
                addEventDialog.endDateTime = new Date(newEnd);
            }

            function stepStartHour(delta) {
                let d = new Date(addEventDialog.startDateTime);
                let newH = (d.getHours() + delta + 24) % 24;
                d.setHours(newH);
                addEventDialog.setStartDateTime(d);
            }

            function stepStartMinute(delta) {
                let d = new Date(addEventDialog.startDateTime);
                let curM = d.getMinutes();
                let rounded = Math.floor(curM / 5) * 5;
                let newM = (rounded + delta + 60) % 60;
                d.setMinutes(newM);
                addEventDialog.setStartDateTime(d);
            }

            function stepEndHour(delta) {
                let d = new Date(addEventDialog.endDateTime);
                let newH = (d.getHours() + delta + 24) % 24;
                d.setHours(newH);
                addEventDialog.setEndDateTime(d);
            }

            function stepEndMinute(delta) {
                let d = new Date(addEventDialog.endDateTime);
                let curM = d.getMinutes();
                let rounded = Math.floor(curM / 5) * 5;
                let newM = (rounded + delta + 60) % 60;
                d.setMinutes(newM);
                addEventDialog.setEndDateTime(d);
            }

            function resetFields() {
                eventTitleInput.text = "";
                eventDescInput.text = "";
                customColorInput.text = "";
                addEventDialog.customMode = false;
                addEventDialog.selectedColor = addEventDialog.colorOptions[0].hex;
                addEventDialog.editingEventId = "";
                addEventDialog.errorText = "";
                addEventDialog.allDay = false;
                addEventDialog.activeDatePicker = "";
                addEventDialog.repeatMode = "none";
                addEventDialog.repeatEnds = "never";
                addEventDialog.reminderMinutes = -1;

                let now = new Date();
                addEventDialog.startDateTime = now;
                addEventDialog.endDateTime = new Date(now.getTime() + 3600000);
                addEventDialog.repeatUntilDate = new Date(now.getTime() + 30 * 86400000);
            }

            function openForNew(dayDate, startMinutes) {
                addEventDialog.resetFields();
                addEventDialog.editingEventId = "";

                let baseDate = new Date(dayDate);
                let startHour = Math.floor(startMinutes / 60);
                let startMinute = startMinutes % 60;
                let startDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), startHour, startMinute, 0, 0);
                let endDate = new Date(startDate.getTime() + 60 * 60 * 1000);

                addEventDialog.startDateTime = startDate;
                addEventDialog.endDateTime = endDate;
                addEventDialog.repeatUntilDate = new Date(startDate.getTime() + 30 * 86400000);
                addEventDialog.allDay = false;

                root.showAddDialog = true;
            }

            function openForEdit(ev, dayDate) {
                addEventDialog.resetFields();
                addEventDialog.errorText = "";

                let master = (ev && ev.id ? CalendarService.getEventById(ev.id) : null) || ev || {};
                addEventDialog.editingEventId = master.id || (ev ? ev.id : "") || "";

                eventTitleInput.text = master.title || (ev ? ev.title : "") || "";
                eventDescInput.text = master.description || (ev ? ev.description : "") || "";

                let isAllDay = !!(master.allDay || (ev && ev.allDay) || root.isAllDayEvent(master) || root.isAllDayEvent(ev));
                addEventDialog.allDay = isAllDay;

                let startDate = null;
                let endDate = null;

                if (master && master.start) {
                    let d = new Date(master.start);
                    if (!isNaN(d.getTime())) {
                        startDate = d;
                    }
                }
                if (master && master.end) {
                    let d = new Date(master.end);
                    if (!isNaN(d.getTime())) {
                        endDate = d;
                    }
                }

                // Fallback to ev.start / ev.end + dayDate if no master ISO timestamps
                if (!startDate) {
                    let baseDate = dayDate ? new Date(dayDate) : new Date();
                    let rawStart = (ev && ev.start) ? String(ev.start) : (master && master.start ? String(master.start) : "00:00");
                    let rawEnd = (ev && ev.end) ? String(ev.end) : (master && master.end ? String(master.end) : "");

                    let tryStartIso = new Date(rawStart);
                    if (!isNaN(tryStartIso.getTime()) && rawStart.indexOf("T") !== -1) {
                        startDate = tryStartIso;
                    } else {
                        let spParts = rawStart.split(":");
                        let sh = parseInt(spParts[0]) || 0;
                        let sm = parseInt(spParts[1]) || 0;
                        startDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), sh, sm, 0, 0);
                    }

                    if (rawEnd) {
                        let tryEndIso = new Date(rawEnd);
                        if (!isNaN(tryEndIso.getTime()) && rawEnd.indexOf("T") !== -1) {
                            endDate = tryEndIso;
                        } else {
                            let epParts = rawEnd.split(":");
                            let eh = parseInt(epParts[0]) || 0;
                            let em = parseInt(epParts[1]) || 0;
                            if (eh === 24 && em === 0) {
                                endDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate() + 1, 0, 0, 0, 0);
                            } else if (eh < startDate.getHours() || (eh === startDate.getHours() && em < startDate.getMinutes())) {
                                endDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate() + 1, eh, em, 0, 0);
                            } else {
                                endDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), eh, em, 0, 0);
                            }
                        }
                    } else {
                        endDate = new Date(startDate.getTime() + 3600000);
                    }
                }

                if (!endDate) {
                    if (isAllDay) {
                        endDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate(), 23, 59, 0, 0);
                    } else {
                        endDate = new Date(startDate.getTime() + 3600000);
                    }
                }

                if (isAllDay) {
                    startDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate(), 0, 0, 0, 0);
                    endDate = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate(), 23, 59, 0, 0);
                    if (endDate < startDate) {
                        endDate = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate(), 23, 59, 0, 0);
                    }
                } else if (endDate <= startDate) {
                    endDate = new Date(startDate.getTime() + 3600000);
                }

                addEventDialog.startDateTime = startDate;
                addEventDialog.endDateTime = endDate;
                addEventDialog.pickerYear = startDate.getFullYear();
                addEventDialog.pickerMonth = startDate.getMonth();

                addEventDialog.repeatMode = master.repeat || (ev ? ev.repeat : "none") || "none";
                let until = master.repeatUntil || (ev ? ev.repeatUntil : "") || "";
                if (until) {
                    addEventDialog.repeatEnds = "date";
                    let parts = until.split("-");
                    if (parts.length >= 3) {
                        addEventDialog.repeatUntilDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                    } else {
                        addEventDialog.repeatUntilDate = new Date(startDate.getTime() + 30 * 86400000);
                    }
                } else {
                    addEventDialog.repeatEnds = "never";
                    addEventDialog.repeatUntilDate = new Date(startDate.getTime() + 30 * 86400000);
                }

                let rem = (master.reminder !== undefined && master.reminder !== null) ? master.reminder :
                          (ev && ev.reminder !== undefined && ev.reminder !== null ? ev.reminder : -1);
                addEventDialog.reminderMinutes = parseInt(rem);

                let col = master.color || (ev ? ev.color : "");
                if (col && addEventDialog.isPreset(col)) {
                    addEventDialog.customMode = false;
                    addEventDialog.selectedColor = col;
                } else if (col) {
                    addEventDialog.customMode = true;
                    customColorInput.text = col;
                    addEventDialog.selectedColor = col;
                } else {
                    addEventDialog.customMode = false;
                    addEventDialog.selectedColor = addEventDialog.colorOptions[0].hex;
                }

                root.showAddDialog = true;
            }

            function addEvent() {
                addEventDialog.errorText = "";
                if (eventTitleInput.text.trim().length === 0) return;

                if (!addEventDialog.allDay && addEventDialog.endDateTime <= addEventDialog.startDateTime) {
                    addEventDialog.errorText = Translation.tr("End must be after start");
                    return;
                }

                if (addEventDialog.repeatMode !== "none" && addEventDialog.repeatEnds === "date") {
                    let startDay = new Date(addEventDialog.startDateTime.getFullYear(), addEventDialog.startDateTime.getMonth(), addEventDialog.startDateTime.getDate());
                    let untilDay = new Date(addEventDialog.repeatUntilDate.getFullYear(), addEventDialog.repeatUntilDate.getMonth(), addEventDialog.repeatUntilDate.getDate());
                    if (untilDay < startDay) {
                        addEventDialog.errorText = Translation.tr("Repeat end must be after start");
                        return;
                    }
                }

                let start = addEventDialog.startDateTime;
                let end = addEventDialog.endDateTime;

                if (addEventDialog.allDay) {
                    start = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 0, 0, 0, 0);
                    end = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 0, 0);
                    if (end < start) end = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 23, 59, 0, 0);
                }

                let repMode = addEventDialog.repeatMode;
                let repUntil = (repMode !== "none" && addEventDialog.repeatEnds === "date") ? addEventDialog.formattedIsoDate(addEventDialog.repeatUntilDate) : "";

                if (addEventDialog.editingEventId) {
                    CalendarService.updateLocalEvent(addEventDialog.editingEventId, eventTitleInput.text.trim(), eventDescInput.text.trim(), start, end, addEventDialog.selectedColor, addEventDialog.allDay, repMode, repUntil, addEventDialog.reminderMinutes);
                } else {
                    CalendarService.addLocalEvent(eventTitleInput.text.trim(), eventDescInput.text.trim(), start, end, addEventDialog.selectedColor, addEventDialog.allDay, repMode, repUntil, addEventDialog.reminderMinutes);
                }
                addEventDialog.resetFields();
                root.showAddDialog = false;
            }

            function deleteEvent() {
                if (addEventDialog.editingEventId) {
                    CalendarService.deleteLocalEvent(addEventDialog.editingEventId);
                }
                addEventDialog.resetFields();
                root.showAddDialog = false;
            }

            ColumnLayout {
                id: addEventColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 24
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.alignment: Qt.AlignLeft
                    color: Appearance.m3colors.m3onSurface
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: addEventDialog.editingEventId ? Translation.tr("Edit event") : Translation.tr("Add event")
                }

                TextField {
                    id: eventTitleInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 44
                    padding: 9
                    placeholderText: Translation.tr("Title")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    focus: root.showAddDialog
                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: eventTitleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }
                }

                TextField {
                    id: eventDescInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    implicitHeight: 44
                    padding: 10
                    placeholderText: Translation.tr("Description (optional)")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: eventDescInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }
                }

                // All-day switch row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 12

                    StyledText {
                        text: Translation.tr("All day")
                        color: Appearance.m3colors.m3onSurface
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    StyledSwitch {
                        id: allDaySwitch
                        checked: addEventDialog.allDay
                        onCheckedChanged: {
                            if (addEventDialog.allDay !== checked) {
                                addEventDialog.allDay = checked;
                            }
                        }
                    }
                }

                // Start row
                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText { text: Translation.tr("Start"); color: Appearance.m3colors.m3onSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Appearance.rounding.verysmall
                            color: Appearance.m3colors.m3surfaceContainerHighest
                            border.width: 1
                            border.color: Appearance.m3colors.m3outlineVariant

                            RippleButton {
                                anchors.fill: parent
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                onClicked: {
                                    addEventDialog.pickerYear = addEventDialog.startDateTime.getFullYear();
                                    addEventDialog.pickerMonth = addEventDialog.startDateTime.getMonth();
                                    addEventDialog.activeDatePicker = (addEventDialog.activeDatePicker === "start" ? "" : "start");
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    StyledText {
                                        text: "calendar_today"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.bodyLarge
                                        color: Appearance.colors.colPrimary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Qt.formatDate(addEventDialog.startDateTime, "ddd, dd MMM yyyy")
                                        color: Appearance.m3colors.m3onSurface
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        RowLayout {
                            visible: !addEventDialog.allDay
                            spacing: 4

                            ColumnLayout {
                                spacing: 0
                                WheelHandler {
                                    onWheel: (event) => {
                                        if (event.angleDelta.y > 0) addEventDialog.stepStartHour(1);
                                        else if (event.angleDelta.y < 0) addEventDialog.stepStartHour(-1);
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepStartHour(1)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_up"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 28
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: Appearance.m3colors.m3outlineVariant
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Qt.formatTime(addEventDialog.startDateTime, "hh")
                                        font.weight: Font.Medium
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepStartHour(-1)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_down"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                            }

                            StyledText {
                                text: ":"
                                font.weight: Font.Bold
                                color: Appearance.m3colors.m3onSurface
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                WheelHandler {
                                    onWheel: (event) => {
                                        if (event.angleDelta.y > 0) addEventDialog.stepStartMinute(5);
                                        else if (event.angleDelta.y < 0) addEventDialog.stepStartMinute(-5);
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepStartMinute(5)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_up"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 28
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: Appearance.m3colors.m3outlineVariant
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Qt.formatTime(addEventDialog.startDateTime, "mm")
                                        font.weight: Font.Medium
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepStartMinute(-5)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_down"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                            }
                        }
                    }
                }

                // End row (hidden when allDay)
                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4
                    visible: !addEventDialog.allDay

                    StyledText { text: Translation.tr("End"); color: Appearance.m3colors.m3onSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Appearance.rounding.verysmall
                            color: Appearance.m3colors.m3surfaceContainerHighest
                            border.width: 1
                            border.color: Appearance.m3colors.m3outlineVariant

                            RippleButton {
                                anchors.fill: parent
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                onClicked: {
                                    addEventDialog.pickerYear = addEventDialog.endDateTime.getFullYear();
                                    addEventDialog.pickerMonth = addEventDialog.endDateTime.getMonth();
                                    addEventDialog.activeDatePicker = (addEventDialog.activeDatePicker === "end" ? "" : "end");
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8

                                    StyledText {
                                        text: "calendar_today"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.bodyLarge
                                        color: Appearance.colors.colPrimary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Qt.formatDate(addEventDialog.endDateTime, "ddd, dd MMM yyyy")
                                        color: Appearance.m3colors.m3onSurface
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        RowLayout {
                            spacing: 4

                            ColumnLayout {
                                spacing: 0
                                WheelHandler {
                                    onWheel: (event) => {
                                        if (event.angleDelta.y > 0) addEventDialog.stepEndHour(1);
                                        else if (event.angleDelta.y < 0) addEventDialog.stepEndHour(-1);
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepEndHour(1)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_up"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 28
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: Appearance.m3colors.m3outlineVariant
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Qt.formatTime(addEventDialog.endDateTime, "hh")
                                        font.weight: Font.Medium
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepEndHour(-1)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_down"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                            }

                            StyledText {
                                text: ":"
                                font.weight: Font.Bold
                                color: Appearance.m3colors.m3onSurface
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                spacing: 0
                                WheelHandler {
                                    onWheel: (event) => {
                                        if (event.angleDelta.y > 0) addEventDialog.stepEndMinute(5);
                                        else if (event.angleDelta.y < 0) addEventDialog.stepEndMinute(-5);
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepEndMinute(5)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_up"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                Rectangle {
                                    implicitWidth: 36
                                    implicitHeight: 28
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: Appearance.m3colors.m3outlineVariant
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Qt.formatTime(addEventDialog.endDateTime, "mm")
                                        font.weight: Font.Medium
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                                RippleButton {
                                    implicitWidth: 36
                                    implicitHeight: 18
                                    buttonRadius: Appearance.rounding.verysmall
                                    onClicked: addEventDialog.stepEndMinute(-5)
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "keyboard_arrow_down"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.body
                                        color: Appearance.m3colors.m3onSurface
                                    }
                                }
                            }
                        }
                    }
                }

                // Repeat selector
                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText { text: Translation.tr("Repeat"); color: Appearance.m3colors.m3onSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [
                                { "id": "none", "name": Translation.tr("None") },
                                { "id": "daily", "name": Translation.tr("Daily") },
                                { "id": "weekdays", "name": Translation.tr("Weekdays") },
                                { "id": "weekly", "name": Translation.tr("Weekly") },
                                { "id": "monthly", "name": Translation.tr("Monthly") }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: Appearance.rounding.verysmall
                                color: addEventDialog.repeatMode === modelData.id ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHighest
                                border.width: 1
                                border.color: addEventDialog.repeatMode === modelData.id ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant

                                RippleButton {
                                    anchors.fill: parent
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: "transparent"
                                    onClicked: {
                                        addEventDialog.repeatMode = modelData.id;
                                        if (modelData.id === "none") {
                                            addEventDialog.repeatEnds = "never";
                                            if (addEventDialog.activeDatePicker === "repeatUntil") {
                                                addEventDialog.activeDatePicker = "";
                                            }
                                        }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: addEventDialog.repeatMode === modelData.id ? Font.Bold : Font.Normal
                                        color: addEventDialog.repeatMode === modelData.id ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                    }
                                }
                            }
                        }
                    }
                }

                // Ends selector (visible when repeatMode !== "none")
                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4
                    visible: addEventDialog.repeatMode !== "none"

                    StyledText { text: Translation.tr("Ends"); color: Appearance.m3colors.m3onSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        RowLayout {
                            spacing: 4

                            Rectangle {
                                implicitWidth: 80
                                implicitHeight: 36
                                radius: Appearance.rounding.verysmall
                                color: addEventDialog.repeatEnds === "never" ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHighest
                                border.width: 1
                                border.color: addEventDialog.repeatEnds === "never" ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant

                                RippleButton {
                                    anchors.fill: parent
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: "transparent"
                                    onClicked: {
                                        addEventDialog.repeatEnds = "never";
                                        if (addEventDialog.activeDatePicker === "repeatUntil") {
                                            addEventDialog.activeDatePicker = "";
                                        }
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("Never")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: addEventDialog.repeatEnds === "never" ? Font.Bold : Font.Normal
                                        color: addEventDialog.repeatEnds === "never" ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 86
                                implicitHeight: 36
                                radius: Appearance.rounding.verysmall
                                color: addEventDialog.repeatEnds === "date" ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHighest
                                border.width: 1
                                border.color: addEventDialog.repeatEnds === "date" ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant

                                RippleButton {
                                    anchors.fill: parent
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: "transparent"
                                    onClicked: addEventDialog.repeatEnds = "date"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("On date")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: addEventDialog.repeatEnds === "date" ? Font.Bold : Font.Normal
                                        color: addEventDialog.repeatEnds === "date" ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Appearance.rounding.verysmall
                            visible: addEventDialog.repeatEnds === "date"
                            color: Appearance.m3colors.m3surfaceContainerHighest
                            border.width: 1
                            border.color: Appearance.m3colors.m3outlineVariant

                            RippleButton {
                                anchors.fill: parent
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                onClicked: {
                                    addEventDialog.pickerYear = addEventDialog.repeatUntilDate.getFullYear();
                                    addEventDialog.pickerMonth = addEventDialog.repeatUntilDate.getMonth();
                                    addEventDialog.activeDatePicker = (addEventDialog.activeDatePicker === "repeatUntil" ? "" : "repeatUntil");
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    StyledText {
                                        text: "calendar_today"
                                        font.family: Appearance.font.family.iconMaterial
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colPrimary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Qt.formatDate(addEventDialog.repeatUntilDate, "ddd, dd MMM yyyy")
                                        color: Appearance.m3colors.m3onSurface
                                        font.weight: Font.Medium
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Recurring edit hint
                StyledText {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    visible: addEventDialog.editingEventId.length > 0 && addEventDialog.repeatMode !== "none"
                    color: Appearance.m3colors.m3onSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Changes apply to all occurrences")
                }

                // Reminder selector
                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: addEventDialog.allDay ?
                              Translation.tr("Reminder (9:00 AM on the day)") :
                              Translation.tr("Reminder")
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: reminderFlow.implicitHeight

                        Flow {
                            id: reminderFlow
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: [
                                    { "mins": -1, "name": Translation.tr("None") },
                                    { "mins": 0, "name": Translation.tr("At start") },
                                    { "mins": 5, "name": Translation.tr("5 min") },
                                    { "mins": 10, "name": Translation.tr("10 min") },
                                    { "mins": 30, "name": Translation.tr("30 min") },
                                    { "mins": 60, "name": Translation.tr("1 hour") }
                                ]
                                delegate: Rectangle {
                                    implicitWidth: reminderChipText.implicitWidth + 20
                                    implicitHeight: 32
                                    radius: Appearance.rounding.verysmall
                                    color: addEventDialog.reminderMinutes === modelData.mins ? Appearance.colors.colPrimary : Appearance.m3colors.m3surfaceContainerHighest
                                    border.width: 1
                                    border.color: addEventDialog.reminderMinutes === modelData.mins ? Appearance.colors.colPrimary : Appearance.m3colors.m3outlineVariant

                                    RippleButton {
                                        anchors.fill: parent
                                        buttonRadius: Appearance.rounding.verysmall
                                        colBackground: "transparent"
                                        onClicked: addEventDialog.reminderMinutes = modelData.mins

                                        StyledText {
                                            id: reminderChipText
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: addEventDialog.reminderMinutes === modelData.mins ? Font.Bold : Font.Normal
                                            color: addEventDialog.reminderMinutes === modelData.mins ? Appearance.colors.colOnPrimary : Appearance.m3colors.m3onSurface
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText { text: Translation.tr("Color"); color: Appearance.m3colors.m3onSurfaceVariant }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: addEventDialog.colorOptions
                            delegate: Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: Appearance.rounding.full
                                color: modelData.hex
                                border.width: addEventDialog.selectedColor === modelData.hex ? 3 : 0
                                border.color: Appearance.m3colors.m3onSurface

                                StyledText {
                                    anchors.centerIn: parent
                                    visible: addEventDialog.selectedColor === modelData.hex
                                    text: "check"
                                    font.family: Appearance.font.family.iconMaterial
                                    color: ColorUtils.getContrastingTextColor(modelData.hex)
                                }

                                ToolTip {
                                    visible: swatchHover.hovered
                                    delay: 250
                                    timeout: 0
                                    text: modelData.name
                                }
                                HoverHandler {
                                    id: swatchHover
                                }
                                TapHandler {
                                    onTapped: {
                                        addEventDialog.customMode = false;
                                        addEventDialog.selectedColor = modelData.hex;
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: CalendarService.customColorOptions
                            delegate: Rectangle {
                                Layout.preferredWidth: 36
                                Layout.preferredHeight: 36
                                radius: Appearance.rounding.full
                                color: modelData.hex
                                border.width: (!addEventDialog.customMode && addEventDialog.selectedColor === modelData.hex) ? 3 : 0
                                border.color: Appearance.m3colors.m3onSurface

                                StyledText {
                                    anchors.centerIn: parent
                                    visible: !addEventDialog.customMode && addEventDialog.selectedColor === modelData.hex
                                    text: "check"
                                    font.family: Appearance.font.family.iconMaterial
                                    color: ColorUtils.getContrastingTextColor(modelData.hex)
                                }

                                ToolTip {
                                    visible: savedSwatchHover.hovered
                                    delay: 250
                                    timeout: 0
                                    text: modelData.name
                                }
                                HoverHandler {
                                    id: savedSwatchHover
                                }
                                TapHandler {
                                    onTapped: {
                                        addEventDialog.customMode = false;
                                        addEventDialog.selectedColor = modelData.hex;
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: customSwatch
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: Appearance.rounding.full
                            property bool hasValidHex: addEventDialog.hexPattern.test(customColorInput.text)
                            color: hasValidHex ? customColorInput.text : Appearance.m3colors.m3surfaceContainerHighest
                            border.width: addEventDialog.customMode ? 3 : 1
                            border.color: addEventDialog.customMode ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline

                            StyledText {
                                anchors.centerIn: parent
                                visible: !customSwatch.hasValidHex
                                text: "palette"
                                font.family: Appearance.font.family.iconMaterial
                                color: Appearance.m3colors.m3onSurfaceVariant
                            }
                            StyledText {
                                anchors.centerIn: parent
                                visible: customSwatch.hasValidHex && addEventDialog.customMode
                                text: "check"
                                font.family: Appearance.font.family.iconMaterial
                                color: ColorUtils.getContrastingTextColor(customColorInput.text)
                            }

                            ToolTip {
                                visible: customSwatchHover.hovered
                                delay: 250
                                timeout: 0
                                text: Translation.tr("Custom color")
                            }
                            HoverHandler {
                                id: customSwatchHover
                            }
                            TapHandler {
                                onTapped: {
                                    addEventDialog.customMode = true;
                                    customColorInput.forceActiveFocus();
                                    if (customSwatch.hasValidHex) addEventDialog.selectedColor = customColorInput.text;
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8
                        visible: addEventDialog.customMode

                        TextField {
                            id: customColorInput
                            Layout.fillWidth: true
                            padding: 8
                            placeholderText: Translation.tr("Custom hex, e.g. #8ab4f8")
                            placeholderTextColor: Appearance.m3colors.m3outline
                            color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                            onTextChanged: {
                                if (addEventDialog.hexPattern.test(text)) addEventDialog.selectedColor = text;
                            }
                            background: Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.verysmall
                                border.width: 2
                                border.color: customColorInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                                color: "transparent"
                            }
                        }

                        RippleButton {
                            id: saveCustomColorButton
                            implicitWidth: 40
                            implicitHeight: 40
                            buttonRadius: Appearance.rounding.verysmall
                            enabled: addEventDialog.hexPattern.test(customColorInput.text) && !CalendarService.customColorOptions.some(function(o) { return o.hex === customColorInput.text; })
                            onClicked: CalendarService.addCustomColorOption(customColorInput.text)

                            ToolTip {
                                visible: saveCustomColorButton.hovered
                                delay: 250
                                timeout: 0
                                text: Translation.tr("Save to options")
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: "bookmark_add"
                                font.family: Appearance.font.family.iconMaterial
                                color: saveCustomColorButton.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                            }
                        }
                    }
                }

                StyledText {
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    visible: addEventDialog.errorText.length > 0
                    color: Appearance.colors.colError
                    text: addEventDialog.errorText
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.fillWidth: true
                    spacing: 5

                    DialogButton {
                        buttonText: Translation.tr("Delete")
                        visible: addEventDialog.editingEventId.length > 0
                        onClicked: addEventDialog.deleteEvent()
                    }
                    Item { Layout.fillWidth: true }
                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        onClicked: {
                            addEventDialog.resetFields()
                            root.showAddDialog = false
                        }
                    }
                    DialogButton {
                        buttonText: addEventDialog.editingEventId ? Translation.tr("Save") : Translation.tr("Add")
                        enabled: eventTitleInput.text.length > 0
                        onClicked: addEventDialog.addEvent()
                    }
                }
            }

            // Inline month-grid date picker popup overlay
            Item {
                id: datePickerOverlay
                anchors.fill: parent
                visible: addEventDialog.activeDatePicker !== ""
                z: 100

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.45)
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        onClicked: addEventDialog.activeDatePicker = ""
                    }
                }

                Rectangle {
                    id: datePickerCard
                    anchors.centerIn: parent
                    width: Math.min(340, parent.width - 24)
                    implicitHeight: datePickerCardLayout.implicitHeight + 20
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    radius: Appearance.rounding.normal
                    border.width: 1
                    border.color: Appearance.m3colors.m3outlineVariant

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                    }

                    ColumnLayout {
                        id: datePickerCardLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                onClicked: {
                                    if (addEventDialog.pickerMonth === 0) {
                                        addEventDialog.pickerMonth = 11;
                                        addEventDialog.pickerYear -= 1;
                                    } else {
                                        addEventDialog.pickerMonth -= 1;
                                    }
                                }
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "chevron_left"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }

                            RippleButton {
                                id: monthTitleButton
                                Layout.fillWidth: true
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.verysmall
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.m3colors.m3surfaceContainerHighest
                                onClicked: {
                                    let today = DateTime.clock.date;
                                    addEventDialog.pickerYear = today.getFullYear();
                                    addEventDialog.pickerMonth = today.getMonth();
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: Qt.formatDate(new Date(addEventDialog.pickerYear, addEventDialog.pickerMonth, 1), "MMMM yyyy")
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }

                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.full
                                onClicked: {
                                    if (addEventDialog.pickerMonth === 11) {
                                        addEventDialog.pickerMonth = 0;
                                        addEventDialog.pickerYear += 1;
                                    } else {
                                        addEventDialog.pickerMonth += 1;
                                    }
                                }
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                model: 7
                                delegate: Item {
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 20
                                    readonly property int dayOfWeek: ((root.firstDayOfWeek - 1 + index) % 7) + 1

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: Qt.locale().dayName(dayOfWeek, Locale.ShortFormat)
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: Appearance.m3colors.m3onSurfaceVariant
                                    }
                                }
                            }
                        }

                        GridLayout {
                            id: monthDaysGrid
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 0

                            Repeater {
                                model: 42
                                delegate: Item {
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 30

                                    readonly property date cellDate: {
                                        let firstDay = root.firstDayOfWeek;
                                        let firstDayJs = firstDay === 7 ? 0 : firstDay;
                                        let firstOfMonth = new Date(addEventDialog.pickerYear, addEventDialog.pickerMonth, 1);
                                        let jsDay = firstOfMonth.getDay();
                                        let offset = (jsDay - firstDayJs + 7) % 7;
                                        return new Date(addEventDialog.pickerYear, addEventDialog.pickerMonth, 1 - offset + index);
                                    }

                                    readonly property bool inCurrentMonth: cellDate.getMonth() === addEventDialog.pickerMonth
                                    readonly property bool isToday: {
                                        let today = DateTime.clock.date;
                                        return cellDate.getFullYear() === today.getFullYear() &&
                                               cellDate.getMonth() === today.getMonth() &&
                                               cellDate.getDate() === today.getDate();
                                    }
                                    readonly property bool isSelected: {
                                        let target = addEventDialog.activeDatePicker === "start" ? addEventDialog.startDateTime :
                                                     addEventDialog.activeDatePicker === "end" ? addEventDialog.endDateTime :
                                                     addEventDialog.repeatUntilDate;
                                        return cellDate.getFullYear() === target.getFullYear() &&
                                               cellDate.getMonth() === target.getMonth() &&
                                               cellDate.getDate() === target.getDate();
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        radius: Appearance.rounding.full
                                        color: isSelected ? Appearance.colors.colPrimary :
                                               isToday ? Appearance.m3colors.m3surfaceContainerHighest : "transparent"
                                        border.width: (!isSelected && isToday) ? 1 : 0
                                        border.color: Appearance.colors.colPrimary

                                        RippleButton {
                                            anchors.fill: parent
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: "transparent"
                                            colBackgroundHover: isSelected ? Appearance.colors.colPrimaryHover : Appearance.m3colors.m3surfaceContainerHighest

                                            onClicked: {
                                                if (addEventDialog.activeDatePicker === "start") {
                                                    let d = new Date(addEventDialog.startDateTime);
                                                    d.setFullYear(cellDate.getFullYear(), cellDate.getMonth(), cellDate.getDate());
                                                    addEventDialog.setStartDateTime(d);
                                                } else if (addEventDialog.activeDatePicker === "end") {
                                                    let d = new Date(addEventDialog.endDateTime);
                                                    d.setFullYear(cellDate.getFullYear(), cellDate.getMonth(), cellDate.getDate());
                                                    addEventDialog.setEndDateTime(d);
                                                } else if (addEventDialog.activeDatePicker === "repeatUntil") {
                                                    addEventDialog.repeatUntilDate = new Date(cellDate.getFullYear(), cellDate.getMonth(), cellDate.getDate());
                                                }
                                                addEventDialog.activeDatePicker = "";
                                            }

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: cellDate.getDate()
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: (isSelected || isToday) ? Font.Bold : Font.Normal
                                                color: isSelected ? Appearance.colors.colOnPrimary :
                                                       !inCurrentMonth ? Appearance.m3colors.m3outline :
                                                       Appearance.m3colors.m3onSurface
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: viewDialogOverlay
        anchors.fill: parent
        z: 9998
        visible: opacity > 0
        opacity: root.showViewDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
                onClicked: root.showViewDialog = false
            }
        }

        Rectangle {
            id: viewDialog
            anchors.centerIn: parent
            width: Math.min(360, parent.width - root.dialogMargins * 2)
            implicitHeight: Math.max(viewDialogColumn.implicitHeight, 180)
            radius: Appearance.rounding.normal
            color: root.viewingEvent ? (root.viewingEvent.color || Appearance.colors.colTertiaryContainer) : Appearance.colors.colTertiaryContainer

            readonly property color textColor: ColorUtils.getContrastingTextColor(color)

            function formattedRange() {
                if (!root.viewingEvent) return "";
                if (root.isAllDayEvent(root.viewingEvent)) return Translation.tr("All day");

                let sp = (root.viewingEvent.start || "00:00").split(":");
                let ep = (root.viewingEvent.end || "00:00").split(":");
                let fmt = (h, m) => {
                    let d = new Date();
                    d.setHours(parseInt(h), parseInt(m), 0);
                    return Qt.formatTime(d, Config.options?.time.format ?? "hh:mm");
                };
                return fmt(sp[0], sp[1]) + " - " + fmt(ep[0], ep[1]);
            }

            function formattedRepeatText() {
                if (!root.viewingEvent || !root.viewingEvent.repeat || root.viewingEvent.repeat === "none") return "";
                let mode = root.viewingEvent.repeat;
                let modeLabel = mode === "daily" ? Translation.tr("Repeats daily") :
                                mode === "weekdays" ? Translation.tr("Repeats weekdays") :
                                mode === "weekly" ? Translation.tr("Repeats weekly") :
                                mode === "monthly" ? Translation.tr("Repeats monthly") : "";
                if (!modeLabel) return "";

                if (root.viewingEvent.repeatUntil) {
                    let parts = root.viewingEvent.repeatUntil.split("-");
                    if (parts.length >= 3) {
                        let untilDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                        let dateStr = Qt.formatDate(untilDate, "dd MMM yyyy");
                        return modeLabel + " " + Translation.tr("until") + " " + dateStr;
                    }
                }
                return modeLabel;
            }

            function formattedReminderText() {
                if (!root.viewingEvent || root.viewingEvent.reminder === undefined || root.viewingEvent.reminder === null || root.viewingEvent.reminder < 0) return "";
                if (root.isAllDayEvent(root.viewingEvent)) {
                    return Translation.tr("Reminder: 9:00 AM on the day");
                }
                let r = root.viewingEvent.reminder;
                if (r === 0) return Translation.tr("Reminder: at start");
                if (r === 60) return Translation.tr("Reminder: 1 hour before");
                return Translation.tr("Reminder: %1 minutes before").arg(r);
            }

            MouseArea { // Absorb clicks so they don't fall through to the scrim
                anchors.fill: parent
                preventStealing: true
            }

            RippleButton {
                id: deleteButton
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 14
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                visible: root.viewingEvent && root.viewingEvent.id
                onClicked: {
                    if (root.viewingEvent && root.viewingEvent.id) {
                        CalendarService.deleteLocalEvent(root.viewingEvent.id);
                    }
                    root.showViewDialog = false
                }

                ToolTip {
                    visible: deleteButtonHover.hovered
                    delay: 250
                    timeout: 0
                    text: root.viewingEvent && root.viewingEvent.recurring ?
                          Translation.tr("Delete all occurrences") :
                          Translation.tr("Delete")
                }
                HoverHandler {
                    id: deleteButtonHover
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "delete"
                    font.family: Appearance.font.family.iconMaterial
                    color: viewDialog.textColor
                }
            }

            RippleButton {
                id: editButton
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 14
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    let evToEdit = root.viewingEvent;
                    let dayToEdit = root.viewingDayDate;
                    root.showViewDialog = false;
                    addEventDialog.openForEdit(evToEdit, dayToEdit);
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "edit"
                    font.family: Appearance.font.family.iconMaterial
                    color: viewDialog.textColor
                }
            }

            ColumnLayout {
                id: viewDialogColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 14

                StyledText {
                    Layout.topMargin: 64
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.fillWidth: true
                    color: viewDialog.textColor
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    text: root.viewingEvent ? root.viewingEvent.title : ""
                }

                StyledText {
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.fillWidth: true
                    color: viewDialog.textColor
                    font.pixelSize: Appearance.font.pixelSize.large
                    text: viewDialog.formattedRange()
                }

                RowLayout {
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.viewingEvent && root.viewingEvent.repeat && root.viewingEvent.repeat !== "none"

                    StyledText {
                        text: "repeat"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.medium
                        color: viewDialog.textColor
                        opacity: 0.9
                    }

                    StyledText {
                        Layout.fillWidth: true
                        color: viewDialog.textColor
                        font.pixelSize: Appearance.font.pixelSize.medium
                        font.weight: Font.Medium
                        opacity: 0.9
                        text: viewDialog.formattedRepeatText()
                    }
                }

                RowLayout {
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.viewingEvent && root.viewingEvent.reminder !== undefined && root.viewingEvent.reminder !== null && root.viewingEvent.reminder >= 0

                    StyledText {
                        text: "notifications"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: viewDialog.textColor
                        opacity: 0.9
                    }

                    StyledText {
                        Layout.fillWidth: true
                        color: viewDialog.textColor
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        opacity: 0.9
                        text: viewDialog.formattedReminderText()
                    }
                }

                StyledText {
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.bottomMargin: 32
                    Layout.fillWidth: true
                    color: viewDialog.textColor
                    wrapMode: Text.WordWrap
                    visible: root.viewingEvent && root.viewingEvent.description && root.viewingEvent.description.length > 0
                    text: root.viewingEvent ? root.viewingEvent.description : ""
                }
            }
        }
    }
}

