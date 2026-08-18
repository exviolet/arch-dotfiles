pragma ComponentBehavior: Bound

import QtQuick

import "../../services"

Item {
    id: surface

    required property date now
    required property bool pinned
    required property bool expanded

    property int monthOffset: 0

    readonly property var viewDate: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)
    readonly property int viewYear: viewDate.getFullYear()
    readonly property int viewMonth: viewDate.getMonth()
    readonly property bool viewingNow: monthOffset === 0
    readonly property int today: now.getDate()

    // 1 января 2024 — понедельник, поэтому неделя всегда начинается с него
    readonly property var weekdayNames: {
        const names = []
        for (let index = 0; index < 7; ++index)
            names.push(Qt.formatDate(new Date(2024, 0, 1 + index), "ddd").toUpperCase())
        return names
    }

    // нули добивают сетку до первого дня месяца
    readonly property var cells: {
        const offset = (new Date(surface.viewYear, surface.viewMonth, 1).getDay() + 6) % 7
        const total = new Date(surface.viewYear, surface.viewMonth + 1, 0).getDate()
        const list = []
        for (let index = 0; index < offset; ++index)
            list.push(0)
        for (let day = 1; day <= total; ++day)
            list.push(day)
        return list
    }

    function capitalize(text: string): string {
        return text.length === 0 ? text : text.slice(0, 1).toUpperCase() + text.slice(1)
    }

    function monthLabel(): string {
        return surface.capitalize(Qt.formatDate(surface.viewDate, "MMMM")) + " " + String(surface.viewYear)
    }

    // возврат к текущему месяцу, чтобы календарь всегда открывался на сегодня
    onVisibleChanged: {
        if (!visible)
            monthOffset = 0
    }

    WheelHandler {
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
            if (delta !== 0)
                surface.monthOffset += delta > 0 ? -1 : 1
        }
    }

    SurfaceHeader {
        width: parent.width
        eyebrow: "TIME /"
        eyebrowLabel: Qt.formatDate(surface.viewDate, "MMMM").toUpperCase()
        mode: String(surface.viewYear)
        pinned: surface.pinned
        expanded: surface.expanded
        title: surface.viewingNow ? Qt.formatDate(surface.now, "d MMMM") : surface.monthLabel()
        subtitle: surface.viewingNow
            ? surface.capitalize(Qt.formatDate(surface.now, "dddd"))
            : "Сегодня — " + Qt.formatDate(surface.now, "d MMMM")
    }

    Column {
        x: 22
        y: 158
        width: parent.width - 44
        spacing: 10

        Item {
            width: parent.width
            height: 30

            Rectangle {
                id: previousMonth
                width: 40
                height: 30
                radius: 9
                color: previousMouse.containsMouse ? Theme.raisedSurface : "transparent"
                border.width: 1
                border.color: Theme.border

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: Qt.resolvedUrl("../../icons/iconoir/nav-arrow-left.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: previousMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: surface.monthOffset -= 1
                }
            }

            Rectangle {
                visible: !surface.viewingNow
                anchors.centerIn: parent
                width: 78
                height: 30
                radius: 9
                color: todayMouse.containsMouse ? Theme.raisedSurface : "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "TODAY"
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: surface.monthOffset = 0
                }
            }

            Rectangle {
                id: nextMonth
                anchors.right: parent.right
                width: 40
                height: 30
                radius: 9
                color: nextMouse.containsMouse ? Theme.raisedSurface : "transparent"
                border.width: 1
                border.color: Theme.border

                Image {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: Qt.resolvedUrl("../../icons/iconoir/nav-arrow-right.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: surface.monthOffset += 1
                }
            }
        }

        Row {
            spacing: 2

            Repeater {
                model: surface.weekdayNames

                Text {
                    required property string modelData
                    required property int index
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Theme.accent : Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }
            }
        }

        Grid {
            columns: 7
            columnSpacing: 2
            rowSpacing: 2

            Repeater {
                model: surface.cells

                Item {
                    id: dayCell
                    required property int modelData
                    required property int index
                    readonly property bool present: modelData > 0
                    readonly property bool isToday: present && surface.viewingNow && modelData === surface.today
                    readonly property bool weekend: index % 7 >= 5

                    width: 40
                    height: 32

                    Rectangle {
                        visible: dayCell.isToday
                        anchors.fill: parent
                        radius: 9
                        color: Theme.accent
                    }

                    Text {
                        visible: dayCell.present
                        anchors.centerIn: parent
                        text: String(dayCell.modelData)
                        color: dayCell.isToday ? Theme.background : (dayCell.weekend ? Theme.subtleForeground : Theme.foreground)
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 12
                        font.weight: dayCell.isToday ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }
}
