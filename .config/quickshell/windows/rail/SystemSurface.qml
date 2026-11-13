pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import "../../services"

Item {
    id: surface

    required property string outputName
    required property string workspaceLabel
    required property bool pinned
    required property bool expanded
    required property bool active
    signal networkSettingsRequested()

    property bool compact: false
    property string section: ""
    readonly property bool wifiExpanded: section === "wifi"
    readonly property bool bluetoothExpanded: section === "bluetooth"
    readonly property bool scanning: active && wifiExpanded
    readonly property string scannerId: outputName + (compact ? ":island" : "")
    readonly property var connectedBluetooth: BluetoothService.devices.find(device => device.connected)
    implicitHeight: contentColumn.implicitHeight + (compact ? 14 : 170)

    readonly property int visibleBluetoothCount: Math.min(3, BluetoothService.devices.length)

    function measurement(value: var, unit: string): string {
        return value === undefined ? "—" : Math.round(value) + unit
    }

    function traffic(value: var, suffix: string): string {
        if (value === undefined) return "—"
        const units = ["Б", "КиБ", "МиБ", "ГиБ", "ТиБ"]
        let index = 0
        while (value >= 1024 && index < units.length - 1) {
            value /= 1024
            ++index
        }
        return value.toLocaleString(Qt.locale(), "f", index === 0 ? 0 : 1) + " " + units[index] + suffix
    }

    function profileLabel(profile: string): string {
        if (profile === "power-saver") return "SAVER"
        if (profile === "performance") return "PERF"
        return "BALANCED"
    }

    onScanningChanged: NetworkService.setScanningFor(scannerId, scanning)
    onActiveChanged: {
        section = active && NetworkService.speedTestRunning ? "wifi" : ""
        if (active) settingsScroll.contentY = 0
    }
    Component.onCompleted: NetworkService.setScanningFor(scannerId, scanning)
    Component.onDestruction: NetworkService.setScanningFor(scannerId, false)

    Connections {
        target: NetworkService
        function onSpeedTestRunningChanged(): void {
            if (surface.active && NetworkService.speedTestRunning) {
                surface.section = "wifi"
                settingsScroll.contentY = 0
            }
        }
    }

    SurfaceHeader {
        visible: !surface.compact
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
        id: settingsScroll
        x: surface.compact ? 14 : 22
        y: surface.compact ? 0 : 146
        width: Math.max(0, parent.width - x * 2)
        height: Math.max(0, parent.height - y - (surface.compact ? 12 : 24))
        contentWidth: width
        contentHeight: contentColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn
            width: parent.width
            spacing: 10

            Rectangle {
                width: parent.width
                height: surface.wifiExpanded ? wifiDetails.y + wifiDetails.height + 10 : 60
                radius: 12
                color: Theme.raisedSurface
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    id: wifiHeader
                    width: parent.width - 72
                    height: 60
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: "Wi-Fi"
                    Accessible.onPressAction: toggle()
                    activeFocusOnTab: true
                    Keys.onReturnPressed: toggle()
                    Keys.onSpacePressed: toggle()
                    onClicked: toggle()

                    function toggle(): void {
                        surface.section = surface.wifiExpanded ? "" : "wifi"
                    }
                }

                Text {
                    x: 14
                    y: 11
                    width: wifiHeader.width - 28
                    text: NetworkService.connectedNetwork?.name ?? "Wi-Fi"
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    x: 14
                    y: 33
                    width: wifiHeader.width - 28
                    text: {
                        const network = NetworkService.connectedNetwork
                        if (network) return "Wi-Fi · " + NetworkService.signalPercent(network)
                            + "% · " + NetworkService.wifiSecurity(network)
                        return NetworkService.wifiEnabled ? "Нет подключения" : "Wi-Fi выключен"
                    }
                    elide: Text.ElideRight
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: wifiToggle.left
                    anchors.rightMargin: 8
                    y: 18
                    text: surface.wifiExpanded ? "⌄" : "›"
                    color: wifiHeader.activeFocus ? Theme.foreground : Theme.subtleForeground
                    font.pixelSize: 15
                }

                RadioSwitch {
                    id: wifiToggle
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: (60 - height) / 2
                    label: "Wi-Fi"
                    checked: NetworkService.wifiEnabled
                    enabled: NetworkService.wifiHardwareEnabled
                    onToggled: NetworkService.toggleWifi()
                }

                Column {
                    id: wifiDetails
                    x: 12
                    y: 59
                    width: parent.width - 24
                    spacing: 8
                    visible: surface.wifiExpanded

                    Grid {
                        id: wifiMetrics
                        width: parent.width
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 5
                        visible: NetworkService.connectedNetwork !== null

                        Repeater {
                            model: {
                                const info = NetworkService.wifiStatus
                                return [
                                    ["Пинг", surface.measurement(info.latency, " мс")],
                                    ["Потери", surface.measurement(info.loss, "%")],
                                    ["Приём", surface.traffic(info.down, "/с")],
                                    ["Отдача", surface.traffic(info.up, "/с")],
                                    ["Принято", surface.traffic(info.rx, "")],
                                    ["Отдано", surface.traffic(info.tx, "")],
                                    ["IP-адрес", info.address || "—"],
                                    ["Шлюз", info.gateway || "—"]
                                ]
                            }

                            Item {
                                id: metric
                                required property var modelData
                                width: (wifiMetrics.width - wifiMetrics.columnSpacing) / 2
                                height: 15

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: metricValue.left
                                    anchors.rightMargin: 4
                                    text: metric.modelData[0]
                                    elide: Text.ElideRight
                                    color: Theme.subtleForeground
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 10
                                }

                                Text {
                                    id: metricValue
                                    anchors.right: parent.right
                                    width: Math.min(implicitWidth, parent.width * 0.66)
                                    text: metric.modelData[1]
                                    elide: Text.ElideRight
                                    color: Theme.foreground
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        visible: wifiMetrics.visible
                        color: Theme.border
                    }

                    Rectangle {
                        width: parent.width
                        height: speedTestContent.implicitHeight + 24
                        radius: 12
                        color: Theme.surface

                        Column {
                            id: speedTestContent
                            x: 14
                            y: 12
                            width: parent.width - 28
                            spacing: 8

                            Item {
                                width: parent.width
                                height: 28

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: speedTestButton.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "INTERNET SPEED"
                                    elide: Text.ElideRight
                                    color: Theme.subtleForeground
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1
                                }

                                Rectangle {
                                    id: speedTestButton
                                    anchors.right: parent.right
                                    width: speedTestButtonLabel.implicitWidth + 20
                                    height: parent.height
                                    radius: 9
                                    color: speedTestMouse.containsMouse && speedTestMouse.enabled ? Theme.surface : Theme.track

                                    Text {
                                        id: speedTestButtonLabel
                                        anchors.centerIn: parent
                                        text: NetworkService.speedTestRunning ? "Testing…" : "Run test"
                                        color: NetworkService.speedTestRunning ? Theme.mutedForeground : Theme.foreground
                                        font.family: "DejaVu Sans"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: speedTestMouse
                                        anchors.fill: parent
                                        enabled: !NetworkService.speedTestRunning
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: NetworkService.startSpeedTest()
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                visible: NetworkService.speedTestResult !== null
                                spacing: 6

                                Repeater {
                                    model: NetworkService.speedTestResult ? [
                                        { "label": "Download", "value": NetworkService.speedTestResult.downloadMbps, "unit": "Mbps" },
                                        { "label": "Upload", "value": NetworkService.speedTestResult.uploadMbps, "unit": "Mbps" },
                                        { "label": "Latency", "value": NetworkService.speedTestResult.latencyMs, "unit": "ms" }
                                    ] : []

                                    Column {
                                        required property var modelData
                                        width: (parent.width - 12) / 3
                                        spacing: 3

                                        Text {
                                            text: parent.modelData.label
                                            color: Theme.subtleForeground
                                            font.family: "DejaVu Sans"
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            width: parent.width
                                            text: parent.modelData.value === null ? "—"
                                                : parent.modelData.value.toLocaleString(Qt.locale(), "f", 1) + " " + parent.modelData.unit
                                            elide: Text.ElideRight
                                            color: Theme.foreground
                                            font.family: "DejaVu Sans Mono"
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                visible: NetworkService.speedTestResult !== null
                                text: visible ? "Last test · " + Qt.formatDateTime(NetworkService.speedTestResult.measuredAt, "d MMM, HH:mm") : ""
                                color: Theme.subtleForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 10
                            }

                            Text {
                                width: parent.width
                                visible: NetworkService.speedTestError !== ""
                                text: NetworkService.speedTestError
                                wrapMode: Text.WordWrap
                                color: Theme.warningAccent
                                font.family: "DejaVu Sans"
                                font.pixelSize: 11
                            }
                        }
                    }

                    WifiGroup {
                        width: parent.width
                        title: "Известные сети"
                        networks: surface.wifiExpanded && NetworkService.wifiEnabled
                            ? NetworkService.networks.filter(network => network.known || network.connected) : []
                    }

                    WifiGroup {
                        width: parent.width
                        title: "Доступные сети"
                        networks: surface.wifiExpanded && NetworkService.wifiEnabled
                            ? NetworkService.networks.filter(network => !network.known && !network.connected) : []
                    }

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 6
                        color: networkSettingsMouse.containsMouse || networkSettingsMouse.activeFocus
                            ? Theme.surface : "transparent"

                        Text {
                            x: 5
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Настройки сети…"
                            color: Theme.foreground
                            font.family: "DejaVu Sans"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: networkSettingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: "Настройки сети"
                            Accessible.onPressAction: openEditor()
                            activeFocusOnTab: true
                            Keys.onReturnPressed: openEditor()
                            Keys.onSpacePressed: openEditor()
                            onClicked: openEditor()

                            function openEditor(): void {
                                surface.networkSettingsRequested()
                                Quickshell.execDetached(["nm-connection-editor"])
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: surface.bluetoothExpanded ? bluetoothDetails.y + bluetoothDetails.height + 8 : 57
                radius: 12
                color: "transparent"
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    id: bluetoothHeader
                    x: 0
                    y: 0
                    width: parent.width - 70
                    height: 56
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: "Bluetooth"
                    Accessible.onPressAction: toggle()
                    activeFocusOnTab: true
                    Keys.onReturnPressed: toggle()
                    Keys.onSpacePressed: toggle()
                    onClicked: toggle()

                    function toggle(): void {
                        surface.section = surface.bluetoothExpanded ? "" : "bluetooth"
                    }
                }

                Text {
                    x: 14
                    y: 12
                    text: "BLUETOOTH"
                    color: bluetoothHeader.activeFocus ? Theme.foreground
                        : BluetoothService.enabled ? Theme.accent : Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Text {
                    x: 14
                    y: 31
                    width: parent.width - 105
                    text: BluetoothService.enabled
                        ? (surface.connectedBluetooth ? BluetoothService.deviceName(surface.connectedBluetooth) : "Not connected")
                        : "Controller disabled"
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                }

                Text {
                    anchors.right: bluetoothToggle.left
                    anchors.rightMargin: 8
                    y: 18
                    text: surface.bluetoothExpanded ? "⌄" : "›"
                    color: Theme.subtleForeground
                    font.pixelSize: 15
                }

                RadioSwitch {
                    id: bluetoothToggle
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    y: (57 - height) / 2
                    label: "Bluetooth"
                    checked: BluetoothService.enabled
                    enabled: BluetoothService.available
                    onToggled: BluetoothService.toggleEnabled()
                }

                Column {
                    id: bluetoothDetails
                    x: 8
                    y: 57
                    width: parent.width - 16
                    visible: surface.bluetoothExpanded

                    Repeater {
                        model: surface.bluetoothExpanded ? surface.visibleBluetoothCount : 0

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

            SettingsSlider {
                width: parent.width
                label: "Volume"
                available: AudioService.sinkReady
                level: AudioService.volumePercent
                maximum: Math.round(AudioService.maxVolume * 100)
                onRequested: level => AudioService.setVolume(level / 100)
            }

            SettingsSlider {
                width: parent.width
                label: "Brightness"
                available: BrightnessService.ready
                level: BrightnessService.percent
                onRequested: level => BrightnessService.setPercent(level, surface.outputName)
            }

            Rectangle {
                width: parent.width
                height: 54
                radius: 12
                color: Theme.raisedSurface
                border.width: 1
                border.color: Theme.border

                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: PowerService.battery.ready ? "POWER  " + PowerService.batteryPercent + "%" : "POWER"
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: PowerService.profiles

                        Rectangle {
                            required property string modelData
                            readonly property bool active: modelData === PowerService.profile
                            width: Math.min(modelData === "balanced" ? 72 : 60, (surface.width - 128) / PowerService.profiles.length)
                            height: 32
                            radius: 9
                            color: active ? Theme.accent : (profileMouse.containsMouse ? Theme.surface : Theme.track)

                            Text {
                                anchors.centerIn: parent
                                text: surface.profileLabel(parent.modelData)
                                color: parent.active ? Theme.accentForeground : Theme.mutedForeground
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
                visible: NetworkService.statusMessage !== "" || BluetoothService.statusMessage !== ""
                wrapMode: Text.WordWrap
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
