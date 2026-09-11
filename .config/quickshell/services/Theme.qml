pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Palette, and the one question it depends on: is the desktop dark right now.
//
// The answer is followed rather than pushed. It used to be read once at
// startup and refreshed only when the theme script called `sidecarctl theme`;
// if that single read raced with anything, the shell stayed in the wrong
// palette until the next toggle — which is exactly what happened. `gsettings
// monitor` reports every change, including ones made by other tools, so the
// shell cannot drift out of step any more.
Singleton {
    id: root

    property bool dark: true

    function applyScheme(text: string): void {
        const value = String(text)
        if (value.indexOf("prefer-dark") !== -1) root.dark = true
        else if (value.indexOf("prefer-light") !== -1 || value.indexOf("default") !== -1) root.dark = false
    }

    Process {
        id: initialRead

        command: ["/usr/sbin/gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.applyScheme(text)
        }
    }

    // Long-lived: one line per change, for as long as the shell runs.
    Process {
        id: watcher

        command: ["/usr/sbin/gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        running: true

        stdout: SplitParser {
            onRead: line => root.applyScheme(line)
        }
    }

    readonly property color background: root.dark ? "#171817" : "#f4f2ee"
    readonly property color surface: root.dark ? "#222321" : "#e9e6df"
    readonly property color raisedSurface: root.dark ? "#292a28" : "#dfdcd5"
    readonly property color foreground: root.dark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: root.dark ? "#9c9d98" : "#666862"
    readonly property color subtleForeground: root.dark ? "#8f918b" : "#6e706a"
    readonly property color border: root.dark ? "#343633" : "#d6d3cc"
    readonly property color track: root.dark ? "#30322f" : "#dedbd4"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property color layoutUs: "#356ea3"
    readonly property color layoutRu: root.dark ? "#b53f37" : "#a93832"
    readonly property color layoutKk: root.dark ? "#d0a13c" : "#bd841e"
}
