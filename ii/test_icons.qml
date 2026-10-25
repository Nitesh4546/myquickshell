import QtQuick
import Quickshell
import Quickshell.Io
import "services"

Item {
    Component.onCompleted: {
        const testApps = ["firefox", "org.kde.dolphin", "chromium", "kitty", "mpv", "vlc", "slack", "discord", "quickshell", "org.quickshell", "antigravity-ide"];
        for (const app of testApps) {
            const e1 = DesktopEntries.byId(app);
            const e2 = DesktopEntries.byId(app + ".desktop");
            const e3 = DesktopEntries.heuristicLookup(app);
            const guess = AppSearch.guessIcon(app);
            const path = Quickshell.iconPath(guess, "image-missing");
            console.log(`[TEST] ${app}: byId=${e1?.id}, byId(.desktop)=${e2?.id}, heuristic=${e3?.id}, guessIcon=${guess}, iconPath=${path}`);
        }
        Qt.quit();
    }
}
