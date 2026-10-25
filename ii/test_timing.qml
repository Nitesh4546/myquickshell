import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    id: root

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
        
        console.time("TOTAL_RESOLUTION_BEFORE_DE");
        for (const app of apps) {
            console.time("app: " + app);
            const icon = AppSearch.guessIcon(app);
            console.timeEnd("app: " + app);
        }
        console.timeEnd("TOTAL_RESOLUTION_BEFORE_DE");

        Qt.quit();
    }
}
