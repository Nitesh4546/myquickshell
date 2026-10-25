import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root
    property var iconExistsCache: ({})

    function fastIconExists(name) {
        if (!name || name.length === 0 || name.length > 32 || name.includes(" ")) return false;
        if (root.iconExistsCache[name] !== undefined) return root.iconExistsCache[name];
        const res = AppSearch.iconExists(name);
        root.iconExistsCache[name] = res;
        return res;
    }

    function fastResolveIcon(appId) {
        if (!appId || appId.length === 0) return "application-x-executable";
        if (appId.length > 32) return "application-x-executable";

        // 1. Desktop entry lookup (instant C++ map lookup)
        let entry = DesktopEntries.byId(appId) || 
                    DesktopEntries.byId(appId + ".desktop") || 
                    DesktopEntries.heuristicLookup(appId);

        if (!entry && !appId.includes(".")) {
            entry = DesktopEntries.byId("org." + appId) ||
                    DesktopEntries.byId("org.kde." + appId) ||
                    DesktopEntries.byId("org.gnome." + appId) ||
                    DesktopEntries.byId("com." + appId);
        }
        if (entry && entry.icon && entry.icon.length > 0) {
            return entry.icon;
        }

        // 2. Direct icon theme existence check via fast cache
        const lower = appId.toLowerCase();
        if (fastIconExists(appId)) return appId;
        if (fastIconExists(lower)) return lower;

        // 3. Substitution table
        if (AppSearch.substitutions[appId]) return AppSearch.substitutions[appId];
        if (AppSearch.substitutions[lower]) return AppSearch.substitutions[lower];

        // 4. Try prefix org. (e.g. quickshell -> org.quickshell)
        if (!appId.includes(".")) {
            if (fastIconExists("org." + lower)) return "org." + lower;
        }

        // 5. Reverse domain name (e.g. org.kde.dolphin -> dolphin)
        if (appId.includes(".")) {
            const lastPart = lower.split('.').pop();
            if (fastIconExists(lastPart)) return lastPart;
        }

        return "application-x-executable";
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
        
        console.time("BENCHMARK_FAST_RESOLVE_2");
        for (const app of apps) {
            console.time("fast2: " + app);
            const icon = fastResolveIcon(app);
            console.timeEnd("fast2: " + app);
            console.log("  result:", app, "=>", icon);
        }
        console.timeEnd("BENCHMARK_FAST_RESOLVE_2");

        Qt.quit();
    }
}
