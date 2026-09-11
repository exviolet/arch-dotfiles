pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Coding agents running in herdr, and what each of them is doing.
//
// Polled rather than subscribed. herdr does expose events.subscribe, but
// pane.agent_status_changed needs a pane_id per subscription — so following
// every agent would mean re-subscribing as panes come and go — and the global
// pane.updated does not fire on a status change. Meanwhile `herdr agent list`
// measured at 1.6ms for a 3.4KB reply, which makes a three second poll cheaper
// than the bookkeeping a socket would need.
//
// Read-only, and it has to be. `herdr agent focus` called from outside a herdr
// pane sets the server's focused flag and nothing else — the attached client
// keeps showing whatever it was showing, then the flag snaps back. Verified
// 2026-09-11 with the context variables stripped exactly as Quickshell has
// them. So this lists agents; it cannot jump to one.
//
// Worth remembering what this is for: herdr shows the same statuses in its own
// sidebar and already sends desktop notifications when they change. The rail
// earns its place only while herdr is *not* the focused window.
Singleton {
    id: root

    readonly property int pollInterval: 3000

    // [{ id, label, project, status, kind, focused }], attention first.
    property var agents: []
    property bool ready: false

    readonly property int blockedCount: root.countOf("blocked")
    readonly property int workingCount: root.countOf("working")
    readonly property bool needsAttention: root.blockedCount > 0

    function countOf(status: string): int {
        let total = 0
        for (let index = 0; index < root.agents.length; ++index) {
            if (root.agents[index].status === status) total += 1
        }
        return total
    }

    function statusLabel(status: string): string {
        if (status === "blocked") return "ЖДЁТ"
        if (status === "working") return "РАБОТАЕТ"
        if (status === "done") return "ГОТОВ"
        if (status === "idle") return "ПРОСТОЙ"
        return "—"
    }

    function refresh(): void {
        if (lister.running) return
        lister.running = true
    }

    Process {
        id: lister

        command: ["herdr", "agent", "list"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    root.ready = false
                    root.agents = []
                    return
                }

                const list = (parsed.result && parsed.result.agents) || []
                const next = []

                for (let index = 0; index < list.length; ++index) {
                    const entry = list[index]
                    const cwd = String(entry.cwd || "")
                    const title = String(entry.terminal_title_stripped || entry.name || "")

                    next.push({
                        "id": String(entry.pane_id || ""),
                        "label": title !== "" ? title : String(entry.pane_id || "agent"),
                        "project": cwd === "" ? "" : cwd.split("/").pop(),
                        "status": String(entry.agent_status || "unknown"),
                        "kind": String(entry.agent || ""),
                        "focused": Boolean(entry.focused)
                    })
                }

                // Sorted by where the agent lives, not by what it is doing.
                // Status changes every few seconds, and a list that reorders
                // itself under the eye is unreadable — who needs you is told
                // by the dot and the count in the section header instead.
                next.sort((left, right) => {
                    const byProject = left.project.localeCompare(right.project)
                    return byProject !== 0 ? byProject : left.label.localeCompare(right.label)
                })

                root.agents = next
                root.ready = true
            }
        }
    }

    Timer {
        interval: root.pollInterval
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: root.refresh()
    }
}
