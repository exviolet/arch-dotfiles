pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering
    readonly property var devices: {
        const values = Bluetooth.devices.values.filter(device => device.paired)
        values.sort((left, right) => {
            if (left.connected !== right.connected) return left.connected ? -1 : 1
            return String(left.name || left.deviceName).localeCompare(String(right.name || right.deviceName))
        })
        return values.slice(0, 5)
    }
    property string statusMessage: ""

    function deviceName(device: var): string {
        if (!device) return "Unknown device"
        return String(device.name || device.deviceName || device.address)
    }

    function batteryPercent(device: var): int {
        if (!device || !device.batteryAvailable) return -1
        const value = Number(device.battery || 0)
        return Math.round(Math.max(0, Math.min(100, value <= 1 ? value * 100 : value)))
    }

    function toggleEnabled(): bool {
        if (!root.adapter) return false
        root.adapter.enabled = !root.adapter.enabled
        return true
    }

    function toggleDevice(device: var): bool {
        if (!device || !root.enabled) return false
        root.statusMessage = device.connected ? "Disconnecting" : "Connecting"
        if (device.connected)
            device.disconnect()
        else
            device.connect()
        return true
    }

    Timer {
        interval: 2600
        running: root.statusMessage !== ""
        repeat: false
        onTriggered: root.statusMessage = ""
    }
}
