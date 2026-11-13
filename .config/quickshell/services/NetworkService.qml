pragma Singleton

import Quickshell
import Quickshell.Io
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
        return values.filter(network => network.name !== "")
    }
    readonly property var connectedNetwork: {
        for (let index = 0; index < networks.length; ++index) {
            if (networks[index].connected) return networks[index]
        }
        return null
    }
    property var scannerRequests: ({})
    property string statusMessage: ""
    property bool speedTestRunning: false
    property var speedTestResult: null
    property string speedTestError: ""
    property var wifiStatus: ({})
    readonly property string wifiStatusTarget: Object.keys(scannerRequests).length > 0 && connectedNetwork && wifiDevice
        ? JSON.stringify([wifiDevice.name, connectedNetwork.name]) : ""

    onWifiStatusTargetChanged: {
        root.wifiStatus = ({})
        if (root.wifiStatusTarget !== "") Qt.callLater(root.refreshWifiStatus)
    }

    function wifiSecurity(network: var): string {
        switch (network.security) {
        case WifiSecurityType.Open: return "Открытая"
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap: return "WPA2"
        case WifiSecurityType.Sae:
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3"
        default: return "Защищена"
        }
    }

    function refreshWifiStatus(): void {
        if (root.wifiStatusTarget === "" || wifiProbe.running) return
        wifiProbe.target = root.wifiStatusTarget
        wifiProbe.exec(["/usr/bin/python3", Quickshell.shellDir + "/scripts/wifi-status.py", root.wifiDevice.name])
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.wifiStatusTarget !== ""
        onTriggered: root.refreshWifiStatus()
    }

    Process {
        id: wifiProbe
        property string target: ""
        stdout: StdioCollector { id: wifiOutput }

        onExited: exitCode => {
            if (target !== root.wifiStatusTarget) {
                Qt.callLater(root.refreshWifiStatus)
                return
            }
            try {
                const next = exitCode === 0 ? JSON.parse(wifiOutput.text) : ({})
                const previous = root.wifiStatus
                const seconds = next.time - previous.time
                if (seconds > 0 && next.address === previous.address && next.gateway === previous.gateway) {
                    if (next.rx >= previous.rx) next.down = (next.rx - previous.rx) / seconds
                    if (next.tx >= previous.tx) next.up = (next.tx - previous.tx) / seconds
                }
                root.wifiStatus = next
            } catch (error) {
                root.wifiStatus = ({})
            }
        }
    }

    function startSpeedTest(): void {
        if (root.speedTestRunning) return
        root.speedTestRunning = true
        root.speedTestError = ""
        speedTest.running = true
    }

    Process {
        id: speedTest
        command: ["/usr/bin/timeout", "--kill-after=3s", "60s",
            "speedtest-cli", "--secure", "--json", "--timeout", "10"]
        stdout: StdioCollector { id: speedTestOutput }

        onExited: exitCode => {
            root.speedTestRunning = false
            if (exitCode === 0) {
                try {
                    const result = JSON.parse(speedTestOutput.text)
                    if ([result.download, result.upload, result.ping].every(value => Number.isFinite(value) && value >= 0)) {
                        root.speedTestResult = {
                            "downloadMbps": result.download / 1000000,
                            "uploadMbps": result.upload / 1000000,
                            // A failed latency probe adds 600,000 ms to speedtest-cli's reported ping.
                            "latencyMs": result.ping < 600000 ? result.ping : null,
                            "measuredAt": new Date()
                        }
                        return
                    }
                } catch (error) {
                    // The command may exit successfully without a complete JSON result.
                }
                root.speedTestError = "Invalid speed test result"
            } else if (exitCode === 127) {
                root.speedTestError = "Install speedtest-cli to run the test"
            } else if (exitCode === 124 || exitCode === 137) {
                root.speedTestError = "Speed test timed out. Try again."
            } else {
                root.speedTestError = "Speed test failed. Check your connection and try again."
            }
        }
    }

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
