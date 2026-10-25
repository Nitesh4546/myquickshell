pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int daysShown: 7
    property int weekOffset: 0

    property var localEvents: []   // events added locally, persisted to disk, merged in regardless of mode
    property var eventsInWeek: []
    property var customColorOptions: []   // user-saved custom colors, offered as swatches in the Add Event dialog
    property var firedReminders: ({})
    property double serviceStartTime: Date.now()
    property var notificationQueue: []

    Process {
        id: notifyProcess
        onExited: (exitCode) => {
            root.processNextNotification();
        }
    }

    Timer {
        id: reminderTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: root.checkReminders()
    }

    function sendNotification(title, body) {
        let q = root.notificationQueue.slice(0);
        q.push({ "title": title, "body": body });
        root.notificationQueue = q;
        if (!notifyProcess.running) {
            root.processNextNotification();
        }
    }

    function processNextNotification() {
        if (notifyProcess.running || root.notificationQueue.length === 0) return;
        let q = root.notificationQueue.slice(0);
        let item = q.shift();
        root.notificationQueue = q;
        notifyProcess.command = ["notify-send", "-a", "Calendar", item.title, item.body];
        notifyProcess.running = true;
    }

    function persistLocalData() {
        localDataFileView.setText(JSON.stringify({
            "localEvents": root.localEvents,
            "customColorOptions": root.customColorOptions
        }));
    }

    function addCustomColorOption(hex) {
        if (root.customColorOptions.some(function(o) { return o.hex === hex; })) return;
        let updated = root.customColorOptions.slice(0);
        updated.push({ "name": hex, "hex": hex });
        root.customColorOptions = updated;
        root.persistLocalData();
    }

    function addLocalEvent(title, desc, startDate, endDate, color, allDay, repeat, repeatUntil, reminder) {
        let updated = root.localEvents.slice(0);
        updated.push({
            "id": `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            "title": title,
            "description": desc,
            "start": root.isoLocal(startDate),
            "end": root.isoLocal(endDate),
            "allDay": !!allDay,
            "color": color,
            "repeat": repeat || "none",
            "repeatUntil": repeatUntil || "",
            "reminder": (reminder !== undefined && reminder !== null) ? parseInt(reminder) : -1
        });
        root.localEvents = updated;
        root.persistLocalData();
    }

    function updateLocalEvent(id, title, desc, startDate, endDate, color, allDay, repeat, repeatUntil, reminder) {
        root.localEvents = root.localEvents.map(function(ev) {
            if (ev.id !== id) return ev;
            return Object.assign({}, ev, {
                "title": title,
                "description": desc,
                "start": root.isoLocal(startDate),
                "end": root.isoLocal(endDate),
                "allDay": allDay !== undefined ? !!allDay : (ev.allDay ?? false),
                "color": color,
                "repeat": repeat !== undefined ? (repeat || "none") : (ev.repeat || "none"),
                "repeatUntil": repeatUntil !== undefined ? (repeatUntil || "") : (ev.repeatUntil || ""),
                "reminder": (reminder !== undefined && reminder !== null) ? parseInt(reminder) : (ev.reminder !== undefined ? ev.reminder : -1)
            });
        });
        root.persistLocalData();
    }

    function deleteLocalEvent(id) {
        root.localEvents = root.localEvents.filter(function(ev) { return ev.id !== id; });
        root.persistLocalData();
    }

    function getEventById(id) {
        if (!id) return null;
        for (let ev of root.localEvents) {
            if (ev.id === id) return ev;
        }
        return null;
    }

    function matchesOccurrence(ev, d) {
        if (!ev.start) return false;
        let evDate = new Date(ev.start);
        if (isNaN(evDate.getTime())) return false;

        let dy = d.getFullYear();
        let dm = d.getMonth();
        let dd = d.getDate();

        let isRecurring = ev.repeat && ev.repeat !== "none";
        if (!isRecurring) {
            return (evDate.getFullYear() === dy &&
                    evDate.getMonth() === dm &&
                    evDate.getDate() === dd);
        }

        let masterY = evDate.getFullYear();
        let masterM = evDate.getMonth();
        let masterD = evDate.getDate();
        let masterWeekday = evDate.getDay();

        // 1. Day's date is on or after master's start date (calendar day only)
        if (dy < masterY || (dy === masterY && dm < masterM) || (dy === masterY && dm === masterM && dd < masterD)) {
            return false;
        }

        // 2. repeatUntil check (if specified, day's date must be on or before repeatUntil)
        if (ev.repeatUntil) {
            let parts = ev.repeatUntil.split("-");
            if (parts.length >= 3) {
                let untilY = parseInt(parts[0]);
                let untilM = parseInt(parts[1]) - 1;
                let untilD = parseInt(parts[2]);
                if (dy > untilY || (dy === untilY && dm > untilM) || (dy === untilY && dm === untilM && dd > untilD)) {
                    return false;
                }
            }
        }

        // 3. Rule matching
        let jsDay = d.getDay();
        if (ev.repeat === "daily") {
            return true;
        } else if (ev.repeat === "weekdays") {
            return (jsDay >= 1 && jsDay <= 5);
        } else if (ev.repeat === "weekly") {
            return (jsDay === masterWeekday);
        } else if (ev.repeat === "monthly") {
            return (dd === masterD);
        }
        return false;
    }

    function placeEventInDays(days, ev) {
        if (!ev.start) return;

        let evDate = new Date(ev.start);
        if (isNaN(evDate.getTime())) return;

        let isRecurring = ev.repeat && ev.repeat !== "none";
        let startH = evDate.getHours();
        let startM = evDate.getMinutes();
        let endH = 0;
        let endM = 0;
        if (ev.allDay) {
            startH = 0;
            startM = 0;
            endH = 23;
            endM = 59;
        } else if (ev.end) {
            let endDate = new Date(ev.end);
            endH = endDate.getHours();
            endM = endDate.getMinutes();
            if (endDate.getDate() !== evDate.getDate() && endH === 0 && endM === 0) {
                endH = 24;
            }
        } else {
            endH = (startH + 1) % 24;
            endM = startM;
        }

        for (let day of days) {
            if (root.matchesOccurrence(ev, day.date)) {
                day.events.push({
                    "id": ev.id,
                    "title": ev.title,
                    "description": ev.description,
                    "start": ev.allDay ? "00:00" : `${root.pad(startH)}:${root.pad(startM)}`,
                    "end": ev.allDay ? "23:59" : `${root.pad(endH)}:${root.pad(endM)}`,
                    "color": ev.color,
                    "allDay": !!ev.allDay,
                    "repeat": ev.repeat || "none",
                    "repeatUntil": ev.repeatUntil || "",
                    "reminder": ev.reminder !== undefined ? ev.reminder : -1,
                    "recurring": isRecurring
                });
                if (!isRecurring) {
                    break;
                }
            }
        }
    }

    function nextItems(now, lookaheadMs, includeAllDay) {
        let currentDate = (now instanceof Date) ? now : new Date();
        let nowMs = currentDate.getTime();
        let lookahead = (typeof lookaheadMs === "number" && lookaheadMs > 0) ? lookaheadMs : (12 * 3600 * 1000);
        let endMs = nowMs + lookahead;
        let allowAllDay = !!includeAllDay;

        let today = new Date(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate(), 0, 0, 0, 0);
        let tomorrow = new Date(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate() + 1, 0, 0, 0, 0);
        let targetDays = [today];
        if (tomorrow.getTime() <= endMs) {
            targetDays.push(tomorrow);
        }

        let items = [];

        for (let ev of root.localEvents) {
            if (!ev || !ev.start) continue;
            let isAllDay = !!ev.allDay;
            if (isAllDay && !allowAllDay) continue;

            let evDate = new Date(ev.start);
            if (isNaN(evDate.getTime())) continue;

            let isRecurring = ev.repeat && ev.repeat !== "none";

            for (let dayDate of targetDays) {
                if (!root.matchesOccurrence(ev, dayDate)) continue;

                let occStart, occEnd;
                if (isAllDay) {
                    occStart = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), 0, 0, 0, 0);
                    occEnd = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), 23, 59, 59, 999);
                } else {
                    let startH = evDate.getHours();
                    let startM = evDate.getMinutes();
                    occStart = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), startH, startM, 0, 0);
                    if (ev.end) {
                        let endDate = new Date(ev.end);
                        let diffMs = endDate.getTime() - evDate.getTime();
                        occEnd = new Date(occStart.getTime() + (diffMs > 0 ? diffMs : 3600000));
                    } else {
                        occEnd = new Date(occStart.getTime() + 3600000);
                    }
                }

                let occStartMs = occStart.getTime();
                let occEndMs = occEnd.getTime();

                // Skip if already ended
                if (occEndMs <= nowMs) continue;

                // Skip if starts outside lookahead window
                if (occStartMs > endMs) continue;

                let inProgress = (occStartMs <= nowMs && occEndMs > nowMs);

                items.push({
                    "id": ev.id,
                    "title": (ev.title && ev.title.trim()) ? ev.title.trim() : Translation.tr("Calendar Event"),
                    "description": ev.description || "",
                    "color": ev.color || "",
                    "start": occStart,
                    "end": occEnd,
                    "allDay": isAllDay,
                    "inProgress": inProgress,
                    "itemType": "event",
                    "recurring": isRecurring
                });

                if (!isRecurring) {
                    break;
                }
            }
        }

        return items;
    }

    function dayMarkers(rangeStart, rangeEnd) {
        if (!rangeStart || !rangeEnd) return {};

        let start = new Date(rangeStart.getFullYear(), rangeStart.getMonth(), rangeStart.getDate(), 0, 0, 0, 0);
        let end = new Date(rangeEnd.getFullYear(), rangeEnd.getMonth(), rangeEnd.getDate(), 23, 59, 59, 999);
        if (start.getTime() > end.getTime()) return {};

        let markers = {};
        let dayList = [];
        let curr = new Date(start);
        while (curr.getTime() <= end.getTime()) {
            let y = curr.getFullYear();
            let m = root.pad(curr.getMonth() + 1);
            let d = root.pad(curr.getDate());
            let dateKey = `${y}-${m}-${d}`;
            markers[dateKey] = {
                "eventCount": 0,
                "eventTitles": [],
                "taskCount": 0,
                "overdueCount": 0
            };
            dayList.push({ "key": dateKey, "date": new Date(curr) });
            curr.setDate(curr.getDate() + 1);
        }

        // Events: iterate localEvents using matchesOccurrence
        for (let ev of root.localEvents) {
            if (!ev || !ev.start) continue;
            let evDate = new Date(ev.start);
            if (isNaN(evDate.getTime())) continue;

            let evTitle = (ev.title && ev.title.trim()) ? ev.title.trim() : Translation.tr("Calendar Event");

            let isRecurring = ev.repeat && ev.repeat !== "none";
            if (!isRecurring) {
                let y = evDate.getFullYear();
                let m = root.pad(evDate.getMonth() + 1);
                let d = root.pad(evDate.getDate());
                let key = `${y}-${m}-${d}`;
                if (markers[key]) {
                    markers[key].eventCount++;
                    markers[key].eventTitles.push(evTitle);
                }
            } else {
                for (let dayItem of dayList) {
                    if (root.matchesOccurrence(ev, dayItem.date)) {
                        markers[dayItem.key].eventCount++;
                        markers[dayItem.key].eventTitles.push(evTitle);
                    }
                }
            }
        }

        // Tasks: iterate Todo.list for unfinished tasks with a non-empty due
        let nowMs = Date.now();
        let todoList = Todo.list || [];
        for (let task of todoList) {
            if (!task || task.done || !task.due) continue;
            let d = Todo.dueDate(task);
            if (!d || isNaN(d.getTime())) continue;

            let y = d.getFullYear();
            let m = root.pad(d.getMonth() + 1);
            let dayNum = root.pad(d.getDate());
            let key = `${y}-${m}-${dayNum}`;

            if (markers[key]) {
                markers[key].taskCount++;
                if (nowMs > d.getTime()) {
                    markers[key].overdueCount++;
                }
            }
        }

        return markers;
    }

    function sendEventNotification(ev, occStart, occEnd, isAllDay) {
        let title = ev.title ? ev.title : Translation.tr("Calendar Event");
        let tf = Config.options?.time?.format ?? "hh:mm";
        let timeRange = isAllDay ? Translation.tr("All day") : `${Qt.formatTime(occStart, tf)} - ${Qt.formatTime(occEnd, tf)}`;
        let nowMs = Date.now();
        let statusText = "";
        if (isAllDay) {
            statusText = Translation.tr("Today");
        } else if (nowMs >= occStart.getTime() - 30000) {
            statusText = Translation.tr("Starting now");
        } else {
            let minsLeft = Math.max(1, Math.round((occStart.getTime() - nowMs) / 60000));
            statusText = minsLeft === 1 ? Translation.tr("Starts in 1 minute") : Translation.tr("Starts in %1 minutes").arg(minsLeft);
        }
        let body = `${timeRange}\n${statusText}`;
        root.sendNotification(title, body);
    }

    function checkReminders() {
        let now = new Date();
        let nowMs = now.getTime();

        // Prune old fired keys (older than 24h)
        let pruneCutoff = nowMs - 24 * 3600 * 1000;
        let pruned = Object.assign({}, root.firedReminders);
        let changed = false;
        for (let k in pruned) {
            if (typeof pruned[k] === "number" && pruned[k] < pruneCutoff) {
                delete pruned[k];
                changed = true;
            }
        }
        if (changed) root.firedReminders = pruned;

        let today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
        let tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 0, 0);
        let targetDays = [today, tomorrow];

        for (let ev of root.localEvents) {
            if (ev.reminder === undefined || ev.reminder === null || ev.reminder < 0) continue;
            if (!ev.start) continue;

            let evStart = new Date(ev.start);
            if (isNaN(evStart.getTime())) continue;

            let isAllDay = !!ev.allDay;

            for (let dayDate of targetDays) {
                if (!root.matchesOccurrence(ev, dayDate)) continue;

                let occStart, occEnd;
                if (isAllDay) {
                    occStart = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), 9, 0, 0, 0);
                    occEnd = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), 23, 59, 0, 0);
                } else {
                    let startH = evStart.getHours();
                    let startM = evStart.getMinutes();
                    occStart = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), startH, startM, 0, 0);
                    if (ev.end) {
                        let evEnd = new Date(ev.end);
                        let diffMs = evEnd.getTime() - evStart.getTime();
                        occEnd = new Date(occStart.getTime() + (diffMs > 0 ? diffMs : 3600000));
                    } else {
                        occEnd = new Date(occStart.getTime() + 3600000);
                    }
                }

                let occStartISO = root.isoLocal(occStart);
                let fireKey = `${ev.id}|${occStartISO}|${ev.reminder}`;

                if (root.firedReminders[fireKey]) continue;

                let shouldFire = false;
                let occStartMs = occStart.getTime();

                if (isAllDay) {
                    let nineAmMs = occStartMs;
                    if (nowMs >= nineAmMs && nowMs <= (nineAmMs + 60 * 1000) && nineAmMs > root.serviceStartTime) {
                        shouldFire = true;
                    }
                } else {
                    let reminderMs = ev.reminder * 60 * 1000;
                    let triggerMs = occStartMs - reminderMs;
                    if (nowMs >= triggerMs && nowMs <= (occStartMs + 60 * 1000) && occStartMs > root.serviceStartTime) {
                        shouldFire = true;
                    }
                }

                if (shouldFire) {
                    let updatedReminders = Object.assign({}, root.firedReminders);
                    updatedReminders[fireKey] = nowMs;
                    root.firedReminders = updatedReminders;
                    root.sendEventNotification(ev, occStart, occEnd, isAllDay);
                }
            }
        }
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    function isoLocal(date) {
        let tzOffsetMin = -date.getTimezoneOffset();
        let sign = tzOffsetMin >= 0 ? "+" : "-";
        tzOffsetMin = Math.abs(tzOffsetMin);
        let tzStr = `${sign}${pad(Math.floor(tzOffsetMin / 60))}:${pad(tzOffsetMin % 60)}`;
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
               `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}${tzStr}`;
    }

    function startOfWeek() {
        const firstDay = Config.options?.time?.firstDayOfWeek ?? 1; // 1=Mon..7=Sun
        const now = new Date();
        const jsDay = now.getDay() === 0 ? 7 : now.getDay();
        const diff = (jsDay - firstDay + 7) % 7;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        start.setDate(start.getDate() - diff + (root.weekOffset * 7));
        return start;
    }

    function dayName(date) {
        const jsDay = date.getDay() === 0 ? 7 : date.getDay();
        return Qt.locale().dayName(jsDay, Locale.ShortFormat);
    }

    function nextWeek() {
        root.weekOffset++;
    }

    function prevWeek() {
        root.weekOffset--;
    }

    function goToToday() {
        root.weekOffset = 0;
    }

    function weekRangeLabel() {
        const start = root.startOfWeek();
        const end = new Date(start);
        end.setDate(end.getDate() + (root.daysShown - 1));

        const loc = Qt.locale();
        const startMonth = loc.monthName(start.getMonth(), Locale.ShortFormat);
        const endMonth = loc.monthName(end.getMonth(), Locale.ShortFormat);

        if (start.getFullYear() !== end.getFullYear()) {
            return `${start.getDate()} ${startMonth} ${start.getFullYear()} – ${end.getDate()} ${endMonth} ${end.getFullYear()}`;
        }
        if (start.getMonth() !== end.getMonth()) {
            return `${start.getDate()} ${startMonth} – ${end.getDate()} ${endMonth} ${start.getFullYear()}`;
        }
        return `${start.getDate()} – ${end.getDate()} ${startMonth} ${start.getFullYear()}`;
    }

    function rebuildWeek() {
        const start = root.startOfWeek();
        let days = [];
        for (let i = 0; i < root.daysShown; i++) {
            let d = new Date(start);
            d.setDate(d.getDate() + i);
            days.push({ "name": root.dayName(d), "date": d, "events": [] });
        }

        for (const ev of root.localEvents) root.placeEventInDays(days, ev);
        root.eventsInWeek = days;
    }

    onWeekOffsetChanged: root.rebuildWeek()
    onLocalEventsChanged: {
        root.rebuildWeek();
        if (reminderTimer.running) root.checkReminders();
    }

    FileView {
        id: localDataFileView
        path: Qt.resolvedUrl(Directories.calendarLocalDataPath)
        watchChanges: true
        onLoaded: {
            try {
                const parsed = JSON.parse(localDataFileView.text());
                let needsMigration = false;
                const events = (parsed.localEvents ?? []).map(function(ev) {
                    let migratedEv = Object.assign({
                        "repeat": "none",
                        "repeatUntil": "",
                        "reminder": -1
                    }, ev);
                    if (!migratedEv.id) {
                        needsMigration = true;
                        migratedEv.id = `local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
                    }
                    if (ev.repeat === undefined || ev.reminder === undefined) {
                        needsMigration = true;
                    }
                    if (migratedEv.reminder === undefined || migratedEv.reminder === null) {
                        migratedEv.reminder = -1;
                    }
                    return migratedEv;
                });
                root.localEvents = events;
                root.customColorOptions = parsed.customColorOptions ?? [];
                if (needsMigration) {
                    console.log("[CalendarService] Backfilled missing fields on old events");
                    root.persistLocalData();
                }
                console.log("[CalendarService] Local data loaded");
                reminderTimer.running = true;
                root.checkReminders();
            } catch (e) {
                console.warn(`[CalendarService] Failed to parse local data: ${e.message}`);
                reminderTimer.running = true;
            }
        }
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) {
                console.log("[CalendarService] Local data file not found, creating new one.");
                root.localEvents = [];
                root.customColorOptions = [];
                localDataFileView.setText(JSON.stringify({ "localEvents": [], "customColorOptions": [] }));
            } else {
                console.warn(`[CalendarService] Error loading local data: ${error}`);
            }
            reminderTimer.running = true;
        }
    }

    Component.onCompleted: {
        localDataFileView.reload();
    }
}