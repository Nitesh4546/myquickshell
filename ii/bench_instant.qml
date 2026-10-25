import QtQuick
import Quickshell
import "services"

Item {
    function getAppMeta(appId) {
        if (!appId) return { name: "", icon: "application-x-executable" };

        const clean = appId.trim();
        const lower = clean.toLowerCase();

        let entry = DesktopEntries.byId(clean) || 
                    DesktopEntries.byId(clean + ".desktop") || 
                    DesktopEntries.heuristicLookup(clean);

        if (!entry && !clean.includes(".")) {
            entry = DesktopEntries.byId("org." + clean) ||
                    DesktopEntries.byId("org.kde." + clean) ||
                    DesktopEntries.byId("org.gnome." + clean) ||
                    DesktopEntries.byId("com." + clean);
        }

        if (!entry && clean.includes(".")) {
            const shortName = clean.split('.').pop().toLowerCase();
            entry = DesktopEntries.byId(shortName) || DesktopEntries.byId(shortName + ".desktop");
        }

        let name = entry?.name;
        let icon = entry?.icon;

        if (!icon) {
            icon = AppSearch.substitutions[clean] || AppSearch.substitutions[lower];
        }

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
        
        console.time("instantResolve ALL 13 apps");
        for (const app of apps) {
            console.time("app: " + app);
            const meta = getAppMeta(app);
            console.timeEnd("app: " + app);
            console.log(`Resolved: ${app} -> name="${meta.name}", icon="${meta.icon}"`);
        }
        console.timeEnd("instantResolve ALL 13 apps");
        Qt.quit();
    }
}
