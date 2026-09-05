pragma Singleton

import Quickshell
import QtCore
import QtQuick

// Persistent user-controlled list of desktop entry ids shown in the Dock.
Singleton {
    id: root

    readonly property var defaults: [
        "dev.sendoff.app",
        "hermes",
        "helium",
        "spotify-launcher",
        "firefox",
        "org.telegram.desktop"
    ]

    property var pinnedIds: []

    readonly property string storePath: {
        const stateHome = String(Quickshell.env("XDG_STATE_HOME") || "")
        const base = stateHome !== "" ? stateHome : String(Quickshell.env("HOME")) + "/.local/state"
        return base + "/quickshell/dock.ini"
    }

    function contains(id: string): bool {
        return root.pinnedIds.indexOf(id) !== -1
    }

    function pin(id: string): bool {
        if (!id || root.contains(id)) return false
        root.pinnedIds = root.pinnedIds.concat([id])
        root.persist()
        return true
    }

    function unpin(id: string): bool {
        const index = root.pinnedIds.indexOf(id)
        if (index === -1) return false
        const next = root.pinnedIds.slice()
        next.splice(index, 1)
        root.pinnedIds = next
        root.persist()
        return true
    }

    function toggle(id: string): bool {
        return root.contains(id) ? root.unpin(id) : root.pin(id)
    }

    function persist(): void {
        store.pinnedJson = JSON.stringify(root.pinnedIds)
    }

    Settings {
        id: store
        location: "file://" + root.storePath
        property string pinnedJson: JSON.stringify(root.defaults)

        Component.onCompleted: {
            try {
                const parsed = JSON.parse(pinnedJson)
                root.pinnedIds = Array.isArray(parsed) ? parsed : root.defaults.slice()
            } catch (error) {
                root.pinnedIds = root.defaults.slice()
            }
        }
    }
}
