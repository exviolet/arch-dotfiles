import QtQuick

import "../../services"

Item {
    id: surface

    required property string outputName
    required property string workspaceLabel
    required property bool pinned
    required property bool expanded

    SurfaceHeader {
        width: parent.width
        eyebrow: "RAIL / " + surface.outputName
        mode: surface.pinned ? "PINNED" : "PREVIEW"
        pinned: surface.pinned
        expanded: surface.expanded
        title: "Open state"
        subtitle: surface.pinned ? "The rail stays open." : "Move across the surface."
    }

    Column {
        x: 22
        y: 164
        width: parent.width - 44
        spacing: 10

        Rectangle {
            width: parent.width
            height: 58
            radius: 12
            color: Theme.raisedSurface
            border.width: 1
            border.color: Theme.border

            Text {
                x: 14
                y: 12
                text: "NIRI"
                color: NiriService.ready ? Theme.accent : Theme.warningAccent
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                x: 14
                y: 30
                text: NiriService.ready ? "Event stream connected" : "Waiting for compositor"
                color: Theme.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 21
                text: surface.workspaceLabel
                color: Theme.foreground
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
            border.color: Theme.border

            Text {
                x: 14
                y: 12
                text: "MOTION"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }

            Text {
                x: 14
                y: 30
                text: surface.pinned ? "Click signal to release" : "Click signal to keep open"
                color: Theme.foreground
                font.family: "DejaVu Sans"
                font.pixelSize: 12
            }
        }
    }
}
