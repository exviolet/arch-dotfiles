pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The `emoji` prefix in the launcher.
//
// The table is a copy of rofi-emoji's all_emojis.txt, kept in the repository
// because the original belongs to that package and would disappear with it.
// Format per line: glyph, group, subgroup, name, keywords separated by "|".
//
// Loaded on first use rather than at startup: 5000 lines are not worth parsing
// for a shell that may never be asked for an emoji all day.
Singleton {
    id: root

    readonly property int limit: 48

    // [{ glyph, name, haystack }]
    property var entries: []
    property bool loaded: false

    readonly property string tablePath: Quickshell.env("HOME") + "/.config/quickshell/data/emoji.txt"

    function ensureLoaded(): void {
        if (root.loaded || table.path !== "") return
        table.path = root.tablePath
    }

    function parse(text: string): void {
        const lines = String(text).split("\n")
        const parsed = []

        for (let index = 0; index < lines.length; ++index) {
            const fields = lines[index].split("\t")
            if (fields.length < 4) continue

            const glyph = fields[0]
            const name = fields[3]
            if (glyph === "" || name === "") continue

            parsed.push({
                "glyph": glyph,
                "name": name,
                // Group, subgroup and keywords are worth searching but not
                // worth showing, so they live in one lowercased haystack.
                "haystack": (name + " " + fields[1] + " " + fields[2] + " "
                    + (fields[4] || "")).toLowerCase()
            })
        }

        root.entries = parsed
        root.loaded = true
    }

    // Name first, then anywhere in the metadata: typing "grin" should reach
    // "grinning face" before a dozen faces that merely list grin as a keyword.
    function search(needle: string): var {
        if (!root.loaded) return []

        const lowered = needle.trim().toLowerCase()
        if (lowered === "") return root.entries.slice(0, root.limit)

        const starts = []
        const contains = []
        const meta = []

        for (let index = 0; index < root.entries.length; ++index) {
            const entry = root.entries[index]
            const name = entry.name.toLowerCase()

            if (name.startsWith(lowered)) starts.push(entry)
            else if (name.indexOf(lowered) !== -1) contains.push(entry)
            else if (entry.haystack.indexOf(lowered) !== -1) meta.push(entry)

            if (starts.length >= root.limit) break
        }

        return starts.concat(contains, meta).slice(0, root.limit)
    }

    function copy(glyph: string): void {
        if (glyph === "") return
        copier.command = ["/usr/sbin/wl-copy", "--", glyph]
        copier.running = true
    }

    FileView {
        id: table

        path: ""
        printErrors: false

        onLoaded: root.parse(table.text())
    }

    Process {
        id: copier
    }
}
