pragma Singleton

import Quickshell
import QtCore
import QtQuick

// Launch counts for the application launcher, persisted across restarts.
//
// A singleton rather than per-window state: Launcher is instantiated once per
// screen through Variants, and several instances writing the same settings
// file would race.
Singleton {
    id: root

    // { "<desktop entry id>": { "count": int, "last": unix seconds } }
    property var usage: ({})

    readonly property string storePath: {
        const cacheHome = String(Quickshell.env("XDG_CACHE_HOME") || "")
        const base = cacheHome !== "" ? cacheHome : String(Quickshell.env("HOME")) + "/.cache"
        return base + "/quickshell/launcher-usage.ini"
    }

    // Age weights taken from the rofi search script this replaces, so ordering
    // matches the behaviour already learned: recent use dominates, but an entry
    // never decays to nothing.
    function ageWeight(age: int): real {
        if (age < 3600) return 4.0
        if (age < 86400) return 2.0
        if (age < 604800) return 0.5
        return 0.25
    }

    function score(id: string): real {
        const record = root.usage[id]
        if (!record) return 0

        const count = Number(record.count || 0)
        const last = Number(record.last || 0)
        if (count <= 0 || last <= 0) return 0

        const age = Math.max(0, Math.floor(Date.now() / 1000) - last)
        return count * root.ageWeight(age)
    }

    function record(id: string): void {
        if (!id) return

        const next = Object.assign({}, root.usage)
        const previous = next[id]
        next[id] = {
            "count": Number(previous ? previous.count : 0) + 1,
            "last": Math.floor(Date.now() / 1000)
        }

        root.usage = next
        store.usageJson = JSON.stringify(next)
    }

    Settings {
        id: store

        location: "file://" + root.storePath

        property string usageJson: "{}"

        Component.onCompleted: {
            try {
                root.usage = JSON.parse(usageJson) || {}
            } catch (error) {
                root.usage = ({})
            }
        }
    }
}
