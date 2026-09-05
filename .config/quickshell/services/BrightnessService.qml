pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    signal feedbackRequested(real value, string screen)

    property bool ready: false
    property real value: 0
    readonly property int percent: Math.round(value * 100)
    property string feedbackScreen: ""

    function acceptValue(nextValue: real): void {
        root.value = Math.max(0, Math.min(1, nextValue))
        root.ready = true
    }

    function refresh(): void {
        if (!readProcess.running)
            readProcess.running = true
    }

    function adjust(step: int, screen: string): bool {
        if (step === 0 || actionProcess.running) return false
        root.feedbackScreen = screen
        actionProcess.command = [
            "/usr/sbin/brightnessctl",
            "--class=backlight",
            "--device=intel_backlight",
            "set",
            String(Math.max(1, Math.min(25, Math.abs(step)))) + (step > 0 ? "%+" : "%-")
        ]
        actionProcess.running = true
        return true
    }

    function setPercent(percent: int, screen: string): bool {
        if (actionProcess.running) return false
        const normalized = Math.max(1, Math.min(100, Math.round(percent)))
        root.feedbackScreen = screen
        actionProcess.command = [
            "/usr/sbin/brightnessctl",
            "--class=backlight",
            "--device=intel_backlight",
            "set",
            String(normalized) + "%"
        ]
        actionProcess.running = true
        return true
    }

    function show(screen: string): void {
        root.feedbackRequested(root.value, screen)
    }

    Process {
        id: readProcess
        command: [
            "/usr/sbin/brightnessctl",
            "--class=backlight",
            "--device=intel_backlight",
            "-m"
        ]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",")
                if (fields.length >= 4) {
                    const parsed = Number(fields[3].replace("%", "")) / 100
                    if (isFinite(parsed))
                        root.acceptValue(parsed)
                }
                if (root.feedbackScreen !== "") {
                    root.feedbackRequested(root.value, root.feedbackScreen)
                    root.feedbackScreen = ""
                }
            }
        }
    }

    Process {
        id: actionProcess
        onExited: root.refresh()
    }
}
