pragma ComponentBehavior: Bound

import QtQuick

import "../../services"

Item {
    id: surface

    required property bool pinned
    required property bool expanded

    readonly property real routesTop: 330
    readonly property real routesHeight: 28 + AudioService.sinks.length * 44 + Math.max(0, AudioService.sinks.length - 1) * 7

    SurfaceHeader {
        width: parent.width
        eyebrow: "AUDIO /"
        iconSource: Qt.resolvedUrl(AudioService.muted ? "../../icons/iconoir/sound-off.svg" : "../../icons/iconoir/sound-high.svg")
        eyebrowLabel: "PIPEWIRE"
        mode: AudioService.muted ? "MUTED" : String(AudioService.volumePercent) + "%"
        pinned: surface.pinned
        expanded: surface.expanded
        title: AudioService.label(AudioService.sink)
        subtitle: AudioService.kind(AudioService.sink) + " / DEFAULT OUTPUT"
    }

    Rectangle {
        x: 22
        y: 158
        width: parent.width - 44
        height: 144
        radius: 14
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

        Text {
            x: 14
            y: 14
            text: "OUTPUT LEVEL"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 10
            text: AudioService.muted ? "MUTED" : String(AudioService.volumePercent) + "%"
            color: AudioService.muted ? Theme.warningAccent : Theme.foreground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Rectangle {
            x: 14
            y: 50
            width: parent.width - 28
            height: 4
            radius: 2
            color: Theme.border

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, AudioService.volume / AudioService.maxVolume))
                height: parent.height
                radius: 2
                color: AudioService.muted ? Theme.subtleForeground : Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * AudioService.volume / AudioService.maxVolume - width / 2))
                y: -3
                width: 10
                height: 10
                radius: 5
                color: Theme.foreground

                Behavior on x {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                x: Math.round(parent.width / AudioService.maxVolume) - 1
                y: -3
                width: 1
                height: 10
                color: Theme.subtleForeground
                opacity: 0.55
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => AudioService.setVolume(mouse.x / width * AudioService.maxVolume)
                onPositionChanged: mouse => {
                    if (pressed) AudioService.setVolume(mouse.x / width * AudioService.maxVolume)
                }
            }
        }

        Rectangle {
            x: 14
            y: 82
            width: parent.width - 28
            height: 44
            radius: 10
            color: audioMuteMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: AudioService.muted ? Theme.warningAccent : Theme.border

            Text {
                anchors.centerIn: parent
                text: AudioService.muted ? "UNMUTE OUTPUT" : "MUTE OUTPUT"
                color: AudioService.muted ? Theme.warningAccent : Theme.foreground
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
                onClicked: AudioService.toggleMute()
            }
        }
    }

    Item {
        x: 22
        y: surface.routesTop
        width: parent.width - 44
        height: 330

        Text {
            x: 0
            y: 0
            text: "OUTPUT ROUTES / " + String(AudioService.sinks.length)
            color: Theme.subtleForeground
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
                model: AudioService.sinks

                Rectangle {
                    id: routeItem
                    required property var modelData
                    readonly property bool active: AudioService.sink !== null && modelData.id === AudioService.sink.id
                    width: parent.width
                    height: 44
                    radius: 10
                    color: active ? Theme.raisedSurface : (routeMouse.containsMouse ? Theme.surface : "transparent")
                    border.width: active ? 1 : 0
                    border.color: Theme.border

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 16
                        radius: 1
                        color: Theme.accent
                        opacity: routeItem.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 112
                        text: AudioService.label(routeItem.modelData)
                        elide: Text.ElideRight
                        color: routeItem.active ? Theme.foreground : Theme.subtleForeground
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
                        text: routeItem.active ? "ACTIVE" : AudioService.kind(routeItem.modelData)
                        color: routeItem.active ? Theme.accent : Theme.subtleForeground
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
                        onClicked: AudioService.selectSink(routeItem.modelData.id)
                    }
                }
            }
        }
    }

    Rectangle {
        visible: AudioService.sourceReady
        x: 22
        y: surface.routesTop + surface.routesHeight + 22
        width: parent.width - 44
        height: 182 + Math.ceil(AudioService.sources.length / 2) * 48
        radius: 14
        color: Theme.raisedSurface
        border.width: 1
        border.color: Theme.border

        Text {
            x: 14
            y: 12
            text: "INPUT / " + AudioService.kind(AudioService.source)
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 10
            text: AudioService.sourceMuted ? "MUTED" : String(AudioService.sourceVolumePercent) + "%"
            color: AudioService.sourceMuted ? Theme.warningAccent : Theme.foreground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Text {
            x: 14
            y: 34
            width: parent.width - 28
            text: AudioService.label(AudioService.source)
            elide: Text.ElideRight
            color: Theme.foreground
            font.family: "DejaVu Sans"
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Rectangle {
            x: 14
            y: 69
            width: parent.width - 28
            height: 4
            radius: 2
            color: Theme.border

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, AudioService.sourceVolume / AudioService.maxSourceVolume))
                height: parent.height
                radius: 2
                color: AudioService.sourceMuted ? Theme.subtleForeground : Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * AudioService.sourceVolume / AudioService.maxSourceVolume - width / 2))
                y: -3
                width: 10
                height: 10
                radius: 5
                color: Theme.foreground

                Behavior on x {
                    NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                x: Math.round(parent.width / AudioService.maxSourceVolume) - 1
                y: -3
                width: 1
                height: 10
                color: Theme.subtleForeground
                opacity: 0.55
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -12
                anchors.bottomMargin: -12
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => AudioService.setSourceVolume(mouse.x / width * AudioService.maxSourceVolume)
                onPositionChanged: mouse => {
                    if (pressed) AudioService.setSourceVolume(mouse.x / width * AudioService.maxSourceVolume)
                }
            }
        }

        Rectangle {
            x: 14
            y: 96
            width: parent.width - 28
            height: 40
            radius: 10
            color: microphoneMuteMouse.containsMouse ? Theme.surface : "transparent"
            border.width: 1
            border.color: AudioService.sourceMuted ? Theme.warningAccent : Theme.border

            Text {
                anchors.centerIn: parent
                text: AudioService.sourceMuted ? "ENABLE INPUT" : "MUTE INPUT"
                color: AudioService.sourceMuted ? Theme.warningAccent : Theme.foreground
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
                onClicked: AudioService.toggleSourceMute()
            }
        }

        Text {
            x: 14
            y: 151
            text: "SOURCE ROUTES / " + String(AudioService.sources.length)
            color: Theme.subtleForeground
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
                model: AudioService.sources

                Rectangle {
                    id: inputRouteItem
                    required property var modelData
                    readonly property bool active: AudioService.source !== null && modelData.id === AudioService.source.id
                    width: (parent.width - 7) / 2
                    height: 42
                    radius: 9
                    color: active ? Theme.surface : (inputRouteMouse.containsMouse ? Theme.surface : "transparent")
                    border.width: 1
                    border.color: active ? Theme.border : Qt.rgba(0, 0, 0, 0)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 14
                        radius: 1
                        color: Theme.accent
                        opacity: inputRouteItem.active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        x: 11
                        y: 6
                        width: parent.width - 20
                        text: AudioService.label(inputRouteItem.modelData)
                        elide: Text.ElideRight
                        color: inputRouteItem.active ? Theme.foreground : Theme.subtleForeground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 10
                        font.weight: inputRouteItem.active ? Font.DemiBold : Font.Medium
                    }

                    Text {
                        x: 11
                        y: 24
                        text: inputRouteItem.active ? "ACTIVE" : AudioService.kind(inputRouteItem.modelData)
                        color: inputRouteItem.active ? Theme.accent : Theme.subtleForeground
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
                                AudioService.selectSource(inputRouteItem.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
