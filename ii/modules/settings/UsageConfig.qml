import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    forceWidth: true

    property int selectedRangeDays: 7
    property string selectedDayKey: ""

    property int rangeTotalSec: 0
    property int dailyAverageSec: 0
    property int maxAppSec: 0
    property int maxDailySec: 0
    property var dailyList: []
    property var rangeTopApps: []
    property var selectedDayTopApps: []
    property string selectedDayLabel: ""

    readonly property string pendingExcludeText: (typeof excludeAppInput !== "undefined" && excludeAppInput) ? excludeAppInput.text.trim().toLowerCase() : ""
    readonly property bool canAddExcludedApp: pendingExcludeText.length > 0 && !root.isAppExcluded(pendingExcludeText)

    function formatDuration(sec) {
        return UsageTracker.formatDuration(sec);
    }

    function computeAggregates() {
        const aggs = UsageTracker.getRangeAggregates(root.selectedRangeDays, root.selectedDayKey);
        root.rangeTotalSec = aggs.rangeTotalSec;
        root.dailyAverageSec = aggs.dailyAverageSec;
        root.maxDailySec = aggs.maxDailySec;
        root.maxAppSec = aggs.maxAppSec;
        root.dailyList = aggs.dailyList;
        root.rangeTopApps = aggs.rangeTopApps;
        root.selectedDayTopApps = aggs.selectedDayTopApps;
        root.selectedDayLabel = aggs.selectedDayLabel;
    }

    function isAppExcluded(appId) {
        if (!appId) return false;
        const clean = appId.toLowerCase().trim();
        if (!clean) return false;
        const current = Config.options?.usage?.excludedApps ?? [];
        return current.some(item => item && item.toLowerCase().trim() === clean);
    }

    function addExcludedApp(appId) {
        if (!appId) return;
        appId = appId.toLowerCase().trim();
        if (appId.length === 0) return;
        const current = Array.from(Config.options?.usage?.excludedApps ?? []);
        if (!current.includes(appId)) {
            current.push(appId);
            Config.options.usage.excludedApps = current;
        }
    }

    function removeExcludedApp(appId) {
        if (!appId) return;
        appId = appId.toLowerCase().trim();
        const current = Array.from(Config.options?.usage?.excludedApps ?? []);
        Config.options.usage.excludedApps = current.filter(item => item && item.toLowerCase() !== appId);
    }

    Connections {
        target: UsageTracker
        function onDataChanged() {
            root.computeAggregates();
        }
        function onRuntimePausedChanged() {
            root.computeAggregates();
        }
    }

    property int desktopEntriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.metaCache = {};
            root.desktopEntriesRevision++;
        }
    }

    property var metaCache: ({})

    function getAppMeta(appId) {
        if (!appId) return { name: "", icon: "application-x-executable" };
        if (root.metaCache[appId]) return root.metaCache[appId];

        const clean = appId.trim();
        const lower = clean.toLowerCase();

        // 1. Direct in-memory DesktopEntries lookup
        let entry = DesktopEntries.byId(clean) || 
                    DesktopEntries.byId(clean + ".desktop") || 
                    DesktopEntries.heuristicLookup(clean);

        // 2. Try common domain prefixes for non-domain IDs (e.g. "quickshell" -> "org.quickshell")
        if (!entry && !clean.includes(".")) {
            entry = DesktopEntries.byId("org." + clean) ||
                    DesktopEntries.byId("org.kde." + clean) ||
                    DesktopEntries.byId("org.gnome." + clean) ||
                    DesktopEntries.byId("com." + clean);
        }

        // 3. Try reverse domain name for domain IDs (e.g. "com.discordapp.Discord" -> "discord")
        if (!entry && clean.includes(".")) {
            const shortName = clean.split('.').pop().toLowerCase();
            entry = DesktopEntries.byId(shortName) || DesktopEntries.byId(shortName + ".desktop");
        }

        let name = entry?.name;
        let icon = entry?.icon;

        // 4. In-memory substitutions
        if (!icon) {
            icon = AppSearch.substitutions[clean] || AppSearch.substitutions[lower];
        }

        // 5. Clean string as direct icon name (Kirigami.Icon resolves it asynchronously)
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

        const meta = { name: name, icon: icon };
        root.metaCache[appId] = meta;
        return meta;
    }

    Timer {
        id: visibleRefreshTimer
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: {
            UsageTracker.refresh();
            root.computeAggregates();
        }
    }

    Component.onCompleted: {
        root.computeAggregates();
    }

    // Runtime pause notice
    NoticeBox {
        visible: UsageTracker.runtimePaused
        Layout.fillWidth: true
        materialIcon: "pause_circle"
        text: Translation.tr("Tracking is temporarily paused for this session.")
        DialogButton {
            buttonText: Translation.tr("Resume tracking")
            onClicked: {
                UsageTracker.setRuntimePaused(false);
            }
        }
    }

    // Section: Overview
    ContentSection {
        icon: "dashboard"
        title: Translation.tr("Overview")

        // Range selector chips
        ConfigSelectionArray {
            currentValue: root.selectedRangeDays
            onSelected: (newValue) => {
                root.selectedRangeDays = newValue;
                root.selectedDayKey = "";
                root.computeAggregates();
            }
            options: [
                {
                    displayName: Translation.tr("Today"),
                    icon: "today",
                    value: 1
                },
                {
                    displayName: Translation.tr("7 days"),
                    icon: "date_range",
                    value: 7
                },
                {
                    displayName: Translation.tr("30 days"),
                    icon: "calendar_month",
                    value: 30
                }
            ]
        }

        // Summary metric cards
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: totalCardCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                ColumnLayout {
                    id: totalCardCol
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 4

                    StyledText {
                        text: root.selectedRangeDays === 1 ? Translation.tr("Total today") : Translation.tr("Total time in range")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: root.formatDuration(root.rangeTotalSec)
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        color: Appearance.colors.colPrimary
                    }
                }
            }

            Rectangle {
                visible: root.selectedRangeDays > 1
                Layout.fillWidth: true
                implicitHeight: avgCardCol.implicitHeight + 24
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                ColumnLayout {
                    id: avgCardCol
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Daily average")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: root.formatDuration(root.dailyAverageSec)
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Bold
                        color: Appearance.colors.colSecondary
                    }
                }
            }
        }
    }

    // Section: Chart
    ContentSection {
        icon: "bar_chart"
        title: Translation.tr("Chart")

        // Empty state when no data exists for the selected range
        Item {
            visible: root.rangeTotalSec === 0
            implicitHeight: 200
            Layout.fillWidth: true

            PagePlaceholder {
                anchors.fill: parent
                icon: "hourglass_empty"
                title: Translation.tr("No usage recorded yet")
                description: Translation.tr("Focus applications to begin tracking your daily usage.")
            }
        }

        // Chart content when data is available
        ColumnLayout {
            visible: root.rangeTotalSec > 0
            Layout.fillWidth: true
            spacing: 16

            // Vertical bar chart for 7 / 30 days
            Rectangle {
                visible: root.selectedRangeDays > 1
                Layout.fillWidth: true
                implicitHeight: 180
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: root.selectedRangeDays === 7 ? 8 : 2

                    Repeater {
                        model: root.dailyList
                        delegate: Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 4

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Rectangle {
                                        id: barRect
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: root.selectedRangeDays === 7 ? Math.min(parent.width, 36) : Math.min(parent.width, 12)
                                        height: Math.max(4, Math.round((modelData.totalSec / Math.max(root.maxDailySec, 1)) * (parent.height - 4)))
                                        radius: 4
                                        color: {
                                            if (root.selectedDayKey === modelData.key) return Appearance.colors.colPrimary;
                                            if (modelData.isToday) return Appearance.colors.colPrimary;
                                            if (modelData.totalSec > 0) return Appearance.colors.colSecondaryContainer;
                                            return Appearance.colors.colLayer2;
                                        }
                                        opacity: (root.selectedDayKey && root.selectedDayKey !== modelData.key && !modelData.isToday) ? 0.6 : 1.0

                                        border.width: (root.selectedDayKey === modelData.key) ? 2 : 0
                                        border.color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    font.pixelSize: Appearance.font.pixelSize.verySmall ?? 11
                                    color: (root.selectedDayKey === modelData.key || modelData.isToday) ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                    font.weight: (root.selectedDayKey === modelData.key || modelData.isToday) ? Font.Bold : Font.Normal
                                    text: {
                                        if (root.selectedRangeDays === 7) return modelData.weekday;
                                        if (index % 5 === 0 || index === root.dailyList.length - 1) return modelData.shortDate;
                                        return "";
                                    }
                                }
                            }

                            MouseArea {
                                id: barMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedDayKey = (root.selectedDayKey === modelData.key ? "" : modelData.key);
                                    root.computeAggregates();
                                }
                                StyledToolTip {
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: barMouseArea.containsMouse
                                    text: `${modelData.fullDateLabel}\n${root.formatDuration(modelData.totalSec)}`
                                }
                            }
                        }
                    }
                }
            }

            // Breakdown for selected day (in 7/30 days mode)
            ContentSubsection {
                visible: root.selectedRangeDays > 1 && root.selectedDayKey.length > 0 && root.selectedDayTopApps.length > 0
                title: `${Translation.tr("Day breakdown")}: ${root.selectedDayLabel}`

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.selectedDayTopApps
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 52
                            height: 52
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1

                            RowLayout {
                                id: appRowLayout
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 10

                                AppIcon {
                                    implicitSize: 24
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: modelData.name
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnSecondaryContainer
                                            elide: Text.ElideRight
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: root.formatDuration(modelData.seconds)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: `${modelData.percent}%`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colPrimary
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 6
                                        radius: 3
                                        color: Appearance.colors.colLayer2

                                        Rectangle {
                                            height: parent.height
                                            radius: 3
                                            width: Math.max(4, Math.round(parent.width * modelData.fraction))
                                            color: modelData.id === "others" ? Appearance.colors.colSecondary : Appearance.colors.colPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Top apps for Today (when selectedRangeDays === 1)
            ContentSubsection {
                visible: root.selectedRangeDays === 1 && root.rangeTopApps.length > 0
                title: Translation.tr("Applications used today")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.rangeTopApps
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 52
                            height: 52
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1

                            RowLayout {
                                id: appRowLayoutToday
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 10

                                AppIcon {
                                    implicitSize: 24
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: modelData.name
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnSecondaryContainer
                                            elide: Text.ElideRight
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: root.formatDuration(modelData.seconds)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: `${modelData.percent}%`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colPrimary
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        radius: 4
                                        color: Appearance.colors.colLayer2

                                        Rectangle {
                                            height: parent.height
                                            radius: 4
                                            width: Math.max(4, Math.round(parent.width * modelData.fraction))
                                            color: modelData.id === "others" ? Appearance.colors.colSecondary : Appearance.colors.colPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Below the chart: Top apps over the selected range (for 7 / 30 days)
            ContentSubsection {
                visible: root.selectedRangeDays > 1 && root.rangeTopApps.length > 0
                title: Translation.tr("Top apps over this period")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.rangeTopApps
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 52
                            height: 52
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colLayer1

                            RowLayout {
                                id: rangeAppRow
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 10

                                AppIcon {
                                    implicitSize: 24
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: modelData.name
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnSecondaryContainer
                                            elide: Text.ElideRight
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: root.formatDuration(modelData.seconds)
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: `${modelData.percent}%`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colPrimary
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 8
                                        radius: 4
                                        color: Appearance.colors.colLayer2

                                        Rectangle {
                                            height: parent.height
                                            radius: 4
                                            width: Math.max(4, Math.round(parent.width * modelData.fraction))
                                            color: modelData.id === "others" ? Appearance.colors.colSecondary : Appearance.colors.colPrimary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Section: Desktop widget
    ContentSection {
        icon: "widgets"
        title: Translation.tr("Desktop widget")

        ConfigRow {
            uniform: true
            Layout.fillWidth: true

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable desktop widget")
                checked: Config.options.background.widgets.usage.enable
                onCheckedChanged: {
                    Config.options.background.widgets.usage.enable = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "contract"
                text: Translation.tr("Compact mode")
                checked: Config.options.background.widgets.usage.compact
                onCheckedChanged: {
                    Config.options.background.widgets.usage.compact = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Placement strategy")

            ConfigSelectionArray {
                Layout.fillWidth: true
                currentValue: Config.options.background.widgets.usage.placementStrategy
                onSelected: newValue => {
                    Config.options.background.widgets.usage.placementStrategy = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Draggable"),
                        icon: "drag_pan",
                        value: "free"
                    },
                    {
                        displayName: Translation.tr("Least busy"),
                        icon: "category",
                        value: "leastBusy"
                    },
                    {
                        displayName: Translation.tr("Most busy"),
                        icon: "shapes",
                        value: "mostBusy"
                    },
                ]
            }
        }
    }

    // Section: Tracking Settings
    ContentSection {
        icon: "settings"
        title: Translation.tr("Tracking settings")

        ConfigSwitch {
            buttonIcon: UsageTracker.runtimePaused ? "play_arrow" : "pause"
            text: UsageTracker.runtimePaused ? Translation.tr("Resume tracking (currently paused)") : Translation.tr("Pause tracking")
            checked: UsageTracker.runtimePaused
            onCheckedChanged: {
                UsageTracker.setRuntimePaused(checked);
            }
            StyledToolTip {
                text: Translation.tr("Temporarily stop tracking without changing your saved configuration")
            }
        }

        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Idle timeout (seconds)")
            value: Config.options?.usage?.idleTimeoutSec ?? 120
            from: 30
            to: 600
            stepSize: 30
            onValueChanged: {
                if (Config.options?.usage) {
                    Config.options.usage.idleTimeoutSec = value;
                }
            }
        }

        ConfigSpinBox {
            icon: "history"
            text: Translation.tr("Data retention (days)")
            value: Config.options?.usage?.retentionDays ?? 90
            from: 7
            to: 365
            stepSize: 1
            onValueChanged: {
                if (Config.options?.usage) {
                    Config.options.usage.retentionDays = value;
                }
            }
        }
        // Excluded applications subsection
        ContentSubsection {
            title: Translation.tr("Excluded applications")
            tooltip: Translation.tr("Applications that will never be tracked")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Search / add input row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: excludeAppInput
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Search app to exclude or type window class...")
                        onAccepted: {
                            if (root.canAddExcludedApp) {
                                root.addExcludedApp(excludeAppInput.text.trim());
                                excludeAppInput.text = "";
                            }
                        }
                    }

                    RippleButton {
                        id: addExcludeButton
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: false
                        Layout.preferredWidth: 84
                        Layout.minimumWidth: 84
                        implicitWidth: 84
                        implicitHeight: excludeAppInput.implicitHeight
                        Layout.preferredHeight: excludeAppInput.implicitHeight
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colSecondaryContainer
                        colBackgroundHover: root.canAddExcludedApp ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                        colRipple: Appearance.colors.colSecondaryContainerActive
                        opacity: root.canAddExcludedApp ? 1.0 : 0.4
                        rippleEnabled: root.canAddExcludedApp
                        pointingHandCursor: root.canAddExcludedApp
                        onClicked: {
                            if (root.canAddExcludedApp) {
                                root.addExcludedApp(excludeAppInput.text.trim());
                                excludeAppInput.text = "";
                            }
                        }
                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Add")
                            font.weight: Font.Medium
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }

                // Autocomplete / Search suggestions popup
                Rectangle {
                    id: searchDropdown
                    visible: excludeAppInput.text.trim().length > 0
                    Layout.fillWidth: true
                    implicitHeight: Math.min(suggestedColumn.implicitHeight + 12, 180)
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    clip: true

                    StyledFlickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentHeight: suggestedColumn.implicitHeight

                        ColumnLayout {
                            id: suggestedColumn
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: {
                                    if (excludeAppInput.text.trim().length === 0) return [];
                                    const results = AppSearch.fuzzyQuery(excludeAppInput.text.trim());
                                    return results.slice(0, 5);
                                }
                                delegate: RippleButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    leftPadding: 8
                                    rightPadding: 8
                                    buttonRadius: Appearance.rounding.verysmall
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer2
                                    onClicked: {
                                        root.addExcludedApp(modelData.id);
                                        excludeAppInput.text = "";
                                    }

                                    contentItem: RowLayout {
                                        spacing: 8

                                        AppIcon {
                                            implicitSize: 20
                                            width: 20
                                            height: 20
                                            animated: false
                                            source: Quickshell.iconPath(modelData.icon || AppSearch.guessIcon(modelData.id), "application-x-executable")
                                        }
                                        StyledText {
                                            text: modelData.name
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer1
                                        }
                                        StyledText {
                                            text: `(${modelData.id})`
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                    }
                }

                                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: Config.options?.usage?.excludedApps ?? []
                        delegate: Rectangle {
                            id: chipDelegate
                            required property string modelData
                            readonly property var appMeta: root.getAppMeta(modelData)
                            implicitHeight: 32
                            implicitWidth: chipRow.implicitWidth + 16
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colSecondaryContainer

                            MouseArea {
                                id: chipHoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            StyledToolTip {
                                extraVisibleCondition: false
                                alternativeVisibleCondition: chipHoverArea.containsMouse && !removeChipArea.containsMouse
                                text: modelData
                            }

                            Row {
                                id: chipRow
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 6

                                AppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 16
                                    width: 16
                                    height: 16
                                    animated: false
                                    source: Quickshell.iconPath(chipDelegate.appMeta.icon, "application-x-executable")
                                }

                                StyledText {
                                    id: chipLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chipDelegate.appMeta.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnSecondaryContainer
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 160)
                                }

                                MouseArea {
                                    id: removeChipArea
                                    width: 18
                                    height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: root.removeExcludedApp(modelData)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 9
                                        color: removeChipArea.containsMouse ? Appearance.colors.colSecondaryContainerHover : "transparent"

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: 14
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }

                                    StyledToolTip {
                                        extraVisibleCondition: false
                                        alternativeVisibleCondition: removeChipArea.containsMouse
                                        text: Translation.tr("Remove")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Clear all data button
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Deletes all recorded usage data. This cannot be undone.")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            RippleButton {
                id: clearAllBtn
                Layout.alignment: Qt.AlignLeft
                implicitHeight: 38
                implicitWidth: 190
                leftPadding: 16
                rightPadding: 16
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                onClicked: {
                    confirmClearDialog.show = true;
                }

                contentItem: RowLayout {
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "delete_forever"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnErrorContainer
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Clear all usage data")
                        font.weight: Font.Medium
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnErrorContainer
                    }
                }
            }
        }
    }

    // Bottom description / Privacy note
    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Stored only on this computer. No window titles are recorded.")
        font.pixelSize: Appearance.font.pixelSize.small
        color: Appearance.colors.colSubtext
    }

    // Confirmation dialog overlay for Clear All Data
    WindowDialog {
        id: confirmClearDialog
        parent: root
        anchors.fill: parent
        visible: show
        show: false
        onDismiss: show = false

        WindowDialogTitle {
            text: Translation.tr("Clear all usage data?")
        }

        WindowDialogParagraph {
            text: Translation.tr("This will permanently delete all recorded application usage history. This action cannot be undone.")
        }

        WindowDialogButtonRow {
            Item { Layout.fillWidth: true }

            DialogButton {
                buttonText: Translation.tr("Cancel")
                onClicked: {
                    confirmClearDialog.show = false;
                }
            }

            DialogButton {
                buttonText: Translation.tr("Clear data")
                onClicked: {
                    UsageTracker.clearAllData();
                    Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "usageTracker", "clear"]);
                    confirmClearDialog.show = false;
                    root.computeAggregates();
                }
            }
        }
    }
}
