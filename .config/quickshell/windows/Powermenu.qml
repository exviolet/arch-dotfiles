pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../components"

PanelWindow {
    id: powermenu

    required property var outputScreen
    required property var powerController

    readonly property int cardPadding: 22
    readonly property int tileWidth: 128
    readonly property int tileHeight: 116
    readonly property int tileSpacing: 8
    readonly property int headerHeight: 54
    readonly property int cardWidth: PowerService.actions.length * powermenu.tileWidth
        + (PowerService.actions.length - 1) * powermenu.tileSpacing
        + powermenu.cardPadding * 2
    readonly property int cardHeight: powermenu.cardPadding * 2 + powermenu.headerHeight
        + powermenu.tileHeight

    // Shut down leads the list, so the default selection makes the end-of-day
    // case Enter, Enter. See PowerService.actions for the ordering rationale.
    property int selectedIndex: 0
    property bool confirming: false

    readonly property var selectedAction: PowerService.actions[powermenu.selectedIndex] || null

    function move(delta: int): void {
        if (powermenu.confirming) return
        const count = PowerService.actions.length
        powermenu.selectedIndex = Math.max(0, Math.min(count - 1, powermenu.selectedIndex + delta))
    }

    // Confirmation is a state of this card, not a second window: a separate
    // dialog would mean another keyboard-grabbing surface layered over this one.
    function activate(): void {
        const action = powermenu.selectedAction
        if (!action) return

        if (action.confirm && !powermenu.confirming) {
            powermenu.confirming = true
            return
        }

        powermenu.confirming = false
        powermenu.powerController.hidePowermenu()
        PowerService.run(action)
    }

    function cancel(): void {
        if (powermenu.confirming) {
            powermenu.confirming = false
            return
        }
        powermenu.powerController.hidePowermenu()
    }

    onVisibleChanged: {
        if (visible) {
            PowerService.refresh()
            powermenu.selectedIndex = 0
            powermenu.confirming = false
            keyHandler.forceActiveFocus()
        } else {
            powermenu.confirming = false
        }
    }

    screen: outputScreen
    visible: powerController.powermenuVisible
        && (powerController.powermenuScreen === "" || powerController.powermenuScreen === outputScreen.name)
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

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: powermenu.cancel()
        }
    }

    Item {
        id: keyHandler

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: powermenu.cancel()
        Keys.onReturnPressed: powermenu.activate()
        Keys.onEnterPressed: powermenu.activate()
        Keys.onLeftPressed: powermenu.move(-1)
        Keys.onRightPressed: powermenu.move(1)
        Keys.onTabPressed: powermenu.move(1)
        Keys.onBacktabPressed: powermenu.move(-1)

        Rectangle {
            id: card

            anchors.centerIn: parent
            width: powermenu.cardWidth
            height: powermenu.cardHeight
            radius: 14
            color: Theme.background
            border.width: 1
            border.color: powermenu.confirming ? Theme.warningAccent : Theme.border
            antialiasing: true

            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                x: powermenu.cardPadding
                y: powermenu.cardPadding + 2
                width: 3
                height: 26
                radius: 1.5
                color: powermenu.confirming ? Theme.warningAccent : Theme.accent
            }

            Text {
                x: powermenu.cardPadding + 16
                y: powermenu.cardPadding
                text: powermenu.confirming && powermenu.selectedAction
                    ? powermenu.selectedAction.label + "?"
                    : "Goodbye"
                color: Theme.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                x: powermenu.cardPadding + 16
                y: powermenu.cardPadding + 24
                text: powermenu.confirming
                    ? "Enter to confirm · Esc to cancel"
                    : (PowerService.uptime === "" ? "" : "Up " + PowerService.uptime)
                color: powermenu.confirming ? Theme.warningAccent : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }

            Row {
                x: powermenu.cardPadding
                y: powermenu.cardPadding + powermenu.headerHeight
                spacing: powermenu.tileSpacing

                Repeater {
                    model: PowerService.actions

                    delegate: Item {
                        id: tile

                        required property int index
                        required property var modelData

                        readonly property bool active: powermenu.selectedIndex === tile.index
                        // While confirming, everything except the pending
                        // action is dimmed so the card reads as one question.
                        readonly property bool dimmed: powermenu.confirming && !tile.active

                        width: powermenu.tileWidth
                        height: powermenu.tileHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            antialiasing: true
                            color: tile.active
                                ? Theme.raisedSurface
                                : (tileHover.hovered ? Theme.surface : "transparent")
                            border.width: 1
                            border.color: tile.active
                                ? (powermenu.confirming ? Theme.warningAccent : Theme.accent)
                                : "transparent"
                            opacity: tile.dimmed ? 0.35 : 1

                            Behavior on border.color {
                                ColorAnimation { duration: 90 }
                            }
                        }

                        ThemeIcon {
                            y: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 30
                            name: tile.modelData.icon
                            opacity: tile.dimmed ? 0.35 : 1
                            color: {
                                if (tile.active && powermenu.confirming) return Theme.warningAccent
                                if (tile.modelData.id === "shutdown") return Theme.accent
                                return Theme.foreground
                            }
                        }

                        Text {
                            y: 76
                            width: parent.width - 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            color: Theme.foreground
                            opacity: tile.dimmed ? 0.35 : 1
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: "DejaVu Sans"
                            font.pixelSize: 11
                        }

                        HoverHandler {
                            id: tileHover
                        }

                        TapHandler {
                            onTapped: {
                                if (powermenu.confirming && !tile.active) return
                                powermenu.selectedIndex = tile.index
                                powermenu.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
