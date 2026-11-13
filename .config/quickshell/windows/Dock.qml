pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"

PanelWindow {
    id: dock

    required property var outputScreen
    required property var dockController
    property var railWindow: null

    readonly property string edge: PanelPlacement.edgeFor("dock", outputScreen.name)
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool farEdge: edge === "right" || edge === "bottom"
    readonly property int screenLength: vertical ? outputScreen.height : outputScreen.width
    readonly property int activationLength: Math.min(screenLength, 700)
    readonly property int panelDepth: vertical ? 300 : 128
    readonly property int cardThickness: 76
    readonly property int tileLength: vertical ? 64 : 54
    readonly property int iconSize: 42
    readonly property var hermesCommand: ["/home/ex1te/.local/bin/hermes", "desktop"]
    readonly property int cardLength: Math.max(0, Math.min(screenLength - 20,
        Math.max(74, items.length * (tileLength + 4) + 16 + (items.some(item => !item.pinned) ? 11 : 0))))
    readonly property int windowLength: Math.min(screenLength, Math.max(activationLength, cardLength + 20))
    readonly property bool sharedEdge: railWindow !== null && railWindow.visible && railWindow.edge === edge
    readonly property int inset: sharedEdge ? PanelPlacement.railThickness : 0
    readonly property bool blockedByRail: sharedEdge
        && (railWindow.expanded || railWindow.revealProgress > 0)
        && railWindow.drawerStart < (screenLength + cardLength) / 2 + 10
        && railWindow.drawerStart + railWindow.drawerLength > (screenLength - cardLength) / 2 - 10

    property bool revealed: false
    property Item hoveredApp: null
    readonly property bool showing: revealed || dockController.dockForcedVisible
    readonly property int inputLength: showing ? Math.min(windowLength, cardLength + 20) : activationLength
    readonly property int inputDepth: showing ? cardThickness + 12 : 2

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
    visible: edge !== "" && !blockedByRail
    implicitWidth: vertical ? panelDepth : windowLength
    implicitHeight: vertical ? windowLength : panelDepth
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        left: dock.edge === "left"
        right: dock.edge === "right"
        top: dock.edge === "top"
        bottom: dock.edge === "bottom"
    }

    margins {
        left: dock.edge === "left" ? dock.inset : 0
        right: dock.edge === "right" ? dock.inset : 0
        top: dock.edge === "top" ? dock.inset : 0
        bottom: dock.edge === "bottom" ? dock.inset : 0
    }

    mask: Region {
        x: dock.vertical ? (dock.farEdge ? dock.width - dock.inputDepth : 0)
            : Math.floor((dock.width - dock.inputLength) / 2)
        y: dock.vertical ? Math.floor((dock.height - dock.inputLength) / 2)
            : (dock.farEdge ? dock.height - dock.inputDepth : 0)
        width: dock.vertical ? dock.inputDepth : dock.inputLength
        height: dock.vertical ? dock.inputLength : dock.inputDepth
    }

    onVisibleChanged: {
        if (visible) return
        dock.revealed = false
        dock.hoveredApp = null
        revealTimer.stop()
        hideTimer.stop()
    }

    Timer {
        id: revealTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (dockHover.hovered && dock.visible) dock.revealed = true
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

        property real edgeOffset: dock.showing
            ? (dock.farEdge ? dock.panelDepth - dock.cardThickness - 9 : 9)
            : (dock.farEdge ? dock.panelDepth + 4 : -dock.cardThickness - 4)

        x: dock.vertical ? edgeOffset : Math.round((dock.width - width) / 2)
        y: dock.vertical ? Math.round((dock.height - height) / 2) : edgeOffset
        width: dock.vertical ? dock.cardThickness : dock.cardLength
        height: dock.vertical ? dock.cardLength : dock.cardThickness
        radius: 17
        color: Theme.background
        border.width: 1
        border.color: Theme.border
        opacity: dock.showing ? 1 : 0

        Behavior on edgeOffset {
            NumberAnimation { duration: 210; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        ListView {
            id: appList

            anchors.centerIn: parent
            width: dock.vertical ? 64 : Math.max(0, card.width - 20)
            height: dock.vertical ? Math.max(0, card.height - 20) : 64
            orientation: dock.vertical ? ListView.Vertical : ListView.Horizontal
            model: dock.items
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: appItem

                required property int index
                required property var modelData

                readonly property bool running: modelData.windows.length > 0
                readonly property bool focused: modelData.windows.some(window => window.is_focused)
                readonly property bool firstUnpinned: !modelData.pinned
                    && (appItem.index === 0 || dock.items[appItem.index - 1]?.pinned)
                readonly property int separatorSpace: firstUnpinned ? 11 : 0
                readonly property string hint: String(modelData.entry.name || "")
                    + (modelData.pinned ? " · ПКМ — открепить" : " · ПКМ — закрепить")

                width: dock.vertical ? 64 : dock.tileLength + separatorSpace
                height: dock.vertical ? dock.tileLength + separatorSpace : 64

                Rectangle {
                    visible: appItem.firstUnpinned
                    x: dock.vertical ? (parent.width - width) / 2 : 2
                    y: dock.vertical ? 2 : (parent.height - height) / 2
                    width: dock.vertical ? 34 : 1
                    height: dock.vertical ? 1 : 34
                    color: Theme.border
                }

                Item {
                    id: iconTile

                    x: dock.vertical ? (parent.width - width) / 2 : appItem.separatorSpace
                    y: (parent.height - height + (dock.vertical ? appItem.separatorSpace : 0)) / 2
                    width: 54
                    height: 58
                    scale: appMouse.containsMouse ? 1.1 : 1

                    Behavior on scale {
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
                    onContainsMouseChanged: {
                        if (containsMouse) dock.hoveredApp = appItem
                        else if (dock.hoveredApp === appItem) dock.hoveredApp = null
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            dock.togglePin(appItem.modelData)
                        else
                            dock.activate(appItem.modelData)
                    }
                }
            }
        }
    }

    Rectangle {
        id: tooltip

        readonly property real appCenter: {
            const app = dock.hoveredApp
            if (!app) return 0
            return dock.vertical ? card.y + appList.y + app.y - appList.contentY + app.height / 2
                : card.x + appList.x + app.x - appList.contentX + app.width / 2
        }

        visible: dock.showing && dock.hoveredApp !== null
        x: dock.vertical ? (dock.farEdge ? card.x - width - 6 : card.x + card.width + 6)
            : Math.max(4, Math.min(dock.width - width - 4, appCenter - width / 2))
        y: dock.vertical ? Math.max(4, Math.min(dock.height - height - 4, appCenter - height / 2))
            : (dock.farEdge ? card.y - height - 6 : card.y + card.height + 6)
        width: Math.max(0, Math.min(label.implicitWidth + 18,
            dock.vertical ? dock.panelDepth - dock.cardThickness - 20 : dock.width - 8))
        height: 26
        radius: 8
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

        Text {
            id: label

            anchors.centerIn: parent
            width: Math.max(0, parent.width - 18)
            text: dock.hoveredApp?.hint ?? ""
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: "DejaVu Sans"
            font.pixelSize: 11
        }
    }
}
