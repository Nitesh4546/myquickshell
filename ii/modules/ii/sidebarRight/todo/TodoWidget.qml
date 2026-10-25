import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var tabButtonList: [{"icon": "checklist", "name": Translation.tr("Unfinished")}, {"name": Translation.tr("Done"), "icon": "check_circle"}]
    property bool showAddDialog: false
    property int dialogMargins: 12
    property int fabSize: 48
    property int fabMargins: 14

    // Due & Reminder editing state
    property bool isEditDueMode: false
    property int editingOriginalIndex: -1
    property string editingTaskId: ""
    property int selectedPriority: 0
    property string selectedDateStr: ""
    property bool hasTime: false
    property int selectedHour: 12
    property int selectedMinute: 0
    property int selectedReminder: -1
    property bool showDatePickerOverlay: false
    property string activeEditingTaskId: ""
    readonly property bool isEditingTask: activeEditingTaskId.length > 0
    readonly property string sortMode: {
        try {
            return Persistent.states.sidebar.todo.sortMode ?? "due";
        } catch (e) {
            return "due";
        }
    }

    component FilterChip: RippleButton {
        id: chipRoot
        property bool selected: false
        property string chipText: ""
        property string iconName: ""
        property color dotColor: "transparent"

        implicitHeight: 24
        implicitWidth: chipRow.implicitWidth + 14
        buttonRadius: Appearance.rounding.verysmall

        colBackground: chipRoot.selected ? Appearance.colors.colPrimaryContainer : Appearance.m3colors.m3surfaceContainerHighest
        colBackgroundHover: chipRoot.selected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3Hover
        readonly property color colContent: chipRoot.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurface

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4

            Rectangle {
                visible: chipRoot.dotColor !== "transparent" && chipRoot.dotColor !== "" && chipRoot.dotColor != "#00000000"
                width: 8
                height: 8
                radius: 4
                color: chipRoot.dotColor
            }

            MaterialSymbol {
                visible: chipRoot.iconName.length > 0
                text: chipRoot.iconName
                iconSize: 14
                color: chipRoot.colContent
            }

            StyledText {
                text: chipRoot.chipText
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: chipRoot.selected ? Font.Bold : Font.Normal
                color: chipRoot.colContent
            }
        }
    }

    function stepHour(delta) {
        let h = (root.selectedHour + delta) % 24;
        if (h < 0) h += 24;
        root.selectedHour = h;
    }

    function stepMinute(delta) {
        let m = (root.selectedMinute + delta) % 60;
        if (m < 0) m += 60;
        root.selectedMinute = Math.round(m / 5) * 5 % 60;
    }

    function sortedUnfinishedTasks(list, mode = root.sortMode) {
        let mapped = list
            .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
            .filter(function(item) { return !item.done; });
        return mapped.sort(function(a, b) {
            let pA = (a.priority !== undefined && a.priority !== null) ? parseInt(a.priority) : 0;
            let pB = (b.priority !== undefined && b.priority !== null) ? parseInt(b.priority) : 0;
            let hasDueA = !!(a.due && String(a.due).trim());
            let hasDueB = !!(b.due && String(b.due).trim());

            if (mode === "priority") {
                if (pA !== pB) return pB - pA;
                if (hasDueA && !hasDueB) return -1;
                if (!hasDueA && hasDueB) return 1;
                if (hasDueA && hasDueB) {
                    let dateA = Todo.dueDate(a);
                    let dateB = Todo.dueDate(b);
                    let timeA = dateA ? dateA.getTime() : Infinity;
                    let timeB = dateB ? dateB.getTime() : Infinity;
                    if (timeA !== timeB) return timeA - timeB;
                }
                return a.originalIndex - b.originalIndex;
            } else {
                // "due" mode (default)
                if (hasDueA && !hasDueB) return -1;
                if (!hasDueA && hasDueB) return 1;
                if (!hasDueA && !hasDueB) {
                    if (pA !== pB) return pB - pA;
                    return a.originalIndex - b.originalIndex;
                }
                let dateA = Todo.dueDate(a);
                let dateB = Todo.dueDate(b);
                let timeA = dateA ? dateA.getTime() : Infinity;
                let timeB = dateB ? dateB.getTime() : Infinity;
                if (timeA !== timeB) return timeA - timeB;
                if (pA !== pB) return pB - pA;
                return a.originalIndex - b.originalIndex;
            }
        });
    }

    function toggleSortMode() {
        let nextMode = (root.sortMode === "priority") ? "due" : "priority";
        try {
            if (Persistent.states && Persistent.states.sidebar && Persistent.states.sidebar.todo) {
                Persistent.states.sidebar.todo.sortMode = nextMode;
            }
        } catch (e) {
            console.warn("[To Do] Could not persist sortMode:", e);
        }
    }

    function resolveEditingIndex() {
        if (root.editingTaskId) {
            let idx = Todo.list.findIndex(t => t && t.id === root.editingTaskId);
            if (idx !== -1) return idx;
        }
        return root.editingOriginalIndex;
    }

    function resetDialog() {
        todoInput.text = "";
        root.isEditDueMode = false;
        root.editingOriginalIndex = -1;
        root.editingTaskId = "";
        root.selectedPriority = 0;
        root.selectedDateStr = "";
        root.hasTime = false;
        let now = new Date();
        root.selectedHour = now.getHours();
        root.selectedMinute = Math.round(now.getMinutes() / 5) * 5 % 60;
        root.selectedReminder = -1;
        root.showDatePickerOverlay = false;
        if (dialogFlickable) {
            dialogFlickable.contentY = 0;
        }
        fabButton.focus = true;
    }

    function closeDialog() {
        root.showAddDialog = false;
        root.resetDialog();
    }

    function openAddDialog() {
        root.activeEditingTaskId = "";
        root.resetDialog();
        root.showAddDialog = true;
        todoInput.focus = true;
    }

    function openEditDueDialog(originalIndex, task) {
        root.activeEditingTaskId = "";
        root.isEditDueMode = true;
        root.editingOriginalIndex = originalIndex;
        root.editingTaskId = (task && task.id) ? task.id : "";
        todoInput.text = (task && task.content) ? task.content : "";
        root.selectedPriority = (task && task.priority !== undefined && task.priority !== null) ? parseInt(task.priority) : 0;
        if (task && task.due) {
            let dueStr = String(task.due).trim();
            let dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dueStr);
            if (dateOnlyMatch) {
                root.selectedDateStr = dueStr;
                root.hasTime = false;
                let now = new Date();
                root.selectedHour = 12;
                root.selectedMinute = 0;
            } else {
                let dt = new Date(dueStr);
                if (!isNaN(dt.getTime())) {
                    root.selectedDateStr = Todo.formatDateOnly(dt);
                    root.hasTime = true;
                    root.selectedHour = dt.getHours();
                    root.selectedMinute = dt.getMinutes();
                } else {
                    root.selectedDateStr = "";
                    root.hasTime = false;
                }
            }
            root.selectedReminder = (task.reminder !== undefined && task.reminder !== null) ? parseInt(task.reminder) : -1;
        } else {
            root.selectedDateStr = "";
            root.hasTime = false;
            root.selectedReminder = -1;
        }
        root.showDatePickerOverlay = false;
        root.showAddDialog = true;
    }

    function saveDialog() {
        let finalDue = "";
        let finalReminder = -1;
        if (root.selectedDateStr) {
            if (root.hasTime) {
                let parts = root.selectedDateStr.split("-");
                let dt = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]), root.selectedHour, root.selectedMinute, 0);
                finalDue = Todo.isoLocal(dt);
            } else {
                finalDue = root.selectedDateStr;
            }
            finalReminder = root.selectedReminder;
        }

        if (root.isEditDueMode) {
            let targetIdx = root.resolveEditingIndex();
            let newContent = todoInput.text.trim();
            if (newContent.length > 0) {
                Todo.updateTaskDetails(targetIdx, newContent, finalDue, finalReminder, root.selectedPriority);
            } else {
                Todo.updateDue(targetIdx, finalDue, finalReminder);
                Todo.setPriority(targetIdx, root.selectedPriority);
            }
            root.closeDialog();
        } else {
            if (todoInput.text.length > 0) {
                Todo.addTask(todoInput.text, finalDue, finalReminder, root.selectedPriority);
                root.closeDialog();
                tabBar.setCurrentIndex(0); // Show unfinished tasks
            }
        }
    }

    Keys.onPressed: (event) => {
        if (root.isEditingTask) {
            return;
        }
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
        }
        // Open add dialog on "N" (any modifiers)
        else if (event.key === Qt.Key_N) {
            root.openAddDialog();
            event.accepted = true;
        }
        // Close dialog on Esc if open
        else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            if (root.showDatePickerOverlay) {
                root.showDatePickerOverlay = false;
            } else {
                root.closeDialog();
            }
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            SecondaryTabBar {
                id: tabBar
                Layout.fillWidth: true
                currentIndex: swipeView.currentIndex
                onCurrentIndexChanged: {
                    root.activeEditingTaskId = "";
                }

                Repeater {
                    model: root.tabButtonList
                    delegate: SecondaryTabButton {
                        buttonText: modelData.name
                        buttonIcon: modelData.icon
                    }
                }
            }

            RippleButton {
                id: sortButton
                implicitWidth: 32
                implicitHeight: 32
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4
                buttonRadius: Appearance.rounding.verysmall
                colBackground: root.sortMode === "priority" ? Appearance.colors.colLayer3 : "transparent"
                colBackgroundHover: Appearance.colors.colLayer3Hover
                onClicked: root.toggleSortMode()

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "sort"
                    iconSize: 18
                    color: root.sortMode === "priority" ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurfaceVariant
                }

                MouseArea {
                    id: sortButtonHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                StyledToolTip {
                    extraVisibleCondition: sortButtonHover.containsMouse
                    text: root.sortMode === "priority" ?
                        Translation.tr("Sort: Priority") :
                        Translation.tr("Sort: Due date")
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            // To Do tab
            TaskList {
                id: unfinishedTaskList
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "check_circle"
                emptyPlaceholderText: Translation.tr("Nothing here!")
                taskList: root.sortedUnfinishedTasks(Todo.list, root.sortMode)
                activeEditingTaskId: root.activeEditingTaskId
                onEditTaskStarted: (taskId) => {
                    root.activeEditingTaskId = taskId;
                }
                onEditTaskFinished: () => {
                    root.activeEditingTaskId = "";
                }
                onEditDueRequested: (originalIndex, task) => {
                    root.openEditDueDialog(originalIndex, task);
                }
            }
            TaskList {
                id: doneTaskList
                listBottomPadding: root.fabSize + root.fabMargins * 2
                emptyPlaceholderIcon: "checklist"
                emptyPlaceholderText: Translation.tr("Finished tasks will go here")
                taskList: Todo.list
                    .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                    .filter(function(item) { return item.done; })
                activeEditingTaskId: root.activeEditingTaskId
                onEditTaskStarted: (taskId) => {
                    root.activeEditingTaskId = taskId;
                }
                onEditTaskFinished: () => {
                    root.activeEditingTaskId = "";
                }
                onEditDueRequested: (originalIndex, task) => {
                    root.openEditDueDialog(originalIndex, task);
                }
            }

            Binding {
                target: unfinishedTaskList
                property: "activeEditingTaskId"
                value: root.activeEditingTaskId
            }
            Binding {
                target: doneTaskList
                property: "activeEditingTaskId"
                value: root.activeEditingTaskId
            }
        }
    }

    // + FAB
    StyledRectangularShadow {
        target: fabButton
        visible: fabButton.visible
        radius: fabButton.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }
    FloatingActionButton {
        id: fabButton
        visible: !root.isEditingTask
        enabled: !root.isEditingTask
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins

        onClicked: root.openAddDialog()
        iconText: "add"
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { 
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                root.resetDialog();
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colScrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
                onClicked: root.closeDialog()
            }
            WheelHandler {
                target: null
                onWheel: (event) => {
                    event.accepted = true;
                }
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            readonly property real naturalHeight: dialogHeader.implicitHeight + formColumnLayout.implicitHeight + dialogActionsRow.implicitHeight + 44
            height: Math.min(naturalHeight, root.height - 16)
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            color: Appearance.m3colors.m3surfaceContainerHigh
            radius: Appearance.rounding.normal

            // Absorb any wheel events over the dialog so background tasks never scroll
            WheelHandler {
                target: null
                onWheel: (event) => {
                    if (dialogFlickable.contentHeight > dialogFlickable.height) {
                        const delta = event.angleDelta.y;
                        const step = (Math.abs(delta) >= 120 ? 40 : 20) * (delta > 0 ? -1 : 1);
                        const maxY = Math.max(0, dialogFlickable.contentHeight - dialogFlickable.height);
                        dialogFlickable.contentY = Math.max(0, Math.min(dialogFlickable.contentY + step, maxY));
                    }
                    event.accepted = true;
                }
            }

            // Fixed header
            StyledText {
                id: dialogHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 14
                color: Appearance.m3colors.m3onSurface
                font.pixelSize: Appearance.font.pixelSize.larger
                text: root.isEditDueMode ? Translation.tr("Edit task") : Translation.tr("Add task")
            }

            // Scrollable body for form fields
            StyledFlickable {
                id: dialogFlickable
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: dialogHeader.bottom
                anchors.bottom: dialogDivider.top
                anchors.topMargin: 8
                anchors.bottomMargin: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                contentWidth: width
                contentHeight: formColumnLayout.implicitHeight

                ColumnLayout {
                    id: formColumnLayout
                    width: dialogFlickable.width - 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    spacing: 10

                TextField {
                    id: todoInput
                    visible: true
                    Layout.fillWidth: true
                    padding: 8
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                    selectionColor: Appearance.colors.colSecondaryContainer
                    placeholderText: Translation.tr("Task description")
                    placeholderTextColor: Appearance.m3colors.m3outline
                    focus: root.showAddDialog
                    onAccepted: root.saveDialog()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.verysmall
                        border.width: 2
                        border.color: todoInput.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? Appearance.colors.colPrimary : "transparent"
                        radius: 1
                    }
                }

                // Priority chips row
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Priority")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        FilterChip {
                            chipText: Translation.tr("None")
                            selected: root.selectedPriority === 0
                            onClicked: root.selectedPriority = 0
                        }

                        FilterChip {
                            chipText: Translation.tr("Low")
                            dotColor: Todo.priorityColors[1]
                            selected: root.selectedPriority === 1
                            onClicked: root.selectedPriority = 1
                        }

                        FilterChip {
                            chipText: Translation.tr("Medium")
                            dotColor: Todo.priorityColors[2]
                            selected: root.selectedPriority === 2
                            onClicked: root.selectedPriority = 2
                        }

                        FilterChip {
                            chipText: Translation.tr("High")
                            dotColor: Todo.priorityColors[3]
                            selected: root.selectedPriority === 3
                            onClicked: root.selectedPriority = 3
                        }
                    }
                }

                // Due date chips row
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Due date")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        FilterChip {
                            chipText: Translation.tr("None")
                            selected: root.selectedDateStr === ""
                            onClicked: {
                                root.selectedDateStr = "";
                                root.hasTime = false;
                                root.selectedReminder = -1;
                            }
                        }

                        FilterChip {
                            chipText: Translation.tr("Today")
                            selected: root.selectedDateStr === Todo.formatDateOnly(new Date())
                            onClicked: {
                                root.selectedDateStr = Todo.formatDateOnly(new Date());
                            }
                        }

                        FilterChip {
                            chipText: Translation.tr("Tomorrow")
                            selected: {
                                let d = new Date();
                                d.setDate(d.getDate() + 1);
                                return root.selectedDateStr === Todo.formatDateOnly(d);
                            }
                            onClicked: {
                                let d = new Date();
                                d.setDate(d.getDate() + 1);
                                root.selectedDateStr = Todo.formatDateOnly(d);
                            }
                        }

                        FilterChip {
                            iconName: "calendar_month"
                            chipText: {
                                let todayStr = Todo.formatDateOnly(new Date());
                                let tom = new Date(); tom.setDate(tom.getDate() + 1);
                                let tomStr = Todo.formatDateOnly(tom);
                                if (root.selectedDateStr !== "" && root.selectedDateStr !== todayStr && root.selectedDateStr !== tomStr) {
                                    let parts = root.selectedDateStr.split("-");
                                    if (parts.length === 3) {
                                        let dt = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                                        let loc = Qt.locale();
                                        let now = new Date();
                                        if (dt.getFullYear() !== now.getFullYear()) {
                                            return `${dt.getDate()} ${loc.monthName(dt.getMonth(), Locale.ShortFormat)} ${dt.getFullYear()}`;
                                        }
                                        return `${dt.getDate()} ${loc.monthName(dt.getMonth(), Locale.ShortFormat)}`;
                                    }
                                }
                                return Translation.tr("Pick date");
                            }
                            selected: {
                                let todayStr = Todo.formatDateOnly(new Date());
                                let tom = new Date(); tom.setDate(tom.getDate() + 1);
                                let tomStr = Todo.formatDateOnly(tom);
                                return root.selectedDateStr !== "" && root.selectedDateStr !== todayStr && root.selectedDateStr !== tomStr;
                            }
                            onClicked: {
                                root.showDatePickerOverlay = true;
                            }
                        }
                    }
                }

                // Add time switch & steppers
                RowLayout {
                    visible: root.selectedDateStr !== ""
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: Translation.tr("Add time")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurface
                    }

                    StyledSwitch {
                        checked: root.hasTime
                        onToggled: {
                            root.hasTime = checked;
                            if (checked) {
                                Qt.callLater(() => {
                                    dialogFlickable.contentY = Math.max(0, dialogFlickable.contentHeight - dialogFlickable.height);
                                });
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        visible: root.hasTime
                        spacing: 4

                        ColumnLayout {
                            spacing: 0
                            WheelHandler {
                                onWheel: (event) => {
                                    if (event.angleDelta.y > 0) root.stepHour(1);
                                    else if (event.angleDelta.y < 0) root.stepHour(-1);
                                    event.accepted = true;
                                }
                            }
                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 16
                                buttonRadius: Appearance.rounding.verysmall
                                onClicked: root.stepHour(1)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "keyboard_arrow_up"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 22
                                radius: Appearance.rounding.verysmall
                                color: Appearance.m3colors.m3surfaceContainerHighest
                                border.width: 1
                                border.color: Appearance.m3colors.m3outlineVariant
                                StyledText {
                                    anchors.centerIn: parent
                                    text: String(root.selectedHour).padStart(2, "0")
                                    font.weight: Font.Medium
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 16
                                buttonRadius: Appearance.rounding.verysmall
                                onClicked: root.stepHour(-1)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "keyboard_arrow_down"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                        }

                        StyledText {
                            text: ":"
                            font.weight: Font.Bold
                            color: Appearance.m3colors.m3onSurface
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 0
                            WheelHandler {
                                onWheel: (event) => {
                                    if (event.angleDelta.y > 0) root.stepMinute(5);
                                    else if (event.angleDelta.y < 0) root.stepMinute(-5);
                                    event.accepted = true;
                                }
                            }
                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 16
                                buttonRadius: Appearance.rounding.verysmall
                                onClicked: root.stepMinute(5)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "keyboard_arrow_up"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 22
                                radius: Appearance.rounding.verysmall
                                color: Appearance.m3colors.m3surfaceContainerHighest
                                border.width: 1
                                border.color: Appearance.m3colors.m3outlineVariant
                                StyledText {
                                    anchors.centerIn: parent
                                    text: String(root.selectedMinute).padStart(2, "0")
                                    font.weight: Font.Medium
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 16
                                buttonRadius: Appearance.rounding.verysmall
                                onClicked: root.stepMinute(-5)
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "keyboard_arrow_down"
                                    font.family: Appearance.font.family.iconMaterial
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }
                        }
                    }
                }

                // Reminder section
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    enabled: root.selectedDateStr !== ""
                    opacity: root.selectedDateStr !== "" ? 1.0 : 0.4

                    StyledText {
                        text: Translation.tr("Reminder")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3onSurfaceVariant
                    }

                    RowLayout {
                        visible: root.selectedDateStr !== "" && !root.hasTime
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Reminder at 9:00 on the day")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3onSurface
                        }

                        RowLayout {
                            spacing: 6
                            FilterChip {
                                chipText: Translation.tr("None")
                                selected: root.selectedReminder < 0
                                onClicked: root.selectedReminder = -1
                            }
                            FilterChip {
                                chipText: Translation.tr("At 9:00")
                                selected: root.selectedReminder >= 0
                                onClicked: root.selectedReminder = 0
                            }
                        }
                    }

                    Flow {
                        visible: root.selectedDateStr === "" || root.hasTime
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { name: Translation.tr("None"), val: -1 },
                                { name: Translation.tr("At due time"), val: 0 },
                                { name: Translation.tr("10 min"), val: 10 },
                                { name: Translation.tr("30 min"), val: 30 },
                                { name: Translation.tr("1 hour"), val: 60 }
                            ]
                            delegate: FilterChip {
                                required property var modelData
                                chipText: modelData.name
                                selected: root.selectedReminder === modelData.val
                                onClicked: root.selectedReminder = modelData.val
                            }
                        }
                    }
                }

                }
            }

            // Subtle divider visible when form content scrolls
            Rectangle {
                id: dialogDivider
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: dialogActionsRow.top
                anchors.bottomMargin: 6
                height: 1
                color: Appearance.m3colors.m3outlineVariant
                opacity: dialogFlickable.contentHeight > dialogFlickable.height ? 0.6 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            // Fixed footer: Action buttons row is always visible and clickable
            RowLayout {
                id: dialogActionsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 14
                spacing: 6

                DialogButton {
                    visible: root.isEditDueMode && !!root.selectedDateStr
                    buttonText: Translation.tr("Remove due date")
                    onClicked: {
                        let targetIdx = root.resolveEditingIndex();
                        let newContent = todoInput.text.trim();
                        if (newContent.length > 0) {
                            Todo.updateTaskDetails(targetIdx, newContent, "", -1, root.selectedPriority);
                        } else {
                            Todo.updateDue(targetIdx, "", -1);
                            Todo.setPriority(targetIdx, root.selectedPriority);
                        }
                        root.closeDialog();
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: root.closeDialog()
                }
                DialogButton {
                    buttonText: root.isEditDueMode ? Translation.tr("Save") : Translation.tr("Add")
                    enabled: todoInput.text.trim().length > 0
                    onClicked: root.saveDialog()
                }
            }
        }

        DueDatePicker {
            visible: root.showDatePickerOverlay
            anchors.fill: parent
            selectedDate: {
                if (root.selectedDateStr) {
                    let parts = root.selectedDateStr.split("-");
                    if (parts.length === 3) {
                        return new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                    }
                }
                return new Date();
            }
            onDateSelected: (selected) => {
                root.selectedDateStr = Todo.formatDateOnly(selected);
                root.showDatePickerOverlay = false;
            }
            onClosed: {
                root.showDatePickerOverlay = false;
            }
        }
    }
}
