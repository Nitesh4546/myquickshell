import QtQuick
import Quickshell
import "services"

Item {
    function fastResolveIcon(appId) {
        if (!appId) return "application-x-executable";
        const clean = appId.trim();
        if (!clean) return "application-x-executable";

        // 1. Direct DesktopEntries lookup
        let entry = DesktopEntries.byId(clean) || 
                    DesktopEntries.byId(clean + ".desktop") || 
                    DesktopEntries.heuristicLookup(clean);
        if (entry?.icon) return entry.icon;

        // 2. Direct icon theme existence
        if (Quickshell.iconPath(clean, true).length > 0) return clean;
        const lower = clean.toLowerCase();
        if (Quickshell.iconPath(lower, true).length > 0) return lower;

        // 3. Domain prefix (e.g. "quickshell" -> "org.quickshell")
        if (!clean.includes(".")) {
            entry = DesktopEntries.byId("org." + clean) ||
                    DesktopEntries.byId("org.kde." + clean) ||
                    DesktopEntries.byId("org.gnome." + clean) ||
                    DesktopEntries.byId("com." + clean);
            if (entry?.icon) return entry.icon;
            if (Quickshell.iconPath("org." + clean, true).length > 0) return "org." + clean;
        }

        // 4. Reverse domain suffix (e.g. "org.kde.dolphin" -> "dolphin")
        if (clean.includes(".")) {
            const shortName = clean.split('.').pop();
            if (shortName) {
                entry = DesktopEntries.byId(shortName) || DesktopEntries.byId(shortName + ".desktop");
                if (entry?.icon) return entry.icon;
                if (Quickshell.iconPath(shortName, true).length > 0) return shortName;
                if (Quickshell.iconPath(shortName.toLowerCase(), true).length > 0) return shortName.toLowerCase();
            }
        }

        // 5. Substitutions
        if (AppSearch.substitutions[clean]) return AppSearch.substitutions[clean];
        if (AppSearch.substitutions[lower]) return AppSearch.substitutions[lower];

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
        
        console.time("fastResolve all apps");
        for (const app of apps) {
            console.time("app " + app);
            const icon = fastResolveIcon(app);
            console.timeEnd("app " + app);
            console.log("Result:", app, "=>", icon);
        }
        console.timeEnd("fastResolve all apps");
        Qt.quit();
    }
}
