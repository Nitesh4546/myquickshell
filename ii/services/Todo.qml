pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * To-do list manager with due dates and reminders.
 * Each item is an object with "id", "content", "done", "due", and "reminder" properties.
 */
Singleton {
    id: root
    property var filePath: Directories.todoPath
    property var list: []
    property var firedReminders: ({})
    property bool isLoaded: false

    readonly property var priorityColors: ({
        0: "transparent",
        1: "#1cbaba",
        2: "#ffb700",
        3: "#f63737"
    })
    readonly property var priorityNames: ({
        0: Translation.tr("None"),
        1: Translation.tr("Low"),
        2: Translation.tr("Medium"),
        3: Translation.tr("High")
    })

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
        running: root.isLoaded
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
        notifyProcess.command = ["notify-send", "-a", "To Do", "-i", "done_outline", item.title, item.body];
        notifyProcess.running = true;
    }

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    function isoLocal(date) {
        if (!date || isNaN(date.getTime())) return "";
        let tzOffsetMin = -date.getTimezoneOffset();
        let sign = tzOffsetMin >= 0 ? "+" : "-";
        tzOffsetMin = Math.abs(tzOffsetMin);
        let tzStr = `${sign}${pad(Math.floor(tzOffsetMin / 60))}:${pad(tzOffsetMin % 60)}`;
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
               `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}${tzStr}`;
    }

    function formatDateOnly(d) {
        if (!d || isNaN(d.getTime())) return "";
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    }

    function dueDate(task) {
        if (!task || !task.due) return null;
        let dueStr = String(task.due).trim();
        if (!dueStr) return null;
        let dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dueStr);
        if (dateOnlyMatch) {
            let y = parseInt(dateOnlyMatch[1]);
            let m = parseInt(dateOnlyMatch[2]) - 1;
            let d = parseInt(dateOnlyMatch[3]);
            return new Date(y, m, d, 23, 59, 59, 999);
        }
        let dt = new Date(dueStr);
        return isNaN(dt.getTime()) ? null : dt;
    }

    function isOverdue(task) {
        if (!task || task.done || !task.due) return false;
        let d = dueDate(task);
        if (!d || isNaN(d.getTime())) return false;
        return Date.now() > d.getTime();
    }

    function isDueToday(task) {
        if (!task || !task.due) return false;
        let d = dueDate(task);
        if (!d || isNaN(d.getTime())) return false;
        let now = new Date();
        return d.getFullYear() === now.getFullYear() &&
               d.getMonth() === now.getMonth() &&
               d.getDate() === now.getDate();
    }

    function addItem(item) {
        if (!item.id) {
            item.id = `todo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
        }
        if (item.due === undefined) item.due = "";
        if (item.reminder === undefined || item.reminder === null) item.reminder = -1;
        if (item.priority === undefined || item.priority === null) item.priority = 0;
        else item.priority = Math.max(0, Math.min(3, parseInt(item.priority) || 0));
        list.push(item)
        // Reassign to trigger onListChanged
        root.list = list.slice(0)
        todoFileView.setText(JSON.stringify(root.list))
    }

    function addTask(desc, due = "", reminder = -1, priority = 0) {
        let p = (priority !== undefined && priority !== null) ? parseInt(priority) : 0;
        const item = {
            "id": `todo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            "content": desc,
            "done": false,
            "due": due || "",
            "reminder": (reminder !== undefined && reminder !== null) ? parseInt(reminder) : -1,
            "priority": Math.max(0, Math.min(3, isNaN(p) ? 0 : p))
        }
        addItem(item)
    }

    function setPriority(index, priority) {
        if (index >= 0 && index < list.length) {
            let p = parseInt(priority);
            if (isNaN(p)) p = 0;
            list[index].priority = Math.max(0, Math.min(3, p));
            root.list = list.slice(0);
            todoFileView.setText(JSON.stringify(root.list));
        }
    }

    function updateDue(index, due, reminder) {
        if (index >= 0 && index < list.length) {
            list[index].due = due || "";
            list[index].reminder = (reminder !== undefined && reminder !== null) ? parseInt(reminder) : -1;
            root.list = list.slice(0);
            todoFileView.setText(JSON.stringify(root.list));
        }
    }

    function updateTask(index, content) {
        let trimmed = (content || "").trim();
        if (index >= 0 && index < list.length && trimmed.length > 0) {
            list[index].content = trimmed;
            root.list = list.slice(0);
            todoFileView.setText(JSON.stringify(root.list));
        }
    }

    function updateTaskDetails(index, content, due, reminder, priority) {
        if (index >= 0 && index < list.length) {
            let trimmed = (content || "").trim();
            if (trimmed.length > 0) list[index].content = trimmed;
            if (due !== undefined && due !== null) list[index].due = due || "";
            if (reminder !== undefined && reminder !== null) list[index].reminder = parseInt(reminder);
            if (priority !== undefined && priority !== null) {
                let p = parseInt(priority);
                list[index].priority = Math.max(0, Math.min(3, isNaN(p) ? 0 : p));
            }
            root.list = list.slice(0);
            todoFileView.setText(JSON.stringify(root.list));
        }
    }

    function markDone(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = true
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function markUnfinished(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = false
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < list.length) {
            list.splice(index, 1)
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    function getTriggerMs(task) {
        if (!task || !task.due || task.reminder === undefined || task.reminder === null || task.reminder < 0) return null;
        let dueStr = String(task.due).trim();
        let dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dueStr);
        if (dateOnlyMatch) {
            let y = parseInt(dateOnlyMatch[1]);
            let m = parseInt(dateOnlyMatch[2]) - 1;
            let d = parseInt(dateOnlyMatch[3]);
            return new Date(y, m, d, 9, 0, 0, 0).getTime();
        }
        let dt = new Date(dueStr);
        if (isNaN(dt.getTime())) return null;
        let reminderMs = parseInt(task.reminder) * 60 * 1000;
        return dt.getTime() - reminderMs;
    }

    function initStartupReminders() {
        let nowMs = Date.now();
        let initialFired = {};
        for (let task of root.list) {
            if (task.done || !task.due || task.reminder === undefined || task.reminder === null || task.reminder < 0) continue;
            let triggerMs = getTriggerMs(task);
            if (triggerMs !== null && triggerMs <= nowMs) {
                let key = `${task.id}|${task.due}|${task.reminder}`;
                initialFired[key] = triggerMs;
            }
        }
        root.firedReminders = initialFired;
    }

    function checkReminders() {
        let nowMs = Date.now();

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

        for (let task of root.list) {
            if (task.done || !task.due || task.reminder === undefined || task.reminder === null || task.reminder < 0) continue;

            let triggerMs = getTriggerMs(task);
            if (triggerMs === null) continue;

            let fireKey = `${task.id}|${task.due}|${task.reminder}`;
            if (root.firedReminders[fireKey]) continue;

            let shouldFire = false;
            let dueStr = String(task.due).trim();
            let isDateOnly = /^\d{4}-\d{2}-\d{2}$/.test(dueStr);

            if (isDateOnly) {
                // Fire at 09:00 on that day (within 1 minute window)
                if (nowMs >= triggerMs && nowMs < (triggerMs + 60 * 1000)) {
                    shouldFire = true;
                }
            } else {
                // Timed due: fire when now >= due - reminder minutes and now < due + 1 min
                let dt = new Date(dueStr);
                let dueMs = dt.getTime();
                if (nowMs >= triggerMs && nowMs < (dueMs + 60 * 1000)) {
                    shouldFire = true;
                }
            }

            if (shouldFire) {
                let updatedReminders = Object.assign({}, root.firedReminders);
                updatedReminders[fireKey] = nowMs;
                root.firedReminders = updatedReminders;

                let title = task.content || Translation.tr("To Do");
                let tf = (Config.options && Config.options.time && Config.options.time.format) ? Config.options.time.format : "hh:mm";
                let body = isDateOnly ? Translation.tr("Due today") :
                    Translation.tr("Due %1").arg(Qt.formatTime(new Date(dueStr), tf));
                root.sendNotification(title, body);
            }
        }
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: root.refresh()
        onLoaded: {
            try {
                const fileContents = todoFileView.text();
                let parsed = JSON.parse(fileContents);
                if (!Array.isArray(parsed)) parsed = [];
                let needsMigration = false;
                let migratedList = parsed.map(function(item) {
                    let task = Object.assign({
                        "due": "",
                        "reminder": -1,
                        "priority": 0
                    }, item);
                    if (!task.id) {
                        needsMigration = true;
                        task.id = `todo-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
                    }
                    if (item.due === undefined || item.reminder === undefined || item.priority === undefined) {
                        needsMigration = true;
                    }
                    if (task.reminder === undefined || task.reminder === null) {
                        task.reminder = -1;
                    }
                    if (task.priority === undefined || task.priority === null) {
                        task.priority = 0;
                    } else {
                        task.priority = Math.max(0, Math.min(3, parseInt(task.priority) || 0));
                    }
                    return task;
                });
                root.list = migratedList;
                if (needsMigration) {
                    console.log("[To Do] Backfilled missing fields on old tasks");
                    todoFileView.setText(JSON.stringify(root.list));
                }
                console.log("[To Do] File loaded");
                root.isLoaded = true;
                root.initStartupReminders();
                root.checkReminders();
            } catch (e) {
                console.warn("[To Do] Error parsing file: " + e);
                root.list = [];
                root.isLoaded = true;
            }
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[To Do] File not found, creating new file.")
                root.list = []
                todoFileView.setText(JSON.stringify(root.list))
            } else {
                console.log("[To Do] Error loading file: " + error)
            }
            root.isLoaded = true;
        }
    }
}


