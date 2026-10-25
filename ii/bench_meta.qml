import QtQuick
import Quickshell
import "services"

Item {
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
        
        console.time("getAppMeta all apps");
        for (const app of apps) {
            console.time("app " + app);
            let entry = DesktopEntries.byId(app) || DesktopEntries.byId(app + ".desktop") || DesktopEntries.heuristicLookup(app);
            if (!entry && !app.includes(".")) {
                entry = DesktopEntries.byId("org." + app) || DesktopEntries.byId("org.kde." + app) || DesktopEntries.byId("org.gnome." + app) || DesktopEntries.byId("com." + app);
            }
            let icon = entry?.icon;
            if (!icon) {
                icon = AppSearch.guessIcon(app);
            }
            if (!icon || icon === "application-x-executable" || icon === "image-missing") {
                if (!app.includes(".")) {
                    const guessedWithOrg = AppSearch.guessIcon("org." + app);
                    if (guessedWithOrg && guessedWithOrg !== "application-x-executable" && guessedWithOrg !== "image-missing") {
                        icon = guessedWithOrg;
                    }
                }
            }
            console.timeEnd("app " + app);
        }
        console.timeEnd("getAppMeta all apps");
        Qt.quit();
    }
}
