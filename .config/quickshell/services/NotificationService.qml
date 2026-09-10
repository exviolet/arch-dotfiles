pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// The freedesktop notification server, replacing swaync.
//
// Only one process can own org.freedesktop.Notifications on the bus, so this
// and swaync are mutually exclusive: swaync has to be gone from startup.kdl
// and killed before this takes over. There is no partial cutover.
//
// Popups only, no history and no notification center — the swaync center went
// unused, so nothing here keeps a notification after its card leaves the
// screen. That is why every removal path below actually closes the
// notification on the bus: with nowhere left to read it, a notification the
// server still tracks is one no one can ever act on, and a sender waiting on
// its action would wait forever.
//
// A singleton because the popup window is instantiated once per screen through
// Variants — the queue and the expiry clock have to be shared, or each screen
// would run its own timers over its own copies.
Singleton {
    id: root

    // Popup lifetime when the sender does not ask for one. Critical never
    // expires by itself: the spec keeps it until dismissed, and that is
    // exactly what the crash notification needs.
    readonly property int lowTimeout: 4000
    readonly property int normalTimeout: 6000

    // Anything past this is expired oldest-first rather than silently dropped,
    // so a burst cannot leave notifications tracked with no card to close them.
    readonly property int maxPopups: 4

    // [{ id, notification, deadline }], newest first. deadline 0 = no expiry.
    property var popups: []

    readonly property bool hasPopups: root.popups.length > 0

    function timeoutFor(notification: var): int {
        const asked = Number(notification.expireTimeout)
        // The spec uses -1 for "server decides" and 0 for "never".
        if (asked === 0) return 0
        if (asked > 0) return asked

        if (notification.urgency === NotificationUrgency.Critical) return 0
        return notification.urgency === NotificationUrgency.Low
            ? root.lowTimeout
            : root.normalTimeout
    }

    // Anything here goes straight into an Image source, so a bare path has to
    // come back as a file:// URL — Qt would otherwise resolve it against the
    // QML file's directory.
    function asSource(path: string): string {
        if (path === "") return ""
        return path.startsWith("/") ? "file://" + path : path
    }

    function iconFor(notification: var): string {
        // image is the pixmap a sender attached inline; appIcon is a themed
        // name or a path. Prefer the picture, fall back to the app's icon.
        const image = String(notification.image || "")
        if (image !== "") return root.asSource(image)

        const icon = String(notification.appIcon || "")
        if (icon === "") return ""
        if (icon.startsWith("/") || icon.startsWith("file:")) return root.asSource(icon)
        return Quickshell.iconPath(icon, true)
    }

    function entryFor(id: int): var {
        for (let index = 0; index < root.popups.length; ++index) {
            if (root.popups[index].id === id) return root.popups[index]
        }
        return null
    }

    // The user swatted the card away: closed as Dismissed.
    function dismiss(id: int): void {
        const entry = root.entryFor(id)
        if (entry) entry.notification.tracked = false
    }

    function dismissAll(): void {
        const entries = root.popups.slice()
        for (let index = 0; index < entries.length; ++index) {
            entries[index].notification.tracked = false
        }
    }

    function invokeAction(id: int, identifier: string): void {
        const entry = root.entryFor(id)
        if (!entry) return

        const actions = entry.notification.actions
        for (let index = 0; index < actions.length; ++index) {
            if (actions[index].identifier !== identifier) continue

            actions[index].invoke()
            // A resident notification asks to stay put after its action runs;
            // everything else is done once the user has acted on it.
            if (!entry.notification.resident) entry.notification.tracked = false
            return
        }
    }

    // Called when a notification leaves the server, whether we closed it, it
    // timed out, or the sender withdrew it.
    function forget(id: int): void {
        const kept = root.popups.filter(entry => entry.id !== id)
        if (kept.length !== root.popups.length) root.popups = kept
    }

    NotificationServer {
        id: server

        // Survives a config reload, so editing QML does not wipe what is on
        // screen. It does not survive a process restart.
        keepOnReload: true

        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            // Without this the server drops it the moment this handler ends.
            notification.tracked = true

            const timeout = root.timeoutFor(notification)
            const popups = root.popups.slice()

            popups.unshift({
                "id": Number(notification.id),
                "notification": notification,
                "deadline": timeout > 0 ? Date.now() + timeout : 0
            })

            // Expire the overflow rather than dropping it from the array: a
            // notification with no card left is one nothing can ever close.
            const overflow = popups.splice(root.maxPopups)
            root.popups = popups
            for (let index = 0; index < overflow.length; ++index) {
                overflow[index].notification.expire()
            }
        }
    }

    // One clock for every popup instead of a Timer per card: the cards live in
    // a per-screen window, so per-card timers would multiply by screen count.
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0

        onTriggered: {
            const now = Date.now()
            // Collect first, then expire: each expire() closes a notification,
            // which calls back into forget() and rewrites root.popups.
            const due = root.popups.filter(entry => entry.deadline !== 0 && entry.deadline <= now)
            for (let index = 0; index < due.length; ++index) {
                due[index].notification.expire()
            }
        }
    }

    // A sender can close its own notification (herdr replaces a toast this
    // way), so the queue has to follow the server, not only our own calls.
    Instantiator {
        model: server.trackedNotifications

        delegate: Connections {
            required property var modelData

            target: modelData

            function onClosed(reason: int): void {
                root.forget(Number(modelData.id))
            }
        }
    }
}
