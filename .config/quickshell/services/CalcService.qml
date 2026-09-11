pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The `calc` prefix in the launcher, backed by qalc.
//
// A singleton because the launcher is instantiated per screen through Variants
// and each copy would otherwise spawn its own qalc on every keystroke.
//
// qalc is run under LC_ALL=C: in a Russian locale it parses English syntax
// wrongly — "15% of 240" came back as rem(15, 1 B).
Singleton {
    id: root

    // Long enough that a burst of typing costs one process, short enough that
    // the answer feels like it was already there.
    readonly property int debounce: 180

    property string expression: ""
    property string result: ""
    property bool busy: false

    readonly property bool hasResult: root.result !== ""

    function evaluate(next: string): void {
        const trimmed = next.trim()
        if (trimmed === root.expression) return

        root.expression = trimmed

        if (trimmed === "") {
            root.result = ""
            root.busy = false
            debounceTimer.stop()
            return
        }

        root.busy = true
        debounceTimer.restart()
    }

    function copyResult(): void {
        if (!root.hasResult) return
        copier.command = ["/usr/sbin/wl-copy", "--", root.result]
        copier.running = true
    }

    Timer {
        id: debounceTimer

        interval: root.debounce
        repeat: false

        onTriggered: {
            calculator.running = false
            // Terse output, and the expression as one argument rather than
            // through a shell — it is whatever the user typed.
            calculator.command = ["/usr/sbin/qalc", "-t", "--", root.expression]
            calculator.running = true
        }
    }

    Process {
        id: calculator

        running: false
        environment: ({ "LC_ALL": "C", "LANG": "C" })

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                const value = String(text).trim().split("\n")[0].trim()
                // qalc echoes the input back when it cannot make sense of it.
                root.result = value === root.expression ? "" : value
            }
        }

        onExited: root.busy = false
    }

    Process {
        id: copier
    }
}
