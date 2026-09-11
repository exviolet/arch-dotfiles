pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// How much of the Claude Code plan is burnt.
//
// Claude Code hands these percentages to the status line command and nowhere
// else — they are not in the transcripts, which only record rate_limit *errors*
// — so ~/.claude/statusline-command.sh publishes them to the file this reads.
// That makes the numbers exact rather than re-derived, at the cost of only
// being fresh while some session is on screen: see `stale`.
Singleton {
    id: root

    // Older than this and the file is describing a window that has probably
    // moved on; the five hour window is the shorter of the two.
    readonly property int staleAfter: 3600

    property real fivePercent: -1
    property real sevenPercent: -1
    property double fiveResetsAt: 0
    property double sevenResetsAt: 0
    property double updatedAt: 0

    readonly property bool ready: root.fivePercent >= 0 || root.sevenPercent >= 0

    // Re-evaluated by the same clock that drives the countdowns.
    property double now: Date.now() / 1000
    readonly property bool stale: root.ready && (root.now - root.updatedAt) > root.staleAfter

    readonly property string statePath: {
        const runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "")
        return (runtime !== "" ? runtime : "/tmp") + "/claude-usage.json"
    }

    // Token totals, aggregated from the transcripts on demand. Claude Code
    // publishes percentages but never counts, so the transcripts are the only
    // source; a full pass over them takes about half a second, which is why
    // there is no cache, no incremental read and no refresh timer.
    property var tokenDays: []
    property var tokenModels: []
    property double tokenTotal: 0
    property bool tokensLoading: false
    property double tokensReadAt: 0

    readonly property bool tokensReady: root.tokenDays.length > 0 || root.tokenModels.length > 0

    readonly property double tokenDayPeak: {
        let peak = 0
        for (let index = 0; index < root.tokenDays.length; ++index) {
            peak = Math.max(peak, Number(root.tokenDays[index].tokens))
        }
        return peak
    }

    readonly property double tokenModelPeak: {
        let peak = 0
        for (let index = 0; index < root.tokenModels.length; ++index) {
            peak = Math.max(peak, Number(root.tokenModels[index].tokens))
        }
        return peak
    }

    function refreshTokens(): void {
        if (root.tokensLoading) return
        root.tokensLoading = true
        tokenReader.running = true
    }

    // 3_164_145_370 -> "3.16B". Counts this large are only ever read as an
    // order of magnitude.
    function compact(value: real): string {
        const number = Number(value) || 0
        if (number >= 1e9) return (number / 1e9).toFixed(2) + "B"
        if (number >= 1e6) return (number / 1e6).toFixed(1) + "M"
        if (number >= 1e3) return Math.round(number / 1e3) + "K"
        return String(Math.round(number))
    }

    // "claude-opus-4-8" -> "OPUS 4.8", "claude-haiku-4-5-20251001" -> "HAIKU 4.5"
    function modelLabel(id: string): string {
        let name = String(id).replace(/^claude-/, "").replace(/-\d{8}$/, "")
        const parts = name.split("-")
        const family = parts.shift() || name
        const version = parts.join(".")
        return (version === "" ? family : family + " " + version).toUpperCase()
    }

    // "2026-09-10" -> "10.09"
    function dayLabel(date: string): string {
        const parts = String(date).split("-")
        return parts.length === 3 ? parts[2] + "." + parts[1] : String(date)
    }

    function percentLabel(value: real): string {
        return value < 0 ? "--" : String(Math.round(value))
    }

    // "48m", "2h48m", "1d12h" — same shape as the battery's time-left label.
    function countdown(timestamp: double): string {
        if (!timestamp) return ""

        const remaining = Math.floor(timestamp - root.now)
        if (remaining <= 0) return ""

        const days = Math.floor(remaining / 86400)
        const hours = Math.floor((remaining % 86400) / 3600)
        const minutes = Math.floor((remaining % 3600) / 60)

        if (days > 0) return days + "d" + hours + "h"
        if (hours > 0) return hours + "h" + minutes + "m"
        return minutes + "m"
    }

    function apply(text: string): void {
        if (text === "") return

        let parsed
        try {
            parsed = JSON.parse(text)
        } catch (error) {
            return
        }

        const five = parsed.five_hour || ({})
        const seven = parsed.seven_day || ({})

        root.fivePercent = five.used === null || five.used === undefined ? -1 : Number(five.used)
        root.sevenPercent = seven.used === null || seven.used === undefined ? -1 : Number(seven.used)
        root.fiveResetsAt = Number(five.resets_at || 0)
        root.sevenResetsAt = Number(seven.resets_at || 0)
        root.updatedAt = Number(parsed.updated_at || 0)
    }

    Process {
        id: tokenReader

        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/claude-tokens"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.tokensLoading = false

                let parsed
                try {
                    parsed = JSON.parse(text)
                } catch (error) {
                    return
                }

                root.tokenDays = parsed.days || []
                root.tokenModels = parsed.models || []
                root.tokenTotal = Number(parsed.total || 0)
                root.tokensReadAt = Date.now() / 1000
            }
        }

        onExited: root.tokensLoading = false
    }

    FileView {
        id: state

        path: root.statePath
        watchChanges: true
        printErrors: false

        onLoaded: root.apply(state.text())
        onFileChanged: {
            // The writer replaces the file by rename rather than truncating
            // it. Measured: the watch survives that and fires within a second,
            // but reload() is what re-reads the new inode's contents.
            state.reload()
            root.apply(state.text())
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            // Drives the countdowns, which have to tick whether or not the
            // file changes. The re-read is a cheap backstop for a watch that
            // quietly stops firing.
            root.now = Date.now() / 1000
            state.reload()
            root.apply(state.text())
        }
    }
}
