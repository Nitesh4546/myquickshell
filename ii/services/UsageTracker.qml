pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool isTracker: false
    property string filePath: Directories.usagePath

    property bool isLoaded: false
    property bool dataDirty: false
    property bool runtimePaused: false

    FileView {
        id: pauseFlagView
        path: Qt.resolvedUrl("/tmp/quickshell/usage_paused")
        watchChanges: true
        onLoaded: {
            root.runtimePaused = true;
            root.transitionState();
        }
        onLoadFailed: {
            root.runtimePaused = false;
            root.transitionState();
        }
    }

    function setRuntimePaused(paused) {
        root.runtimePaused = paused;
        if (paused) {
            Quickshell.execDetached(["bash", "-c", "mkdir -p /tmp/quickshell && touch /tmp/quickshell/usage_paused"]);
            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "usageTracker", "pause"]);
        } else {
            Quickshell.execDetached(["rm", "-f", "/tmp/quickshell/usage_paused"]);
            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "usageTracker", "resume"]);
        }
        root.transitionState();
    }

    readonly property bool serviceEnabled: Config.options?.usage?.enable ?? true
    readonly property bool trackingActive: isTracker && serviceEnabled && !runtimePaused

    property var usageData: ({
        "version": 1,
        "apps": ({}),
        "days": ({})
    })

    property string currentApp: ""
    property real sinceTime: 0
    property real lastTickTime: 0

    property int todayTotalSec: 0
    property var todayTopApps: []
    property var last7DaysList: []
    property int last7DaysMaxSec: 0
    property int dataRevision: 0

    signal dataChanged()
    onDataChanged: root.computeTodayAndWeekStats()

    function load() {
        if (!isLoaded && usageFileView) {
            usageFileView.reload();
        }
    }

    function refresh() {
        if (usageFileView) {
            usageFileView.reload();
        }
    }

    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel
    readonly property string rawActiveAppId: {
        if (!activeToplevel || !activeToplevel.activated) return "";
        let id = activeToplevel.appId ? activeToplevel.appId.trim() : "";
        if (id.length === 0) {
            const client = HyprlandData.clientForToplevel(activeToplevel);
            id = (client?.class || client?.initialClass || "").trim();
        }
        return id.toLowerCase();
    }

    onRawActiveAppIdChanged: root.transitionState()
    onTrackingActiveChanged: root.transitionState()

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            root.transitionState();
        }
    }

    Connections {
        target: Hyprland
        enabled: root.trackingActive
        function onRawEvent(event) {
            if (event.name === "activewindow" || event.name === "activewindowv2") {
                root.transitionState();
            }
        }
    }

    IdleMonitor {
        id: idleMonitor
        enabled: root.trackingActive
        timeout: Config.options?.usage?.idleTimeoutSec ?? 120
        respectInhibitors: true
        onIsIdleChanged: root.transitionState()
    }

    Timer {
        id: commitTimer
        interval: 30000
        repeat: true
        running: root.trackingActive
        onTriggered: {
            root.transitionState();
        }
    }

    Timer {
        id: saveTimer
        interval: 60000
        repeat: true
        running: root.trackingActive && root.dataDirty
        onTriggered: {
            root.saveNow();
        }
    }

    Timer {
        id: dailyPruneTimer
        interval: 86400000
        repeat: true
        running: root.trackingActive
        onTriggered: {
            root.pruneRetention();
        }
    }

    function getQualifyingApp() {
        if (!root.trackingActive) return "";
        if (GlobalStates.screenLocked) return "";
        if (idleMonitor.isIdle) return "";
        const appId = root.rawActiveAppId;
        if (!appId || appId.length === 0) return "";
        const excluded = Config.options?.usage?.excludedApps ?? [];
        for (let i = 0; i < excluded.length; i++) {
            if (excluded[i] && excluded[i].toLowerCase() === appId) return "";
        }
        return appId;
    }

    function pad2(n) {
        return String(n).padStart(2, "0");
    }

    function formatDateKey(d) {
        if (!d || isNaN(d.getTime())) d = new Date();
        return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
    }

    function resolveAppMetadata(appId) {
        if (!appId) return { name: "", icon: "application-x-executable" };

        const clean = appId.trim();
        const lower = clean.toLowerCase();

        // 1. Direct in-memory DesktopEntries lookup
        let entry = DesktopEntries.byId(clean) || 
                    DesktopEntries.byId(clean + ".desktop") || 
                    DesktopEntries.heuristicLookup(clean);

        // 2. Try common domain prefixes for non-domain IDs (e.g. "quickshell" -> "org.quickshell")
        if (!entry && !clean.includes(".")) {
            entry = DesktopEntries.byId("org." + clean) ||
                    DesktopEntries.byId("org.kde." + clean) ||
                    DesktopEntries.byId("org.gnome." + clean) ||
                    DesktopEntries.byId("com." + clean);
        }

        // 3. Try reverse domain name for domain IDs (e.g. "com.discordapp.Discord" -> "discord")
        if (!entry && clean.includes(".")) {
            const shortName = clean.split('.').pop().toLowerCase();
            entry = DesktopEntries.byId(shortName) || DesktopEntries.byId(shortName + ".desktop");
        }

        let name = entry?.name;
        let icon = entry?.icon;

        // 4. In-memory substitutions
        if (!icon) {
            icon = AppSearch.substitutions[clean] || AppSearch.substitutions[lower];
        }

        // 5. Clean string as direct icon name (Kirigami.Icon resolves it asynchronously)
        if (!icon) {
            if (/^[a-zA-Z0-9_\-\.]+$/.test(clean) && clean.length < 32) {
                icon = clean.includes(".") ? clean.split('.').pop().toLowerCase() : lower;
            } else {
                icon = "application-x-executable";
            }
        }

        if (!name || name.length === 0) {
            name = clean;
            if (name.includes(".")) {
                const parts = name.split(".");
                name = parts[parts.length - 1];
            }
            if (name.length > 0) {
                name = name.charAt(0).toUpperCase() + name.slice(1);
            }
        }

        return { name: name, icon: icon };
    }

    function ensureAppMetadata(appId) {
        if (!appId) return;
        if (!root.usageData.apps) root.usageData.apps = {};
        const existing = root.usageData.apps[appId];
        if (existing && existing.icon && existing.icon !== "application-x-executable" && existing.name) return;

        const resolved = resolveAppMetadata(appId);
        root.usageData.apps[appId] = resolved;
        root.dataDirty = true;
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (!root.usageData?.apps) return;
            let changed = false;
            for (const appId in root.usageData.apps) {
                const curr = root.usageData.apps[appId];
                if (!curr || !curr.icon || curr.icon === "application-x-executable") {
                    const resolved = root.resolveAppMetadata(appId);
                    if (resolved.icon !== "application-x-executable" || resolved.name !== curr?.name) {
                        root.usageData.apps[appId] = resolved;
                        changed = true;
                    }
                }
            }
            if (changed) {
                root.dataDirty = true;
                root.computeTodayAndWeekStats();
                root.dataChanged();
            }
        }
    }

    function addTimeToDate(dateObj, appId, seconds) {
        if (!appId || seconds <= 0) return;
        if (!root.usageData.days) root.usageData.days = {};
        const dayKey = formatDateKey(dateObj);
        if (!root.usageData.days[dayKey]) {
            root.usageData.days[dayKey] = {};
        }
        const current = root.usageData.days[dayKey][appId] || 0;
        root.usageData.days[dayKey][appId] = current + seconds;
        ensureAppMetadata(appId);
        root.dataDirty = true;
        root.dataChanged();
    }

    function commitCredit(appId, startMs, endMs, totalSec) {
        if (!appId || totalSec <= 0) return;
        const startDate = new Date(startMs);
        const endDate = new Date(endMs);

        if (startDate.toDateString() !== endDate.toDateString()) {
            const midnight = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate(), 0, 0, 0, 0).getTime();
            const secBefore = Math.floor((midnight - startMs) / 1000);
            const secAfter = Math.floor((endMs - midnight) / 1000);
            if (secBefore > 0) {
                addTimeToDate(startDate, appId, Math.min(secBefore, totalSec));
            }
            if (secAfter > 0) {
                addTimeToDate(endDate, appId, Math.min(secAfter, totalSec));
            }
        } else {
            addTimeToDate(endDate, appId, totalSec);
        }
    }

    function transitionState() {
        if (!root.isTracker) return;
        const now = Date.now();

        const gapSinceLastTick = root.lastTickTime > 0 ? (now - root.lastTickTime) : 0;
        const isStalledOrSuspended = gapSinceLastTick > 90000;

        if (root.currentApp && root.sinceTime > 0 && !isStalledOrSuspended) {
            const deltaMs = now - root.sinceTime;
            const deltaSec = Math.floor(deltaMs / 1000);
            if (deltaSec > 0) {
                const creditSec = Math.min(deltaSec, 60);
                commitCredit(root.currentApp, root.sinceTime, now, creditSec);
            }
        }

        root.lastTickTime = now;
        root.sinceTime = now;
        root.currentApp = root.getQualifyingApp();
    }

    function testMidnightSplit(syntheticSinceMs, syntheticNowMs, testAppId) {
        const deltaSec = Math.floor((syntheticNowMs - syntheticSinceMs) / 1000);
        const creditSec = Math.min(deltaSec, 60);
        commitCredit(testAppId, syntheticSinceMs, syntheticNowMs, creditSec);
    }

    function pruneRetention() {
        if (!root.isTracker || !root.usageData || !root.usageData.days) return;
        const retentionDays = Config.options?.usage?.retentionDays ?? 90;
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - retentionDays);
        const cutoffKey = formatDateKey(cutoffDate);

        let changed = false;
        const referencedApps = new Set();

        for (const dayKey in root.usageData.days) {
            if (dayKey < cutoffKey) {
                delete root.usageData.days[dayKey];
                changed = true;
            } else {
                const dayApps = root.usageData.days[dayKey];
                for (const appId in dayApps) {
                    referencedApps.add(appId);
                }
            }
        }

        if (root.usageData.apps) {
            for (const appId in root.usageData.apps) {
                if (!referencedApps.has(appId)) {
                    delete root.usageData.apps[appId];
                    changed = true;
                }
            }
        }

        if (changed) {
            root.dataDirty = true;
            root.saveNow();
            root.dataChanged();
        }
    }

    function saveNow() {
        if (!root.isTracker) return;
        if (!root.isLoaded) return;
        if (!root.dataDirty) return;

        try {
            const text = JSON.stringify(root.usageData, null, 2);
            usageFileView.setText(text);
            root.dataDirty = false;
        } catch (e) {
            console.warn("[UsageTracker] Error saving data: " + e);
        }
    }

    function clearAllData() {
        root.usageData = {
            "version": 1,
            "apps": ({}),
            "days": ({})
        };
        root.currentApp = "";
        root.sinceTime = Date.now();
        root.lastTickTime = Date.now();
        try {
            usageFileView.setText(JSON.stringify(root.usageData, null, 2));
            root.dataDirty = false;
            root.dataChanged();
        } catch (e) {
            console.warn("[UsageTracker] Error clearing data: " + e);
        }
    }

    function formatDuration(sec) {
        if (sec === undefined || sec === null || isNaN(sec) || sec <= 0) return "<1 min";
        const totalMinutes = Math.floor(sec / 60);
        if (totalMinutes < 1) {
            return "<1 min";
        }
        if (totalMinutes < 60) {
            return `${totalMinutes} min`;
        }
        const hours = Math.floor(totalMinutes / 60);
        const remMinutes = totalMinutes % 60;
        const padMin = String(remMinutes).padStart(2, "0");
        return `${hours} h ${padMin} min`;
    }

    function buildTopAppsWithOthers(sortedList, totalSec, maxTop) {
        if (!sortedList || sortedList.length === 0) return [];
        const limit = (typeof maxTop === "number" && maxTop > 0) ? maxTop : 8;
        const top = sortedList.slice(0, limit);
        const rest = sortedList.slice(limit);
        let othersSec = 0;
        for (let i = 0; i < rest.length; i++) {
            othersSec += rest[i].seconds;
        }
        const result = [];
        for (let i = 0; i < top.length; i++) {
            const item = top[i];
            const pct = totalSec > 0 ? Math.round((item.seconds / totalSec) * 100) : 0;
            result.push({
                id: item.id,
                name: item.name,
                icon: item.icon,
                seconds: item.seconds,
                percent: pct,
                fraction: totalSec > 0 ? (item.seconds / totalSec) : 0
            });
        }
        if (othersSec > 0) {
            const pct = totalSec > 0 ? Math.round((othersSec / totalSec) * 100) : 0;
            result.push({
                id: "others",
                name: Translation.tr("Others"),
                icon: "more_horiz",
                seconds: othersSec,
                percent: pct,
                fraction: totalSec > 0 ? (othersSec / totalSec) : 0
            });
        }
        return result;
    }

    function computeTodayAndWeekStats() {
        const rawData = root.usageData;
        const daysData = rawData?.days ?? {};
        const appsData = rawData?.apps ?? {};

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Last 7 days
        const dList = [];
        let max7Day = 0;
        for (let i = 6; i >= 0; i--) {
            const d = new Date(today);
            d.setDate(d.getDate() - i);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const dayNum = String(d.getDate()).padStart(2, "0");
            const dayKey = `${y}-${m}-${dayNum}`;

            const dayApps = daysData[dayKey] || {};
            let dayTotal = 0;
            for (const appId in dayApps) {
                dayTotal += (dayApps[appId] || 0);
            }
            if (dayTotal > max7Day) max7Day = dayTotal;

            dList.push({
                key: dayKey,
                dateObj: d,
                totalSec: dayTotal,
                isToday: (i === 0),
                weekday: Qt.formatDate(d, "ddd"),
                shortDate: Qt.formatDate(d, Config.options?.time?.shortDateFormat ?? "dd/MM")
            });
        }

        root.last7DaysList = dList;
        root.last7DaysMaxSec = max7Day;

        // Today stats
        const todayKey = dList[6]?.key || root.formatDateKey(today);
        const todayAppsData = daysData[todayKey] || {};
        let tTotal = 0;
        const todayAppList = [];

        for (const appId in todayAppsData) {
            const sec = todayAppsData[appId] || 0;
            if (sec > 0) {
                tTotal += sec;
                const meta = appsData[appId] || {};
                todayAppList.push({
                    id: appId,
                    name: meta.name || appId,
                    icon: meta.icon || "application-x-executable",
                    seconds: sec
                });
            }
        }
        todayAppList.sort((a, b) => b.seconds - a.seconds);

        root.todayTotalSec = tTotal;
        root.todayTopApps = root.buildTopAppsWithOthers(todayAppList, tTotal, 8);
        root.dataRevision++;
    }

    function getRangeAggregates(numDays, selectedDayKey) {
        const rawData = root.usageData;
        const daysData = rawData?.days ?? {};
        const appsData = rawData?.apps ?? {};

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const dList = [];
        let rTotal = 0;
        let mDaily = 0;
        const rangeAppTotals = {};

        for (let i = numDays - 1; i >= 0; i--) {
            const d = new Date(today);
            d.setDate(d.getDate() - i);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, "0");
            const dayNum = String(d.getDate()).padStart(2, "0");
            const dayKey = `${y}-${m}-${dayNum}`;

            const dayApps = daysData[dayKey] || {};
            let dayTotal = 0;
            for (const appId in dayApps) {
                const sec = dayApps[appId] || 0;
                dayTotal += sec;
                rangeAppTotals[appId] = (rangeAppTotals[appId] || 0) + sec;
            }

            rTotal += dayTotal;
            if (dayTotal > mDaily) mDaily = dayTotal;

            const weekday = Qt.formatDate(d, "ddd");
            const fullDate = Qt.formatDate(d, Config.options?.time?.dateFormat ?? "ddd, dd/MM");
            const shortDate = Qt.formatDate(d, Config.options?.time?.shortDateFormat ?? "dd/MM");

            dList.push({
                key: dayKey,
                dateObj: d,
                totalSec: dayTotal,
                isToday: (i === 0),
                weekday: weekday,
                shortDate: shortDate,
                fullDateLabel: fullDate
            });
        }

        const allApps = [];
        for (const appId in rangeAppTotals) {
            const meta = appsData[appId] || {};
            const appSec = rangeAppTotals[appId];
            if (appSec > 0) {
                allApps.push({
                    id: appId,
                    name: meta.name || appId,
                    icon: meta.icon || "application-x-executable",
                    seconds: appSec
                });
            }
        }
        allApps.sort((a, b) => b.seconds - a.seconds);

        let mApp = 0;
        for (let j = 0; j < allApps.length; j++) {
            if (allApps[j].seconds > mApp) mApp = allApps[j].seconds;
        }

        const rangeTopApps = root.buildTopAppsWithOthers(allApps, rTotal, 8);

        let selectedDayTopApps = [];
        let selectedDayLabel = "";
        const activeDayKey = (numDays === 1) ? dList[dList.length - 1]?.key : selectedDayKey;
        if (activeDayKey) {
            const activeDayData = daysData[activeDayKey] || {};
            const dayAppList = [];
            let activeDayTotal = 0;
            for (const appId in activeDayData) {
                const meta = appsData[appId] || {};
                const sec = activeDayData[appId] || 0;
                if (sec > 0) {
                    dayAppList.push({
                        id: appId,
                        name: meta.name || appId,
                        icon: meta.icon || "application-x-executable",
                        seconds: sec
                    });
                    activeDayTotal += sec;
                }
            }
            dayAppList.sort((a, b) => b.seconds - a.seconds);
            selectedDayTopApps = root.buildTopAppsWithOthers(dayAppList, activeDayTotal, 8);

            const foundDay = dList.find(item => item.key === activeDayKey);
            selectedDayLabel = foundDay ? `${foundDay.fullDateLabel} (${root.formatDuration(activeDayTotal)})` : activeDayKey;
        }

        return {
            rangeTotalSec: rTotal,
            dailyAverageSec: Math.round(rTotal / numDays),
            maxDailySec: mDaily,
            maxAppSec: mApp,
            dailyList: dList,
            rangeTopApps: rangeTopApps,
            selectedDayTopApps: selectedDayTopApps,
            selectedDayLabel: selectedDayLabel
        };
    }

    function openUsageSettings() {
        const script = "settingsPath=\"$HOME/.config/quickshell/ii/settings.qml\"; if ! qs ipc -p \"$settingsPath\" call settings openPage Usage 2>/dev/null; then QS_SETTINGS_PAGE=Usage qs -p \"$settingsPath\" & fi";
        Quickshell.execDetached(["bash", "-c", script]);
    }

    IpcHandler {
        target: "usageTracker"

        function clear(): void {
            root.clearAllData();
        }

        function pause(): void {
            root.runtimePaused = true;
            root.transitionState();
        }

        function resume(): void {
            root.runtimePaused = false;
            root.transitionState();
        }
    }

    Component.onCompleted: {
        root.load();
    }

    Component.onDestruction: {
        if (root.isTracker) {
            root.transitionState();
            root.saveNow();
        }
    }

    FileView {
        id: usageFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            if (!root.dataDirty) {
                usageFileView.reload();
            }
        }
        onLoaded: {
            try {
                const content = usageFileView.text();
                if (!content || content.trim().length === 0) {
                    root.usageData = { "version": 1, "apps": ({}), "days": ({}) };
                } else {
                    let parsed = JSON.parse(content);
                    if (!parsed || typeof parsed !== "object" || !parsed.days) {
                        throw new Error("Invalid structure");
                    }
                    if (!parsed.apps) parsed.apps = {};
                    root.usageData = parsed;
                }
                root.isLoaded = true;
                root.dataChanged();
                if (root.isTracker) {
                    root.pruneRetention();
                    root.transitionState();
                }
            } catch (e) {
                console.warn("[UsageTracker] Corrupt usage file, renaming to .corrupt: " + e);
                Quickshell.execDetached(["mv", Directories.usagePath, Directories.usagePath + ".corrupt"]);
                root.usageData = { "version": 1, "apps": ({}), "days": ({}) };
                root.isLoaded = true;
                root.dataDirty = true;
                root.saveNow();
                root.dataChanged();
            }
        }
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) {
                root.usageData = { "version": 1, "apps": ({}), "days": ({}) };
                root.isLoaded = true;
                root.dataDirty = true;
                root.saveNow();
                root.dataChanged();
            } else {
                console.warn("[UsageTracker] Error loading file: " + error);
                root.isLoaded = true;
            }
        }
    }
}
