pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"

PanelWindow {
    id: dock

    required property var outputScreen
    required property var dockController

    readonly property int activationWidth: 700
    // Extra transparent headroom keeps app tooltips inside the Wayland
    // surface instead of clipping them at its top edge.
    readonly property int panelHeight: 128
    readonly property int iconSize: 42
    readonly property var hermesCommand: ["/home/ex1te/.local/bin/hermes", "desktop"]

    property bool revealed: false
    readonly property bool showing: revealed || dockController.dockForcedVisible

    function entryForAppId(appId: string): var {
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry) return entry
        const dash = appId.indexOf("-")
        return dash > 0 ? DesktopEntries.heuristicLookup(appId.slice(0, dash)) : null
    }

    readonly property var items: {
        const windowsById = ({})
        const entriesById = ({})
        const windows = NiriService.windows

        for (let index = 0; index < windows.length; ++index) {
            const window = windows[index]
            const entry = dock.entryForAppId(String(window.app_id || ""))
            if (!entry) continue
            const key = String(entry.id || "")
            if (key === "") continue
            entriesById[key] = entry
            if (!windowsById[key]) windowsById[key] = []
            windowsById[key].push(window)
        }

        for (const key in windowsById)
            windowsById[key].sort((left, right) => right.focus_timestamp - left.focus_timestamp)

        const result = []
        const added = ({})
        const pinned = DockService.pinnedIds

        for (let index = 0; index < pinned.length; ++index) {
            const entry = DesktopEntries.heuristicLookup(String(pinned[index]))
            if (!entry) continue
            const key = String(entry.id || pinned[index])
            if (added[key]) continue
            result.push({
                "entry": entry,
                "id": key,
                "pinId": String(pinned[index]),
                "pinned": true,
                "windows": windowsById[key] || []
            })
            added[key] = true
        }

        const runningIds = Object.keys(windowsById)
        runningIds.sort((left, right) => {
            const leftStamp = windowsById[left][0].focus_timestamp
            const rightStamp = windowsById[right][0].focus_timestamp
            return rightStamp - leftStamp
        })

        for (let index = 0; index < runningIds.length; ++index) {
            const key = runningIds[index]
            if (added[key]) continue
            result.push({
                "entry": entriesById[key],
                "id": key,
                "pinId": key,
                "pinned": false,
                "windows": windowsById[key]
            })
            added[key] = true
        }

        return result
    }

    function iconFor(entry: var): string {
        const name = entry ? String(entry.icon || "") : ""
        return name !== "" ? Quickshell.iconPath(name, true) : ""
    }

    function activate(item: var): void {
        if (!item || !item.entry) return
        if (item.windows.length > 0) {
            NiriService.focusWindow(item.windows[0].id)
        } else {
            const entryId = String(item.entry.id || "").toLowerCase()
            AppUsageService.record(String(item.entry.id || ""))
            if (entryId === "hermes" || entryId === "hermes.desktop")
                Quickshell.execDetached(dock.hermesCommand)
            else
                item.entry.execute()
        }
        dock.revealed = false
    }

    function togglePin(item: var): void {
        if (!item || !item.entry) return
        const id = String(item.pinId || item.id || "")
        if (item.pinned)
            DockService.unpin(id)
        else
            DockService.pin(id)
    }

    screen: outputScreen
    // eDP-1 is the physical bottom edge in both the laptop-only and stacked
    // work layouts. A second dock on HDMI-A-1 would sit on the monitor seam.
    visible: outputScreen.name === "eDP-1"
    implicitWidth: activationWidth
    implicitHeight: panelHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { bottom: true }

    mask: Region {
        x: dock.showing ? Math.floor(card.x - 10) : 0
        y: dock.showing ? 0 : dock.panelHeight - 2
        width: dock.showing ? Math.ceil(card.width + 20) : dock.activationWidth
        height: dock.showing ? dock.panelHeight : 2
    }

    Timer {
        id: revealTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (dockHover.hovered) dock.revealed = true
        }
    }

    Timer {
        id: hideTimer
        interval: 320
        repeat: false
        onTriggered: {
            if (!dockHover.hovered) dock.revealed = false
        }
    }

    HoverHandler {
        id: dockHover
        onHoveredChanged: {
            if (hovered) {
                hideTimer.stop()
                if (!dock.revealed) revealTimer.restart()
            } else {
                revealTimer.stop()
                if (dock.revealed) hideTimer.restart()
            }
        }
    }

    Rectangle {
        id: card

        x: Math.round((dock.width - width) / 2)
        y: dock.showing ? dock.panelHeight - height - 9 : dock.panelHeight + 4
        width: Math.max(74, appRow.width + 20)
        height: 76
        radius: 17
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: dock.showing ? 1 : 0

        Behavior on y {
            NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        Row {
            id: appRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: dock.items

                delegate: Item {
                    id: appItem

                    required property int index
                    required property var modelData

                    readonly property bool running: modelData.windows.length > 0
                    readonly property bool focused: {
                        for (let index = 0; index < modelData.windows.length; ++index) {
                            if (modelData.windows[index].is_focused) return true
                        }
                        return false
                    }
                    readonly property bool firstUnpinned: !modelData.pinned
                        && (appItem.index === 0 || dock.items[appItem.index - 1].pinned)

                    width: 54 + (firstUnpinned ? 11 : 0)
                    height: 64

                    Rectangle {
                        visible: appItem.firstUnpinned
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 34
                        color: Theme.border
                    }

                    Item {
                        id: iconTile
                        x: appItem.firstUnpinned ? 11 : 0
                        width: 54
                        height: 58
                        anchors.verticalCenter: parent.verticalCenter
                        scale: appMouse.containsMouse ? 1.1 : 1
                        y: appMouse.containsMouse ? -2 : 0

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                        Behavior on y {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.centerIn: appIcon
                            width: dock.iconSize + 8
                            height: dock.iconSize + 8
                            radius: 13
                            color: appMouse.containsMouse ? Theme.raisedSurface : "transparent"
                        }

                        Image {
                            id: appIcon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 5
                            width: dock.iconSize
                            height: dock.iconSize
                            source: dock.iconFor(appItem.modelData.entry)
                            sourceSize.width: dock.iconSize * 2
                            sourceSize.height: dock.iconSize * 2
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: appItem.focused ? 13 : (appItem.running ? 5 : 0)
                            height: 2
                            radius: 1
                            color: appItem.focused ? Theme.accent : Theme.subtleForeground
                            opacity: appItem.running ? 1 : 0

                            Behavior on width {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                dock.togglePin(appItem.modelData)
                            else
                                dock.activate(appItem.modelData)
                        }
                    }

                    Rectangle {
                        visible: appMouse.containsMouse
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 6
                        width: appLabel.width + 18
                        height: 26
                        radius: 8
                        color: Theme.raisedSurface
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            id: appLabel
                            anchors.centerIn: parent
                            text: String(appItem.modelData.entry.name || "")
                                + (appItem.modelData.pinned ? " · right-click to unpin" : " · right-click to pin")
                            color: Theme.foreground
                            font.family: "DejaVu Sans"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
