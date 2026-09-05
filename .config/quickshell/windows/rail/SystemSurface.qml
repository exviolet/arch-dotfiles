pragma ComponentBehavior: Bound

import QtQuick

import "../../services"

Item {
    id: surface

    required property string outputName
    required property string workspaceLabel
    required property bool pinned
    required property bool expanded
    required property bool active

    readonly property int visibleWifiCount: Math.min(4, NetworkService.networks.length)
    readonly property int visibleBluetoothCount: Math.min(3, BluetoothService.devices.length)

    function profileLabel(profile: string): string {
        if (profile === "power-saver") return "SAVER"
        if (profile === "performance") return "PERF"
        return "BALANCED"
    }

    onActiveChanged: NetworkService.setScanningFor(outputName, active)
    Component.onCompleted: NetworkService.setScanningFor(outputName, active)
    Component.onDestruction: {
        NetworkService.setScanningFor(outputName, false)
    }

    SurfaceHeader {
        width: parent.width
        eyebrow: "SYSTEM / " + surface.outputName
        mode: surface.pinned ? "PINNED" : "PREVIEW"
        pinned: surface.pinned
        expanded: surface.expanded
        title: "System controls"
        subtitle: NetworkService.ready
            ? (NetworkService.connectedNetwork ? String(NetworkService.connectedNetwork.name) : "Network disconnected")
            : "Reading system state"
    }

    Flickable {
        x: 22
        y: 146
        width: parent.width - 44
        height: parent.height - 218
        contentHeight: contentColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 10

            Rectangle {
                width: parent.width
                height: 64 + surface.visibleWifiCount * 38
                radius: 12
                color: Theme.raisedSurface
                border.width: 1
                border.color: Theme.border

                Text {
                    x: 14
                    y: 12
                    text: "WI-FI"
                    color: NetworkService.wifiEnabled ? Theme.accent : Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    x: 14
                    y: 31
                    width: parent.width - 84
                    text: NetworkService.wifiEnabled
                        ? (NetworkService.connectedNetwork
                            ? String(NetworkService.connectedNetwork.name) + "  " + NetworkService.signalPercent(NetworkService.connectedNetwork) + "%"
                            : "Not connected")
                        : "Radio disabled"
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 13
                    width: 48
                    height: 28
                    radius: 9
                    color: NetworkService.wifiEnabled ? Theme.accent : Theme.track

                    Text {
                        anchors.centerIn: parent
                        text: NetworkService.wifiEnabled ? "ON" : "OFF"
                        color: NetworkService.wifiEnabled ? "#ffffff" : Theme.subtleForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: NetworkService.wifiHardwareEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NetworkService.toggleWifi()
                    }
                }

                Column {
                    x: 8
                    y: 58
                    width: parent.width - 16

                    Repeater {
                        model: surface.visibleWifiCount

                        Rectangle {
                            required property int index
                            readonly property var network: NetworkService.networks[index]
                            width: parent.width
                            height: 38
                            radius: 9
                            color: network.connected ? Theme.surface : (networkMouse.containsMouse ? Theme.track : "transparent")

                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 70
                                text: String(parent.network.name || "")
                                elide: Text.ElideRight
                                color: parent.network.connected ? Theme.foreground : Theme.mutedForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 11
                                font.weight: parent.network.connected ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.network.connected ? "ACTIVE" : String(NetworkService.signalPercent(parent.network)) + "%"
                                color: parent.network.connected ? Theme.accent : Theme.subtleForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: networkMouse
                                anchors.fill: parent
                                enabled: !parent.network.connected && !parent.network.stateChanging
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: NetworkService.connectNetwork(parent.network)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 64 + surface.visibleBluetoothCount * 38
                radius: 12
                color: "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    x: 14
                    y: 12
                    text: "BLUETOOTH"
                    color: BluetoothService.enabled ? Theme.accent : Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    x: 14
                    y: 31
                    text: BluetoothService.enabled
                        ? (BluetoothService.devices.length > 0 ? "Known devices" : "No known devices")
                        : "Controller disabled"
                    color: Theme.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: 13
                    width: 48
                    height: 28
                    radius: 9
                    color: BluetoothService.enabled ? Theme.accent : Theme.track

                    Text {
                        anchors.centerIn: parent
                        text: BluetoothService.enabled ? "ON" : "OFF"
                        color: BluetoothService.enabled ? "#ffffff" : Theme.subtleForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: BluetoothService.available
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BluetoothService.toggleEnabled()
                    }
                }

                Column {
                    x: 8
                    y: 58
                    width: parent.width - 16

                    Repeater {
                        model: surface.visibleBluetoothCount

                        Rectangle {
                            required property int index
                            readonly property var device: BluetoothService.devices[index]
                            width: parent.width
                            height: 38
                            radius: 9
                            color: device.connected ? Theme.surface : (deviceMouse.containsMouse ? Theme.track : "transparent")

                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 76
                                text: BluetoothService.deviceName(parent.device)
                                elide: Text.ElideRight
                                color: parent.device.connected ? Theme.foreground : Theme.mutedForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 11
                                font.weight: parent.device.connected ? Font.DemiBold : Font.Normal
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: parent.device.connected
                                    ? (BluetoothService.batteryPercent(parent.device) >= 0
                                        ? String(BluetoothService.batteryPercent(parent.device)) + "%"
                                        : "LIVE")
                                    : "CONNECT"
                                color: parent.device.connected ? Theme.accent : Theme.subtleForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                enabled: BluetoothService.enabled
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: BluetoothService.toggleDevice(parent.device)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 98
                radius: 12
                color: "transparent"
                border.width: 1
                border.color: Theme.border

                Text {
                    x: 14
                    y: 12
                    text: "DISPLAY / LAPTOP"
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 11
                    text: BrightnessService.ready ? String(BrightnessService.percent) + "%" : "N/A"
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: brightnessTrack
                    x: 14
                    y: 42
                    width: parent.width - 28
                    height: 8
                    radius: 4
                    color: Theme.track

                    Rectangle {
                        width: parent.width * BrightnessService.value
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent

                        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: BrightnessService.ready
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => BrightnessService.setPercent(Math.round(mouse.x / width * 100), surface.outputName)
                    }
                }

                Row {
                    x: 14
                    y: 62
                    spacing: 8

                    Repeater {
                        model: [-10, -5, 5, 10]

                        Rectangle {
                            required property int modelData
                            width: 48
                            height: 24
                            radius: 8
                            color: stepMouse.containsMouse ? Theme.raisedSurface : Theme.surface
                            border.width: 1
                            border.color: Theme.border

                            Text {
                                anchors.centerIn: parent
                                text: (parent.modelData > 0 ? "+" : "") + String(parent.modelData)
                                color: Theme.foreground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: stepMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BrightnessService.adjust(parent.modelData, surface.outputName)
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 116
                radius: 12
                color: Theme.raisedSurface
                border.width: 1
                border.color: Theme.border

                Text {
                    x: 14
                    y: 12
                    text: "POWER"
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 11
                    text: PowerService.battery.ready ? String(PowerService.batteryPercent) + "%" : "NO BATTERY"
                    color: PowerService.batteryPercent <= 15 ? Theme.warningAccent : Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }

                Text {
                    x: 14
                    y: 34
                    width: parent.width - 28
                    text: PowerService.battery.ready
                        ? ((PowerService.externalPower
                                ? (PowerService.charging ? "Charging" : "Plugged in")
                                : "On battery")
                            + (PowerService.batteryTimeLabel !== "" ? " / " + PowerService.batteryTimeLabel : ""))
                        : "Battery state unavailable"
                    color: Theme.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                }

                Row {
                    x: 14
                    y: 66
                    spacing: 6

                    Repeater {
                        model: PowerService.profiles

                        Rectangle {
                            required property string modelData
                            readonly property bool active: modelData === PowerService.profile
                            width: modelData === "balanced" ? 82 : 70
                            height: 32
                            radius: 9
                            color: active ? Theme.accent : (profileMouse.containsMouse ? Theme.surface : Theme.track)

                            Text {
                                anchors.centerIn: parent
                                text: surface.profileLabel(parent.modelData)
                                color: parent.active ? "#ffffff" : Theme.mutedForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: profileMouse
                                anchors.fill: parent
                                enabled: !parent.active
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: PowerService.setProfile(parent.modelData)
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: visible ? 24 : 0
                visible: NetworkService.statusMessage !== "" || BluetoothService.statusMessage !== ""
                text: NetworkService.statusMessage !== "" ? NetworkService.statusMessage : BluetoothService.statusMessage
                horizontalAlignment: Text.AlignHCenter
                color: Theme.warningAccent
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }
        }
    }
}
