import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: rail

    required property var outputScreen
    required property var niriState
    required property var railController
    required property bool shellDark
    required property bool railEnabled

    readonly property int compactWidth: 46
    readonly property int drawerWidth: 304
    readonly property bool externallyPinned: railController.railPinned && railController.railExpansionScreen === outputScreen.name
    readonly property bool previewing: railController.railPreviewScreen === outputScreen.name
    readonly property bool expanded: externallyPinned || previewing
    property real revealProgress: expanded ? 1 : 0
    readonly property real interactiveWidth: compactWidth + drawerWidth * revealProgress

    readonly property color background: shellDark ? "#171817" : "#f4f2ee"
    readonly property color surface: shellDark ? "#222321" : "#e9e6df"
    readonly property color raisedSurface: shellDark ? "#292a28" : "#dfdcd5"
    readonly property color foreground: shellDark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: shellDark ? "#8f918b" : "#6e706a"
    readonly property color border: shellDark ? "#343633" : "#d6d3cc"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property var screenWorkspaces: niriState.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercentage: battery.ready ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery.ready && battery.state === UPowerDeviceState.Charging

    screen: outputScreen
    visible: railEnabled
    implicitWidth: compactWidth + drawerWidth
    color: "transparent"
    exclusiveZone: compactWidth
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        width: Math.ceil(rail.interactiveWidth)
        height: rail.height
    }

    anchors {
        left: true
        top: true
        bottom: true
    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: 230
            easing.type: Easing.OutCubic
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process { id: workspaceAction }
    Process { id: rendererAction }

    Timer {
        id: previewTimer
        interval: 130
        repeat: false
        onTriggered: {
            if (!rail.externallyPinned && railHover.hovered)
                rail.railController.setRailPreview(rail.outputScreen.name, true)
        }
    }

    Timer {
        id: collapseTimer
        interval: 260
        repeat: false
        onTriggered: {
            if (!rail.externallyPinned && !railHover.hovered)
                rail.railController.setRailPreview(rail.outputScreen.name, false)
        }
    }

    HoverHandler {
        id: railHover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                if (!rail.expanded) previewTimer.restart()
            } else {
                previewTimer.stop()
                if (!rail.externallyPinned) collapseTimer.restart()
            }
        }
    }

    function focusWorkspace(output: string, index: int): void {
        workspaceAction.exec([
            "/usr/sbin/bash",
            "-c",
            "/usr/sbin/niri msg action focus-monitor \"$1\" && /usr/sbin/niri msg action focus-workspace \"$2\"",
            "quickshell-rail",
            output,
            String(index)
        ])
    }

    function focusedWorkspaceLabel(): string {
        for (let index = 0; index < screenWorkspaces.length; ++index) {
            const workspace = screenWorkspaces[index]
            if (workspace.is_focused)
                return workspace.name !== "" ? workspace.name : String(workspace.idx)
        }
        return "—"
    }

    Rectangle {
        id: drawer
        x: rail.compactWidth
        width: rail.drawerWidth * rail.revealProgress
        height: parent.height
        color: rail.surface
        clip: true

        Item {
            id: drawerContent
            width: rail.drawerWidth
            height: parent.height
            x: rail.expanded ? 0 : -14
            opacity: rail.revealProgress

            Behavior on x {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 155; easing.type: Easing.OutCubic }
            }

            Text {
                id: drawerEyebrow
                x: 22
                y: 22
                text: "RAIL / " + rail.outputScreen.name
                color: rail.accent
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }

            Text {
                id: drawerMode
                anchors.right: parent.right
                anchors.rightMargin: 22
                y: 22
                text: rail.externallyPinned ? "PINNED" : "PREVIEW"
                color: rail.externallyPinned ? rail.foreground : rail.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Rectangle {
                x: 22
                y: 45
                width: rail.expanded ? 92 : 18
                height: 2
                radius: 1
                color: rail.accent

                Behavior on width {
                    NumberAnimation { duration: 310; easing.type: Easing.OutCubic }
                }
            }

            Text {
                x: 22
                y: 74
                text: "Open state"
                color: rail.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }

            Text {
                x: 22
                y: 108
                width: parent.width - 44
                text: rail.externallyPinned ? "The rail stays open." : "Move across the surface."
                color: rail.mutedForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }

            Column {
                x: 22
                y: 164
                width: parent.width - 44
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 12
                    color: rail.raisedSurface
                    border.width: 1
                    border.color: rail.border

                    Text {
                        x: 14
                        y: 12
                        text: "NIRI"
                        color: rail.niriState.ready ? rail.accent : rail.warningAccent
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Text {
                        x: 14
                        y: 30
                        text: rail.niriState.ready ? "Event stream connected" : "Waiting for compositor"
                        color: rail.foreground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 21
                        text: rail.focusedWorkspaceLabel()
                        color: rail.foreground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 12
                    color: "transparent"
                    border.width: 1
                    border.color: rail.border

                    Text {
                        x: 14
                        y: 12
                        text: "MOTION"
                        color: rail.mutedForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Text {
                        x: 14
                        y: 30
                        text: rail.externallyPinned ? "Click signal to release" : "Click signal to keep open"
                        color: rail.foreground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 12
                    }
                }
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 24
                height: 48

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: rail.border

                    Rectangle {
                        width: 24
                        height: 1
                        color: rail.accent
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: rail.externallyPinned ? "CLICK TO CLOSE" : "LEAVE TO COLLAPSE"
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: String(Math.round(rail.interactiveWidth)) + " PX"
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }
            }
        }
    }

    Rectangle {
        id: railBase
        x: 0
        width: rail.compactWidth
        height: parent.height
        color: rail.background

        Item {
            id: signal
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 30
            height: 38

            Column {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [14, 22, 9]

                    Rectangle {
                        required property int modelData
                        width: rail.expanded ? modelData + 3 : modelData
                        height: 2
                        radius: 1
                        color: rail.niriState.ready ? rail.accent : rail.warningAccent
                        opacity: rail.niriState.connected ? 1 : 0.45

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        rendererAction.exec(["/home/ex1te/.config/quickshell/scripts/sidecarctl", "renderer"])
                    } else {
                        rail.railController.setRailPreview(rail.outputScreen.name, false)
                        rail.railController.toggleRailFor(rail.outputScreen.name)
                    }
                }
            }
        }

        Rectangle {
            id: upperRule
            anchors.top: signal.bottom
            anchors.topMargin: 9
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 1
            color: rail.border

            Rectangle {
                anchors.left: parent.left
                width: 6
                height: 1
                color: rail.accent
            }
        }

        Column {
            id: workspaceColumn
            anchors.top: upperRule.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: rail.screenWorkspaces

                Item {
                    id: workspaceItem
                    required property var modelData
                    width: 32
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: workspaceItem.modelData.is_active ? rail.surface : "transparent"
                        border.width: workspaceItem.modelData.is_active ? 1 : 0
                        border.color: rail.border
                        scale: workspaceMouse.containsMouse ? 1.06 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: workspaceItem.modelData.is_focused ? 15 : (workspaceItem.modelData.is_urgent ? 8 : 0)
                        radius: 1
                        color: workspaceItem.modelData.is_urgent ? rail.warningAccent : rail.accent

                        Behavior on height {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: workspaceItem.modelData.name !== "" ? workspaceItem.modelData.name.slice(0, 2) : String(workspaceItem.modelData.idx)
                        color: workspaceItem.modelData.is_active ? rail.foreground : rail.mutedForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 11
                        font.weight: workspaceItem.modelData.is_active ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.focusWorkspace(rail.outputScreen.name, workspaceItem.modelData.idx)
                    }
                }
            }
        }

        Column {
            id: clockColumn
            anchors.centerIn: parent
            spacing: -1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: 1
                color: rail.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Item { width: 1; height: 7 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dd")
                color: rail.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                color: rail.mutedForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Column {
            id: batteryBlock
            visible: rail.battery.ready
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String(rail.batteryPercentage)
                color: rail.batteryPercentage <= 15 ? rail.warningAccent : rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 25
                radius: 2
                color: rail.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(2, parent.height * Math.min(1, rail.batteryPercentage / 100))
                    radius: 2
                    color: rail.batteryPercentage <= 15 ? rail.warningAccent : rail.foreground

                    Behavior on height {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                visible: rail.charging
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: 2
                radius: 1
                color: rail.accent
            }
        }
    }

    Rectangle {
        x: Math.max(rail.compactWidth - 1, rail.interactiveWidth - 1)
        width: 1
        height: parent.height
        color: rail.border
    }
}
