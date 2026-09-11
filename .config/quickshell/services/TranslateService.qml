pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The `tr` prefix in the launcher, backed by translate-shell.
//
// A singleton for the same reason as the calculator: the launcher exists once
// per screen and each copy would otherwise run its own request.
//
// The debounce is much longer than the calculator's because every lookup is a
// network round trip — measured at about 1.5 seconds — and translating each
// keystroke would be both slow and rude to the endpoint.
Singleton {
    id: root

    readonly property int debounce: 600
    readonly property var codes: ["en", "ru", "kk"]

    // Everything after the prefix, before it is split into a target and a body.
    property string input: ""
    property string result: ""
    property bool busy: false
    property bool failed: false

    // "tr kk привет" names the target explicitly; anything else is decided by
    // the text.
    readonly property string explicitTarget: {
        const first = root.input.split(/\s+/)[0]
        return first && root.codes.indexOf(first.toLowerCase()) !== -1 ? first.toLowerCase() : ""
    }

    readonly property string source: root.explicitTarget === ""
        ? root.input
        : root.input.replace(/^\S+\s*/, "")

    // Kazakh is Cyrillic too, so script alone cannot tell it from Russian.
    // These nine letters exist in Kazakh and not in Russian, which separates
    // them well enough in practice.
    readonly property bool looksKazakh: /[әғқңөұүһіӘҒҚҢӨҰҮҺІ]/.test(root.source)
    readonly property bool looksCyrillic: /[А-Яа-яЁё]/.test(root.source)

    readonly property string detected: root.looksKazakh
        ? "kk"
        : (root.looksCyrillic ? "ru" : "en")

    // Kazakh in means Russian out, Russian in means English out, anything else
    // means Russian out. Every one of those is a guess, which is why the header
    // states the direction rather than leaving it to be inferred.
    readonly property string target: {
        if (root.explicitTarget !== "") return root.explicitTarget
        if (root.detected === "kk") return "ru"
        if (root.detected === "ru") return "en"
        return "ru"
    }

    readonly property string direction: root.source.trim() === ""
        ? "→ " + root.target.toUpperCase()
        : root.detected.toUpperCase() + " → " + root.target.toUpperCase()

    readonly property bool hasResult: root.result !== ""

    function translate(next: string): void {
        const trimmed = next.trim()
        if (trimmed === root.input) return

        root.input = trimmed

        if (root.source.trim() === "") {
            root.result = ""
            root.busy = false
            root.failed = false
            debounceTimer.stop()
            return
        }

        root.busy = true
        root.failed = false
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
            translator.running = false
            // -b is brief output: the translation and nothing else. The source
            // language is left to trans to detect; only the target is ours.
            translator.command = ["/usr/sbin/trans", "-b", ":" + root.target,
                                  "--", root.source]
            translator.running = true
        }
    }

    Process {
        id: translator

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false
                const value = String(text).trim()
                root.result = value
                root.failed = value === ""
            }
        }

        onExited: root.busy = false
    }

    Process {
        id: copier
    }
}
