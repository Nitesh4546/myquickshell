import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root
    property var metaCache: ({})
    property var iconExistsCache: ({})

    function fastIconExists(name) {
        if (!name || name.length === 0 || name.length > 32 || name.includes(" ")) return false;
        if (root.iconExistsCache[name] !== undefined) return root.iconExistsCache[name];
        const res = AppSearch.iconExists(name);
        root.iconExistsCache[name] = res;
        return res;
    }

    function getAppMeta(appId) {
        if (!appId || appId.length === 0) return { name: "", icon: "application-x-executable" };
        if (root.metaCache[appId]) return root.metaCache[appId];

        let name = appId;
        if (name.includes(".")) {
            const parts = name.split(".");
            name = parts[parts.length - 1];
        }
        if (name.length > 0 && name.length < 35) {
            name = name.charAt(0).toUpperCase() + name.slice(1);
        }

        if (appId.length > 32) {
            const fallback = { name: name, icon: "application-x-executable" };
            root.metaCache[appId] = fallback;
            return fallback;
        }

        let entry = DesktopEntries.byId(appId) || 
                    DesktopEntries.byId(appId + ".desktop") || 
                    DesktopEntries.heuristicLookup(appId);

        if (!entry && !appId.includes(".")) {
            entry = DesktopEntries.byId("org." + appId) ||
                    DesktopEntries.byId("org.kde." + appId) ||
                    DesktopEntries.byId("org.gnome." + appId) ||
                    DesktopEntries.byId("com." + appId);
        }

        if (entry) {
            const res = {
                name: entry.name || name,
                icon: entry.icon || appId
            };
            root.metaCache[appId] = res;
            return res;
        }

        const cached = UsageTracker.usageData?.apps?.[appId];
        if (cached && (cached.name || cached.icon)) {
            const res = {
                name: cached.name || name,
                icon: cached.icon || "application-x-executable"
            };
            root.metaCache[appId] = res;
            return res;
        }

        const lower = appId.toLowerCase();
        let icon = "";
        if (root.fastIconExists(appId)) icon = appId;
        else if (root.fastIconExists(lower)) icon = lower;
        else if (AppSearch.substitutions[appId]) icon = AppSearch.substitutions[appId];
        else if (AppSearch.substitutions[lower]) icon = AppSearch.substitutions[lower];
        else if (!appId.includes(".") && root.fastIconExists("org." + lower)) icon = "org." + lower;
        else if (appId.includes(".")) {
            const lastPart = lower.split('.').pop();
            if (root.fastIconExists(lastPart)) icon = lastPart;
        }

        if (!icon) {
            icon = "application-x-executable";
        }

        const res = { name: name, icon: icon };
        root.metaCache[appId] = res;
        return res;
    }

    Component.onCompleted: {
        const apps = [
            "org.quickshell",
            "quickshell",
            "firefox",
            "chromium",
            "org.kde.dolphin",
            "antigravity-ide",
            "very-long-application-name-that-should-be-elided-properly-in-chip",
            "another-super-long-desktop-entry-window-class-identifier-to-test-chip-width",
            "kitty",
            "mpv",
            "vlc",
            "slack",
            "discord"
        ];
        
        console.time("TOTAL_13_APPS_TIME");
        for (const app of apps) {
            const meta = getAppMeta(app);
            console.log("  result:", app, "=>", meta.name, "(icon:", meta.icon, ")");
        }
        console.timeEnd("TOTAL_13_APPS_TIME");

        Qt.quit();
    }
}
