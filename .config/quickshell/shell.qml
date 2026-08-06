import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    property bool windowVisible: false
    property bool presenting: false
    property bool dark: true
    property bool muted: false
    property bool warning: false
    property real value: 0
    property string kind: "volume"
    property string profile: ""
    property string renderer: ""
    property string statusText: ""
    property string targetScreen: ""

    readonly property color background: dark ? "#171817" : "#f4f2ee"
    readonly property color foreground: dark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: dark ? "#9c9d98" : "#666862"
    readonly property color border: dark ? "#343633" : "#d6d3cc"
    readonly property color track: dark ? "#30322f" : "#dedbd4"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"

    function code(): string {
        if (kind === "microphone") return "MIC"
        if (kind === "brightness") return "BRT"
        if (kind === "renderer") return "GPU"
        return "VOL"
    }

    function title(): string {
        if (kind === "microphone") return "Microphone"
        if (kind === "brightness") return "Display brightness"
        if (kind === "renderer") return renderer
        return "System volume"
    }

    function valueLabel(): string {
        if (kind === "renderer") return profile
        if (muted) return "Muted"
        return Math.round(value * 100) + "%"
    }

    function detail(): string {
        if (kind === "renderer") return statusText
        if (kind === "microphone") return muted ? "Input disabled" : "Input level"
        if (kind === "brightness") return "Built-in display"
        return muted ? "Output disabled" : "Default output"
    }

    function reveal(duration: int): void {
        closeTimer.stop()
        hideTimer.stop()
        windowVisible = true
        presenting = false
        revealTimer.restart()
        hideTimer.interval = duration
        hideTimer.restart()
    }

    function dismiss(): void {
        hideTimer.stop()
        presenting = false
        closeTimer.restart()
    }

    IpcHandler {
        target: "sidecar"

        function showOsd(kind: string, value: real, muted: bool, screen: string): void {
            root.kind = kind
            root.value = Math.max(0, Math.min(1, value))
            root.muted = muted
            root.warning = false
            root.targetScreen = screen
            root.reveal(1800)
        }

        function showRenderer(profile: string, renderer: string, status: string, screen: string, warning: bool): void {
            root.kind = "renderer"
            root.profile = profile
            root.renderer = renderer
            root.statusText = status
            root.warning = warning
            root.muted = false
            root.value = warning ? 0.35 : 1
            root.targetScreen = screen
            root.reveal(warning ? 5200 : 3200)
        }

        function refreshTheme(): void {
            themeProcess.exec(["/usr/sbin/gsettings", "get", "org.gnome.desktop.interface", "color-scheme"])
        }

        function hide(): void {
            root.dismiss()
        }

        function ping(): string {
            return "ready"
        }

        function getTheme(): string {
            return root.dark ? "dark" : "light"
        }
    }

    Process {
        id: themeProcess
        command: ["/usr/sbin/gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.dark = text.indexOf("prefer-dark") !== -1
        }
    }

    Timer {
        id: revealTimer
        interval: 16
        repeat: false
        onTriggered: root.presenting = true
    }

    Timer {
        id: hideTimer
        repeat: false
        onTriggered: root.dismiss()
    }

    Timer {
        id: closeTimer
        interval: 170
        repeat: false
        onTriggered: root.windowVisible = false
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: osdWindow

                required property var modelData

                screen: modelData
                visible: root.windowVisible && (root.targetScreen === "" || root.targetScreen === modelData.name)
                implicitWidth: 368
                implicitHeight: 96
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                updatesEnabled: visible
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {
                    width: 0
                    height: 0
                }

                anchors {
                    bottom: true
                }

                margins {
                    bottom: 52
                }

                Rectangle {
                    id: card

                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 15
                    color: root.background
                    border.width: 1
                    border.color: root.warning ? root.warningAccent : root.border
                    opacity: root.presenting ? 1 : 0
                    y: root.presenting ? 0 : 8

                    Behavior on opacity {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    Behavior on y {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        width: 3
                        height: 34
                        x: 0
                        y: 14
                        radius: 1.5
                        color: root.warning ? root.warningAccent : root.accent
                    }

                    Text {
                        x: 18
                        y: 18
                        width: 38
                        text: root.code()
                        color: root.warning ? root.warningAccent : root.accent
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }

                    Text {
                        x: 72
                        y: 13
                        width: parent.width - 154
                        text: root.title()
                        color: root.foreground
                        elide: Text.ElideRight
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Text {
                        x: parent.width - 82
                        y: 15
                        width: 62
                        horizontalAlignment: Text.AlignRight
                        text: root.valueLabel()
                        color: root.warning ? root.warningAccent : root.foreground
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: root.kind === "renderer" ? 10 : 13
                        font.weight: Font.Medium
                    }

                    Text {
                        x: 72
                        y: 39
                        width: parent.width - 94
                        text: root.detail()
                        color: root.mutedForeground
                        elide: Text.ElideRight
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 11
                    }

                    Rectangle {
                        id: progressTrack
                        x: 72
                        y: 67
                        width: parent.width - 94
                        height: 2
                        radius: 1
                        color: root.track

                        Rectangle {
                            width: Math.max(0, Math.min(1, root.value)) * parent.width
                            height: parent.height
                            radius: 1
                            color: root.warning ? root.warningAccent : root.accent

                            Behavior on width {
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }
                        }

                        Rectangle {
                            visible: root.kind !== "renderer" && !root.muted
                            x: Math.max(0, Math.min(parent.width - width, root.value * parent.width - width / 2))
                            y: -2
                            width: 6
                            height: 6
                            radius: 3
                            color: root.foreground

                            Behavior on x {
                                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
