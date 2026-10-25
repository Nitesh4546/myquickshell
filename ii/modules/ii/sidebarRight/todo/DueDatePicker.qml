pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property date selectedDate: new Date()
    property int pickerYear: new Date().getFullYear()
    property int pickerMonth: new Date().getMonth()
    property int firstDayOfWeek: (Config.options && Config.options.time && Config.options.time.firstDayOfWeek !== undefined) ? Config.options.time.firstDayOfWeek : 1

    signal dateSelected(date selected)
    signal closed()

    anchors.fill: parent
    z: 100

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: ColorUtils.transparentize(Appearance.m3colors.m3scrim, 0.45)
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            onClicked: root.closed()
        }
        WheelHandler {
            target: null
            onWheel: (event) => {
                event.accepted = true;
            }
        }
    }

    Rectangle {
        id: datePickerCard
        anchors.centerIn: parent
        width: Math.min(320, parent.width - 20)
        implicitHeight: datePickerCardLayout.implicitHeight + 20
        color: Appearance.m3colors.m3surfaceContainerHigh
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant

        MouseArea {
            anchors.fill: parent
            preventStealing: true
        }

        ColumnLayout {
            id: datePickerCardLayout
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // Month navigation row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    onClicked: {
                        if (root.pickerMonth === 0) {
                            root.pickerMonth = 11;
                            root.pickerYear -= 1;
                        } else {
                            root.pickerMonth -= 1;
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.m3colors.m3onSurface
                    }
                }

                RippleButton {
                    id: monthTitleButton
                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.verysmall
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.m3colors.m3surfaceContainerHighest
                    onClicked: {
                        let today = new Date();
                        root.pickerYear = today.getFullYear();
                        root.pickerMonth = today.getMonth();
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: Qt.formatDate(new Date(root.pickerYear, root.pickerMonth, 1), "MMMM yyyy")
                        font.weight: Font.DemiBold
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3onSurface
                    }
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    onClicked: {
                        if (root.pickerMonth === 11) {
                            root.pickerMonth = 0;
                            root.pickerYear += 1;
                        } else {
                            root.pickerMonth += 1;
                        }
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: Appearance.font.family.iconMaterial
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.m3colors.m3onSurface
                    }
                }
            }

            // Days of week header
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: 7
                    delegate: Item {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 20
                        readonly property int dayOfWeek: ((root.firstDayOfWeek - 1 + index) % 7) + 1

                        StyledText {
                            anchors.centerIn: parent
                            text: Qt.locale().dayName(dayOfWeek, Locale.ShortFormat)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.m3colors.m3onSurfaceVariant
                        }
                    }
                }
            }

            // Month days 7x6 grid
            GridLayout {
                id: monthDaysGrid
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                Repeater {
                    model: 42
                    delegate: Item {
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 28

                        readonly property date cellDate: {
                            let firstDay = root.firstDayOfWeek;
                            let firstDayJs = firstDay === 7 ? 0 : firstDay;
                            let firstOfMonth = new Date(root.pickerYear, root.pickerMonth, 1);
                            let jsDay = firstOfMonth.getDay();
                            let offset = (jsDay - firstDayJs + 7) % 7;
                            return new Date(root.pickerYear, root.pickerMonth, 1 - offset + index);
                        }

                        readonly property bool inCurrentMonth: cellDate.getMonth() === root.pickerMonth
                        readonly property bool isToday: {
                            let today = new Date();
                            return cellDate.getFullYear() === today.getFullYear() &&
                                   cellDate.getMonth() === today.getMonth() &&
                                   cellDate.getDate() === today.getDate();
                        }
                        readonly property bool isSelected: {
                            return root.selectedDate &&
                                   cellDate.getFullYear() === root.selectedDate.getFullYear() &&
                                   cellDate.getMonth() === root.selectedDate.getMonth() &&
                                   cellDate.getDate() === root.selectedDate.getDate();
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: Appearance.rounding.full
                            color: isSelected ? Appearance.colors.colPrimary :
                                   isToday ? Appearance.m3colors.m3surfaceContainerHighest : "transparent"
                            border.width: (!isSelected && isToday) ? 1 : 0
                            border.color: Appearance.colors.colPrimary

                            RippleButton {
                                anchors.fill: parent
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: isSelected ? Appearance.colors.colPrimaryHover : Appearance.m3colors.m3surfaceContainerHighest

                                onClicked: {
                                    root.dateSelected(cellDate);
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: cellDate.getDate()
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: (isSelected || isToday) ? Font.Bold : Font.Normal
                                    color: isSelected ? Appearance.colors.colOnPrimary :
                                           !inCurrentMonth ? Appearance.m3colors.m3outline :
                                           Appearance.m3colors.m3onSurface
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
