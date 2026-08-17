import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick

import "services"
import "windows"

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
    property bool launcherVisible: false
    property string launcherScreen: ""

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

    Binding {
        target: Theme
        property: "dark"
        value: root.dark
    }

    Connections {
        target: AudioService

        function onSinkReadyChanged(): void {
            if (!AudioService.sinkReady && root.activeSurface === "audio")
                root.activeSurface = "system"
        }
    }

    Connections {
        target: BrightnessService

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
        target: TrayService

        function onItemCountChanged(): void {
            if (TrayService.itemCount === 0 && root.activeSurface === "tray")
                root.activeSurface = "system"
        }
    }

    Connections {
        target: NiriService

        function onKeyboardLayoutChanged(): void {
            if (NiriService.keyboardLayout === "") return
            root.keyboardLayoutName = NiriService.keyboardLayout
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
        if (code === "US") return Theme.layoutUs
        if (code === "RU") return Theme.layoutRu
        if (code === "KK") return Theme.layoutKk
        return Theme.accent
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
        if (NiriService.keyboardLayout === "") return "unavailable"
        root.kind = "keyboard"
        root.keyboardLayoutName = NiriService.keyboardLayout
        root.muted = false
        root.warning = false
        root.value = 1
        root.targetScreen = screen === "" ? NiriService.focusedOutput : screen
        root.reveal(1100)
        return root.keyboardLayoutCode(root.keyboardLayoutName)
    }

    function presentAudioFeedback(value: real, muted: bool, screen: string): void {
        root.kind = "volume"
        root.value = Math.max(0, Math.min(AudioService.maxVolume, value))
        root.muted = muted
        root.warning = false
        root.targetScreen = screen === "" ? NiriService.focusedOutput : screen
        root.reveal(1800)
    }

    function adjustAudioVolume(delta: real, screen: string): string {
        const requested = Math.max(0, Math.min(AudioService.maxVolume, AudioService.volume + delta))
        if (!AudioService.setVolume(requested)) return "unavailable"
        root.presentAudioFeedback(requested, AudioService.muted, screen)
        return String(Math.round(requested * 100))
    }

    function toggleAudioMuteWithFeedback(screen: string): string {
        const requestedMuted = !AudioService.muted
        if (!AudioService.toggleMute()) return "unavailable"
        root.presentAudioFeedback(AudioService.volume, requestedMuted, screen)
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

    function showLauncher(screen: string): string {
        const target = screen === "" ? NiriService.focusedOutput : screen
        launcherScreen = target
        launcherVisible = true
        return "shown:" + target
    }

    function hideLauncher(): string {
        launcherVisible = false
        launcherScreen = ""
        return "hidden"
    }

    function toggleLauncher(screen: string): string {
        const target = screen === "" ? NiriService.focusedOutput : screen
        if (launcherVisible && launcherScreen === target) return hideLauncher()
        return showLauncher(target)
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
        if (requested === "audio" && !AudioService.sinkReady) return "unavailable:audio"
        if (requested === "tray" && TrayService.itemCount === 0) return "unavailable:tray"
        activeSurface = requested
        return activeSurface
    }

    function showRailSurface(surface: string, screen: string): string {
        const selected = selectSurface(surface)
        if (selected.indexOf(":") !== -1) return selected
        const target = screen === "" ? NiriService.focusedOutput : screen
        setRailExpanded(true, target)
        return "pinned:" + target + ":" + activeSurface
    }

    function toggleRailSurface(surface: string, screen: string): string {
        const requested = surface.trim().toLowerCase()
        const wasSamePinnedSurface = railPinned && railExpansionScreen === (screen === "" ? NiriService.focusedOutput : screen) && activeSurface === requested
        const selected = selectSurface(surface)
        if (selected.indexOf(":") !== -1) return selected
        const target = screen === "" ? NiriService.focusedOutput : screen
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
            if (kind === "brightness") BrightnessService.acceptValue(root.value)
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

        function showLauncher(screen: string): string {
            return root.showLauncher(screen)
        }

        function hideLauncher(): string {
            return root.hideLauncher()
        }

        function toggleLauncher(screen: string): string {
            return root.toggleLauncher(screen)
        }

        function getLauncherState(): string {
            return root.launcherVisible ? "shown:" + root.launcherScreen : "hidden"
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
            const target = screen === "" ? NiriService.focusedOutput : screen
            root.setRailExpanded(expanded, target)
            return root.railPinned ? "pinned:" + root.railExpansionScreen : "collapsed"
        }

        function toggleRailExpanded(screen: string): string {
            const target = screen === "" ? NiriService.focusedOutput : screen
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
            return NiriService.ready ? "ready:" + NiriService.focusedOutput : "waiting"
        }

        function getKeyboardLayout(): string {
            return NiriService.keyboardLayout
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
            return JSON.stringify(AudioService.state())
        }

        function setAudioVolume(value: real): string {
            return AudioService.setVolume(value) ? "requested" : "unavailable"
        }

        function toggleAudioMute(): string {
            return AudioService.toggleMute() ? "requested" : "unavailable"
        }

        function adjustAudioVolume(delta: real, screen: string): string {
            return root.adjustAudioVolume(delta, screen)
        }

        function toggleAudioMuteWithFeedback(screen: string): string {
            return root.toggleAudioMuteWithFeedback(screen)
        }

        function getBrightnessState(): string {
            return BrightnessService.ready ? String(BrightnessService.percent) : "unavailable"
        }

        function adjustBrightness(step: int, screen: string): string {
            return BrightnessService.adjust(step, screen) ? "requested" : "busy"
        }

        function setMicrophoneVolume(value: real): string {
            return AudioService.setSourceVolume(value) ? "requested" : "unavailable"
        }

        function toggleMicrophoneMute(): string {
            return AudioService.toggleSourceMute() ? "requested" : "unavailable"
        }

        function selectAudioSink(id: int): string {
            return AudioService.selectSink(id) ? "requested:" + String(id) : "unavailable:" + String(id)
        }

        function selectMicrophoneSource(id: int): string {
            return AudioService.selectSource(id) ? "requested:" + String(id) : "unavailable:" + String(id)
        }

        function getTrayState(): string {
            return JSON.stringify(TrayService.snapshot())
        }

        function activateTrayItem(index: int): string {
            return TrayService.activate(index) ? "requested:" + String(index) : "unavailable:" + String(index)
        }

        function secondaryActivateTrayItem(index: int): string {
            return TrayService.secondaryActivate(index) ? "requested:" + String(index) : "unavailable:" + String(index)
        }

        function openTrayItemMenu(index: int, screen: string): string {
            const item = TrayService.itemAt(index)
            if (!item || !item.hasMenu) return "unavailable:" + String(index)
            const target = screen === "" ? NiriService.focusedOutput : screen
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
            return JSON.stringify(NiriService.workspaces)
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
            railController: root
            mediaPlayer: root.mediaPlayer
        }
    }

    Variants {
        model: Quickshell.screens

        Launcher {
            required property var modelData

            outputScreen: modelData
            launcherController: root
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
                    color: Theme.background
                    border.width: 1
                    border.color: root.warning ? Theme.warningAccent : Theme.border
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
                        color: root.warning ? Theme.warningAccent : Theme.accent
                    }

                    Text {
                        x: 18
                        y: 18
                        width: 38
                        text: root.code()
                        color: root.warning ? Theme.warningAccent : Theme.accent
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
                        color: Theme.foreground
                        elide: Text.ElideRight
                        font.family: "IBM Plex Sans"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        id: keyboardValueTile
                        visible: root.kind === "keyboard"
                        x: parent.width - 66
                        y: 11
                        width: 46
                        height: 22
                        radius: 6
                        color: root.keyboardLayoutColor(root.keyboardLayoutName)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: root.valueLabel()
                            color: root.keyboardLayoutForeground(root.keyboardLayoutName)
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        visible: root.kind !== "keyboard"
                        x: parent.width - 82
                        y: 15
                        width: 62
                        horizontalAlignment: Text.AlignRight
                        text: root.valueLabel()
                        color: root.warning ? Theme.warningAccent : Theme.foreground
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: root.kind === "renderer" ? 10 : 13
                        font.weight: Font.Medium
                    }

                    Text {
                        x: 72
                        y: 39
                        width: parent.width - 94
                        text: root.detail()
                        color: Theme.mutedForeground
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
                        color: Theme.track

                        Rectangle {
                            width: Math.max(0, Math.min(1, root.value)) * parent.width
                            height: parent.height
                            radius: 1
                            color: root.warning ? Theme.warningAccent : Theme.accent

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
                            color: Theme.foreground

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
                            model: NiriService.keyboardLayouts

                            Rectangle {
                                required property string modelData
                                readonly property bool active: modelData === root.keyboardLayoutName
                                width: 48
                                height: 18
                                radius: 5
                                color: active ? root.keyboardLayoutColor(modelData) : Theme.track

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: root.keyboardLayoutCode(parent.modelData)
                                    color: parent.active ? root.keyboardLayoutForeground(parent.modelData) : Theme.mutedForeground
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
