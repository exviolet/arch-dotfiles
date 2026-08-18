pragma ComponentBehavior: Bound

import Quickshell.Services.Mpris
import QtQuick

import "../../services"

Item {
    id: surface

    required property var controller
    required property var player
    required property string iconSource
    required property string applicationName
    required property bool pinned
    required property bool expanded

    readonly property var players: Mpris.players.values
    readonly property bool hasChoice: players.length > 1

    readonly property bool hasMedia: player !== null
    readonly property bool playing: hasMedia && player.playbackState === MprisPlaybackState.Playing
    readonly property string identity: hasMedia ? String(player.identity) : ""
    readonly property string trackTitle: hasMedia ? String(player.trackTitle) : ""
    readonly property string trackArtist: hasMedia ? String(player.trackArtist) : ""
    readonly property string trackAlbum: hasMedia ? String(player.trackAlbum) : ""
    readonly property string trackArtUrl: hasMedia ? String(player.trackArtUrl) : ""
    readonly property real position: hasMedia ? player.position : 0
    readonly property real length: hasMedia ? player.length : 0
    readonly property bool canPrevious: hasMedia && player.canGoPrevious
    readonly property bool canToggle: hasMedia && player.canTogglePlaying
    readonly property bool canNext: hasMedia && player.canGoNext
    readonly property bool canSeek: hasMedia && player.canSeek && player.lengthSupported && length > 0
    readonly property bool canRaise: hasMedia && player.canRaise
    readonly property bool canControl: hasMedia && player.canControl
    readonly property real volume: hasMedia ? player.volume : 0
    readonly property bool shuffle: hasMedia && player.shuffle
    readonly property int loopState: hasMedia ? player.loopState : MprisLoopState.None
    readonly property real progress: hasMedia && player.lengthSupported && length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    // список плееров сдвигает обложку, поэтому всё ниже считается от него
    readonly property real artTop: hasChoice ? 200 : 158
    readonly property real artSize: width - 44
    readonly property real controlsTop: artTop + artSize + 30

    // MPRIS отдаёт позицию по запросу: без периодического positionChanged
    // счётчик и полоса застывают на значении момента открытия
    Timer {
        running: surface.visible && surface.playing && surface.hasMedia && surface.player.positionSupported
        interval: 1000
        repeat: true
        onTriggered: surface.player.positionChanged()
    }

    function formatDuration(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0) return "--:--"
        const minutes = Math.floor(seconds / 60)
        const remainder = Math.floor(seconds % 60)
        return String(minutes) + ":" + (remainder < 10 ? "0" : "") + String(remainder)
    }

    function seekTo(fraction: real): void {
        if (!canSeek) return
        player.position = Math.max(0, Math.min(1, fraction)) * length
    }

    function loopLabel(): string {
        if (loopState === MprisLoopState.Track) return "ONE"
        if (loopState === MprisLoopState.Playlist) return "ALL"
        return "LOOP"
    }

    function cycleLoop(): void {
        if (!canControl) return
        if (loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist
        else if (loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track
        else player.loopState = MprisLoopState.None
    }

    SurfaceHeader {
        width: parent.width
        eyebrow: "MEDIA /"
        iconSource: surface.iconSource
        eyebrowLabel: surface.applicationName.toUpperCase()
        mode: surface.playing ? "PLAYING" : "PAUSED"
        pinned: surface.pinned
        expanded: surface.expanded
        title: surface.trackTitle
        subtitle: surface.trackArtist || surface.trackAlbum
    }

    Row {
        visible: surface.hasChoice
        x: 22
        y: 150
        spacing: 6

        Repeater {
            model: surface.players

            Rectangle {
                id: playerChip
                required property var modelData
                readonly property bool active: surface.hasMedia && String(modelData.uniqueId) === String(surface.player.uniqueId)
                readonly property string chipIcon: surface.controller.mediaIconSourceFor(modelData)

                width: 44
                height: 34
                radius: 10
                color: active ? Theme.raisedSurface : (chipMouse.containsMouse ? Theme.surface : "transparent")
                border.width: 1
                border.color: active ? Theme.accent : Theme.border

                Image {
                    id: chipImage
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: playerChip.chipIcon
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    visible: chipImage.status !== Image.Ready
                    anchors.centerIn: parent
                    text: String(playerChip.modelData.identity).slice(0, 1).toUpperCase()
                    color: playerChip.active ? Theme.foreground : Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: surface.controller.selectMediaPlayer(String(playerChip.modelData.uniqueId))
                }
            }
        }
    }

    Rectangle {
        x: 22
        y: surface.artTop
        width: surface.artSize
        height: surface.artSize
        color: Theme.raisedSurface
        border.width: 1
        border.color: artMouse.containsMouse && surface.canRaise ? Theme.accent : Theme.border

        Text {
            anchors.centerIn: parent
            text: surface.identity.toUpperCase()
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: surface.trackArtUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
        }

        MouseArea {
            id: artMouse
            anchors.fill: parent
            enabled: surface.canRaise
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: surface.player.raise()
        }
    }

    Rectangle {
        x: 22
        y: surface.controlsTop
        width: surface.artSize
        height: 178
        radius: 14
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

        Text {
            x: 14
            y: 13
            width: parent.width - 142
            text: surface.trackAlbum || "NOW PLAYING"
            elide: Text.ElideRight
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Rectangle {
            x: parent.width - 124
            y: 8
            width: 52
            height: 24
            radius: 8
            color: shuffleMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: surface.shuffle ? Theme.accent : Theme.border
            opacity: surface.canControl ? 1 : 0.35

            Text {
                anchors.centerIn: parent
                text: "SHUF"
                color: surface.shuffle ? Theme.accent : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            MouseArea {
                id: shuffleMouse
                anchors.fill: parent
                enabled: surface.canControl
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: surface.player.shuffle = !surface.shuffle
            }
        }

        Rectangle {
            x: parent.width - 66
            y: 8
            width: 52
            height: 24
            radius: 8
            color: loopMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: surface.loopState !== MprisLoopState.None ? Theme.accent : Theme.border
            opacity: surface.canControl ? 1 : 0.35

            Text {
                anchors.centerIn: parent
                text: surface.loopLabel()
                color: surface.loopState !== MprisLoopState.None ? Theme.accent : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 8
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            MouseArea {
                id: loopMouse
                anchors.fill: parent
                enabled: surface.canControl
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: surface.cycleLoop()
            }
        }

        Rectangle {
            id: mediaTrack
            x: 14
            y: 48
            width: parent.width - 28
            height: 2
            radius: 1
            color: Theme.border

            Rectangle {
                width: parent.width * surface.progress
                height: parent.height
                radius: 1
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                visible: surface.canSeek && seekMouse.containsMouse
                x: Math.max(0, Math.min(parent.width - width, parent.width * surface.progress - width / 2))
                y: -4
                width: 10
                height: 10
                radius: 5
                color: Theme.foreground
            }

            MouseArea {
                id: seekMouse
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                enabled: surface.canSeek
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: mouse => surface.seekTo(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed) surface.seekTo(mouse.x / width)
                }
            }
        }

        Text {
            x: 14
            y: 57
            text: surface.formatDuration(surface.position)
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 8
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 57
            text: surface.formatDuration(surface.length)
            color: Theme.subtleForeground
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
                color: previousMouse.containsMouse ? Theme.surface : "transparent"
                border.width: 1
                border.color: Theme.border
                opacity: surface.canPrevious ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "PREV"
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: previousMouse
                    anchors.fill: parent
                    enabled: surface.canPrevious
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: surface.player.previous()
                }
            }

            Rectangle {
                width: 112
                height: 42
                radius: 10
                color: playMouse.containsMouse ? Theme.accent : Theme.surface
                border.width: 1
                border.color: playMouse.containsMouse ? Theme.accent : Theme.border
                opacity: surface.canToggle ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: surface.playing ? "PAUSE" : "PLAY"
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    enabled: surface.canToggle
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: surface.player.togglePlaying()
                }
            }

            Rectangle {
                width: 76
                height: 42
                radius: 10
                color: nextMouse.containsMouse ? Theme.surface : "transparent"
                border.width: 1
                border.color: Theme.border
                opacity: surface.canNext ? 1 : 0.35

                Text {
                    anchors.centerIn: parent
                    text: "NEXT"
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    enabled: surface.canNext
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: surface.player.next()
                }
            }
        }

        Text {
            x: 14
            y: 133
            text: "PLAYER VOLUME"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.letterSpacing: 0.7
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 131
            text: String(Math.round(Math.max(0, surface.volume) * 100)) + "%"
            color: Theme.foreground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Rectangle {
            x: 14
            y: 156
            width: parent.width - 28
            height: 4
            radius: 2
            color: Theme.border
            opacity: surface.canControl ? 1 : 0.35

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, surface.volume))
                height: parent.height
                radius: 2
                color: Theme.accent
            }

            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * Math.max(0, Math.min(1, surface.volume)) - width / 2))
                y: -3
                width: 10
                height: 10
                radius: 5
                color: Theme.foreground
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                enabled: surface.canControl
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: mouse => surface.player.volume = Math.max(0, Math.min(1, mouse.x / width))
                onPositionChanged: mouse => {
                    if (pressed) surface.player.volume = Math.max(0, Math.min(1, mouse.x / width))
                }
            }
        }
    }
}
