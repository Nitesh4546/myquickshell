import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root

    function fastResolveIcon(appId) {
        if (!appId) return "application-x-executable";

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

        // 2. Direct icon theme existence check (0.05ms)
        const lower = appId.toLowerCase();
        if (AppSearch.iconExists(appId)) return appId;
        if (AppSearch.iconExists(lower)) return lower;

        // 3. Substitution table
        if (AppSearch.substitutions[appId]) return AppSearch.substitutions[appId];
        if (AppSearch.substitutions[lower]) return AppSearch.substitutions[lower];

        // 4. Try prefix org. (e.g. quickshell -> org.quickshell)
        if (!appId.includes(".")) {
            if (AppSearch.iconExists("org." + lower)) return "org." + lower;
        }

        // 5. Reverse domain name (e.g. org.kde.dolphin -> dolphin)
        if (appId.includes(".")) {
            const lastPart = lower.split('.').pop();
            if (AppSearch.iconExists(lastPart)) return lastPart;
        }

        // 6. Skip expensive fuzzy search for dummy/extremely long strings
        if (appId.length > 35) {
            return "application-x-executable";
        }

        // 7. Full AppSearch fallback only for short unresolved names
        return AppSearch.guessIcon(appId);
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
        
        console.time("BENCHMARK_FAST_RESOLVE");
        for (const app of apps) {
            console.time("fast: " + app);
            const icon = fastResolveIcon(app);
            console.timeEnd("fast: " + app);
            console.log("  result:", app, "=>", icon);
        }
        console.timeEnd("BENCHMARK_FAST_RESOLVE");

        Qt.quit();
    }
}
