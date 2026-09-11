pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick

// Screen lock: state, authentication and the idle trigger.
//
// Replaces hyprlock, whose config had rotted anyway — it pointed at a
// wallpaper file that no longer exists and at two ~/bash-scripts helpers whose
// directory is gone, so its layout and battery readouts had been blank for
// some time. Both come from PowerService and NiriService here instead.
//
// The lock surface is what the compositor keeps on screen if this process
// dies, so nothing in it may be allowed to throw: keep the face simple, and
// use previewing (see LockFace) rather than locking to iterate on it.
Singleton {
    id: root

    // Set by Lock.qml once the compositor confirms the session is locked.
    property bool locked: false
    property bool authenticating: false
    property string status: ""
    property bool statusIsError: false

    // Output name -> wallpaper path, read from awww at lock time so the lock
    // shows whatever is actually on the desktop right now.
    property var wallpapers: ({})

    readonly property int idleTimeout: 600

    function wallpaperFor(name: string): string {
        const path = String(root.wallpapers[name] || "")
        return path === "" ? "" : "file://" + path
    }

    function refreshWallpapers(): void {
        wallpaperQuery.running = false
        wallpaperQuery.running = true
    }

    function lock(): void {
        if (root.locked) return

        root.status = ""
        root.statusIsError = false
        root.refreshWallpapers()
        root.locked = true
    }

    // The way back in when the face is broken but the process is alive, and
    // half of the recovery path when it is not: restarting the shell leaves
    // the compositor locked with no client, so a new one has to lock and then
    // unlock to release it.
    function unlock(): void {
        root.locked = false
        root.status = ""
        root.statusIsError = false
    }

    function authenticate(password: string): void {
        if (root.authenticating) return

        root.authenticating = true
        root.status = ""
        root.statusIsError = false
        pam.pendingPassword = password
        pam.start()
    }

    PamContext {
        id: pam

        property string pendingPassword: ""

        // /etc/pam.d/quickshell does not exist and creating it would need
        // root. The login stack is what /etc/pam.d/hyprlock included anyway,
        // so it is already proven on this machine.
        config: "login"

        onPamMessage: {
            if (!pam.responseRequired) {
                // Informational text, not a prompt for us.
                if (pam.message !== "") {
                    root.status = pam.message
                    root.statusIsError = pam.messageIsError
                }
                return
            }

            pam.respond(pam.pendingPassword)
        }

        onCompleted: result => {
            pam.pendingPassword = ""
            root.authenticating = false

            if (result === PamResult.Success) {
                root.statusIsError = false
                // Unlocking is the feedback when this runs for real; in the
                // preview nothing else would move, so say it out loud.
                root.status = root.locked ? "" : "Пароль принят"
                root.locked = false
                return
            }

            root.statusIsError = true
            root.status = result === PamResult.MaxTries
                ? "Too many attempts"
                : "Wrong password"
        }

        onError: error => {
            pam.pendingPassword = ""
            root.authenticating = false
            root.statusIsError = true
            root.status = "Authentication unavailable: " + PamError.toString(error)
        }
    }

    // Lines look like:
    //   eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to.png
    Process {
        id: wallpaperQuery

        command: ["awww", "query"]

        stdout: StdioCollector {
            onStreamFinished: {
                const next = ({})
                const lines = String(text).split("\n")

                for (let index = 0; index < lines.length; ++index) {
                    const match = lines[index].match(/^\s*:?\s*([^:]+):.*currently displaying:\s*image:\s*(.+)$/)
                    if (match) next[match[1].trim()] = match[2].trim()
                }

                root.wallpapers = next
            }
        }
    }

    IdleMonitor {
        // respectInhibitors keeps a full-screen video or a call from locking
        // the session out from under it — those set an inhibitor themselves.
        respectInhibitors: true
        timeout: root.idleTimeout
        enabled: !root.locked

        onIsIdleChanged: {
            if (isIdle) root.lock()
        }
    }
}
