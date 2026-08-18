pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

import "../services"
import "rail"

PanelWindow {
    id: rail

    required property var outputScreen
    required property var railController
    required property var mediaPlayer

    readonly property int compactWidth: 46
    readonly property int maxDrawerWidth: 394
    readonly property bool hasMedia: mediaPlayer !== null
    readonly property string activeSurface: String(railController.activeSurface || "system")
    readonly property bool showingMedia: activeSurface === "media" && hasMedia
    readonly property bool showingAudio: activeSurface === "audio" && AudioService.sinkReady
    readonly property bool showingTray: activeSurface === "tray" && TrayService.itemCount > 0
    readonly property url audioIconSource: Qt.resolvedUrl(AudioService.muted ? "../icons/iconoir/sound-off.svg" : "../icons/iconoir/sound-high.svg")
    readonly property url brightnessIconSource: Qt.resolvedUrl("../icons/iconoir/brightness.svg")
    readonly property url trayIconSource: Qt.resolvedUrl("../icons/iconoir/app-notification.svg")
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
    property real drawerWidth: showingAudio ? 394 : (showingMedia ? 360 : (showingTray ? 344 : 304))
    readonly property bool externallyPinned: railController.railPinned && railController.railExpansionScreen === outputScreen.name
    readonly property bool previewing: railController.railPreviewScreen === outputScreen.name
    readonly property bool expanded: externallyPinned || previewing
    property real revealProgress: expanded ? 1 : 0
    readonly property real interactiveWidth: compactWidth + drawerWidth * revealProgress
    readonly property bool outputFocused: NiriService.focusedOutput === outputScreen.name
    property real outputFocusPulse: 0
    property string pendingSurface: ""

    readonly property var screenWorkspaces: NiriService.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercentage: battery.ready ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery.ready && battery.state === UPowerDeviceState.Charging

    screen: outputScreen
    visible: railController.railVisible
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
        id: surfaceHoverTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (rail.pendingSurface !== "")
                rail.railController.selectSurface(rail.pendingSurface)
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
                rail.clearSurfaceRequest()
                if (!rail.externallyPinned) collapseTimer.restart()
            }
        }
    }

    function requestSurface(surface: string): void {
        if (externallyPinned) return
        pendingSurface = surface
        surfaceHoverTimer.restart()
    }

    function cancelSurfaceRequest(surface: string): void {
        if (pendingSurface !== surface) return
        pendingSurface = ""
        surfaceHoverTimer.stop()
    }

    function clearSurfaceRequest(): void {
        pendingSurface = ""
        surfaceHoverTimer.stop()
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

    function keyboardLayoutForeground(): color {
        return keyboardLayoutCode() === "KK" ? "#171817" : "#ffffff"
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
    }

    Rectangle {
        id: drawer
        width: rail.drawerWidth * rail.revealProgress
        x: rail.maxDrawerWidth - width
        height: parent.height
        color: Theme.surface
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

            SystemSurface {
                anchors.fill: parent
                visible: !rail.showingMedia && !rail.showingAudio && !rail.showingTray
                outputName: rail.outputScreen.name
                workspaceLabel: rail.focusedWorkspaceLabel()
                pinned: rail.externallyPinned
                expanded: rail.expanded
            }

            MediaSurface {
                anchors.fill: parent
                visible: rail.showingMedia
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

            TraySurface {
                id: traySurface
                anchors.fill: parent
                visible: rail.showingTray
                pinned: rail.externallyPinned
                expanded: rail.expanded
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
                    color: Theme.border

                    Rectangle {
                        width: 24
                        height: 1
                        color: Theme.accent
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: rail.externallyPinned ? "CLICK TO CLOSE" : "LEAVE TO COLLAPSE"
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: 0.8
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: String(Math.round(rail.interactiveWidth)) + " PX"
                    color: Theme.subtleForeground
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
        color: Theme.background

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
                        color: rail.NiriService.ready ? Theme.accent : Theme.warningAccent
                        opacity: rail.NiriService.connected ? 1 : 0.45

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
                onEntered: rail.requestSurface("system")
                onExited: rail.cancelSurfaceRequest("system")
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        rendererAction.exec(["/home/ex1te/.config/quickshell/scripts/sidecarctl", "renderer"])
                    } else {
                        rail.clearSurfaceRequest()
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
            color: Theme.border

            Rectangle {
                anchors.left: parent.left
                width: 6
                height: 1
                color: Theme.accent
            }
        }

        Text {
            id: outputIdentityLabel
            anchors.top: upperRule.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: rail.outputIdentity()
            color: rail.outputFocused ? Theme.accent : Theme.subtleForeground
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
                        color: workspaceItem.modelData.is_active ? Theme.surface : (workspaceMouse.containsMouse ? Theme.raisedSurface : "transparent")
                        border.width: workspaceItem.modelData.is_active ? 1 : 0
                        border.color: Theme.border
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: workspaceItem.modelData.is_focused ? 15 : (workspaceItem.modelData.is_urgent ? 8 : 0)
                        radius: 1
                        color: workspaceItem.modelData.is_urgent ? Theme.warningAccent : Theme.accent

                        Behavior on height {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: workspaceItem.modelData.name !== "" ? workspaceItem.modelData.name.slice(0, 2) : String(workspaceItem.modelData.idx)
                        color: workspaceItem.modelData.is_active ? Theme.foreground : Theme.subtleForeground
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
            color: Theme.accent
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

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "media" ? Theme.surface : (mediaEntryMouse.containsMouse ? Theme.raisedSurface : "transparent")
                border.width: rail.activeSurface === "media" ? 1 : 0
                border.color: Theme.border
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "media" ? 15 : 0
                radius: 1
                color: Theme.accent
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
                color: rail.activeSurface === "media" ? Theme.foreground : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: mediaEntryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rail.requestSurface("media")
                onExited: rail.cancelSurfaceRequest("media")
                onClicked: {
                    rail.clearSurfaceRequest()
                    rail.railController.setRailPreview(rail.outputScreen.name, false)
                    rail.railController.toggleRailSurface("media", rail.outputScreen.name)
                }
            }
        }

        Item {
            id: audioEntry
            visible: rail.AudioService.sinkReady
            anchors.top: mediaEntry.visible ? mediaEntry.bottom : workspaceColumn.bottom
            anchors.topMargin: mediaEntry.visible ? 7 : 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "audio" ? Theme.surface : (audioEntryMouse.containsMouse ? Theme.raisedSurface : "transparent")
                border.width: rail.activeSurface === "audio" ? 1 : 0
                border.color: Theme.border
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "audio" ? 15 : 0
                radius: 1
                color: Theme.accent
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
                onEntered: rail.requestSurface("audio")
                onExited: rail.cancelSurfaceRequest("audio")
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        rail.railController.toggleAudioMuteWithFeedback(rail.outputScreen.name)
                        return
                    }
                    rail.clearSurfaceRequest()
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
            visible: rail.TrayService.itemCount > 0
            anchors.top: audioEntry.visible ? audioEntry.bottom : (mediaEntry.visible ? mediaEntry.bottom : workspaceColumn.bottom)
            anchors.topMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: rail.activeSurface === "tray" ? Theme.surface : (trayEntryMouse.containsMouse ? Theme.raisedSurface : "transparent")
                border.width: rail.activeSurface === "tray" ? 1 : 0
                border.color: Theme.border
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: rail.activeSurface === "tray" ? 15 : 0
                radius: 1
                color: Theme.accent
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
                visible: rail.TrayService.itemCount > 1
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 12
                height: 12
                radius: 6
                color: Theme.raisedSurface
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: String(rail.TrayService.itemCount)
                    color: Theme.foreground
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
                onEntered: rail.requestSurface("tray")
                onExited: rail.cancelSurfaceRequest("tray")
                onClicked: {
                    rail.clearSurfaceRequest()
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
                color: Theme.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: 1
                color: Theme.accent
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Item { width: 1; height: 7 }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dd")
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.Medium
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                color: Theme.subtleForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Item {
            id: brightnessBlock
            visible: rail.BrightnessService.ready
            anchors.bottom: layoutBlock.top
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 31

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
                text: String(rail.BrightnessService.percent)
                color: Theme.foreground
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
                color: Theme.border

                Rectangle {
                    width: parent.width * rail.BrightnessService.value
                    height: parent.height
                    radius: 1
                    color: Theme.accent

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
            anchors.bottom: batteryBlock.top
            anchors.bottomMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32
            height: 31

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
                color: rail.batteryPercentage <= 15 ? Theme.warningAccent : Theme.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 25
                radius: 2
                color: Theme.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(2, parent.height * Math.min(1, rail.batteryPercentage / 100))
                    radius: 2
                    color: rail.batteryPercentage <= 15 ? Theme.warningAccent : Theme.foreground

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
                color: Theme.accent
            }
        }
    }

    Rectangle {
        x: Math.floor(rail.width - rail.interactiveWidth)
        width: 1
        height: parent.height
        color: Theme.border
    }
}
