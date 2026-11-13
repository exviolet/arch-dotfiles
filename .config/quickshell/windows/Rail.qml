pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

import "../services"
import "../components"
import "rail"

PanelWindow {
    id: rail

    required property var outputScreen
    required property var railController
    required property var mediaPlayer

    readonly property string edge: PanelPlacement.edgeFor("rail", outputScreen.name)
    readonly property bool clockInIsland: edge === "top"
        && PanelPlacement.dockPositionFor(outputScreen.name) === "island"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool farEdge: edge === "right" || edge === "bottom"
    readonly property int compactWidth: PanelPlacement.railThickness
    readonly property string backgroundMode: PanelPlacement.backgroundFor(outputScreen.name)
    readonly property bool wallpaperContrast: backgroundMode === "transparent"
    readonly property string wallpaperPath: wallpaperContrast ? String(WallpaperService.current[outputScreen.name] || "") : ""
    readonly property string sampleKey: wallpaperPath === "" ? ""
        : JSON.stringify([wallpaperPath, edge, outputScreen.width, outputScreen.height])
    property string sampledKey: ""
    property real sampledLight: -1
    readonly property bool useThemeBackgroundAsInk: sampledLight >= 0 && wallpaperPath !== ""
        && contrastRatio(luminance(Theme.background), sampledLight) > contrastRatio(luminance(Theme.foreground), sampledLight)
    readonly property color stripInk: useThemeBackgroundAsInk ? Theme.background : Theme.foreground
    readonly property color contrastBacking: useThemeBackgroundAsInk ? Theme.foreground : Theme.background
    readonly property color stripAccent: wallpaperContrast ? stripInk : Theme.accent
    readonly property color stripForeground: wallpaperContrast ? stripInk : Theme.foreground
    readonly property color stripSubtle: wallpaperContrast ? stripInk : Theme.subtleForeground
    readonly property color stripBorder: wallpaperContrast ? Qt.alpha(stripInk, 0.4) : Theme.border
    readonly property color stripSurface: wallpaperContrast ? Qt.alpha(contrastBacking, 0.32) : Theme.surface
    readonly property color stripHover: wallpaperContrast ? Qt.alpha(contrastBacking, 0.18) : Theme.raisedSurface
    readonly property color stripWarning: wallpaperContrast ? stripInk : Theme.warningAccent
    readonly property int maxDrawerWidth: 394
    readonly property int drawerDepth: Math.max(0, Math.min(640, outputScreen.height - compactWidth))
    readonly property bool hasMedia: mediaPlayer !== null
    readonly property string activeSurface: String(railController.activeSurface || "system")
    readonly property bool showingMedia: activeSurface === "media" && hasMedia
    readonly property bool showingAudio: activeSurface === "audio" && AudioService.sinkReady
    readonly property bool showingTray: activeSurface === "tray" && TrayService.itemCount > 0
    readonly property bool showingCalendar: activeSurface === "calendar"
    readonly property bool hasAgents: AgentService.agents.length > 0
    readonly property bool usageAvailable: ClaudeUsageService.ready || hasAgents
    readonly property bool showingUsage: activeSurface === "usage" && usageAvailable
    readonly property string mediaIdentity: hasMedia ? String(mediaPlayer.identity) : ""
    readonly property string mediaDesktopEntryId: hasMedia ? String(mediaPlayer.desktopEntry) : ""
    readonly property var mediaApplication: hasMedia ? DesktopEntries.heuristicLookup(mediaDesktopEntryId || mediaIdentity) : null
    readonly property string mediaApplicationName: mediaApplication ? String(mediaApplication.name).replace(" (Launcher)", "") : mediaIdentity
    readonly property string mediaIconSource: railController.mediaIconSourceFor(mediaPlayer)
    property real drawerWidth: Math.min(showingMedia ? 360 : (showingTray ? 344 : (showingCalendar ? 336 : maxDrawerWidth)),
        Math.max(0, outputScreen.width - (vertical ? compactWidth : 0)))
    readonly property bool externallyPinned: railController.railPinned && railController.railExpansionScreen === outputScreen.name
    readonly property bool previewing: railController.railPreviewScreen === outputScreen.name
    readonly property bool expanded: externallyPinned || previewing
    property real revealProgress: expanded ? 1 : 0
    readonly property real drawerStart: vertical ? 0 : drawer.x
    readonly property real drawerLength: vertical ? drawer.height : drawer.width
    readonly property Item drawerControl: {
        if (showingMedia) return mediaEntry
        if (showingAudio) return audioEntry
        if (showingTray) return trayEntry
        if (showingCalendar && !clockInIsland) return clockBlock
        if (showingUsage) return usageEntry
        return signal
    }
    property string pendingSurface: ""
    readonly property var hoveredControl: [
        systemMouse, mediaEntryMouse, audioEntryMouse, trayEntryMouse,
        usageEntryMouse, clockMouse, brightnessMouse, layoutMouse, stripMouse
    ].find(control => control.visible && control.containsMouse && !control.pressed) ?? null

    readonly property var screenWorkspaces: NiriService.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: PowerService.battery
    readonly property int batteryPercentage: PowerService.batteryPercent
    readonly property bool charging: PowerService.charging
    readonly property string batteryTimeLabel: PowerService.batteryTimeLabel.replace("h ", ":").replace("m", "")

    screen: outputScreen
    visible: railController.railVisible
    implicitWidth: vertical ? Math.min(outputScreen.width, compactWidth + maxDrawerWidth) : outputScreen.width
    implicitHeight: vertical ? outputScreen.height : compactWidth + drawerDepth
    color: "transparent"
    exclusiveZone: compactWidth + (clockInIsland ? PanelPlacement.islandReservation : 0)
    focusable: false
    WlrLayershell.namespace: "quickshell-rail"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: backgroundMode === "matte" ? stripBlurRegion : null

    Region {
        id: stripBlurRegion
        item: railBase
    }

    mask: Region {
        item: railBase

        Region {
            x: Math.floor(drawer.x)
            y: Math.floor(drawer.y)
            width: Math.ceil(drawer.width)
            height: Math.ceil(drawer.height)
        }
    }

    anchors {
        left: !rail.vertical || rail.edge === "left"
        right: !rail.vertical || rail.edge === "right"
        top: rail.vertical || rail.edge === "top"
        bottom: rail.vertical || rail.edge === "bottom"
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

    onSampleKeyChanged: Qt.callLater(sampleWallpaperEdge)

    function linearChannel(channel: real): real {
        return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
    }

    function luminance(color: color): real {
        return 0.2126 * linearChannel(color.r) + 0.7152 * linearChannel(color.g) + 0.0722 * linearChannel(color.b)
    }

    function contrastRatio(first: real, second: real): real {
        return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05)
    }

    function sampleWallpaperEdge(): void {
        if (sampleKey === "" || sampleKey === sampledKey || wallpaperSampler.running) return

        const scale = Math.min(1, 480 / Math.max(outputScreen.width, outputScreen.height))
        const width = Math.max(1, Math.round(outputScreen.width * scale))
        const height = Math.max(1, Math.round(outputScreen.height * scale))
        const thickness = Math.max(1, Math.round(compactWidth * scale))
        const size = width + "x" + height
        const strip = vertical ? Math.min(thickness, width) + "x" + height
            : width + "x" + Math.min(thickness, height)
        const gravity = { "left": "West", "right": "East", "top": "North", "bottom": "South" }

        wallpaperSampler.key = sampleKey
        // Match awww's centered crop, then measure only the strip behind this panel.
        wallpaperSampler.exec(["/usr/sbin/magick", "-limit", "thread", "1", wallpaperPath + "[0]",
            "-auto-orient", "-resize", size + "^", "-gravity", "Center", "-extent", size, "+repage",
            "-gravity", gravity[edge], "-crop", strip + "+0+0", "+repage",
            "-background", "black", "-alpha", "remove", "-colorspace", "sRGB",
            "-resize", "1x1!", "-format", "%[fx:r] %[fx:g] %[fx:b]", "info:"])
    }

    Process {
        id: wallpaperSampler
        property string key: ""

        stdout: StdioCollector { id: edgeStats }

        onExited: exitCode => {
            if (key === rail.sampleKey) {
                const rgb = edgeStats.text.trim().split(/\s+/).map(Number)
                rail.sampledLight = exitCode === 0 && rgb.length === 3 && rgb.every(channel => channel >= 0 && channel <= 1)
                    ? rail.luminance(Qt.rgba(rgb[0], rgb[1], rgb[2], 1)) : -1
                rail.sampledKey = key
            }
            Qt.callLater(rail.sampleWallpaperEdge)
        }
    }

    Timer {
        id: previewTimer
        interval: 180
        repeat: false
        onTriggered: {
            const surface = rail.pendingSurface
            rail.pendingSurface = ""
            if (surface === "" || rail.railController.railPinned || !railHover.hovered) return
            if (rail.railController.selectSurface(surface) === surface)
                rail.railController.setRailPreview(rail.outputScreen.name, true)
        }
    }

    Timer {
        id: hintTimer
        interval: 550
        onTriggered: controlHint.ready = true
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

    onExpandedChanged: if (!expanded) clearSurfaceRequest()
    onHoveredControlChanged: {
        controlHint.ready = false
        if (hoveredControl) hintTimer.restart()
        else hintTimer.stop()
    }

    HoverHandler {
        id: railHover
        onHoveredChanged: {
            if (hovered) {
                collapseTimer.stop()
            } else {
                rail.clearSurfaceRequest()
                if (rail.previewing) collapseTimer.restart()
            }
        }
    }

    function requestSurface(surface: string): void {
        if (railController.railPinned || stripMouse.pressed) return
        pendingSurface = surface
        previewTimer.restart()
    }

    function cancelSurfaceRequest(surface: string): void {
        if (pendingSurface === surface) clearSurfaceRequest()
    }

    function clearSurfaceRequest(): void {
        pendingSurface = ""
        previewTimer.stop()
    }

    function toggleSurface(surface: string): void {
        clearSurfaceRequest()
        railController.toggleRailSurface(surface, outputScreen.name)
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

    function keyboardLayoutCode(): string {
        const name = String(NiriService.keyboardLayout || "")
        const normalized = name.toLowerCase()
        if (normalized.indexOf("english") !== -1 && normalized.indexOf("us") !== -1) return "US"
        if (normalized.indexOf("russian") !== -1) return "RU"
        if (normalized.indexOf("kazakh") !== -1) return "KK"
        return name.length >= 2 ? name.slice(0, 2).toUpperCase() : "--"
    }

    function keyboardLayoutColor(): color {
        const code = keyboardLayoutCode()
        if (code === "US") return Theme.layoutUs
        if (code === "RU") return Theme.layoutRu
        if (code === "KK") return Theme.layoutKk
        return Theme.foreground
    }

    function switchKeyboardLayout(): void {
        if (!layoutAction.running)
            layoutAction.exec(["/usr/sbin/niri", "msg", "action", "switch-layout", "next"])
    }

    Connections {
        target: rail.railController

        function onTrayInlineMenuRequested(index: int, screen: string): void {
            if (screen === rail.outputScreen.name)
                traySurface.openMenu(TrayService.itemAt(index))
        }

        function onActiveSurfaceChanged(): void {
            if (rail.activeSurface !== "tray")
                traySurface.closeMenu()
        }

        function onRailPinnedChanged(): void {
            if (rail.railController.railPinned)
                rail.clearSurfaceRequest()
        }
    }

    Rectangle {
        id: drawer
        x: rail.vertical
            ? (rail.farEdge ? railBase.x - width : railBase.width)
            : Math.round(Math.max(0, Math.min(rail.width - width,
                rail.drawerControl.x + (rail.drawerControl.width - width) / 2)))
        y: rail.vertical ? 0 : (rail.farEdge ? railBase.y - height : railBase.height)
        width: rail.vertical ? rail.drawerWidth * rail.revealProgress : rail.drawerWidth
        height: rail.vertical ? rail.height : rail.drawerDepth * rail.revealProgress
        color: Theme.surface
        clip: true

        Item {
            id: drawerContent

            width: rail.drawerWidth
            height: rail.vertical ? parent.height : rail.drawerDepth
            x: rail.vertical && rail.farEdge ? parent.width - width : 0
            y: !rail.vertical && rail.farEdge ? parent.height - height : 0
            opacity: rail.revealProgress

            Behavior on opacity {
                NumberAnimation { duration: 155; easing.type: Easing.OutCubic }
            }

            SystemSurface {
                anchors.fill: parent
                visible: !rail.showingMedia && !rail.showingAudio && !rail.showingTray && !rail.showingCalendar && !rail.showingUsage
                outputName: rail.outputScreen.name
                workspaceLabel: rail.focusedWorkspaceLabel()
                pinned: rail.externallyPinned
                expanded: rail.expanded
                active: visible && rail.expanded
            }

            MediaSurface {
                anchors.fill: parent
                visible: rail.showingMedia
                controller: rail.railController
                player: rail.mediaPlayer
                iconSource: rail.mediaIconSource
                applicationName: rail.mediaApplicationName
                pinned: rail.externallyPinned
                expanded: rail.expanded
            }

            AudioSurface {
                anchors.fill: parent
                visible: rail.showingAudio
                pinned: rail.externallyPinned
                expanded: rail.expanded
            }

            UsageSurface {
                anchors.fill: parent
                visible: rail.showingUsage
                pinned: rail.externallyPinned
                expanded: rail.expanded
                active: visible && rail.expanded
            }

            CalendarSurface {
                anchors.fill: parent
                visible: rail.showingCalendar
                now: clock.date
                pinned: rail.externallyPinned
                expanded: rail.expanded
            }

            TraySurface {
                id: traySurface
                anchors.fill: parent
                visible: rail.showingTray
                pinned: rail.externallyPinned
                expanded: rail.expanded
            }

        }
    }

    Rectangle {
        id: railBase
        x: rail.edge === "right" ? rail.width - width : 0
        y: rail.edge === "bottom" ? rail.height - height : 0
        width: rail.vertical ? rail.compactWidth : rail.width
        height: rail.vertical ? rail.height : rail.compactWidth
        color: {
            if (rail.backgroundMode === "solid") return Theme.background
            if (rail.backgroundMode === "matte") return Qt.alpha(Theme.background, 0.35)
            return "transparent"
        }

        MouseArea {
            id: stripMouse
            readonly property string hint: "Перетащить к краю экрана\nДвойной клик — сменить фон"
            property point pressPoint
            property bool moving: false
            property string destination: ""

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: moving ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            function dropAt(mouse: var): string {
                // Layer-shell anchors put the window at (0, 0) except at the far edges.
                const point = mapToItem(railBase, mouse.x, mouse.y)
                const screenX = point.x + (rail.edge === "right" ? rail.outputScreen.width - railBase.width : 0)
                const screenY = point.y + (rail.edge === "bottom" ? rail.outputScreen.height - railBase.height : 0)
                return PanelPlacement.dropEdge(screenX, screenY, rail.outputScreen.width, rail.outputScreen.height)
            }

            onPressed: mouse => {
                pressPoint = Qt.point(mouse.x, mouse.y)
                rail.clearSurfaceRequest()
                rail.railController.setRailPreview(rail.outputScreen.name, false)
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                if (!moving)
                    moving = Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) >= 10
                if (moving) destination = dropAt(mouse)
            }
            onReleased: mouse => {
                const target = moving ? dropAt(mouse) : ""
                moving = false
                destination = ""
                if (target !== "" && target !== rail.edge)
                    PanelPlacement.setEdge("rail", rail.outputScreen.name, target)
            }
            onCanceled: {
                moving = false
                destination = ""
            }
            onDoubleClicked: {
                const options = PanelPlacement.backgrounds
                const index = options.findIndex(option => option.id === rail.backgroundMode)
                PanelPlacement.setBackground(rail.outputScreen.name, options[(index + 1) % options.length].id)
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: stripMouse.moving && stripMouse.destination !== "" && stripMouse.destination !== rail.edge
            color: "transparent"
            border.color: rail.stripAccent
        }

        Item {
            id: signal
            x: rail.vertical ? (railBase.width - width) / 2 : 12
            y: rail.vertical ? 18 : (railBase.height - height) / 2
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
                        color: rail.NiriService.ready ? rail.stripAccent : rail.stripWarning
                        opacity: rail.NiriService.connected ? 1 : 0.45

                        Behavior on width {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            MouseArea {
                id: systemMouse
                readonly property string hint: "Системные настройки\nПКМ — статус рендерера"
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("system")
                onExited: rail.cancelSurfaceRequest("system")
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        rendererAction.exec(["/home/ex1te/.config/quickshell/scripts/sidecarctl", "renderer"])
                    } else {
                        rail.toggleSurface("system")
                    }
                }
            }
        }

        Flickable {
            id: workspaceColumn
            x: rail.vertical ? (railBase.width - width) / 2 : signal.x + signal.width + 10
            y: rail.vertical ? signal.y + signal.height + 10 : (railBase.height - height) / 2
            width: rail.vertical ? 32 : Math.min(contentWidth, Math.max(0, clockBlock.x - x - 12))
            height: rail.vertical ? Math.min(contentHeight, Math.max(0, clockBlock.y - y - 22
                - 39 * [mediaEntry, audioEntry, trayEntry, usageEntry].filter(entry => entry.visible).length)) : 32
            contentWidth: workspaceGrid.implicitWidth
            contentHeight: workspaceGrid.implicitHeight
            flickableDirection: rail.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Grid {
                id: workspaceGrid
                columns: rail.vertical ? 1 : Math.max(1, rail.screenWorkspaces.length)
                spacing: 8

                Repeater {
                    model: rail.screenWorkspaces

                    Item {
                        id: workspaceItem
                        required property var modelData
                        width: 32
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: workspaceItem.modelData.is_active ? rail.stripSurface : (workspaceMouse.containsMouse ? rail.stripHover : "transparent")
                            border.width: workspaceItem.modelData.is_urgent || (workspaceItem.modelData.is_active && !rail.wallpaperContrast) ? 1 : 0
                            border.color: workspaceItem.modelData.is_urgent ? rail.stripWarning : rail.stripBorder
                        }

                        Text {
                            anchors.centerIn: parent
                            text: workspaceItem.modelData.name !== "" ? workspaceItem.modelData.name.slice(0, 2) : String(workspaceItem.modelData.idx)
                            color: workspaceItem.modelData.is_active ? rail.stripForeground : rail.stripSubtle
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
        }

        Item {
            id: mediaEntry
            visible: rail.hasMedia
            x: rail.vertical ? (railBase.width - width) / 2 : audioEntry.x - (visible ? width + 7 : 0)
            y: rail.vertical ? (workspaceColumn.y + workspaceColumn.height + 12) : (railBase.height - height) / 2
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: (rail.expanded || !rail.wallpaperContrast) && rail.activeSurface === "media" ? rail.stripSurface : (mediaEntryMouse.containsMouse ? rail.stripHover : "transparent")
                border.width: !rail.wallpaperContrast && rail.activeSurface === "media" ? 1 : 0
                border.color: rail.stripBorder
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: !rail.wallpaperContrast && rail.activeSurface === "media" ? 15 : 0
                radius: 1
                color: rail.stripAccent
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
                color: rail.activeSurface === "media" ? rail.stripForeground : rail.stripSubtle
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: mediaEntryMouse
                readonly property string hint: "Управление воспроизведением"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("media")
                onExited: rail.cancelSurfaceRequest("media")
                onClicked: rail.toggleSurface("media")
            }
        }

        Item {
            id: audioEntry
            visible: rail.AudioService.sinkReady
            x: rail.vertical ? (railBase.width - width) / 2 : trayEntry.x - (visible ? width + 7 : 0)
            y: rail.vertical ? (mediaEntry.visible ? mediaEntry.y + mediaEntry.height + 7 : mediaEntry.y) : (railBase.height - height) / 2
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: (rail.expanded || !rail.wallpaperContrast) && rail.activeSurface === "audio" ? rail.stripSurface : (audioEntryMouse.containsMouse ? rail.stripHover : "transparent")
                border.width: !rail.wallpaperContrast && rail.activeSurface === "audio" ? 1 : 0
                border.color: rail.stripBorder
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: !rail.wallpaperContrast && rail.activeSurface === "audio" ? 15 : 0
                radius: 1
                color: rail.stripAccent
            }

            ThemeIcon {
                anchors.centerIn: parent
                size: 17
                name: AudioService.muted ? "sound-off" : "sound-high"
                color: rail.stripAccent
            }

            MouseArea {
                id: audioEntryMouse
                readonly property string hint: "Звук\nКолесо — громкость\nСредний клик — вкл. или выкл. звук"
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("audio")
                onExited: rail.cancelSurfaceRequest("audio")
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        rail.railController.toggleAudioMuteWithFeedback(rail.outputScreen.name)
                        return
                    }
                    rail.toggleSurface("audio")
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
            visible: rail.TrayService.itemCount > 0
            x: rail.vertical ? (railBase.width - width) / 2 : usageEntry.x - (visible ? width + 7 : 0)
            y: rail.vertical ? (audioEntry.y + (audioEntry.visible ? audioEntry.height + 7 : 0)) : (railBase.height - height) / 2
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: (rail.expanded || !rail.wallpaperContrast) && rail.activeSurface === "tray" ? rail.stripSurface : (trayEntryMouse.containsMouse ? rail.stripHover : "transparent")
                border.width: !rail.wallpaperContrast && rail.activeSurface === "tray" ? 1 : 0
                border.color: rail.stripBorder
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: !rail.wallpaperContrast && rail.activeSurface === "tray" ? 15 : 0
                radius: 1
                color: rail.stripAccent
            }

            ThemeIcon {
                anchors.centerIn: parent
                size: 17
                name: "app-notification"
                color: rail.stripAccent
            }

            Rectangle {
                visible: rail.TrayService.itemCount > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 12
                height: 12
                radius: 6
                color: rail.stripHover
                border.width: 1
                border.color: rail.stripBorder

                Text {
                    anchors.centerIn: parent
                    text: String(rail.TrayService.itemCount)
                    color: rail.stripForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 7
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: trayEntryMouse
                readonly property string hint: "Системный трей"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("tray")
                onExited: rail.cancelSurfaceRequest("tray")
                onClicked: rail.toggleSurface("tray")
            }
        }

        Item {
            id: usageEntry

            visible: rail.usageAvailable
            x: rail.vertical ? (railBase.width - width) / 2 : brightnessBlock.x - (visible ? width + 7 : 0)
            y: rail.vertical ? (trayEntry.y + (trayEntry.visible ? trayEntry.height + 7 : 0)) : (railBase.height - height) / 2
            width: 32
            height: 32

            readonly property real percent: Math.max(0, rail.ClaudeUsageService.fivePercent)

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: (rail.expanded || !rail.wallpaperContrast) && rail.activeSurface === "usage" ? rail.stripSurface : (usageEntryMouse.containsMouse ? rail.stripHover : "transparent")
                border.width: !rail.wallpaperContrast && rail.activeSurface === "usage" ? 1 : 0
                border.color: rail.stripBorder
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: !rail.wallpaperContrast && rail.activeSurface === "usage" ? 15 : 0
                radius: 1
                color: rail.stripAccent
            }

            ThemeIcon {
                anchors.centerIn: parent
                size: 17
                name: "asterisk"
                color: rail.stripAccent
                opacity: rail.ClaudeUsageService.stale && !rail.hasAgents ? 0.45 : 1
            }

            // An agent is waiting on an answer. Deliberately louder than the
            // burn sliver: that is a number you glance at, this is a thing to
            // go and do.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 3
                anchors.topMargin: 3
                width: 6
                height: 6
                radius: 3
                visible: rail.AgentService.needsAttention
                color: Theme.alertAccent
                border.width: rail.wallpaperContrast ? 1 : 0
                border.color: rail.stripInk
            }

            // The icon says what this is; the sliver underneath says how much
            // is gone, which is the only thing worth reading at strip width.
            Rectangle {
                visible: rail.ClaudeUsageService.fivePercent >= 0
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                width: 16
                height: 2
                radius: 1
                color: rail.stripBorder

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(2, parent.width * Math.min(1, usageEntry.percent / 100))
                    radius: 1
                    color: {
                        if (rail.ClaudeUsageService.stale) return rail.stripSubtle
                        if (usageEntry.percent >= 80) return rail.stripAccent
                        if (usageEntry.percent >= 50) return rail.stripWarning
                        return rail.stripForeground
                    }

                    Behavior on width {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: usageEntryMouse
                readonly property string hint: {
                    if (!rail.ClaudeUsageService.ready) return "Агенты Herdr"
                    return rail.hasAgents ? "Агенты Herdr и лимиты Claude" : "Лимиты Claude"
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("usage")
                onExited: rail.cancelSurfaceRequest("usage")
                onClicked: rail.toggleSurface("usage")
            }
        }

        Item {
            id: clockBlock
            visible: !rail.clockInIsland
            x: rail.vertical ? (railBase.width - width) / 2
                : Math.max(0, Math.min((railBase.width - width) / 2, mediaEntry.x - width - 12))
            y: (railBase.height - height) / 2
            width: rail.vertical ? 32 : horizontalClock.implicitWidth + 22
            height: rail.vertical ? clockColumn.implicitHeight + 14 : 34

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: (rail.expanded || !rail.wallpaperContrast) && rail.activeSurface === "calendar" ? rail.stripSurface : (clockMouse.containsMouse ? rail.stripHover : "transparent")
                border.width: !rail.wallpaperContrast && rail.activeSurface === "calendar" ? 1 : 0
                border.color: rail.stripBorder
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: !rail.wallpaperContrast && rail.activeSurface === "calendar" ? 15 : 0
                radius: 1
                color: rail.stripAccent
            }

            Column {
                id: clockColumn
                visible: rail.vertical
                anchors.centerIn: parent
                spacing: -1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: rail.stripForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 1
                    color: rail.stripAccent
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: rail.stripForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Item { width: 1; height: 7 }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dd")
                    color: rail.stripSubtle
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                    color: rail.stripSubtle
                    font.family: "DejaVu Sans"
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
            }

            Row {
                id: horizontalClock
                visible: !rail.vertical
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: rail.stripForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "d MMM")
                    color: rail.stripSubtle
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: clockMouse
                readonly property string hint: "Календарь"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("calendar")
                onExited: rail.cancelSurfaceRequest("calendar")
                onClicked: rail.toggleSurface("calendar")
            }
        }

        Item {
            id: brightnessBlock
            visible: rail.BrightnessService.ready
            x: rail.vertical ? (railBase.width - width) / 2 : layoutBlock.x - (visible ? width + 7 : 0)
            y: rail.vertical ? layoutBlock.y - height - 14 : (railBase.height - height) / 2
            width: 32
            height: 31

            ThemeIcon {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !brightnessMouse.containsMouse
                size: 16
                name: "brightness"
                color: rail.stripAccent
            }

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: brightnessMouse.containsMouse
                text: String(rail.BrightnessService.percent)
                color: rail.stripForeground
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
                color: rail.stripBorder

                Rectangle {
                    width: parent.width * rail.BrightnessService.value
                    height: parent.height
                    radius: 1
                    color: rail.stripAccent

                    Behavior on width {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: brightnessMouse
                readonly property string hint: "Яркость\nКолесо — изменить"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.BrightnessService.show(rail.outputScreen.name)
                onWheel: wheel => {
                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                    if (delta !== 0)
                        rail.BrightnessService.adjust(delta > 0 ? 5 : -5, rail.outputScreen.name)
                    wheel.accepted = true
                }
            }
        }

        Item {
            id: layoutBlock
            visible: rail.NiriService.keyboardLayout !== ""
            x: rail.vertical ? (railBase.width - width) / 2 : batteryBlock.x - (visible ? width + 7 : 0)
            y: rail.vertical ? batteryBlock.y - height - 18 : (railBase.height - height) / 2
            width: 32
            height: 31

            Rectangle {
                id: layoutTile
                anchors.fill: parent
                radius: 10
                color: rail.wallpaperContrast
                    ? (layoutMouse.containsMouse ? rail.stripHover : "transparent")
                    : rail.keyboardLayoutColor()

                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: rail.keyboardLayoutCode()
                    color: rail.wallpaperContrast ? rail.stripForeground : Theme.layoutForeground(rail.keyboardLayoutCode())
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold

                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            MouseArea {
                id: layoutMouse
                readonly property string hint: "Переключить раскладку"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: rail.switchKeyboardLayout()
            }
        }

        Column {
            id: batteryBlock
            visible: rail.battery.ready
            width: rail.vertical ? implicitWidth : 46
            x: rail.vertical ? (railBase.width - width) / 2 : railBase.width - 12 - (visible ? width : 0)
            y: rail.vertical ? railBase.height - (visible ? height + 20 : 12)
                : (railBase.height - height) / 2
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: batteryMouse.containsMouse && rail.batteryTimeLabel !== "" ? rail.batteryTimeLabel : String(rail.batteryPercentage)
                color: rail.batteryPercentage <= 15 ? rail.stripWarning : rail.stripForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: rail.vertical ? 4 : 26
                height: rail.vertical ? 25 : 3
                radius: 2
                color: rail.stripBorder

                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: rail.vertical ? parent.width : Math.max(2, parent.width * Math.min(1, rail.batteryPercentage / 100))
                    height: rail.vertical ? Math.max(2, parent.height * Math.min(1, rail.batteryPercentage / 100)) : parent.height
                    radius: 2
                    color: rail.batteryPercentage <= 15 ? rail.stripWarning : rail.stripForeground

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
                color: rail.stripAccent
            }
        }

        MouseArea {
            id: batteryMouse
            visible: batteryBlock.visible
            anchors.fill: batteryBlock
            hoverEnabled: true
        }

        Rectangle {
            id: controlHint

            property bool ready: false
            readonly property var control: rail.hoveredControl
            visible: ready && control !== null
            x: rail.vertical ? (rail.farEdge ? -width - 6 : railBase.width + 6)
                : control === null ? 0 : Math.max(8, Math.min(railBase.width - width - 8,
                    control === stripMouse ? stripMouse.mouseX - width / 2 : control.parent.x + (control.width - width) / 2))
            y: !rail.vertical ? (rail.farEdge ? -height - 6 : railBase.height + 6)
                : control === null ? 0 : Math.max(8, Math.min(railBase.height - height - 8,
                    control === stripMouse ? stripMouse.mouseY - height / 2 : control.parent.y + (control.height - height) / 2))
            width: hintText.implicitWidth + 20
            height: hintText.implicitHeight + 12
            radius: 6
            color: Theme.raisedSurface
            border.width: 1
            border.color: Theme.border

            Text {
                id: hintText
                anchors.centerIn: parent
                text: controlHint.control?.hint ?? ""
                color: Theme.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }
        }
    }
}
