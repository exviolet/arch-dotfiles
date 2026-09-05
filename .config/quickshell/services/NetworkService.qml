pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: root

    readonly property var wifiDevice: {
        const devices = Networking.devices.values
        for (let index = 0; index < devices.length; ++index) {
            if (devices[index].type === DeviceType.Wifi)
                return devices[index]
        }
        return null
    }
    readonly property bool ready: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var networks: {
        if (!wifiDevice) return []
        const values = wifiDevice.networks.values.slice()
        values.sort((left, right) => {
            if (left.connected !== right.connected) return left.connected ? -1 : 1
            return right.signalStrength - left.signalStrength
        })
        return values.slice(0, 6)
    }
    readonly property var connectedNetwork: {
        for (let index = 0; index < networks.length; ++index) {
            if (networks[index].connected) return networks[index]
        }
        return null
    }
    property var scannerRequests: ({})
    property string statusMessage: ""

    function signalPercent(network: var): int {
        if (!network) return 0
        const value = Number(network.signalStrength || 0)
        return Math.round(Math.max(0, Math.min(100, value <= 1 ? value * 100 : value)))
    }

    function syncScanner(): void {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = Object.keys(root.scannerRequests).length > 0
    }

    function setScanningFor(output: string, active: bool): void {
        const next = Object.assign({}, root.scannerRequests)
        if (active)
            next[output] = true
        else
            delete next[output]
        root.scannerRequests = next
    }

    function toggleWifi(): bool {
        if (!root.wifiHardwareEnabled) return false
        Networking.wifiEnabled = !Networking.wifiEnabled
        return true
    }

    function connectNetwork(network: var): bool {
        if (!network || network.connected || network.stateChanging) return false
        root.statusMessage = network.known ? "Connecting" : "Saved password required"
        if (!network.known && network.security !== WifiSecurityType.Open)
            return false
        network.connect()
        return true
    }

    function clearStatus(): void {
        root.statusMessage = ""
    }

    onScannerRequestsChanged: syncScanner()
    onWifiDeviceChanged: syncScanner()

    Timer {
        interval: 2600
        running: root.statusMessage !== ""
        repeat: false
        onTriggered: root.clearStatus()
    }
}
