import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: rail

    required property var outputScreen
    required property var niriState
    required property bool shellDark
    required property bool railEnabled

    readonly property color background: shellDark ? "#171817" : "#f4f2ee"
    readonly property color surface: shellDark ? "#222321" : "#e9e6df"
    readonly property color foreground: shellDark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: shellDark ? "#8f918b" : "#6e706a"
    readonly property color border: shellDark ? "#343633" : "#d6d3cc"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property var screenWorkspaces: niriState.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercentage: battery.ready ? Math.round(battery.percentage) : 0
    readonly property bool charging: battery.ready && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)

    screen: outputScreen
    visible: railEnabled
    implicitWidth: 46
    color: background
    exclusionMode: ExclusionMode.Auto
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        left: true
        top: true
        bottom: true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process { id: workspaceAction }
    Process { id: rendererAction }

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

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: rail.border
    }

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
                    width: modelData
                    height: 2
                    radius: 1
                    color: rail.niriState.ready ? rail.accent : rail.warningAccent
                    opacity: rail.niriState.connected ? 1 : 0.45

                    Behavior on width {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rendererAction.exec(["/home/ex1te/.config/quickshell/scripts/sidecarctl", "renderer"])
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
                    font.family: "GeistMono Nerd Font"
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
            font.family: "GeistMono Nerd Font"
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
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Item { width: 1; height: 7 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dd")
            color: rail.mutedForeground
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
            color: rail.mutedForeground
            font.family: "IBM Plex Sans"
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
            font.family: "GeistMono Nerd Font"
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
