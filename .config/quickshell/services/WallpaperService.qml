pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Everything that knows about awww: which wallpaper each output is showing,
// which files are available, and how to change one.
//
// The lock screen needs the current wallpaper and the picker needs the list;
// putting both here keeps `awww query` parsed in one place instead of two.
Singleton {
    id: root

    readonly property string directory: Quickshell.env("HOME") + "/.config/wallpapers"

    // Output name -> path currently displayed there.
    property var current: ({})

    // Absolute paths, sorted by file name.
    property var files: []

    property bool listing: false

    function sourceFor(output: string): string {
        const path = String(root.current[output] || "")
        return path === "" ? "" : "file://" + path
    }

    function isCurrent(path: string): bool {
        for (const output in root.current) {
            if (root.current[output] === path) return true
        }
        return false
    }

    function nameOf(path: string): string {
        const parts = String(path).split("/")
        return parts[parts.length - 1]
    }

    function refresh(): void {
        query.running = false
        query.running = true

        if (root.files.length === 0 && !root.listing) {
            root.listing = true
            lister.running = true
        }
    }

    function apply(path: string): void {
        if (path === "") return

        // The transition is the one the rofi menu used; it is the only thing
        // worth keeping from it.
        setter.command = ["/usr/sbin/awww", "img", path,
                          "--transition-type=wipe",
                          "--transition-angle=30",
                          "--transition-fps=165"]
        setter.running = true
    }

    // Lines look like:
    //   eDP-1: 1920x1080, scale: 1, currently displaying: image: /path/to.png
    Process {
        id: query

        command: ["/usr/sbin/awww", "query"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const next = ({})
                const lines = String(text).split("\n")

                for (let index = 0; index < lines.length; ++index) {
                    const match = lines[index].match(/^\s*:?\s*([^:]+):.*currently displaying:\s*image:\s*(.+)$/)
                    if (match) next[match[1].trim()] = match[2].trim()
                }

                root.current = next
            }
        }
    }

    Process {
        id: lister

        // -L because ~/.config/wallpapers is a symlink into the dotfiles
        // repository, and find will not descend into one without it.
        command: ["/usr/sbin/find", "-L", root.directory, "-maxdepth", "1", "-type", "f",
                  "-regextype", "posix-extended",
                  "-iregex", ".*\\.(png|jpe?g|webp|gif)$"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const found = String(text).split("\n").filter(line => line.trim() !== "")
                found.sort((left, right) => root.nameOf(left).localeCompare(root.nameOf(right)))
                root.files = found
                root.listing = false
            }
        }

        onExited: root.listing = false
    }

    Process {
        id: setter

        // awww redraws on its own; re-reading tells us which one won.
        onExited: query.running = true
    }
}
