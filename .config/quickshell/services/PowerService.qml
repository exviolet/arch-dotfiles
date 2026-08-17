pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Session actions for the power menu.
//
// A singleton because the power window is instantiated once per screen through
// Variants: each instance would otherwise run its own uptime process.
Singleton {
    id: root

    property string uptime: ""

    // Ordered by descending consequence, so shutting down is the default
    // selection: closing the laptop for the day is the common case, and it
    // wants to be Enter, Enter. The confirmation step still stands between a
    // stray keypress and a powered-off machine.
    //
    // Hibernate is deliberately absent. Swap here is zram, which lives in RAM,
    // so there is nothing to write a hibernation image to. The rofi menu this
    // replaces only ever answered that button with a "not configured" notice.
    readonly property var actions: [
        {
            "id": "shutdown",
            "label": "Shut down",
            "icon": "system-shut",
            "confirm": true,
            "command": ["/usr/sbin/systemctl", "poweroff"]
        },
        {
            "id": "reboot",
            "label": "Reboot",
            "icon": "system-restart",
            "confirm": true,
            "command": ["/usr/sbin/systemctl", "reboot"]
        },
        {
            "id": "logout",
            "label": "Log out",
            "icon": "log-out",
            "confirm": true,
            // -s skips niri's own "press enter to confirm" prompt; this menu
            // has already asked.
            "command": ["/usr/sbin/niri", "msg", "action", "quit", "-s"]
        },
        {
            "id": "suspend",
            "label": "Suspend",
            "icon": "half-moon",
            "confirm": true,
            "command": ["/usr/sbin/systemctl", "suspend"]
        },
        {
            "id": "lock",
            "label": "Lock",
            "icon": "lock",
            "confirm": false,
            "command": ["/usr/sbin/hyprlock"]
        }
    ]

    function refresh(): void {
        uptimeProcess.running = false
        uptimeProcess.running = true
    }

    function run(action: var): void {
        if (!action) return
        actionProcess.command = action.command
        actionProcess.running = true
    }

    Process {
        id: uptimeProcess

        command: ["/usr/sbin/uptime", "-p"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.uptime = text.trim().replace(/^up /, "")
        }
    }

    Process {
        id: actionProcess
    }
}
