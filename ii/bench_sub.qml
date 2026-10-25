import QtQuick
import Quickshell
import "services"

Item {
    Component.onCompleted: {
        const app = "very-long-application-name-that-should-be-elided-properly-in-chip";
        console.time("byId");
        DesktopEntries.byId(app);
        console.timeEnd("byId");

        console.time("heuristicLookup");
        DesktopEntries.heuristicLookup(app);
        console.timeEnd("heuristicLookup");

        console.time("iconPath exact");
        Quickshell.iconPath(app, true);
        console.timeEnd("iconPath exact");

        console.time("iconPath org");
        Quickshell.iconPath("org." + app, true);
        console.timeEnd("iconPath org");

        Qt.quit();
    }
}
