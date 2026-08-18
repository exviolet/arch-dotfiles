import Quickshell.Services.Mpris
import QtQuick

import "../../services"

Item {
    id: surface

    required property var player
    required property string iconSource
    required property string applicationName
    required property bool pinned
    required property bool expanded

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
    readonly property real progress: hasMedia && player.lengthSupported && length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

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

    SurfaceHeader {
        width: parent.width
        eyebrow: "MEDIA /"
        hasIcon: surface.iconSource !== ""
        iconSource: surface.iconSource
        eyebrowLabel: surface.applicationName.toUpperCase()
        mode: surface.playing ? "PLAYING" : "PAUSED"
        pinned: surface.pinned
        expanded: surface.expanded
        title: surface.trackTitle
        subtitle: surface.trackArtist || surface.trackAlbum
    }

    Rectangle {
        x: 22
        y: 158
        width: parent.width - 44
        height: width
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

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
    }

    Rectangle {
        x: 22
        y: 504
        width: parent.width - 44
        height: 142
        radius: 14
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

        Text {
            x: 14
            y: 13
            text: surface.trackAlbum || "NOW PLAYING"
            width: parent.width - 28
            elide: Text.ElideRight
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Rectangle {
            x: 14
            y: 40
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
        }

        Text {
            x: 14
            y: 49
            text: surface.formatDuration(surface.position)
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 8
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 49
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
    }
}
