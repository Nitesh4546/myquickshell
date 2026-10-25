import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property var taskList
    property string emptyPlaceholderIcon
    property string emptyPlaceholderText
    property int todoListItemSpacing: 5
    property int todoListItemPadding: 8
    property int listBottomPadding: 80
    property string activeEditingTaskId: ""
    readonly property bool isEditing: activeEditingTaskId.length > 0
    property bool isCancellingForNewEdit: false

    signal editDueRequested(int originalIndex, var task)
    signal editTaskStarted(string taskId)
    signal editTaskFinished()

    function startEditingTask(taskId) {
        if (root.activeEditingTaskId && root.activeEditingTaskId !== taskId) {
            root.isCancellingForNewEdit = true;
            root.activeEditingTaskId = "";
            root.isCancellingForNewEdit = false;
        }
        root.activeEditingTaskId = taskId;
        root.editTaskStarted(taskId);
    }

    function finishEditingTask(taskId) {
        if (root.activeEditingTaskId === taskId) {
            root.activeEditingTaskId = "";
            root.editTaskFinished();
        }
    }

    function cancelActiveEdit() {
        if (root.isEditing) {
            root.activeEditingTaskId = "";
            root.editTaskFinished();
        }
    }

    function resolveTaskIndex(taskId, fallbackIdx) {
        if (taskId) {
            let idx = Todo.list.findIndex(t => t.id === taskId);
            if (idx !== -1) return idx;
        }
        return (fallbackIdx !== undefined && fallbackIdx !== null) ? fallbackIdx : -1;
    }

    function formatDueLabel(task) {
        if (!task || !task.due) return "";
        let dueStr = String(task.due).trim();
        if (!dueStr) return "";

        let dateOnlyMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dueStr);
        let dt, isTimed;
        if (dateOnlyMatch) {
            dt = new Date(parseInt(dateOnlyMatch[1]), parseInt(dateOnlyMatch[2]) - 1, parseInt(dateOnlyMatch[3]));
            isTimed = false;
        } else {
            dt = new Date(dueStr);
            if (isNaN(dt.getTime())) return "";
            isTimed = true;
        }

        let now = new Date();
        let today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        let target = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
        let diffDays = Math.round((target.getTime() - today.getTime()) / 86400000);

        let tf = (Config.options && Config.options.time && Config.options.time.format) ? Config.options.time.format : "hh:mm";
        let timeStr = isTimed ? ` ${Qt.formatTime(dt, tf)}` : "";

        if (diffDays === 0) {
            return `${Translation.tr("Today")}${timeStr}`;
        } else if (diffDays === 1) {
            return `${Translation.tr("Tomorrow")}${timeStr}`;
        } else {
            let loc = Qt.locale();
            let dayMonth = `${dt.getDate()} ${loc.monthName(dt.getMonth(), Locale.ShortFormat)}`;
            if (dt.getFullYear() !== now.getFullYear()) {
                return `${dayMonth} ${dt.getFullYear()}${timeStr}`;
            }
            return `${dayMonth}${timeStr}`;
        }
    }

    StyledListView {
        id: listView
        anchors.fill: parent
        spacing: root.todoListItemSpacing
        animateAppearance: true
        animateMovement: true

        remove: Transition {
            ParallelAnimation {
                PropertyAnimation {
                    property: "opacity"
                    to: 0
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
                PropertyAnimation {
                    property: "x"
                    to: listView.width * 0.35
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        removeDisplaced: Transition {
            PropertyAnimation {
                property: "y"
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        displaced: Transition {
            PropertyAnimation {
                property: "y"
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        model: ScriptModel {
            objectProp: "id"
            values: root.taskList
        }
        delegate: Item {
            id: todoItem
            required property int index
            required property var modelData
            property bool pendingDoneToggle: false
            property bool pendingDelete: false
            property bool enableHeightAnimation: false
            property bool isCancelling: false
            property bool isSaving: false
            property int editPriority: 0
            property bool isInteractingWithControls: false

            property bool cardEntered: !(Config.options?.sidebar?.tabAnimations ?? true)
            property bool isAnimatingOut: false

            function resetDelegateState() {
                removeTimer.stop();
                removeTimer.callback = null;
                isAnimatingOut = false;
                cardEntered = true;
                todoItem.opacity = Qt.binding(() => (todoItem.isAnimatingOut ? 0 : (todoItem.cardEntered ? 1 : 0)));
                todoItem.implicitHeight = Qt.binding(() => todoItemRectangle.implicitHeight);
                cardTranslate.x = Qt.binding(() => (todoItem.isAnimatingOut ? (todoItem.width * 0.35) : 0));
                cardTranslate.y = Qt.binding(() => (todoItem.cardEntered ? 0 : 8));
                pendingDoneToggle = false;
                pendingDelete = false;
                isCancelling = false;
                isSaving = false;
                isInteractingWithControls = false;
            }

            onModelDataChanged: {
                resetDelegateState();
            }

            Timer {
                id: removeTimer
                interval: Appearance.animation.elementMoveFast.duration
                repeat: false
                property var callback: null
                onTriggered: {
                    if (callback) {
                        let fn = callback;
                        callback = null;
                        fn();
                    }
                }
            }

            function removeCard(actionFn) {
                if (isAnimatingOut) return;
                let enabled = Config.options?.sidebar?.tabAnimations ?? true;
                if (!enabled) {
                    actionFn();
                    return;
                }
                isAnimatingOut = true;
                removeTimer.callback = actionFn;
                removeTimer.restart();
            }

            Component.onCompleted: {
                if ((Config.options?.sidebar?.tabAnimations ?? true) && index < 8) {
                    staggerTimer.interval = index * 20;
                    staggerTimer.start();
                } else {
                    cardEntered = true;
                }
            }

            Timer {
                id: staggerTimer
                repeat: false
                onTriggered: todoItem.cardEntered = true;
            }

            opacity: isAnimatingOut ? 0 : (cardEntered ? 1 : 0)
            transform: Translate {
                id: cardTranslate
                x: todoItem.isAnimatingOut ? (todoItem.width * 0.35) : 0
                y: todoItem.cardEntered ? 0 : 8
                Behavior on x {
                    enabled: Config.options?.sidebar?.tabAnimations ?? true
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Behavior on y {
                    enabled: Config.options?.sidebar?.tabAnimations ?? true
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
            }

            Behavior on opacity {
                enabled: Config.options?.sidebar?.tabAnimations ?? true
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            readonly property bool editing: root.activeEditingTaskId.length > 0 && !!todoItem.modelData && root.activeEditingTaskId === todoItem.modelData.id

            function startEdit() {
                if (!todoItem.modelData) return;
                todoItem.isCancelling = false;
                todoItem.isSaving = false;
                todoItem.editPriority = (todoItem.modelData.priority !== undefined && todoItem.modelData.priority !== null) ? parseInt(todoItem.modelData.priority) : 0;
                root.startEditingTask(todoItem.modelData.id);
            }

            function saveEdit() {
                if (!todoItem.editing || todoItem.isCancelling || root.isCancellingForNewEdit) return;
                let trimmed = editTextArea.text.trim();
                if (trimmed.length === 0) {
                    cancelEdit();
                    return;
                }
                let taskId = todoItem.modelData ? todoItem.modelData.id : "";
                let originalIndex = root.resolveTaskIndex(taskId, todoItem.modelData ? todoItem.modelData.originalIndex : -1);
                let currentContent = todoItem.modelData ? todoItem.modelData.content : "";
                let currentPriority = (todoItem.modelData && todoItem.modelData.priority !== undefined) ? parseInt(todoItem.modelData.priority) : 0;
                let contentChanged = (originalIndex >= 0 && trimmed !== currentContent);
                let priorityChanged = (originalIndex >= 0 && todoItem.editPriority !== currentPriority);

                todoItem.isSaving = false;
                root.finishEditingTask(taskId);

                if (contentChanged && priorityChanged) {
                    Todo.updateTaskDetails(originalIndex, trimmed, undefined, undefined, todoItem.editPriority);
                } else if (contentChanged) {
                    Todo.updateTask(originalIndex, trimmed);
                } else if (priorityChanged) {
                    Todo.setPriority(originalIndex, todoItem.editPriority);
                }
            }

            function cancelEdit() {
                if (!todoItem.editing) return;
                todoItem.isCancelling = true;
                todoItem.isSaving = false;
                editTextArea.text = todoItem.modelData ? todoItem.modelData.content : "";
                editPriority = (todoItem.modelData && todoItem.modelData.priority !== undefined) ? parseInt(todoItem.modelData.priority) : 0;
                root.finishEditingTask(todoItem.modelData ? todoItem.modelData.id : "");
                todoItem.isCancelling = false;
            }

            onEditingChanged: {
                if (editing) {
                    editTextArea.text = todoItem.modelData ? todoItem.modelData.content : "";
                    editPriority = (todoItem.modelData && todoItem.modelData.priority !== undefined && todoItem.modelData.priority !== null) ? parseInt(todoItem.modelData.priority) : 0;
                    editTextArea.forceActiveFocus();
                    editTextArea.cursorPosition = editTextArea.text.length;
                }
            }

            Component.onDestruction: {
                if (removeTimer.running && removeTimer.callback) {
                    let cb = removeTimer.callback;
                    removeTimer.callback = null;
                    cb();
                }
                if (todoItem.editing) {
                    root.finishEditingTask(todoItem.modelData ? todoItem.modelData.id : "");
                }
            }

            implicitHeight: todoItemRectangle.implicitHeight
            width: ListView.view.width
            clip: true

            Behavior on implicitHeight {
                enabled: enableHeightAnimation
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Rectangle {
                id: todoItemRectangle
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                implicitHeight: todoContentRowLayout.implicitHeight
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small

                ColumnLayout {
                    id: todoContentRowLayout
                    anchors.left: parent.left
                    anchors.right: parent.right

                    RowLayout {
                        id: contentRow
                        visible: !todoItem.editing
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: root.todoListItemPadding
                        spacing: 8

                        Item {
                            id: priorityDotContainer
                            implicitWidth: 10
                            implicitHeight: 10
                            Layout.preferredWidth: 10
                            Layout.preferredHeight: 10
                            Layout.fillWidth: false
                            Layout.fillHeight: false
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 4

                            Rectangle {
                                id: priorityDot
                                width: 10
                                height: 10
                                radius: 5
                                visible: (todoItem.modelData && todoItem.modelData.priority > 0)
                                color: (todoItem.modelData && todoItem.modelData.priority > 0) ? (Todo.priorityColors[todoItem.modelData.priority] ?? "transparent") : "transparent"
                                opacity: (todoItem.modelData && todoItem.modelData.done) ? 0.4 : 1.0
                            }

                            MouseArea {
                                id: dotMouseArea
                                anchors.fill: parent
                                enabled: priorityDot.visible
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.editDueRequested(todoItem.modelData.originalIndex, todoItem.modelData);
                                }

                                StyledToolTip {
                                    extraVisibleCondition: dotMouseArea.containsMouse && text.length > 0
                                    text: {
                                        if (!todoItem.modelData || !todoItem.modelData.priority) return "";
                                        if (todoItem.modelData.priority === 1) return Translation.tr("Low priority");
                                        if (todoItem.modelData.priority === 2) return Translation.tr("Medium priority");
                                        if (todoItem.modelData.priority === 3) return Translation.tr("High priority");
                                        return "";
                                    }
                                }
                            }
                        }

                        StyledText {
                            id: todoContentText
                            Layout.fillWidth: true
                            text: todoItem.modelData.content
                            wrapMode: Text.Wrap

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: false
                                onPressed: (mouse) => {
                                    if (root.isEditing && root.activeEditingTaskId !== (todoItem.modelData ? todoItem.modelData.id : "")) {
                                        root.cancelActiveEdit();
                                    }
                                }
                                onDoubleClicked: (mouse) => {
                                    todoItem.startEdit();
                                }
                            }
                        }
                    }

                    TextArea {
                        id: editTextArea
                        visible: todoItem.editing
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: root.todoListItemPadding
                        padding: 8
                        wrapMode: Text.Wrap
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        renderType: Text.NativeRendering
                        selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
                        selectionColor: Appearance.colors.colSecondaryContainer
                        font.pixelSize: Appearance.font.pixelSize.normal
                        selectByMouse: true

                        background: Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.verysmall
                            border.width: 2
                            border.color: editTextArea.activeFocus ? Appearance.colors.colPrimary : Appearance.m3colors.m3outline
                            color: Appearance.colors.colLayer3
                        }

                        cursorDelegate: Rectangle {
                            width: 1
                            color: editTextArea.activeFocus ? Appearance.colors.colPrimary : "transparent"
                            radius: 1
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    return;
                                }
                                event.accepted = true;
                                todoItem.saveEdit();
                            } else if (event.key === Qt.Key_Escape) {
                                event.accepted = true;
                                todoItem.cancelEdit();
                            } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                                event.accepted = true;
                            }
                        }

                        onActiveFocusChanged: {
                            if (!activeFocus && todoItem.editing && !todoItem.isCancelling && !todoItem.isSaving && !root.isCancellingForNewEdit && !todoItem.isInteractingWithControls) {
                                todoItem.saveEdit();
                            }
                        }
                    }

                    // Edit options toolbar (visible when editing: priority & date/time)
                    RowLayout {
                        id: editToolbarRow
                        visible: todoItem.editing
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 4
                        Layout.bottomMargin: 2
                        spacing: 6

                        StyledText {
                            text: Translation.tr("Priority:")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3onSurfaceVariant
                            Layout.alignment: Qt.AlignVCenter
                        }

                        RowLayout {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            // Priority: None (0)
                            RippleButton {
                                id: pNoneBtn
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: 11
                                colBackground: todoItem.editPriority === 0 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                downAction: () => { todoItem.isInteractingWithControls = true; }
                                onClicked: {
                                    todoItem.editPriority = 0;
                                    todoItem.isInteractingWithControls = false;
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "block"
                                    iconSize: 12
                                    color: todoItem.editPriority === 0 ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurfaceVariant
                                }

                                MouseArea {
                                    id: pNoneHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                                StyledToolTip {
                                    extraVisibleCondition: pNoneHover.containsMouse
                                    text: Translation.tr("Priority: None")
                                }
                            }

                            // Priority: Low (1)
                            RippleButton {
                                id: pLowBtn
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: 11
                                colBackground: todoItem.editPriority === 1 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                downAction: () => { todoItem.isInteractingWithControls = true; }
                                onClicked: {
                                    todoItem.editPriority = 1;
                                    todoItem.isInteractingWithControls = false;
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Todo.priorityColors[1]
                                }

                                MouseArea {
                                    id: pLowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                                StyledToolTip {
                                    extraVisibleCondition: pLowHover.containsMouse
                                    text: Translation.tr("Priority: Low")
                                }
                            }

                            // Priority: Medium (2)
                            RippleButton {
                                id: pMedBtn
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: 11
                                colBackground: todoItem.editPriority === 2 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                downAction: () => { todoItem.isInteractingWithControls = true; }
                                onClicked: {
                                    todoItem.editPriority = 2;
                                    todoItem.isInteractingWithControls = false;
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Todo.priorityColors[2]
                                }

                                MouseArea {
                                    id: pMedHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                                StyledToolTip {
                                    extraVisibleCondition: pMedHover.containsMouse
                                    text: Translation.tr("Priority: Medium")
                                }
                            }

                            // Priority: High (3)
                            RippleButton {
                                id: pHighBtn
                                focusPolicy: Qt.NoFocus
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: 11
                                colBackground: todoItem.editPriority === 3 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                                colBackgroundHover: Appearance.colors.colLayer3Hover
                                downAction: () => { todoItem.isInteractingWithControls = true; }
                                onClicked: {
                                    todoItem.editPriority = 3;
                                    todoItem.isInteractingWithControls = false;
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Todo.priorityColors[3]
                                }

                                MouseArea {
                                    id: pHighHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                                StyledToolTip {
                                    extraVisibleCondition: pHighHover.containsMouse
                                    text: Translation.tr("Priority: High")
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Date & Time button in edit mode
                        RippleButton {
                            id: editDateBtn
                            focusPolicy: Qt.NoFocus
                            implicitHeight: 24
                            implicitWidth: editDateRow.implicitWidth + 12
                            buttonRadius: Appearance.rounding.verysmall
                            colBackground: (todoItem.modelData && todoItem.modelData.due) ?
                                Appearance.colors.colPrimaryContainer :
                                Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            Layout.alignment: Qt.AlignVCenter
                            downAction: () => {
                                todoItem.isInteractingWithControls = true;
                            }
                            onClicked: {
                                let currentContent = editTextArea.text.trim();
                                if (currentContent.length === 0) currentContent = todoItem.modelData ? todoItem.modelData.content : "";
                                root.finishEditingTask(todoItem.modelData ? todoItem.modelData.id : "");
                                root.editDueRequested(todoItem.modelData.originalIndex, Object.assign({}, todoItem.modelData, {
                                    content: currentContent,
                                    priority: todoItem.editPriority
                                }));
                                todoItem.isInteractingWithControls = false;
                            }

                            RowLayout {
                                id: editDateRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: "calendar_today"
                                    iconSize: 13
                                    color: (todoItem.modelData && todoItem.modelData.due) ?
                                        Appearance.colors.colOnPrimaryContainer :
                                        Appearance.colors.colOnLayer2
                                }

                                StyledText {
                                    text: (todoItem.modelData && todoItem.modelData.due) ?
                                        root.formatDueLabel(todoItem.modelData) :
                                        Translation.tr("Due date")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: (todoItem.modelData && todoItem.modelData.due) ?
                                        Appearance.colors.colOnPrimaryContainer :
                                        Appearance.colors.colOnLayer2
                                }
                            }

                            MouseArea {
                                id: editDateHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            StyledToolTip {
                                extraVisibleCondition: editDateHover.containsMouse
                                text: (todoItem.modelData && todoItem.modelData.due) ?
                                    Translation.tr("Change due date & time") :
                                    Translation.tr("Set due date & time")
                            }
                        }
                    }

                    RowLayout {
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.bottomMargin: todoListItemPadding
                        spacing: 6

                        RippleButton {
                            id: dueChip
                            visible: !todoItem.editing && !!todoItem.modelData.due
                            implicitHeight: 26
                            implicitWidth: dueChipRow.implicitWidth + 14
                            buttonRadius: Appearance.rounding.verysmall

                            readonly property bool isOverdue: !todoItem.modelData.done && Todo.isOverdue(todoItem.modelData)
                            readonly property bool isToday: !todoItem.modelData.done && Todo.isDueToday(todoItem.modelData)

                            colBackground: todoItem.modelData.done ?
                                Appearance.colors.colLayer3 :
                                isOverdue ? Appearance.colors.colErrorContainer :
                                isToday ? Appearance.colors.colPrimaryContainer :
                                Appearance.colors.colLayer3

                            colBackgroundHover: todoItem.modelData.done ?
                                Appearance.colors.colLayer3Hover :
                                isOverdue ? Appearance.colors.colErrorContainerHover :
                                isToday ? Appearance.colors.colPrimaryContainerHover :
                                Appearance.colors.colLayer3Hover

                            readonly property color colContent: todoItem.modelData.done ?
                                Appearance.colors.colSubtext :
                                isOverdue ? Appearance.colors.colOnErrorContainer :
                                isToday ? Appearance.colors.colOnPrimaryContainer :
                                Appearance.colors.colOnLayer2

                            onClicked: {
                                root.editDueRequested(todoItem.modelData.originalIndex, todoItem.modelData);
                            }

                            RowLayout {
                                id: dueChipRow
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: "calendar_today"
                                    iconSize: 14
                                    color: dueChip.colContent
                                }

                                StyledText {
                                    text: root.formatDueLabel(todoItem.modelData)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: dueChip.isOverdue || dueChip.isToday ? Font.Bold : Font.Normal
                                    color: dueChip.colContent
                                }

                                MaterialSymbol {
                                    visible: todoItem.modelData.reminder !== undefined && todoItem.modelData.reminder !== null && todoItem.modelData.reminder >= 0
                                    text: "notifications"
                                    iconSize: 14
                                    color: dueChip.colContent
                                }
                            }

                            MouseArea {
                                id: dueChipHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            StyledToolTip {
                                extraVisibleCondition: dueChipHover.containsMouse
                                text: Translation.tr("Edit due date")
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        // Edit button (visible when NOT editing)
                        TodoItemActionButton {
                            visible: !todoItem.editing
                            Layout.fillWidth: false
                            tooltipText: Translation.tr("Edit")
                            downAction: () => {
                                if (root.isEditing) {
                                    root.cancelActiveEdit();
                                }
                            }
                            onClicked: {
                                todoItem.startEdit();
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "edit"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        // Save button (swapped edit button, visible WHEN editing)
                        TodoItemActionButton {
                            visible: todoItem.editing
                            Layout.fillWidth: false
                            tooltipText: Translation.tr("Save")
                            downAction: () => {
                                todoItem.isSaving = true;
                            }
                            onClicked: {
                                todoItem.saveEdit();
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "check"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        // Cancel edit button
                        TodoItemActionButton {
                            id: cancelButton
                            visible: todoItem.editing
                            Layout.fillWidth: false
                            tooltipText: Translation.tr("Cancel")
                            downAction: () => {
                                todoItem.isCancelling = true;
                            }
                            onClicked: {
                                todoItem.cancelEdit();
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "close"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        // Complete / Uncomplete button
                        TodoItemActionButton {
                            visible: !todoItem.editing
                            Layout.fillWidth: false
                            tooltipText: todoItem.modelData.done ? Translation.tr("Mark unfinished") : Translation.tr("Mark done")
                            enabled: !todoItem.isAnimatingOut
                            onClicked: {
                                let taskId = todoItem.modelData ? todoItem.modelData.id : "";
                                let fallbackIdx = todoItem.modelData ? todoItem.modelData.originalIndex : -1;
                                let isDone = todoItem.modelData ? todoItem.modelData.done : false;
                                todoItem.removeCard(() => {
                                    let currentIdx = root.resolveTaskIndex(taskId, fallbackIdx);
                                    if (currentIdx !== -1) {
                                        if (!isDone)
                                            Todo.markDone(currentIdx);
                                        else
                                            Todo.markUnfinished(currentIdx);
                                    }
                                });
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: todoItem.modelData.done ? "remove_done" : "check"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        // Delete button
                        TodoItemActionButton {
                            visible: !todoItem.editing
                            Layout.fillWidth: false
                            tooltipText: Translation.tr("Delete")
                            enabled: !todoItem.isAnimatingOut
                            onClicked: {
                                let taskId = todoItem.modelData ? todoItem.modelData.id : "";
                                let fallbackIdx = todoItem.modelData ? todoItem.modelData.originalIndex : -1;
                                todoItem.removeCard(() => {
                                    let currentIdx = root.resolveTaskIndex(taskId, fallbackIdx);
                                    if (currentIdx !== -1) {
                                        Todo.deleteItem(currentIdx);
                                    }
                                });
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "delete_forever"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        // Placeholder when list is empty
        visible: opacity > 0
        opacity: taskList.length === 0 ? 1 : 0
        anchors.fill: parent

        Behavior on opacity {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 55
                color: Appearance.m3colors.m3outline
                text: emptyPlaceholderIcon
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3outline
                horizontalAlignment: Text.AlignHCenter
                text: emptyPlaceholderText
            }
        }
    }
}
