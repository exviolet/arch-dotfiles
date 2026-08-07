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
    required property bool shellDark
    required property bool railEnabled

    readonly property int compactWidth: 46
    readonly property bool hasMedia: mediaPlayer !== null
    readonly property string activeSurface: String(railController.activeSurface || "system")
    readonly property bool showingMedia: activeSurface === "media" && hasMedia
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
    property real drawerWidth: showingMedia ? 360 : 304
    readonly property bool externallyPinned: railController.railPinned && railController.railExpansionScreen === outputScreen.name
    readonly property bool previewing: railController.railPreviewScreen === outputScreen.name
    readonly property bool expanded: externallyPinned || previewing
    property real revealProgress: expanded ? 1 : 0
    readonly property real interactiveWidth: compactWidth + drawerWidth * revealProgress

    readonly property color background: shellDark ? "#171817" : "#f4f2ee"
    readonly property color surface: shellDark ? "#222321" : "#e9e6df"
    readonly property color raisedSurface: shellDark ? "#292a28" : "#dfdcd5"
    readonly property color foreground: shellDark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: shellDark ? "#8f918b" : "#6e706a"
    readonly property color border: shellDark ? "#343633" : "#d6d3cc"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property var screenWorkspaces: niriState.workspaces.filter(workspace => workspace.output === outputScreen.name)
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercentage: battery.ready ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: battery.ready && battery.state === UPowerDeviceState.Charging

    screen: outputScreen
    visible: railEnabled
    implicitWidth: compactWidth + drawerWidth
    color: "transparent"
    exclusiveZone: compactWidth
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        width: Math.ceil(rail.interactiveWidth)
        height: rail.height
    }

    anchors {
        left: true
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

    function keyboardLayoutCode(): string {
        const name = String(niriState.keyboardLayout || "")
        const normalized = name.toLowerCase()
        if (normalized.indexOf("english") !== -1 && normalized.indexOf("us") !== -1) return "US"
        if (normalized.indexOf("russian") !== -1) return "RU"
        if (normalized.indexOf("kazakh") !== -1) return "KK"
        return name.length >= 2 ? name.slice(0, 2).toUpperCase() : "--"
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

    Rectangle {
        id: drawer
        x: rail.compactWidth
        width: rail.drawerWidth * rail.revealProgress
        height: parent.height
        color: rail.surface
        clip: true

        Item {
            id: drawerContent
            width: rail.drawerWidth
            height: parent.height
            x: rail.expanded ? 0 : -14
            opacity: rail.revealProgress

            Behavior on x {
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
                    text: rail.showingMedia ? "MEDIA /" : "RAIL / " + rail.outputScreen.name
                    color: rail.accent
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.1
                }

                Image {
                    visible: rail.showingMedia && rail.mediaIconSource !== ""
                    width: 13
                    height: 13
                    source: rail.mediaIconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    visible: rail.showingMedia
                    text: rail.mediaApplicationName.toUpperCase()
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
                text: rail.showingMedia ? (rail.mediaPlaying ? "PLAYING" : "PAUSED") : (rail.externallyPinned ? "PINNED" : "PREVIEW")
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
                text: rail.showingMedia ? rail.mediaTitle : "Open state"
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
                text: rail.showingMedia ? (rail.mediaArtist || rail.mediaAlbum) : (rail.externallyPinned ? "The rail stays open." : "Move across the surface.")
                elide: Text.ElideRight
                color: rail.mutedForeground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }

            Column {
                visible: !rail.showingMedia
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
        x: 0
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

        Column {
            id: workspaceColumn
            anchors.top: upperRule.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
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

            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                text: rail.keyboardLayoutCode()
                color: rail.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
                font.weight: Font.DemiBold

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: 20
                height: 1
                color: rail.border

                Rectangle {
                    anchors.left: parent.left
                    width: 6
                    height: 1
                    color: rail.accent
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
        x: Math.max(rail.compactWidth - 1, rail.interactiveWidth - 1)
        width: 1
        height: parent.height
        color: rail.border
    }
}
