import Quickshell
import Quickshell.Io
import QtQuick

Scope {
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
            step > 0 ? "5%+" : "5%-"
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
        onExited: (exitCode, exitStatus) => root.refresh()
    }
}
