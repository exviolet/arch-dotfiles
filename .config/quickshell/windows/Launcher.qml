pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"

PanelWindow {
    id: launcher

    required property var outputScreen
    required property var launcherController

    readonly property int columns: 5
    readonly property int rows: 4
    readonly property int cellWidth: 193
    readonly property int cellHeight: 112
    readonly property int cardPadding: 16
    readonly property int queryHeight: 52
    readonly property int cardWidth: columns * cellWidth + cardPadding * 2
    readonly property int cardHeight: cardPadding * 2 + queryHeight + 12 + rows * cellHeight

    property string query: ""
    property int selectedIndex: 0

    readonly property var results: {
        const entries = DesktopEntries.applications.values
        const needle = launcher.query.trim().toLowerCase()
        const matches = []

        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index]
            if (entry.noDisplay) continue

            const name = String(entry.name || "")
            if (needle === "") {
                matches.push({ "entry": entry, "rank": 2, "name": name })
                continue
            }

            const rank = launcher.rankEntry(entry, name, needle)
            if (rank >= 0) matches.push({ "entry": entry, "rank": rank, "name": name })
        }

        matches.sort((left, right) => {
            if (left.rank !== right.rank) return left.rank - right.rank
            return left.name.localeCompare(right.name)
        })

        return matches.map(match => match.entry)
    }

    // 0 = name starts with the query, 1 = name contains it, 2 = only metadata
    // matches. -1 means no match at all.
    function rankEntry(entry: var, name: string, needle: string): int {
        const lowered = name.toLowerCase()
        if (lowered.startsWith(needle)) return 0
        if (lowered.indexOf(needle) !== -1) return 1

        const haystack = [
            String(entry.genericName || ""),
            String(entry.comment || ""),
            (entry.keywords || []).join(" ")
        ].join(" ").toLowerCase()

        return haystack.indexOf(needle) !== -1 ? 2 : -1
    }

    function iconFor(entry: var): string {
        const name = String(entry.icon || "")
        return name !== "" ? Quickshell.iconPath(name, true) : ""
    }

    function moveSelection(delta: int): void {
        if (launcher.results.length === 0) return
        const next = launcher.selectedIndex + delta
        if (next < 0 || next >= launcher.results.length) return
        launcher.selectedIndex = next
        grid.positionViewAtIndex(next, GridView.Contain)
    }

    function activateSelected(): void {
        const entry = launcher.results[launcher.selectedIndex]
        if (!entry) return
        entry.execute()
        launcher.launcherController.hideLauncher()
    }

    onResultsChanged: {
        launcher.selectedIndex = 0
        grid.positionViewAtBeginning()
    }

    onVisibleChanged: {
        if (visible) {
            queryInput.forceActiveFocus()
        } else {
            queryInput.clear()
            launcher.selectedIndex = 0
        }
    }

    screen: outputScreen
    visible: launcherController.launcherVisible
        && (launcherController.launcherScreen === "" || launcherController.launcherScreen === outputScreen.name)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    updatesEnabled: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Backdrop. Clicking anywhere outside the card dismisses the launcher.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.launcherController.hideLauncher()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: launcher.cardWidth
        height: launcher.cardHeight
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        // Swallow clicks so they do not reach the dismissing backdrop.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: queryField

            x: launcher.cardPadding
            y: launcher.cardPadding
            width: parent.width - launcher.cardPadding * 2
            height: launcher.queryHeight
            radius: 10
            color: Theme.surface
            border.width: 1
            border.color: queryInput.activeFocus ? Theme.accent : Theme.border

            Rectangle {
                width: 3
                height: 20
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                radius: 1.5
                color: Theme.accent
            }

            TextInput {
                id: queryInput

                x: 30
                width: parent.width - 118
                anchors.verticalCenter: parent.verticalCenter
                // Deliberately not bound to launcher.query: typing assigns
                // text directly and would break the binding. The query is a
                // one-way mirror of this field, cleared on hide.
                color: Theme.foreground
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                font.family: "DejaVu Sans"
                font.pixelSize: 15
                clip: true

                onTextChanged: launcher.query = text

                Text {
                    anchors.fill: parent
                    visible: queryInput.text === ""
                    text: "Search applications"
                    color: Theme.subtleForeground
                    font: queryInput.font
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onEscapePressed: launcher.launcherController.hideLauncher()
                Keys.onReturnPressed: launcher.activateSelected()
                Keys.onEnterPressed: launcher.activateSelected()
                Keys.onUpPressed: launcher.moveSelection(-launcher.columns)
                Keys.onDownPressed: launcher.moveSelection(launcher.columns)
                Keys.onLeftPressed: launcher.moveSelection(-1)
                Keys.onRightPressed: launcher.moveSelection(1)
                Keys.onTabPressed: launcher.moveSelection(1)
                Keys.onBacktabPressed: launcher.moveSelection(-1)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - width - 14
                text: launcher.results.length === 0 ? "no matches" : String(launcher.results.length)
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }
        }

        GridView {
            id: grid

            x: launcher.cardPadding
            y: queryField.y + queryField.height + 12
            width: parent.width - launcher.cardPadding * 2
            height: launcher.rows * launcher.cellHeight
            cellWidth: launcher.cellWidth
            cellHeight: launcher.cellHeight
            model: launcher.results
            currentIndex: launcher.selectedIndex
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: appCell

                required property int index
                required property var modelData

                width: launcher.cellWidth
                height: launcher.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 10
                    color: appCell.index === launcher.selectedIndex
                        ? Theme.raisedSurface
                        : (cellHover.hovered ? Theme.surface : "transparent")
                    border.width: appCell.index === launcher.selectedIndex ? 1 : 0
                    border.color: Theme.accent

                    Behavior on color {
                        ColorAnimation { duration: 90 }
                    }
                }

                Image {
                    id: appIcon

                    y: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    sourceSize.width: 48
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectFit
                    source: launcher.iconFor(appCell.modelData)
                    visible: source !== ""
                }

                Text {
                    y: 70
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(appCell.modelData.name || "")
                    color: Theme.foreground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                    font.weight: appCell.index === launcher.selectedIndex ? Font.DemiBold : Font.Normal
                }

                Text {
                    y: 86
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(appCell.modelData.genericName || "")
                    visible: text !== ""
                    color: Theme.subtleForeground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "DejaVu Sans"
                    font.pixelSize: 9
                }

                HoverHandler {
                    id: cellHover
                }

                TapHandler {
                    onTapped: {
                        launcher.selectedIndex = appCell.index
                        launcher.activateSelected()
                    }
                }
            }
        }
    }
}
