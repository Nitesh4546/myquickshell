pragma ComponentBehavior: Bound

import Qt.labs.synchronizer
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Wrapper
    id: root

    readonly property string xdgConfigHome: Directories.config
    readonly property int typingDebounceInterval: 200
    readonly property int typingResultLimit: 15 // Should be enough to cover the whole view

    property string searchingText: LauncherSearch.query
    property bool showResults: searchingText != ""
    readonly property bool isClipboardMode: root.searchingText.startsWith(Config.options.search.prefix.clipboard)
    readonly property bool showPinnedPane: root.isClipboardMode && ClipboardPins.hasPins
    onShowPinnedPaneChanged: console.log("[SearchWidget] showPinnedPane:", showPinnedPane, "isClipboardMode:", isClipboardMode, "hasPins:", ClipboardPins.hasPins, "count:", ClipboardPins.count)
    readonly property bool isTwoPane: showPinnedPane
    property string activePane: "left"
    readonly property real defaultContentWidth: searchBar.implicitWidth + searchBar.Layout.leftMargin + searchBar.Layout.rightMargin

    property var pinnedListViewRef: null
    readonly property int pinnedCurrentIndex: pinnedListViewRef ? pinnedListViewRef.currentIndex : 0
    readonly property var pinnedResults: LauncherSearch.pinnedResults

    onSearchingTextChanged: {
        if (!root.isClipboardMode) {
            root.activePane = "left";
        }
        if (appResults.count > 0)
            appResults.currentIndex = 0;
        if (root.pinnedListViewRef)
            root.pinnedListViewRef.currentIndex = 0;
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                root.activePane = "left";
            }
        }
    }

    Connections {
        target: ClipboardPins
        function onHasPinsChanged() {
            if (!ClipboardPins.hasPins && root.activePane === "right") {
                root.activePane = "left";
                root.focusFirstItem();
            }
        }
    }

    function moveSelectionDownRight() {
        if (!pinnedListViewRef) return;
        const count = pinnedResults.length;
        if (count === 0) return;
        let next = pinnedListViewRef.currentIndex + 1;
        if (next < count) {
            pinnedListViewRef.currentIndex = next;
        }
    }

    function moveSelectionUpRight() {
        if (!pinnedListViewRef) return;
        let prev = pinnedListViewRef.currentIndex - 1;
        if (prev >= 0) {
            pinnedListViewRef.currentIndex = prev;
        }
    }

    function togglePinSelected() {
        if (!root.isClipboardMode) return;
        if (root.activePane === "left") {
            const entry = resultModel.values?.[appResults.currentIndex];
            if (entry && entry.rawValue) {
                ClipboardPins.pin(entry.rawValue);
            }
        } else if (root.activePane === "right") {
            const entry = pinnedResults?.[root.pinnedCurrentIndex];
            if (entry) {
                const unpinAction = entry.actions?.find(a => a.name === Translation.tr("Unpin"));
                if (unpinAction) {
                    unpinAction.execute();
                }
            }
        }
    }

    function deleteOrUnpinSelected() {
        if (root.activePane === "right" && root.isTwoPane) {
            const entry = pinnedResults?.[root.pinnedCurrentIndex];
            if (entry) {
                const unpinAction = entry.actions?.find(a => a.name === Translation.tr("Unpin"));
                if (unpinAction) {
                    unpinAction.execute();
                }
            }
        } else {
            const entry = resultModel.values?.[appResults.currentIndex];
            if (entry) {
                const delAction = entry.actions?.find(a => a.name === Translation.tr("Delete"));
                if (delAction) {
                    delAction.execute();
                }
            }
        }
    }

    width: implicitWidth
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + searchBar.verticalPadding * 2 + Appearance.sizes.elevationMargin * 2

    function focusFirstItem() {
        let idx = 0;
        const values = appResults.model?.values ?? [];
        while (idx < values.length && values[idx]?.isSeparator)
            idx++;
        appResults.currentIndex = idx;
    }

    function focusSearchInput() {
        searchBar.forceFocus();
    }

    function disableExpandAnimation() {
        searchBar.animateWidth = false;
    }

    function cancelSearch() {
        searchBar.searchInput.selectAll();
        LauncherSearch.query = "";
        searchBar.animateWidth = true;
    }

    function setSearchingText(text) {
        searchBar.searchInput.text = text;
        LauncherSearch.query = text;
    }

    Keys.onPressed: event => {
        // Prevent Esc and Backspace from registering
        if (event.key === Qt.Key_Escape)
            return;

        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Right && root.isTwoPane) {
                root.activePane = "right";
                event.accepted = true;
                return;
            } else if (event.key === Qt.Key_Left && root.isTwoPane) {
                root.activePane = "left";
                event.accepted = true;
                return;
            }
        }

        // Handle Backspace: focus and delete character if not focused
        if (event.key === Qt.Key_Backspace) {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                if (event.modifiers & Qt.ControlModifier) {
                    // Delete word before cursor
                    let text = searchBar.searchInput.text;
                    let pos = searchBar.searchInput.cursorPosition;
                    if (pos > 0) {
                        // Find the start of the previous word
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchBar.searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchBar.searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    // Delete character before cursor if any
                    if (searchBar.searchInput.cursorPosition > 0) {
                        searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition - 1) + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                        searchBar.searchInput.cursorPosition -= 1;
                    }
                }
                // Always move cursor to end after programmatic edit
                searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length;
                event.accepted = true;
            }
            // If already focused, let TextField handle it
            return;
        }

        // Only handle visible printable characters (ignore control chars, arrows, etc.)
        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) // ignore control chars like Backspace, Tab, etc.
        {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                // Insert the character at the cursor position
                searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition) + event.text + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                searchBar.searchInput.cursorPosition += 1;
                event.accepted = true;
                root.focusFirstItem();
            }
        }
    }

    StyledRectangularShadow {
        target: searchWidgetContent
    }
    Rectangle { // Background
        id: searchWidgetContent
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: Appearance.sizes.elevationMargin
        }
        clip: true
        width: implicitWidth
        implicitWidth: root.showPinnedPane ? Math.round(root.defaultContentWidth * 1.55) : root.defaultContentWidth
        implicitHeight: columnLayout.implicitHeight
        radius: searchBar.height / 2 + searchBar.verticalPadding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Behavior on implicitWidth {
            id: searchWidthBehavior
            enabled: GlobalStates.overviewOpen && root.showResults
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        Behavior on implicitHeight {
            id: searchHeightBehavior
            enabled: GlobalStates.overviewOpen && root.showResults
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        
        ColumnLayout {
            id: columnLayout
            width: searchWidgetContent.width
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 0

            // clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: searchWidgetContent.width
                    height: searchWidgetContent.height
                    radius: searchWidgetContent.radius
                }
            }

            SearchBar {
                id: searchBar
                searchWidget: root
                property real verticalPadding: 4
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                Layout.topMargin: verticalPadding
                Layout.bottomMargin: verticalPadding
                Synchronizer on searchingText {
                    property alias source: root.searchingText
                }
            }

            Rectangle {
                // Separator
                visible: root.showResults
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            RowLayout {
                id: panesRowLayout
                visible: root.showResults
                Layout.fillWidth: true
                spacing: 8
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                ColumnLayout {
                    id: leftPaneColumn
                    Layout.fillWidth: !root.showPinnedPane
                    Layout.preferredWidth: root.showPinnedPane ? (root.defaultContentWidth - 8) : -1
                    Layout.alignment: Qt.AlignTop
                    spacing: 0

                    RowLayout {
                        id: clipboardHeaderRow
                        visible: root.isClipboardMode
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 14
                        Layout.topMargin: 8
                        Layout.bottomMargin: 4
                        spacing: 8

                        StyledText {
                            text: Translation.tr("Clipboard")
                            font.pixelSize: Appearance.font.pixelSize.smallie
                            color: Appearance.colors.colSubtext
                            font.weight: Font.DemiBold
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            id: clearHistoryButton
                            visible: root.isClipboardMode
                            enabled: (Cliphist.entries?.length ?? 0) > 0
                            buttonRadius: Appearance.rounding.verysmall
                            padding: 4
                            leftPadding: 8
                            rightPadding: 8
                            implicitHeight: 24
                            implicitWidth: clearHistoryText.implicitWidth + 16
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colRipple: Appearance.colors.colLayer1Active

                            contentItem: StyledText {
                                id: clearHistoryText
                                text: Translation.tr("Clear all")
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: clearHistoryButton.enabled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            StyledToolTip {
                                text: Translation.tr("Clear clipboard history")
                            }

                            onClicked: {
                                Cliphist.wipe();
                            }
                        }
                    }

                    ListView { // App results (Left pane)
                        id: appResults
                        Layout.fillWidth: true
                        Layout.preferredWidth: leftPaneColumn.width
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: {
                            if (root.isClipboardMode && (resultModel.values?.length ?? 0) === 0) {
                                return root.showPinnedPane ? Math.max(140, pinnedPaneLoader.item ? pinnedPaneLoader.item.implicitHeight : 140) : 140;
                            }
                            return Math.min(600, appResults.contentHeight + topMargin + bottomMargin);
                        }
                        clip: true
                        topMargin: root.isClipboardMode ? 4 : 10
                        bottomMargin: 10
                    spacing: 2
                    KeyNavigation.up: searchBar
                    highlightMoveDuration: 100

                    onFocusChanged: {
                        if (focus)
                            appResults.currentIndex = 1;
                    }

                    // Skip over separator (letter header) rows when the current
                    // index lands on one, in whichever direction we were moving.
                    property int previousIndex: -1
                    onCurrentIndexChanged: {
                        const values = resultModel.values ?? [];
                        if (currentIndex < 0 || currentIndex >= values.length) {
                            previousIndex = currentIndex;
                            return;
                        }
                        if (values[currentIndex]?.isSeparator) {
                            const direction = currentIndex >= previousIndex ? 1 : -1;
                            let next = currentIndex + direction;
                            while (next >= 0 && next < values.length && values[next]?.isSeparator)
                                next += direction;
                            if (next >= 0 && next < values.length) {
                                previousIndex = next;
                                currentIndex = next;
                                return;
                            }
                        }
                        previousIndex = currentIndex;
                    }

                    Connections {
                        target: root
                        function onSearchingTextChanged() {
                            if (appResults.count > 0)
                                appResults.currentIndex = 0;
                        }
                    }

                    Timer {
                        id: debounceTimer
                        interval: root.typingDebounceInterval
                        onTriggered: {
                            const prevIdx = appResults.currentIndex;
                            resultModel.values = LauncherSearch.results ?? [];
                            if (root.isClipboardMode) {
                                const maxIdx = Math.max(0, (resultModel.values?.length ?? 1) - 1);
                                appResults.currentIndex = Math.min(prevIdx, maxIdx);
                            }
                        }
                    }

                    Connections {
                        target: LauncherSearch
                        function onResultsChanged() {
                            const prevIdx = appResults.currentIndex;
                            const isAllAppsMode = root.searchingText === Config.options.search.prefix.app;
                            resultModel.values = isAllAppsMode ? LauncherSearch.results : LauncherSearch.results.slice(0, root.typingResultLimit);
                            if (root.isClipboardMode) {
                                const maxIdx = Math.max(0, (resultModel.values?.length ?? 1) - 1);
                                appResults.currentIndex = Math.min(prevIdx, maxIdx);
                            } else {
                                root.focusFirstItem();
                            }
                            debounceTimer.restart();
                        }
                    }

                    Connections {
                        target: Cliphist
                        function onEntriesChanged() {
                            if (root.isClipboardMode && Cliphist.entries.length === 0) {
                                resultModel.values = [];
                            }
                        }
                    }

                    model: ScriptModel {
                        id: resultModel
                        objectProp: "key"
                    }

                    delegate: Item {
                        id: delegateItem
                        required property var modelData
                        required property int index
                        width: appResults.width
                        implicitHeight: contentLoader.item ? contentLoader.item.implicitHeight : 0
                        height: implicitHeight

                        Loader {
                            id: contentLoader
                            anchors.left: parent.left
                            anchors.right: parent.right
                            sourceComponent: delegateItem.modelData.isSeparator ? separatorComponent : searchItemComponent
                        }

                        Component {
                            id: separatorComponent
                            SearchListSeparator {
                                anchors.left: parent?.left
                                anchors.right: parent?.right
                                letter: delegateItem.modelData.name
                            }
                        }

                        Component {
                            id: searchItemComponent
                            SearchItem {
                                id: searchItem
                                anchors.left: parent?.left
                                anchors.right: parent?.right
                                entry: delegateItem.modelData
                                forcedSelected: (root.activePane === "left" || !root.isTwoPane) && delegateItem.ListView.isCurrentItem
                                query: StringUtils.cleanOnePrefix(root.searchingText, [Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch])

                                onHoveredChanged: {
                                    if (hovered) {
                                        root.activePane = "left";
                                        appResults.currentIndex = delegateItem.index;
                                    }
                                }
                                onClicked: {
                                    root.activePane = "left";
                                    appResults.currentIndex = delegateItem.index;
                                }

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Tab) {
                                        if (LauncherSearch.results.length === 0)
                                            return;
                                        const tabbedText = searchItem.entry.name;
                                        LauncherSearch.query = tabbedText;
                                        searchBar.searchInput.text = tabbedText;
                                        event.accepted = true;
                                        root.focusSearchInput();
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: emptyClipboardState
                        width: appResults.width
                        height: appResults.height
                        visible: root.isClipboardMode && (resultModel.values?.length ?? 0) === 0

                        readonly property string filterText: StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.clipboard).trim()
                        readonly property bool isFiltering: filterText !== ""

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: emptyClipboardState.isFiltering ? "search_off" : "content_paste_off"
                                iconSize: 40
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: emptyClipboardState.isFiltering ? Translation.tr("No matching clipboard items") : Translation.tr("Clipboard history is empty")
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnSurface
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: emptyClipboardState.isFiltering ? Translation.tr("Try searching for something else") : Translation.tr("Copied text and images will appear here")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
                }

                // Right pane: loader active only when showPinnedPane
                Loader {
                    id: pinnedPaneLoader
                    active: root.showPinnedPane
                    visible: root.showPinnedPane
                    Layout.fillWidth: root.showPinnedPane
                    Layout.preferredWidth: root.showPinnedPane ? (Math.round(root.defaultContentWidth * 0.55) - 12) : 0
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 8
                    Layout.bottomMargin: 10
                    Layout.rightMargin: 4
                    sourceComponent: pinnedPaneComponent
                }
            }
        }
    }

    Component {
        id: pinnedPaneComponent
        Rectangle {
            id: pinnedCard
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true
            width: parent ? parent.width : implicitWidth
            implicitWidth: parent?.width ?? (Math.round(root.defaultContentWidth * 0.55) - 12)
            implicitHeight: headerRow.implicitHeight + pinnedListContainer.implicitHeight + 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Header row
                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    Layout.topMargin: 4
                    spacing: 6

                    MaterialSymbol {
                        text: "push_pin"
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Translation.tr("Pinned")
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: `(${ClipboardPins.count})`
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        id: clearPinnedButton
                        enabled: ClipboardPins.count > 0
                        buttonRadius: Appearance.rounding.verysmall
                        padding: 4
                        leftPadding: 8
                        rightPadding: 8
                        implicitHeight: 24
                        implicitWidth: clearPinnedText.implicitWidth + 16
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active

                        contentItem: StyledText {
                            id: clearPinnedText
                            text: Translation.tr("Clear all")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: clearPinnedButton.enabled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }

                        StyledToolTip {
                            text: Translation.tr("Clear all pinned items")
                        }

                        onClicked: {
                            ClipboardPins.clearAll();
                        }
                    }
                }

                // List container or empty state
                Item {
                    id: pinnedListContainer
                    Layout.fillWidth: true
                    implicitHeight: {
                        if (pinnedResultModel.values.length === 0) {
                            return 44;
                        }
                        const maxH = Math.max(80, appResults.height - headerRow.implicitHeight - 24);
                        return Math.min(maxH, pinnedListView.contentHeight + pinnedListView.topMargin + pinnedListView.bottomMargin);
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: pinnedResultModel.values.length === 0
                        text: Translation.tr("No matching pinned items")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    ListView {
                        id: pinnedListView
                        anchors.fill: parent
                        visible: pinnedResultModel.values.length > 0
                        clip: true
                        spacing: 2
                        topMargin: 2
                        bottomMargin: 2

                        Component.onCompleted: {
                            root.pinnedListViewRef = pinnedListView;
                        }
                        Component.onDestruction: {
                            if (root.pinnedListViewRef === pinnedListView) {
                                root.pinnedListViewRef = null;
                            }
                        }

                        model: ScriptModel {
                            id: pinnedResultModel
                            values: LauncherSearch.pinnedResults
                        }

                        delegate: Item {
                            id: pinnedDelegate
                            required property var modelData
                            required property int index
                            width: pinnedListView.width
                            implicitHeight: pinnedSearchItem.implicitHeight
                            height: implicitHeight

                            SearchItem {
                                id: pinnedSearchItem
                                anchors.left: parent?.left
                                anchors.right: parent?.right
                                entry: pinnedDelegate.modelData
                                forcedSelected: root.activePane === "right" && pinnedDelegate.ListView.isCurrentItem
                                query: StringUtils.cleanPrefix(root.searchingText, Config.options.search.prefix.clipboard)

                                onHoveredChanged: {
                                    if (hovered) {
                                        root.activePane = "right";
                                        pinnedListView.currentIndex = pinnedDelegate.index;
                                    }
                                }
                                onClicked: {
                                    root.activePane = "right";
                                    pinnedListView.currentIndex = pinnedDelegate.index;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
