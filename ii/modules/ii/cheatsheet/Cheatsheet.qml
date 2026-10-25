import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    readonly property bool showPeriodicTable: Config.options?.cheatsheet?.showPeriodicTable ?? true
    readonly property bool showTimetable: Config.options?.cheatsheet?.showTimetable ?? true

    readonly property var allTabs: [
        {
            "id": 0,
            "icon": "keyboard",
            "name": Translation.tr("Keybinds"),
            "enabled": true
        },
        {
            "id": 1,
            "icon": "experiment",
            "name": Translation.tr("Elements"),
            "enabled": root.showPeriodicTable
        },
        {
            "id": 2,
            "icon": "calendar_month",
            "name": Translation.tr("Timetable"),
            "enabled": root.showTimetable
        }
    ]

    readonly property var visibleTabs: allTabs.filter(tab => tab.enabled)
    property var tabButtonList: visibleTabs.map(tab => ({ "icon": tab.icon, "name": tab.name }))

    property bool cheatsheetLoadedOnce: false
    property bool cheatsheetOpen: false
    onCheatsheetOpenChanged: GlobalStates.cheatsheetOpen = cheatsheetOpen

    Connections {
        target: GlobalStates
        function onOpenCheatsheetTab(tabIndex) {
            if (root.cheatsheetOpen) {
                const targetIdx = root.logicalToVisualIndex(tabIndex);
                if (cheatsheetLoader.item && cheatsheetLoader.item.currentVisualIndex === targetIdx) {
                    root.closeCheatsheet();
                    return;
                }
            }
            Persistent.states.cheatsheet.tabIndex = tabIndex;
            root.openCheatsheet();
            if (cheatsheetLoader.item) {
                const targetIdx = root.logicalToVisualIndex(tabIndex);
                cheatsheetLoader.item.jumpToVisualTab(targetIdx);
            }
        }
    }

    function openCheatsheet() {
        cheatsheetLoadedOnce = true;
        if (cheatsheetLoader.item) {
            const savedLogical = Persistent.states.cheatsheet.tabIndex;
            const expectedVisual = root.logicalToVisualIndex(savedLogical);
            if (cheatsheetLoader.item.currentVisualIndex !== expectedVisual) {
                cheatsheetLoader.item.jumpToVisualTab(expectedVisual);
            }
        }
        cheatsheetOpen = true;
    }

    function closeCheatsheet() {
        cheatsheetOpen = false;
    }

    function toggleCheatsheet() {
        if (cheatsheetOpen) {
            closeCheatsheet();
        } else {
            openCheatsheet();
        }
    }

    function logicalToVisualIndex(logicalId) {
        const idx = root.visibleTabs.findIndex(t => t.id === logicalId);
        return idx >= 0 ? idx : 0;
    }

    function visualToLogicalIndex(visualIdx) {
        if (visualIdx >= 0 && visualIdx < root.visibleTabs.length) {
            return root.visibleTabs[visualIdx].id;
        }
        return 0;
    }

    Loader {
        id: cheatsheetLoader
        active: root.cheatsheetLoadedOnce

        sourceComponent: PanelWindow { // Window
            id: cheatsheetRoot
            visible: root.cheatsheetOpen && cheatsheetRoot.initialized
            property bool initialized: false

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                root.closeCheatsheet();
            }
            exclusiveZone: 0
            implicitWidth: cheatsheetBackground.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: cheatsheetBackground.height + Appearance.sizes.elevationMargin * 2
            WlrLayershell.namespace: "quickshell:cheatsheet"
            WlrLayershell.keyboardFocus: (root.cheatsheetOpen && cheatsheetTimetableTab && cheatsheetTimetableTab.showAddDialog) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: (root.cheatsheetOpen && cheatsheetRoot.initialized) ? cheatsheetBackground : null
            }

            readonly property alias currentVisualIndex: swipeView.currentIndex
            function jumpToVisualTab(index) {
                updatingPages = true;
                swipeView.currentIndex = index;
                if (swipeView.contentItem) {
                    swipeView.contentItem.positionViewAtIndex(index, ListView.Beginning);
                }
                updatingPages = false;
            }

            property bool updatingPages: true
            property Item periodicTableTab: null
            property Item timetableTab: null
            readonly property var cheatsheetTimetableTab: timetableTab

            Component {
                id: periodicTableComponent
                CheatsheetPeriodicTable {}
            }

            Component {
                id: timetableComponent
                CheatsheetTimetable {}
            }

            function syncPages() {
                if (root.showPeriodicTable) {
                    if (!periodicTableTab) {
                        periodicTableTab = periodicTableComponent.createObject(swipeView);
                        swipeView.insertItem(1, periodicTableTab);
                    }
                } else {
                    if (periodicTableTab) {
                        swipeView.removeItem(periodicTableTab);
                        periodicTableTab.destroy();
                        periodicTableTab = null;
                    }
                }

                if (root.showTimetable) {
                    if (!timetableTab) {
                        timetableTab = timetableComponent.createObject(swipeView);
                        const insertIdx = periodicTableTab ? 2 : 1;
                        swipeView.insertItem(insertIdx, timetableTab);
                    }
                } else {
                    if (timetableTab) {
                        swipeView.removeItem(timetableTab);
                        timetableTab.destroy();
                        timetableTab = null;
                    }
                }
            }

            function initPages() {
                updatingPages = true;
                syncPages();
                const savedLogical = Persistent.states.cheatsheet.tabIndex;
                const isSavedVisible = root.visibleTabs.some(t => t.id === savedLogical);
                if (!isSavedVisible) {
                    Persistent.states.cheatsheet.tabIndex = 0;
                }
                const targetIdx = root.logicalToVisualIndex(Persistent.states.cheatsheet.tabIndex);
                swipeView.currentIndex = targetIdx;
                if (swipeView.contentItem) {
                    swipeView.contentItem.positionViewAtIndex(targetIdx, ListView.Beginning);
                }
                updatingPages = false;
            }

            function handleTogglesChanged() {
                updatingPages = true;
                const currentLogical = Persistent.states.cheatsheet.tabIndex;
                const isCurrentVisible = root.visibleTabs.some(t => t.id === currentLogical);
                if (!isCurrentVisible) {
                    Persistent.states.cheatsheet.tabIndex = 0;
                }
                syncPages();
                const targetIdx = root.logicalToVisualIndex(Persistent.states.cheatsheet.tabIndex);
                swipeView.currentIndex = targetIdx;
                if (swipeView.contentItem) {
                    swipeView.contentItem.positionViewAtIndex(targetIdx, ListView.Beginning);
                }
                updatingPages = false;
            }

            Connections {
                target: root
                function onVisibleTabsChanged() {
                    cheatsheetRoot.handleTogglesChanged();
                }
            }

            Component.onCompleted: {
                initPages();
                initialized = true;
                if (visible) {
                    GlobalFocusGrab.addDismissable(cheatsheetRoot);
                    closeButton.forceActiveFocus();
                }
            }

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(cheatsheetRoot);
                    closeButton.forceActiveFocus();
                    const savedLogical = Persistent.states.cheatsheet.tabIndex;
                    const expectedVisual = root.logicalToVisualIndex(savedLogical);
                    if (swipeView.currentIndex !== expectedVisual) {
                        updatingPages = true;
                        swipeView.currentIndex = expectedVisual;
                        if (swipeView.contentItem) {
                            swipeView.contentItem.positionViewAtIndex(expectedVisual, ListView.Beginning);
                        }
                        updatingPages = false;
                    }
                } else {
                    GlobalFocusGrab.removeDismissable(cheatsheetRoot);
                    if (timetableTab) {
                        timetableTab.showAddDialog = false;
                        timetableTab.showViewDialog = false;
                    }
                }
            }

            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(cheatsheetRoot);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    cheatsheetRoot.hide();
                }
            }

            // Background
            StyledRectangularShadow {
                target: cheatsheetBackground
            }
            Rectangle {
                id: cheatsheetBackground
                anchors.centerIn: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.windowRounding
                property real padding: 20
                implicitWidth: cheatsheetColumnLayout.implicitWidth + padding * 2
                implicitHeight: cheatsheetColumnLayout.implicitHeight + padding * 2

                Keys.onPressed: event => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        cheatsheetRoot.hide();
                    }
                    if (event.modifiers & Qt.ControlModifier) {
                        const count = root.tabButtonList.length;
                        if (count > 1) {
                            if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                                tabBar.setCurrentIndex((tabBar.currentIndex + 1) % count);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                                tabBar.setCurrentIndex((tabBar.currentIndex - 1 + count) % count);
                                event.accepted = true;
                            }
                        }
                    }
                }

                RippleButton { // Close button
                    id: closeButton
                    focus: cheatsheetRoot.visible
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 20
                        rightMargin: 20
                    }

                    onClicked: {
                        cheatsheetRoot.hide();
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.title
                        text: "close"
                    }
                }

                ColumnLayout { // Real content
                    id: cheatsheetColumnLayout
                    anchors.centerIn: parent
                    spacing: 10

                    Toolbar {
                        visible: root.tabButtonList.length > 1
                        Layout.alignment: Qt.AlignHCenter
                        enableShadow: false
                        ToolbarTabBar {
                            id: tabBar
                            tabButtonList: root.tabButtonList

                            Synchronizer on currentIndex {
                                property alias source: swipeView.currentIndex
                            }
                        }
                    }

                    SwipeView { // Content pages
                        id: swipeView
                        Layout.topMargin: 5
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        currentIndex: 0
                        onCurrentIndexChanged: {
                            if (cheatsheetRoot.updatingPages) return;
                            if (currentIndex >= 0 && currentIndex < root.visibleTabs.length) {
                                Persistent.states.cheatsheet.tabIndex = root.visualToLogicalIndex(currentIndex);
                            }
                        }

                        implicitWidth: Math.max.apply(null, [0].concat(contentChildren.map(child => child.implicitWidth || 0)))
                        implicitHeight: Math.max.apply(null, [0].concat(contentChildren.map(child => child.implicitHeight || 0)))

                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: swipeView.width
                                height: swipeView.height
                                radius: Appearance.rounding.small
                            }
                        }

                        CheatsheetKeybinds {}
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): void {
            root.toggleCheatsheet();
        }

        function close(): void {
            root.closeCheatsheet();
        }

        function open(): void {
            root.openCheatsheet();
        }

        function selectTab(logicalId: int): void {
            Persistent.states.cheatsheet.tabIndex = logicalId;
            if (cheatsheetLoader.item) {
                const targetIdx = root.logicalToVisualIndex(logicalId);
                cheatsheetLoader.item.jumpToVisualTab(targetIdx);
            }
        }

        function openTab(logicalId: int): void {
            GlobalStates.openCheatsheetTab(logicalId);
        }
    }

    GlobalShortcut {
        name: "cheatsheetToggle"
        description: "Toggles cheatsheet on press"

        onPressed: {
            root.toggleCheatsheet();
        }
    }

    GlobalShortcut {
        name: "cheatsheetOpen"
        description: "Opens cheatsheet on press"

        onPressed: {
            root.openCheatsheet();
        }
    }

    GlobalShortcut {
        name: "cheatsheetClose"
        description: "Closes cheatsheet on press"

        onPressed: {
            root.closeCheatsheet();
        }
    }
}
