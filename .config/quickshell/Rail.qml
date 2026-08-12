pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: rail

    required property var outputScreen
    required property var niriState
    required property var railController
    required property var mediaPlayer
    required property var audioState
    required property var brightnessState
    required property var trayState
    required property bool shellDark
    required property bool railEnabled

    readonly property int compactWidth: 46
    readonly property int maxDrawerWidth: 394
    readonly property bool hasMedia: mediaPlayer !== null
    readonly property string activeSurface: String(railController.activeSurface || "system")
    readonly property bool showingMedia: activeSurface === "media" && hasMedia
    readonly property bool showingAudio: activeSurface === "audio" && audioState.sinkReady
    readonly property bool showingTray: activeSurface === "tray" && trayState.itemCount > 0
    readonly property string audioSinkLabel: audioState.label(audioState.sink)
    readonly property string audioSinkKind: audioState.kind(audioState.sink)
    readonly property url audioIconSource: Qt.resolvedUrl(audioState.muted ? "icons/iconoir/sound-off.svg" : "icons/iconoir/sound-high.svg")
    readonly property url brightnessIconSource: Qt.resolvedUrl("icons/iconoir/brightness.svg")
    readonly property bool mediaPlaying: hasMedia && mediaPlayer.playbackState === MprisPlaybackState.Playing
    readonly property string mediaIdentity: hasMedia ? String(mediaPlayer.identity) : ""
    readonly property string mediaDesktopEntryId: hasMedia ? String(mediaPlayer.desktopEntry) : ""
    readonly property var mediaApplication: hasMedia ? DesktopEntries.heuristicLookup(mediaDesktopEntryId || mediaIdentity) : null
    readonly property string mediaApplicationName: mediaApplication ? String(mediaApplication.name).replace(" (Launcher)", "") : mediaIdentity
    readonly property string mediaIconName: {
        const key = (mediaDesktopEntryId + " " + mediaIdentity).toLowerCase()
        if (key.indexOf("spotify") !== -1) return "spotify-launcher"
        if (key.indexOf("helium") !== -1) return "helium-browser"
        return mediaApplication ? String(mediaApplication.icon) : mediaDesktopEntryId
    }
    readonly property string mediaIconSource: mediaIconName !== "" ? Quickshell.iconPath(mediaIconName, true) : ""
    readonly property url trayIconSource: Qt.resolvedUrl("icons/iconoir/app-notification.svg")
    readonly property url trayBackIconSource: Qt.resolvedUrl("icons/iconoir/nav-arrow-left.svg")
    readonly property url trayForwardIconSource: Qt.resolvedUrl("icons/iconoir/nav-arrow-right.svg")
    property var trayMenuOwner: null
    property var trayMenuHandle: null
    property var trayMenuStack: []
    readonly property bool showingTrayMenu: showingTray && trayMenuOwner !== null && trayMenuHandle !== null
    readonly property string mediaTitle: hasMedia ? String(mediaPlayer.trackTitle) : ""
    readonly property string mediaArtist: hasMedia ? String(mediaPlayer.trackArtist) : ""
    readonly property string mediaAlbum: hasMedia ? String(mediaPlayer.trackAlbum) : ""
    readonly property string mediaArtUrl: hasMedia ? String(mediaPlayer.trackArtUrl) : ""
    readonly property real mediaPosition: hasMedia ? mediaPlayer.position : 0
    readonly property real mediaLength: hasMedia ? mediaPlayer.length : 0
    readonly property bool mediaCanPrevious: hasMedia && mediaPlayer.canGoPrevious
    readonly property bool mediaCanToggle: hasMedia && mediaPlayer.canTogglePlaying
    readonly property bool mediaCanNext: hasMedia && mediaPlayer.canGoNext
    readonly property real mediaProgress: hasMedia && mediaPlayer.lengthSupported && mediaLength > 0 ? Math.max(0, Math.min(1, mediaPosition / mediaLength)) : 0
    property real drawerWidth: showingAudio ? 394 : (showingMedia ? 360 : (showingTray ? 344 : 304))
    readonly property bool externallyPinned: railController.railPinned && railController.railExpansionScreen === outputScreen.name
    readonly property bool previewing: railController.railPreviewScreen === outputScreen.name
    readonly property bool expanded: externallyPinned || previewing
    property real revealProgress: expanded ? 1 : 0
    readonly property real interactiveWidth: compactWidth + drawerWidth * revealProgress
    readonly property bool outputFocused: niriState.focusedOutput === outputScreen.name
    property real outputFocusPulse: 0

    readonly property color background: shellDark ? "#171817" : "#f4f2ee"
    readonly property color surface: shellDark ? "#222321" : "#e9e6df"
    readonly property color raisedSurface: shellDark ? "#292a28" : "#dfdcd5"
    readonly property color foreground: shellDark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: shellDark ? "#8f918b" : "#6e706a"
    readonly property color border: shellDark ? "#343633" : "#d6d3cc"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property color layoutUs: "#356ea3"
    readonly property color layoutRu: shellDark ? "#b53f37" : "#a93832"
    readonly property color layoutKk: shellDark ? "#d0a13c" : "#bd841e"
    readonly property var screenWorkspaces: niriState.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercentage: battery.ready ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery.ready && battery.state === UPowerDeviceState.Charging

    screen: outputScreen
    visible: railEnabled
    implicitWidth: compactWidth + maxDrawerWidth
    color: "transparent"
    exclusiveZone: compactWidth
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        x: Math.floor(rail.width - rail.interactiveWidth)
        width: Math.ceil(rail.interactiveWidth)
        height: rail.height
    }

    anchors {
        right: true
        top: true
        bottom: true
    }

    Behavior on drawerWidth {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Behavior on revealProgress {
        NumberAnimation {
            duration: 230
            easing.type: Easing.OutCubic
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process { id: workspaceAction }
    Process { id: rendererAction }
    Process { id: layoutAction }

    Timer {
        id: previewTimer
        interval: 130
        repeat: false
        onTriggered: {
            if (!rail.externallyPinned && railHover.hovered)
                rail.railController.setRailPreview(rail.outputScreen.name, true)
        }
    }

    Timer {
        id: collapseTimer
        interval: 260
        repeat: false
        onTriggered: {
            if (!rail.externallyPinned && !railHover.hovered)
                rail.railController.setRailPreview(rail.outputScreen.name, false)
        }
    }

    SequentialAnimation {
        id: outputFocusPulseAnimation

        NumberAnimation {
            target: rail
            property: "outputFocusPulse"
            from: 0
            to: 1
            duration: 110
            easing.type: Easing.OutCubic
        }

        PauseAnimation { duration: 90 }

        NumberAnimation {
            target: rail
            property: "outputFocusPulse"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    onOutputFocusedChanged: {
        if (outputFocused)
            outputFocusPulseAnimation.restart()
    }

    HoverHandler {
        id: railHover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
                if (!rail.expanded) previewTimer.restart()
            } else {
                previewTimer.stop()
                if (!rail.externallyPinned) collapseTimer.restart()
            }
        }
    }

    function focusWorkspace(output: string, index: int): void {
        workspaceAction.exec([
            "/usr/sbin/bash",
            "-c",
            "/usr/sbin/niri msg action focus-monitor \"$1\" && /usr/sbin/niri msg action focus-workspace \"$2\"",
            "quickshell-rail",
            output,
            String(index)
        ])
    }

    function focusedWorkspaceLabel(): string {
        for (let index = 0; index < screenWorkspaces.length; ++index) {
            const workspace = screenWorkspaces[index]
            if (workspace.is_focused)
                return workspace.name !== "" ? workspace.name : String(workspace.idx)
        }
        return "—"
    }

    function outputIdentity(): string {
        if (outputScreen.name === "eDP-1") return "LAP"
        if (outputScreen.name.indexOf("HDMI") === 0) return "EXT"
        const name = String(outputScreen.name || "OUT")
        return name.slice(0, 3).toUpperCase()
    }

    function keyboardLayoutCode(): string {
        const name = String(niriState.keyboardLayout || "")
        const normalized = name.toLowerCase()
        if (normalized.indexOf("english") !== -1 && normalized.indexOf("us") !== -1) return "US"
        if (normalized.indexOf("russian") !== -1) return "RU"
        if (normalized.indexOf("kazakh") !== -1) return "KK"
        return name.length >= 2 ? name.slice(0, 2).toUpperCase() : "--"
    }

    function keyboardLayoutColor(): color {
        const code = keyboardLayoutCode()
        if (code === "US") return layoutUs
        if (code === "RU") return layoutRu
        if (code === "KK") return layoutKk
        return foreground
    }

    function keyboardLayoutForeground(): color {
        return keyboardLayoutCode() === "KK" ? "#171817" : "#ffffff"
    }

    function switchKeyboardLayout(): void {
        if (!layoutAction.running)
            layoutAction.exec(["/usr/sbin/niri", "msg", "action", "switch-layout", "next"])
    }

    function formatDuration(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0) return "--:--"
        const minutes = Math.floor(seconds / 60)
        const remainder = Math.floor(seconds % 60)
        return String(minutes) + ":" + (remainder < 10 ? "0" : "") + String(remainder)
    }

    function previousMedia(): void {
        if (mediaCanPrevious) mediaPlayer.previous()
    }

    function toggleMedia(): void {
        if (mediaCanToggle) mediaPlayer.togglePlaying()
    }

    function nextMedia(): void {
        if (mediaCanNext) mediaPlayer.next()
    }

    function setAudioVolume(value: real): void {
        audioState.setVolume(value)
    }

    function toggleAudioMute(): void {
        audioState.toggleMute()
    }

    function setMicrophoneVolume(value: real): void {
        audioState.setSourceVolume(value)
    }

    function toggleMicrophoneMute(): void {
        audioState.toggleSourceMute()
    }

    function selectAudioSink(id: int): void {
        audioState.selectSink(id)
    }

    function selectMicrophoneSource(id: int): void {
        audioState.selectSource(id)
    }

    function activateTrayItem(index: int): void {
        trayState.activate(index)
    }

    function openTrayMenu(item: var): void {
        if (!item || !item.hasMenu) return
        trayMenuOwner = item
        trayMenuStack = []
        trayMenuHandle = item.menu
    }

    function closeTrayMenu(): void {
        trayMenuHandle = null
        trayMenuOwner = null
        trayMenuStack = []
    }

    function enterTraySubmenu(entry: var): void {
        if (!entry || !entry.hasChildren) return
        trayMenuStack = trayMenuStack.concat([trayMenuHandle])
        trayMenuHandle = entry
    }

    function leaveTraySubmenu(): void {
        if (trayMenuStack.length === 0) {
            closeTrayMenu()
            return
        }
        const previous = trayMenuStack[trayMenuStack.length - 1]
        trayMenuStack = trayMenuStack.slice(0, -1)
        trayMenuHandle = previous
    }

    function triggerTrayMenuEntry(entry: var): void {
        if (!entry || !entry.enabled || entry.isSeparator) return
        if (entry.hasChildren) {
            enterTraySubmenu(entry)
            return
        }
        entry.triggered()
        closeTrayMenu()
    }

    QsMenuOpener {
        id: trayRootMenuOpener
        menu: rail.showingTrayMenu && rail.trayMenuOwner ? rail.trayMenuOwner.menu : null
    }

    QsMenuOpener {
        id: trayMenuOpener
        menu: rail.showingTrayMenu ? rail.trayMenuHandle : null
    }

    Connections {
        target: rail.railController

        function onTrayInlineMenuRequested(index: int, screen: string): void {
            if (screen === rail.outputScreen.name)
                rail.openTrayMenu(rail.trayState.itemAt(index))
        }

        function onActiveSurfaceChanged(): void {
            if (rail.activeSurface !== "tray")
                rail.closeTrayMenu()
        }
    }

    Rectangle {
        id: drawer
        width: rail.drawerWidth * rail.revealProgress
        x: rail.maxDrawerWidth - width
        height: parent.height
        color: rail.surface
        clip: true

        Item {
            id: drawerContent
            property real slideOffset: rail.expanded ? 0 : 14

            width: rail.drawerWidth
            height: parent.height
            x: parent.width - width + slideOffset
            opacity: rail.revealProgress

            Behavior on slideOffset {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 155; easing.type: Easing.OutCubic }
            }

            Row {
                id: drawerEyebrow
                x: 22
                y: 20
                spacing: 6

                Text {
                    text: rail.showingAudio ? "AUDIO /" : (rail.showingMedia ? "MEDIA /" : (rail.showingTray ? "TRAY /" : "RAIL / " + rail.outputScreen.name))
                    color: rail.accent
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }

                Image {
                    visible: rail.showingAudio || rail.showingTray || (rail.showingMedia && rail.mediaIconSource !== "")
                    width: 13
                    height: 13
                    source: rail.showingAudio ? rail.audioIconSource : (rail.showingTray ? rail.trayIconSource : rail.mediaIconSource)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    visible: rail.showingMedia || rail.showingAudio || rail.showingTray
                    text: rail.showingAudio ? "PIPEWIRE" : (rail.showingTray ? "SERVICES" : rail.mediaApplicationName.toUpperCase())
                    color: rail.accent
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }
            }

            Text {
                id: drawerMode
                anchors.right: parent.right
                anchors.rightMargin: 22
                y: 22
                text: rail.showingAudio ? (rail.audioState.muted ? "MUTED" : String(rail.audioState.volumePercent) + "%") : (rail.showingMedia ? (rail.mediaPlaying ? "PLAYING" : "PAUSED") : (rail.showingTray ? (rail.showingTrayMenu ? "MENU" : String(rail.trayState.itemCount) + " LIVE") : (rail.externallyPinned ? "PINNED" : "PREVIEW")))
                color: rail.externallyPinned ? rail.foreground : rail.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Rectangle {
                x: 22
                y: 45
                width: rail.expanded ? 92 : 18
                height: 2
                radius: 1
                color: rail.accent

                Behavior on width {
                    NumberAnimation { duration: 310; easing.type: Easing.OutCubic }
                }
            }

            Text {
                x: 22
                y: 74
                width: parent.width - 44
                text: rail.showingAudio ? rail.audioSinkLabel : (rail.showingMedia ? rail.mediaTitle : (rail.showingTray ? (rail.showingTrayMenu ? rail.trayState.label(rail.trayMenuOwner) : "Background services") : "Open state"))
                elide: Text.ElideRight
                color: rail.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }

            Text {
                x: 22
                y: 108
                width: parent.width - 44
                text: rail.showingAudio ? rail.audioSinkKind + " / DEFAULT OUTPUT" : (rail.showingMedia ? (rail.mediaArtist || rail.mediaAlbum) : (rail.showingTray ? (rail.showingTrayMenu ? "Application actions" : "Native app actions and menus") : (rail.externallyPinned ? "The rail stays open." : "Move across the surface.")))
                elide: Text.ElideRight
                color: rail.mutedForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }

            Column {
                visible: !rail.showingMedia && !rail.showingAudio && !rail.showingTray
                x: 22
                y: 164
                width: parent.width - 44
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 12
                    color: rail.raisedSurface
                    border.width: 1
                    border.color: rail.border

                    Text {
                        x: 14
                        y: 12
                        text: "NIRI"
                        color: rail.niriState.ready ? rail.accent : rail.warningAccent
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Text {
                        x: 14
                        y: 30
                        text: rail.niriState.ready ? "Event stream connected" : "Waiting for compositor"
                        color: rail.foreground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 21
                        text: rail.focusedWorkspaceLabel()
                        color: rail.foreground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 12
                    color: "transparent"
                    border.width: 1
                    border.color: rail.border

                    Text {
                        x: 14
                        y: 12
                        text: "MOTION"
                        color: rail.mutedForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }

                    Text {
                        x: 14
                        y: 30
                        text: rail.externallyPinned ? "Click signal to release" : "Click signal to keep open"
                        color: rail.foreground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 12
                    }
                }
            }

            Item {
                visible: rail.showingTray && !rail.showingTrayMenu
                x: 22
                y: 158
                width: parent.width - 44
                height: Math.max(0, rail.trayState.itemCount * 74)

                Column {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        id: trayRepeater
                        model: rail.trayState.items

                        Rectangle {
                            id: trayItem
                            required property var modelData
                            required property int index
                            readonly property bool attention: rail.trayState.statusLabel(modelData) === "ATTENTION"

                            function openMenu(): void {
                                rail.openTrayMenu(modelData)
                            }

                            width: parent.width
                            height: 66
                            radius: 12
                            color: trayItemMouse.containsMouse ? rail.surface : rail.raisedSurface
                            border.width: 1
                            border.color: attention ? rail.warningAccent : rail.border

                            Image {
                                id: trayAppIcon
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                source: rail.trayState.iconSource(trayItem.modelData)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Text {
                                visible: trayAppIcon.status !== Image.Ready
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: rail.trayState.label(trayItem.modelData).slice(0, 1).toUpperCase()
                                color: rail.accent
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            Text {
                                x: 56
                                y: 12
                                width: parent.width - 146
                                text: rail.trayState.label(trayItem.modelData)
                                elide: Text.ElideRight
                                color: rail.foreground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Text {
                                x: 56
                                y: 35
                                width: parent.width - 146
                                text: rail.trayState.detail(trayItem.modelData)
                                elide: Text.ElideRight
                                color: rail.mutedForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 10
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 13
                                y: 10
                                text: trayItem.attention ? "ATTENTION" : rail.trayState.categoryLabel(trayItem.modelData)
                                color: trayItem.attention ? rail.warningAccent : rail.mutedForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.5
                            }

                            MouseArea {
                                id: trayItemMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                        trayItem.openMenu()
                                    } else {
                                        rail.activateTrayItem(trayItem.index)
                                    }
                                }
                            }

                            Rectangle {
                                visible: trayItem.modelData.hasMenu
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                y: 31
                                width: 56
                                height: 25
                                radius: 8
                                color: trayMenuMouse.containsMouse ? rail.background : "transparent"
                                border.width: 1
                                border.color: rail.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "MENU"
                                    color: rail.foreground
                                    font.family: "DejaVu Sans Mono"
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.5
                                }

                                MouseArea {
                                    id: trayMenuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: trayItem.openMenu()
                                }
                            }
                        }
                    }
                }
            }

            Item {
                visible: rail.showingTrayMenu
                x: 22
                y: 150
                width: parent.width - 44
                height: Math.max(180, parent.height - 224)

                Rectangle {
                    id: trayMenuBack
                    width: parent.width
                    height: 34
                    radius: 10
                    color: trayMenuBackMouse.containsMouse ? rail.raisedSurface : "transparent"
                    border.width: 1
                    border.color: rail.border

                    Image {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        source: rail.trayBackIconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        x: 32
                        anchors.verticalCenter: parent.verticalCenter
                        text: rail.trayMenuStack.length > 0 ? "BACK" : "SERVICES"
                        color: rail.foreground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.7
                    }

                    MouseArea {
                        id: trayMenuBackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.leaveTraySubmenu()
                    }
                }

                ListView {
                    id: trayMenuList
                    y: 44
                    width: parent.width
                    height: parent.height - 44
                    clip: true
                    spacing: 3
                    model: trayMenuOpener.children
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: trayAction
                        required property var modelData
                        required property int index
                        readonly property bool checkable: Number(modelData.buttonType) !== 0
                        readonly property bool checked: Number(modelData.checkState) === Number(Qt.Checked)

                        width: trayMenuList.width - (trayMenuList.contentHeight > trayMenuList.height ? 8 : 0)
                        height: modelData.isSeparator ? 13 : 39
                        opacity: modelData.enabled || modelData.isSeparator ? 1 : 0.42

                        Rectangle {
                            visible: trayAction.modelData.isSeparator
                            anchors.centerIn: parent
                            width: parent.width
                            height: 1
                            color: rail.border
                        }

                        Rectangle {
                            visible: !trayAction.modelData.isSeparator
                            anchors.fill: parent
                            radius: 9
                            color: trayActionMouse.containsMouse ? rail.raisedSurface : "transparent"
                            border.width: trayAction.modelData.hasChildren ? 1 : 0
                            border.color: rail.border
                        }

                        Rectangle {
                            visible: !trayAction.modelData.isSeparator && trayAction.checkable
                            x: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            radius: Number(trayAction.modelData.buttonType) === 2 ? 7 : 4
                            color: trayAction.checked ? rail.accent : "transparent"
                            border.width: 1
                            border.color: trayAction.checked ? rail.accent : rail.mutedForeground

                            Rectangle {
                                visible: trayAction.checked
                                anchors.centerIn: parent
                                width: 5
                                height: 5
                                radius: 3
                                color: rail.background
                            }
                        }

                        Text {
                            visible: !trayAction.modelData.isSeparator
                            x: 34
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (trayAction.modelData.hasChildren ? 64 : 44)
                            text: String(trayAction.modelData.text || "")
                            elide: Text.ElideRight
                            color: rail.foreground
                            font.family: "DejaVu Sans"
                            font.pixelSize: 11
                            font.weight: trayAction.modelData.hasChildren ? Font.DemiBold : Font.Normal
                        }

                        Image {
                            visible: !trayAction.modelData.isSeparator && trayAction.modelData.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            source: rail.trayForwardIconSource
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Timer {
                            id: traySubmenuHoverTimer
                            interval: 180
                            repeat: false
                            onTriggered: {
                                if (trayActionMouse.containsMouse && trayAction.modelData.hasChildren)
                                    rail.enterTraySubmenu(trayAction.modelData)
                            }
                        }

                        MouseArea {
                            id: trayActionMouse
                            visible: !trayAction.modelData.isSeparator
                            anchors.fill: parent
                            enabled: trayAction.modelData.enabled
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onEntered: {
                                if (trayAction.modelData.hasChildren)
                                    traySubmenuHoverTimer.start()
                            }
                            onExited: traySubmenuHoverTimer.stop()
                            onClicked: {
                                traySubmenuHoverTimer.stop()
                                rail.triggerTrayMenuEntry(trayAction.modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: rail.showingAudio
                x: 22
                y: 158
                width: parent.width - 44
                height: 144
                radius: 14
                color: rail.raisedSurface
                border.width: 1
                border.color: rail.border

                Text {
                    x: 14
                    y: 14
                    text: "OUTPUT LEVEL"
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 10
                    text: rail.audioState.muted ? "MUTED" : String(rail.audioState.volumePercent) + "%"
                    color: rail.audioState.muted ? rail.warningAccent : rail.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: audioTrack
                    x: 14
                    y: 50
                    width: parent.width - 28
                    height: 4
                    radius: 2
                    color: rail.border

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, rail.audioState.volume / rail.audioState.maxVolume))
                        height: parent.height
                        radius: 2
                        color: rail.audioState.muted ? rail.mutedForeground : rail.accent

                        Behavior on width {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * rail.audioState.volume / rail.audioState.maxVolume - width / 2))
                        y: -3
                        width: 10
                        height: 10
                        radius: 5
                        color: rail.foreground

                        Behavior on x {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        x: Math.round(parent.width / rail.audioState.maxVolume) - 1
                        y: -3
                        width: 1
                        height: 10
                        color: rail.mutedForeground
                        opacity: 0.55
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => rail.setAudioVolume(mouse.x / width * rail.audioState.maxVolume)
                        onPositionChanged: mouse => {
                            if (pressed) rail.setAudioVolume(mouse.x / width * rail.audioState.maxVolume)
                        }
                    }
                }

                Rectangle {
                    x: 14
                    y: 82
                    width: parent.width - 28
                    height: 44
                    radius: 10
                    color: audioMuteMouse.containsMouse ? rail.surface : "transparent"
                    border.width: 1
                    border.color: rail.audioState.muted ? rail.warningAccent : rail.border

                    Text {
                        anchors.centerIn: parent
                        text: rail.audioState.muted ? "UNMUTE OUTPUT" : "MUTE OUTPUT"
                        color: rail.audioState.muted ? rail.warningAccent : rail.foreground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: audioMuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.toggleAudioMute()
                    }
                }
            }

            Item {
                visible: rail.showingAudio
                x: 22
                y: 330
                width: parent.width - 44
                height: 330

                Text {
                    x: 0
                    y: 0
                    text: "OUTPUT ROUTES / " + String(rail.audioState.sinks.length)
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Column {
                    x: 0
                    y: 28
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: rail.audioState.sinks

                        Rectangle {
                            id: routeItem
                            required property var modelData
                            readonly property bool active: rail.audioState.sink !== null && modelData.id === rail.audioState.sink.id
                            width: parent.width
                            height: 44
                            radius: 10
                            color: active ? rail.raisedSurface : (routeMouse.containsMouse ? rail.surface : "transparent")
                            border.width: active ? 1 : 0
                            border.color: rail.border

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 16
                                radius: 1
                                color: rail.accent
                                opacity: routeItem.active ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 112
                                text: rail.audioState.label(routeItem.modelData)
                                elide: Text.ElideRight
                                color: routeItem.active ? rail.foreground : rail.mutedForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 12
                                font.weight: routeItem.active ? Font.DemiBold : Font.Medium
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 82
                                horizontalAlignment: Text.AlignRight
                                text: routeItem.active ? "ACTIVE" : rail.audioState.kind(routeItem.modelData)
                                color: routeItem.active ? rail.accent : rail.mutedForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.5
                            }

                            MouseArea {
                                id: routeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rail.selectAudioSink(routeItem.modelData.id)
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: rail.showingAudio && rail.audioState.sourceReady
                x: 22
                y: 330 + 28 + rail.audioState.sinks.length * 44 + Math.max(0, rail.audioState.sinks.length - 1) * 7 + 22
                width: parent.width - 44
                height: 182 + Math.ceil(rail.audioState.sources.length / 2) * 48
                radius: 14
                color: rail.raisedSurface
                border.width: 1
                border.color: rail.border

                Text {
                    x: 14
                    y: 12
                    text: "INPUT / " + rail.audioState.kind(rail.audioState.source)
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 10
                    text: rail.audioState.sourceMuted ? "MUTED" : String(rail.audioState.sourceVolumePercent) + "%"
                    color: rail.audioState.sourceMuted ? rail.warningAccent : rail.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Text {
                    x: 14
                    y: 34
                    width: parent.width - 28
                    text: rail.audioState.label(rail.audioState.source)
                    elide: Text.ElideRight
                    color: rail.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: microphoneTrack
                    x: 14
                    y: 69
                    width: parent.width - 28
                    height: 4
                    radius: 2
                    color: rail.border

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, rail.audioState.sourceVolume / rail.audioState.maxSourceVolume))
                        height: parent.height
                        radius: 2
                        color: rail.audioState.sourceMuted ? rail.mutedForeground : rail.accent

                        Behavior on width {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * rail.audioState.sourceVolume / rail.audioState.maxSourceVolume - width / 2))
                        y: -3
                        width: 10
                        height: 10
                        radius: 5
                        color: rail.foreground

                        Behavior on x {
                            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                        }
                    }

                    Rectangle {
                        x: Math.round(parent.width / rail.audioState.maxSourceVolume) - 1
                        y: -3
                        width: 1
                        height: 10
                        color: rail.mutedForeground
                        opacity: 0.55
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -12
                        anchors.bottomMargin: -12
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => rail.setMicrophoneVolume(mouse.x / width * rail.audioState.maxSourceVolume)
                        onPositionChanged: mouse => {
                            if (pressed) rail.setMicrophoneVolume(mouse.x / width * rail.audioState.maxSourceVolume)
                        }
                    }
                }

                Rectangle {
                    x: 14
                    y: 96
                    width: parent.width - 28
                    height: 40
                    radius: 10
                    color: microphoneMuteMouse.containsMouse ? rail.surface : "transparent"
                    border.width: 1
                    border.color: rail.audioState.sourceMuted ? rail.warningAccent : rail.border

                    Text {
                        anchors.centerIn: parent
                        text: rail.audioState.sourceMuted ? "ENABLE INPUT" : "MUTE INPUT"
                        color: rail.audioState.sourceMuted ? rail.warningAccent : rail.foreground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: microphoneMuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.toggleMicrophoneMute()
                    }
                }

                Text {
                    x: 14
                    y: 151
                    text: "SOURCE ROUTES / " + String(rail.audioState.sources.length)
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }

                Grid {
                    x: 14
                    y: 173
                    width: parent.width - 28
                    columns: 2
                    columnSpacing: 7
                    rowSpacing: 6

                    Repeater {
                        model: rail.audioState.sources

                        Rectangle {
                            id: inputRouteItem
                            required property var modelData
                            readonly property bool active: rail.audioState.source !== null && modelData.id === rail.audioState.source.id
                            width: (parent.width - 7) / 2
                            height: 42
                            radius: 9
                            color: active ? rail.surface : (inputRouteMouse.containsMouse ? rail.surface : "transparent")
                            border.width: 1
                            border.color: active ? rail.border : Qt.rgba(0, 0, 0, 0)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 14
                                radius: 1
                                color: rail.accent
                                opacity: inputRouteItem.active ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                x: 11
                                y: 6
                                width: parent.width - 20
                                text: rail.audioState.label(inputRouteItem.modelData)
                                elide: Text.ElideRight
                                color: inputRouteItem.active ? rail.foreground : rail.mutedForeground
                                font.family: "DejaVu Sans"
                                font.pixelSize: 10
                                font.weight: inputRouteItem.active ? Font.DemiBold : Font.Medium
                            }

                            Text {
                                x: 11
                                y: 24
                                text: inputRouteItem.active ? "ACTIVE" : rail.audioState.kind(inputRouteItem.modelData)
                                color: inputRouteItem.active ? rail.accent : rail.mutedForeground
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 7
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.4
                            }

                            MouseArea {
                                id: inputRouteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!inputRouteItem.active)
                                        rail.selectMicrophoneSource(inputRouteItem.modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: rail.showingMedia
                x: 22
                y: 504
                width: parent.width - 44
                height: 142
                radius: 14
                color: rail.raisedSurface
                border.width: 1
                border.color: rail.border

                Text {
                    x: 14
                    y: 13
                    text: rail.mediaAlbum || "NOW PLAYING"
                    width: parent.width - 28
                    elide: Text.ElideRight
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }

                Rectangle {
                    id: mediaTrack
                    x: 14
                    y: 40
                    width: parent.width - 28
                    height: 2
                    radius: 1
                    color: rail.border

                    Rectangle {
                        width: parent.width * rail.mediaProgress
                        height: parent.height
                        radius: 1
                        color: rail.accent

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    x: 14
                    y: 49
                    text: rail.formatDuration(rail.mediaPosition)
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 8
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 49
                    text: rail.formatDuration(rail.mediaLength)
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 8
                }

                Row {
                    x: 14
                    y: 79
                    spacing: 8

                    Rectangle {
                        width: 76
                        height: 42
                        radius: 10
                        color: previousMouse.containsMouse ? rail.surface : "transparent"
                        border.width: 1
                        border.color: rail.border
                        opacity: rail.mediaCanPrevious ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: "PREV"
                            color: rail.foreground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: previousMouse
                            anchors.fill: parent
                            enabled: rail.mediaCanPrevious
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rail.previousMedia()
                        }
                    }

                    Rectangle {
                        width: 112
                        height: 42
                        radius: 10
                        color: playMouse.containsMouse ? rail.accent : rail.surface
                        border.width: 1
                        border.color: playMouse.containsMouse ? rail.accent : rail.border
                        opacity: rail.mediaCanToggle ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: rail.mediaPlaying ? "PAUSE" : "PLAY"
                            color: rail.foreground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            enabled: rail.mediaCanToggle
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rail.toggleMedia()
                        }
                    }

                    Rectangle {
                        width: 76
                        height: 42
                        radius: 10
                        color: nextMouse.containsMouse ? rail.surface : "transparent"
                        border.width: 1
                        border.color: rail.border
                        opacity: rail.mediaCanNext ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: "NEXT"
                            color: rail.foreground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            enabled: rail.mediaCanNext
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: rail.nextMedia()
                        }
                    }
                }
            }

            Rectangle {
                visible: rail.showingMedia
                x: 22
                y: 158
                width: parent.width - 44
                height: width
                color: rail.raisedSurface
                border.width: 1
                border.color: rail.border

                Text {
                    anchors.centerIn: parent
                    text: rail.mediaIdentity.toUpperCase()
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: rail.mediaArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                }
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.bottomMargin: 24
                height: 48

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: rail.border

                    Rectangle {
                        width: 24
                        height: 1
                        color: rail.accent
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: rail.externallyPinned ? "CLICK TO CLOSE" : "LEAVE TO COLLAPSE"
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: String(Math.round(rail.interactiveWidth)) + " PX"
                    color: rail.mutedForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                }
            }
        }
    }

    Rectangle {
        id: railBase
        x: rail.maxDrawerWidth
        width: rail.compactWidth
        height: parent.height
        color: rail.background

        Item {
            id: signal
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 30
            height: 38

            Column {
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: [14, 22, 9]

                    Rectangle {
                        required property int modelData
                        width: rail.expanded ? modelData + 3 : modelData
                        height: 2
                        radius: 1
                        color: rail.niriState.ready ? rail.accent : rail.warningAccent
                        opacity: rail.niriState.connected ? 1 : 0.45

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (!rail.externallyPinned)
                        rail.railController.selectSurface("system")
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        rendererAction.exec(["/home/ex1te/.config/quickshell/scripts/sidecarctl", "renderer"])
                    } else {
                        rail.railController.setRailPreview(rail.outputScreen.name, false)
                        rail.railController.toggleRailSurface("system", rail.outputScreen.name)
                    }
                }
            }
        }

        Rectangle {
            id: upperRule
            anchors.top: signal.bottom
            anchors.topMargin: 9
            anchors.horizontalCenter: parent.horizontalCenter
            width: 22
            height: 1
            color: rail.border

            Rectangle {
                anchors.left: parent.left
                width: 6
                height: 1
                color: rail.accent
            }
        }

        Text {
            id: outputIdentityLabel
            anchors.top: upperRule.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: rail.outputIdentity()
            color: rail.outputFocused ? rail.accent : rail.mutedForeground
            opacity: rail.outputFocused ? 1 : 0.64
            scale: 1 + rail.outputFocusPulse * 0.08
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        Column {
            id: workspaceColumn
            anchors.top: outputIdentityLabel.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: rail.screenWorkspaces

                Item {
                    id: workspaceItem
                    required property var modelData
                    width: 32
                    height: 32
                    opacity: rail.outputFocused || modelData.is_urgent ? 1 : 0.58

                    Behavior on opacity {
                        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: workspaceItem.modelData.is_active ? rail.surface : "transparent"
                        border.width: workspaceItem.modelData.is_active ? 1 : 0
                        border.color: rail.border
                        scale: workspaceMouse.containsMouse ? 1.06 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: workspaceItem.modelData.is_focused ? 15 : (workspaceItem.modelData.is_urgent ? 8 : 0)
                        radius: 1
                        color: workspaceItem.modelData.is_urgent ? rail.warningAccent : rail.accent

                        Behavior on height {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: workspaceItem.modelData.name !== "" ? workspaceItem.modelData.name.slice(0, 2) : String(workspaceItem.modelData.idx)
                        color: workspaceItem.modelData.is_active ? rail.foreground : rail.mutedForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 11
                        font.weight: workspaceItem.modelData.is_active ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rail.focusWorkspace(rail.outputScreen.name, workspaceItem.modelData.idx)
                    }
                }
            }
        }

        Rectangle {
            id: outputFocusSpine
            anchors.left: parent.left
            y: outputIdentityLabel.y - 4
            width: 2 + rail.outputFocusPulse
            height: outputIdentityLabel.height + 8 + workspaceColumn.height
            radius: 1
            color: rail.accent
            opacity: rail.outputFocused ? 0.72 + rail.outputFocusPulse * 0.28 : 0

            Behavior on opacity {
                NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
            }
        }

        Item {
            id: mediaEntry
            visible: rail.hasMedia
            anchors.top: workspaceColumn.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32
            scale: mediaEntryMouse.containsMouse ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "media" ? rail.surface : "transparent"
                border.width: rail.activeSurface === "media" ? 1 : 0
                border.color: rail.border

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "media" ? 15 : 0
                radius: 1
                color: rail.accent

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            Image {
                visible: rail.mediaIconSource !== ""
                anchors.centerIn: parent
                width: 16
                height: 16
                source: rail.mediaIconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                visible: rail.mediaIconSource === ""
                anchors.centerIn: parent
                text: "M"
                color: rail.activeSurface === "media" ? rail.foreground : rail.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: mediaEntryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (!rail.externallyPinned)
                        rail.railController.selectSurface("media")
                }
                onClicked: {
                    rail.railController.setRailPreview(rail.outputScreen.name, false)
                    rail.railController.toggleRailSurface("media", rail.outputScreen.name)
                }
            }
        }

        Item {
            id: audioEntry
            visible: rail.audioState.sinkReady
            anchors.top: mediaEntry.visible ? mediaEntry.bottom : workspaceColumn.bottom
            anchors.topMargin: mediaEntry.visible ? 7 : 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32
            scale: audioEntryMouse.containsMouse ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "audio" ? rail.surface : "transparent"
                border.width: rail.activeSurface === "audio" ? 1 : 0
                border.color: rail.border

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "audio" ? 15 : 0
                radius: 1
                color: rail.accent

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                source: rail.audioIconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            MouseArea {
                id: audioEntryMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (!rail.externallyPinned)
                        rail.railController.selectSurface("audio")
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        rail.railController.toggleAudioMuteWithFeedback(rail.outputScreen.name)
                        return
                    }
                    rail.railController.setRailPreview(rail.outputScreen.name, false)
                    rail.railController.toggleRailSurface("audio", rail.outputScreen.name)
                }
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                    if (delta !== 0)
                        rail.railController.adjustAudioVolume(delta > 0 ? 0.05 : -0.05, rail.outputScreen.name)
                    wheel.accepted = true
                }
            }
        }

        Item {
            id: trayEntry
            visible: rail.trayState.itemCount > 0
            anchors.top: audioEntry.visible ? audioEntry.bottom : (mediaEntry.visible ? mediaEntry.bottom : workspaceColumn.bottom)
            anchors.topMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32
            scale: trayEntryMouse.containsMouse ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "tray" ? rail.surface : "transparent"
                border.width: rail.activeSurface === "tray" ? 1 : 0
                border.color: rail.border

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "tray" ? 15 : 0
                radius: 1
                color: rail.accent

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                source: rail.trayIconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                visible: rail.trayState.itemCount > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 12
                height: 12
                radius: 6
                color: rail.raisedSurface
                border.width: 1
                border.color: rail.border

                Text {
                    anchors.centerIn: parent
                    text: String(rail.trayState.itemCount)
                    color: rail.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 7
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: trayEntryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (!rail.externallyPinned)
                        rail.railController.selectSurface("tray")
                }
                onClicked: {
                    rail.railController.setRailPreview(rail.outputScreen.name, false)
                    rail.railController.toggleRailSurface("tray", rail.outputScreen.name)
                }
            }
        }

        Column {
            id: clockColumn
            anchors.centerIn: parent
            spacing: -1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: 1
                color: rail.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Item { width: 1; height: 7 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dd")
                color: rail.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                color: rail.mutedForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Item {
            id: brightnessBlock
            visible: rail.brightnessState.ready
            anchors.bottom: layoutBlock.top
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 31
            scale: brightnessMouse.containsMouse ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Image {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !brightnessMouse.containsMouse
                width: 16
                height: 16
                source: rail.brightnessIconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: brightnessMouse.containsMouse
                text: String(rail.brightnessState.percent)
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20
                height: 2
                radius: 1
                color: rail.border

                Rectangle {
                    width: parent.width * rail.brightnessState.value
                    height: parent.height
                    radius: 1
                    color: rail.accent

                    Behavior on width {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: brightnessMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.brightnessState.show(rail.outputScreen.name)
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                    if (delta !== 0)
                        rail.brightnessState.adjust(delta > 0 ? 5 : -5, rail.outputScreen.name)
                    wheel.accepted = true
                }
            }
        }

        Item {
            id: layoutBlock
            visible: rail.niriState.keyboardLayout !== ""
            anchors.bottom: batteryBlock.top
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 31
            scale: layoutMouse.containsMouse ? 1.06 : 1

            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: layoutTile
                anchors.fill: parent
                radius: 10
                color: rail.keyboardLayoutColor()

                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: rail.keyboardLayoutCode()
                    color: rail.keyboardLayoutForeground()
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: layoutMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.switchKeyboardLayout()
            }
        }

        Column {
            id: batteryBlock
            visible: rail.battery.ready
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: String(rail.batteryPercentage)
                color: rail.batteryPercentage <= 15 ? rail.warningAccent : rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 25
                radius: 2
                color: rail.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(2, parent.height * Math.min(1, rail.batteryPercentage / 100))
                    radius: 2
                    color: rail.batteryPercentage <= 15 ? rail.warningAccent : rail.foreground

                    Behavior on height {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                visible: rail.charging
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: 2
                radius: 1
                color: rail.accent
            }
        }
    }

    Rectangle {
        x: Math.floor(rail.width - rail.interactiveWidth)
        width: 1
        height: parent.height
        color: rail.border
    }
}
