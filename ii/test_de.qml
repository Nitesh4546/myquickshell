import QtQuick
import Quickshell
import Quickshell.Io

Item {
    Component.onCompleted: {
        console.log("Total entries in DesktopEntries.applications:", DesktopEntries.applications.values.length);
        const apps = DesktopEntries.applications.values;
        for (let i = 0; i < Math.min(10, apps.length); i++) {
            const a = apps[i];
            console.log("Sample:", a.id, "name:", a.name, "icon:", a.icon);
        }
        for (const a of apps) {
            if (a.id.includes("firefox") || a.id.includes("dolphin") || a.id.includes("kitty")) {
                console.log("Matched:", a.id, "name:", a.name, "icon:", a.icon);
            }
        }
        Qt.quit();
    }
}
