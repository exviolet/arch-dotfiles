import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    signal trayInlineMenuRequested(int index, string screen)

    property bool windowVisible: false
    property bool presenting: false
    property bool dark: true
    property bool railVisible: true
    property bool railPinned: false
    property string railExpansionScreen: ""
    property string railPreviewScreen: ""
    property string activeSurface: "system"
    property bool surfaceInitialized: false
    property bool muted: false
    property bool warning: false
    property real value: 0
    property string kind: "volume"
    property string profile: ""
    property string renderer: ""
    property string statusText: ""
    property string targetScreen: ""
    property bool keyboardFeedbackReady: false
    property string keyboardLayoutName: ""

    readonly property var mediaPlayer: {
        const players = Mpris.players.values
        for (let index = 0; index < players.length; ++index) {
            if (players[index].playbackState === MprisPlaybackState.Playing)
                return players[index]
        }
        return players.length > 0 ? players[0] : null
    }

    onMediaPlayerChanged: {
        if (mediaPlayer && !surfaceInitialized) {
            activeSurface = "media"
            surfaceInitialized = true
        } else if (!mediaPlayer && activeSurface === "media") {
            activeSurface = "system"
        }
    }

    readonly property color background: dark ? "#171817" : "#f4f2ee"
    readonly property color foreground: dark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: dark ? "#9c9d98" : "#666862"
    readonly property color border: dark ? "#343633" : "#d6d3cc"
    readonly property color track: dark ? "#30322f" : "#dedbd4"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property color layoutUs: "#356ea3"
    readonly property color layoutRu: dark ? "#b53f37" : "#a93832"
    readonly property color layoutKk: dark ? "#d0a13c" : "#bd841e"

    NiriService {
        id: niriService
    }

    AudioService {
        id: audioService
    }

    BrightnessService {
        id: brightnessService
    }

    TrayService {
        id: trayService
    }

    Connections {
        target: audioService

        function onSinkReadyChanged(): void {
            if (!audioService.sinkReady && root.activeSurface === "audio")
                root.activeSurface = "system"
        }
    }

    Connections {
        target: brightnessService

        function onFeedbackRequested(value: real, screen: string): void {
            root.kind = "brightness"
            root.value = value
            root.muted = false
            root.warning = false
            root.targetScreen = screen
            root.reveal(1800)
        }
    }

    Connections {
        target: trayService

        function onItemCountChanged(): void {
            if (trayService.itemCount === 0 && root.activeSurface === "tray")
                root.activeSurface = "system"
        }
    }

    Connections {
        target: niriService

        function onKeyboardLayoutChanged(): void {
            if (niriService.keyboardLayout === "") return
            root.keyboardLayoutName = niriService.keyboardLayout
            if (!root.keyboardFeedbackReady) {
                root.keyboardFeedbackReady = true
                return
            }
            root.presentKeyboardLayout("")
        }
    }

    function keyboardLayoutCode(name: string): string {
        const normalized = name.toLowerCase()
        if (normalized.indexOf("english") !== -1 && normalized.indexOf("us") !== -1) return "US"
        if (normalized.indexOf("russian") !== -1) return "RU"
        if (normalized.indexOf("kazakh") !== -1) return "KK"
        return name.length >= 2 ? name.slice(0, 2).toUpperCase() : "--"
    }

    function keyboardLayoutColor(name: string): color {
        const code = keyboardLayoutCode(name)
        if (code === "US") return layoutUs
        if (code === "RU") return layoutRu
        if (code === "KK") return layoutKk
        return accent
    }

    function keyboardLayoutForeground(name: string): color {
        return keyboardLayoutCode(name) === "KK" ? "#171817" : "#ffffff"
    }

    function keyboardLayoutLabel(name: string): string {
        const normalized = name.toLowerCase()
        if (normalized.indexOf("english") !== -1) return "English"
        if (normalized.indexOf("russian") !== -1) return "Русский"
        if (normalized.indexOf("kazakh") !== -1) return "Қазақша"
        return name
    }

    function presentKeyboardLayout(screen: string): string {
        if (niriService.keyboardLayout === "") return "unavailable"
        root.kind = "keyboard"
        root.keyboardLayoutName = niriService.keyboardLayout
        root.muted = false
        root.warning = false
        root.value = 1
        root.targetScreen = screen === "" ? niriService.focusedOutput : screen
        root.reveal(1100)
        return root.keyboardLayoutCode(root.keyboardLayoutName)
    }

    function presentAudioFeedback(value: real, muted: bool, screen: string): void {
        root.kind = "volume"
        root.value = Math.max(0, Math.min(audioService.maxVolume, value))
        root.muted = muted
        root.warning = false
        root.targetScreen = screen === "" ? niriService.focusedOutput : screen
        root.reveal(1800)
    }

    function adjustAudioVolume(delta: real, screen: string): string {
        const requested = Math.max(0, Math.min(audioService.maxVolume, audioService.volume + delta))
        if (!audioService.setVolume(requested)) return "unavailable"
        root.presentAudioFeedback(requested, audioService.muted, screen)
        return String(Math.round(requested * 100))
    }

    function toggleAudioMuteWithFeedback(screen: string): string {
        const requestedMuted = !audioService.muted
        if (!audioService.toggleMute()) return "unavailable"
        root.presentAudioFeedback(audioService.volume, requestedMuted, screen)
        return requestedMuted ? "muted" : "unmuted"
    }

    function code(): string {
        if (kind === "microphone") return "MIC"
        if (kind === "brightness") return "BRT"
        if (kind === "renderer") return "GPU"
        if (kind === "keyboard") return "KEY"
        return "VOL"
    }

    function title(): string {
        if (kind === "microphone") return "Microphone"
        if (kind === "brightness") return "Display brightness"
        if (kind === "renderer") return renderer
        if (kind === "keyboard") return "Input source"
        return "System volume"
    }

    function valueLabel(): string {
        if (kind === "renderer") return profile
        if (kind === "keyboard") return keyboardLayoutCode(keyboardLayoutName)
        if (muted) return "Muted"
        return Math.round(value * 100) + "%"
    }

    function detail(): string {
        if (kind === "renderer") return statusText
        if (kind === "keyboard") return keyboardLayoutLabel(keyboardLayoutName)
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

    function setRailPreview(screen: string, active: bool): void {
        if (active) {
            railPreviewScreen = screen
        } else if (railPreviewScreen === screen) {
            railPreviewScreen = ""
        }
    }

    function setRailExpanded(expanded: bool, screen: string): void {
        railPinned = expanded
        railExpansionScreen = expanded ? screen : ""
        if (expanded) railPreviewScreen = ""
    }

    function toggleRailFor(screen: string): bool {
        const shouldOpen = !railPinned || railExpansionScreen !== screen
        setRailExpanded(shouldOpen, screen)
        return shouldOpen
    }

    function selectSurface(surface: string): string {
        const requested = surface.trim().toLowerCase()
        if (requested !== "system" && requested !== "media" && requested !== "audio" && requested !== "tray") return "unsupported:" + requested
        if (requested === "media" && !mediaPlayer) return "unavailable:media"
        if (requested === "audio" && !audioService.sinkReady) return "unavailable:audio"
        if (requested === "tray" && trayService.itemCount === 0) return "unavailable:tray"
        activeSurface = requested
        return activeSurface
    }

    function showRailSurface(surface: string, screen: string): string {
        const selected = selectSurface(surface)
        if (selected.indexOf(":") !== -1) return selected
        const target = screen === "" ? niriService.focusedOutput : screen
        setRailExpanded(true, target)
        return "pinned:" + target + ":" + activeSurface
    }

    function toggleRailSurface(surface: string, screen: string): string {
        const requested = surface.trim().toLowerCase()
        const wasSamePinnedSurface = railPinned && railExpansionScreen === (screen === "" ? niriService.focusedOutput : screen) && activeSurface === requested
        const selected = selectSurface(surface)
        if (selected.indexOf(":") !== -1) return selected
        const target = screen === "" ? niriService.focusedOutput : screen
        if (wasSamePinnedSurface) {
            setRailExpanded(false, target)
            return "collapsed:" + activeSurface
        }
        setRailExpanded(true, target)
        return "pinned:" + target + ":" + activeSurface
    }

    IpcHandler {
        target: "sidecar"

        function showOsd(kind: string, value: real, muted: bool, screen: string): void {
            root.kind = kind
            root.value = Math.max(0, Math.min(1, value))
            if (kind === "brightness") brightnessService.acceptValue(root.value)
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

        function setRailVisible(visible: bool): void {
            root.railVisible = visible
        }

        function toggleRail(): bool {
            root.railVisible = !root.railVisible
            return root.railVisible
        }

        function getRailVisible(): bool {
            return root.railVisible
        }

        function setRailExpanded(expanded: bool, screen: string): string {
            const target = screen === "" ? niriService.focusedOutput : screen
            root.setRailExpanded(expanded, target)
            return root.railPinned ? "pinned:" + root.railExpansionScreen : "collapsed"
        }

        function toggleRailExpanded(screen: string): string {
            const target = screen === "" ? niriService.focusedOutput : screen
            root.toggleRailFor(target)
            return root.railPinned ? "pinned:" + root.railExpansionScreen : "collapsed"
        }

        function getRailExpansion(): string {
            if (root.railPinned) return "pinned:" + root.railExpansionScreen
            if (root.railPreviewScreen !== "") return "preview:" + root.railPreviewScreen
            return "collapsed"
        }

        function getActiveSurface(): string {
            return root.activeSurface
        }

        function setActiveSurface(surface: string): string {
            return root.selectSurface(surface)
        }

        function showSurface(surface: string, screen: string): string {
            return root.showRailSurface(surface, screen)
        }

        function toggleSurface(surface: string, screen: string): string {
            return root.toggleRailSurface(surface, screen)
        }

        function getNiriState(): string {
            return niriService.ready ? "ready:" + niriService.focusedOutput : "waiting"
        }

        function getKeyboardLayout(): string {
            return niriService.keyboardLayout
        }

        function showKeyboardLayout(screen: string): string {
            return root.presentKeyboardLayout(screen)
        }

        function getMediaState(): string {
            if (!root.mediaPlayer) return "unavailable"
            return JSON.stringify({
                "identity": root.mediaPlayer.identity,
                "desktopEntry": root.mediaPlayer.desktopEntry,
                "title": root.mediaPlayer.trackTitle,
                "artist": root.mediaPlayer.trackArtist,
                "playing": root.mediaPlayer.playbackState === MprisPlaybackState.Playing,
                "position": root.mediaPlayer.position,
                "length": root.mediaPlayer.length
            })
        }

        function getAudioState(): string {
            return JSON.stringify(audioService.state())
        }

        function setAudioVolume(value: real): string {
            return audioService.setVolume(value) ? "requested" : "unavailable"
        }

        function toggleAudioMute(): string {
            return audioService.toggleMute() ? "requested" : "unavailable"
        }

        function adjustAudioVolume(delta: real, screen: string): string {
            return root.adjustAudioVolume(delta, screen)
        }

        function toggleAudioMuteWithFeedback(screen: string): string {
            return root.toggleAudioMuteWithFeedback(screen)
        }

        function getBrightnessState(): string {
            return brightnessService.ready ? String(brightnessService.percent) : "unavailable"
        }

        function adjustBrightness(step: int, screen: string): string {
            return brightnessService.adjust(step, screen) ? "requested" : "busy"
        }

        function setMicrophoneVolume(value: real): string {
            return audioService.setSourceVolume(value) ? "requested" : "unavailable"
        }

        function toggleMicrophoneMute(): string {
            return audioService.toggleSourceMute() ? "requested" : "unavailable"
        }

        function selectAudioSink(id: int): string {
            return audioService.selectSink(id) ? "requested:" + String(id) : "unavailable:" + String(id)
        }

        function selectMicrophoneSource(id: int): string {
            return audioService.selectSource(id) ? "requested:" + String(id) : "unavailable:" + String(id)
        }

        function getTrayState(): string {
            return JSON.stringify(trayService.snapshot())
        }

        function activateTrayItem(index: int): string {
            return trayService.activate(index) ? "requested:" + String(index) : "unavailable:" + String(index)
        }

        function secondaryActivateTrayItem(index: int): string {
            return trayService.secondaryActivate(index) ? "requested:" + String(index) : "unavailable:" + String(index)
        }

        function openTrayItemMenu(index: int, screen: string): string {
            const item = trayService.itemAt(index)
            if (!item || !item.hasMenu) return "unavailable:" + String(index)
            const target = screen === "" ? niriService.focusedOutput : screen
            root.trayInlineMenuRequested(index, target)
            return "requested:" + String(index) + ":" + target
        }

        function toggleMedia(): string {
            if (!root.mediaPlayer || !root.mediaPlayer.canTogglePlaying) return "unavailable"
            root.mediaPlayer.togglePlaying()
            return "requested"
        }

        function previousMedia(): string {
            if (!root.mediaPlayer || !root.mediaPlayer.canGoPrevious) return "unavailable"
            root.mediaPlayer.previous()
            return "requested"
        }

        function nextMedia(): string {
            if (!root.mediaPlayer || !root.mediaPlayer.canGoNext) return "unavailable"
            root.mediaPlayer.next()
            return "requested"
        }

        function getWorkspaces(): string {
            return JSON.stringify(niriService.workspaces)
        }

        function getOsdState(): string {
            return JSON.stringify({
                "visible": root.windowVisible,
                "presenting": root.presenting,
                "kind": root.kind,
                "profile": root.profile,
                "renderer": root.renderer,
                "status": root.statusText,
                "warning": root.warning,
                "screen": root.targetScreen
            })
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

        Rail {
            required property var modelData

            outputScreen: modelData
            niriState: niriService
            railController: root
            mediaPlayer: root.mediaPlayer
            audioState: audioService
            brightnessState: brightnessService
            trayState: trayService
            shellDark: root.dark
            railEnabled: root.railVisible
        }
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
                        visible: root.kind !== "keyboard"
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

                    Row {
                        id: layoutOptions
                        visible: root.kind === "keyboard"
                        x: 72
                        y: 62
                        spacing: 7

                        Repeater {
                            model: niriService.keyboardLayouts

                            Rectangle {
                                required property string modelData
                                readonly property bool active: modelData === root.keyboardLayoutName
                                width: 48
                                height: 18
                                radius: 5
                                color: active ? root.keyboardLayoutColor(modelData) : root.track

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.keyboardLayoutCode(parent.modelData)
                                    color: parent.active ? root.keyboardLayoutForeground(parent.modelData) : root.mutedForeground
                                    font.family: "GeistMono Nerd Font"
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
