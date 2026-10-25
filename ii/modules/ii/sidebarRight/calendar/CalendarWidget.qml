import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    // Layout.topMargin: 10
    anchors.topMargin: 10
    property int monthShift: 0
    property int prevMonthShift: 0
    property bool entered: false
    property bool navReady: false
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property bool showMarkers: Config.options?.sidebar?.showCalendarMarkers ?? true

    readonly property var markers: {
        if (!root.showMarkers || !root.calendarLayout || root.calendarLayout.length < 6) return {};
        const _events = CalendarService.localEvents;
        const _todos = Todo.list;
        const firstRow = root.calendarLayout[0];
        const lastRow = root.calendarLayout[5];
        if (!firstRow || !lastRow || firstRow.length < 7 || lastRow.length < 7) return {};
        const rangeStart = firstRow[0].date;
        const rangeEnd = lastRow[6].date;
        if (!rangeStart || !rangeEnd) return {};
        return CalendarService.dayMarkers(rangeStart, rangeEnd);
    }

    onMonthShiftChanged: {
        let enabled = Config.options?.sidebar?.tabAnimations ?? true;
        if (root.navReady && enabled) {
            let forward = root.monthShift > root.prevMonthShift;
            monthNavAnim.fromX = forward ? 14 : -14;
            monthNavAnim.restart();
        }
        root.prevMonthShift = root.monthShift;
    }

    width: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                monthShift++;
            } else if (event.key === Qt.Key_PageUp) {
                monthShift--;
            }
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                monthShift--;
            } else if (event.angleDelta.y < 0) {
                monthShift++;
            }
        }
    }

    ColumnLayout {
        id: calendarColumn
        anchors.centerIn: parent
        spacing: 5

        // Calendar header
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            opacity: root.entered ? 1 : 0
            Behavior on opacity {
                enabled: Config.options?.sidebar?.tabAnimations ?? true
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            CalendarHeaderButton {
                clip: true
                buttonText: `${monthShift != 0 ? "• " : ""}${viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                tooltipText: (monthShift === 0) ? "" : Translation.tr("Jump to current month")
                downAction: () => {
                    monthShift = 0;
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift--;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift++;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // Week days row
        RowLayout {
            id: weekDaysRow
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            spacing: 5
            opacity: root.entered ? 1 : 0
            Behavior on opacity {
                enabled: Config.options?.sidebar?.tabAnimations ?? true
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Repeater {
                model: CalendarLayout.weekDays
                delegate: CalendarDayButton {
                    day: Translation.tr(modelData.day)
                    isToday: modelData.today
                    bold: true
                    enabled: false
                }
            }
        }

        // Real week rows container with navigation slide/crossfade
        ColumnLayout {
            id: gridContainer
            spacing: 5
            transform: Translate {
                id: gridTranslate
                x: 0
            }

            ParallelAnimation {
                id: monthNavAnim
                property real fromX: 14
                PropertyAnimation {
                    target: gridTranslate
                    property: "x"
                    from: monthNavAnim.fromX
                    to: 0
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
                PropertyAnimation {
                    target: gridContainer
                    property: "opacity"
                    from: 0.25
                    to: 1
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            Repeater {
                id: calendarRows
                model: 6
                delegate: RowLayout {
                    id: weekRow
                    required property int modelData
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: false
                    spacing: 5

                    property bool rowEntered: !(Config.options?.sidebar?.tabAnimations ?? true)

                    opacity: rowEntered ? 1 : 0
                    transform: Translate {
                        id: rowTranslate
                        y: weekRow.rowEntered ? 0 : 8
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

                    Timer {
                        interval: 40 + weekRow.modelData * 25
                        running: Config.options?.sidebar?.tabAnimations ?? true
                        repeat: false
                        onTriggered: {
                            weekRow.rowEntered = true;
                        }
                    }

                    Repeater {
                        model: Array(7).fill(modelData)
                        delegate: CalendarDayButton {
                            day: calendarLayout[modelData][index].day
                            isToday: calendarLayout[modelData][index].today
                            markerData: (root.showMarkers && root.markers) ? (root.markers[calendarLayout[modelData][index].dateString] || null) : null
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(() => {
            root.entered = true;
            root.navReady = true;
        });
    }
}