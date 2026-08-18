import QtQuick

import "../../services"

Item {
    id: header

    property string eyebrow: ""
    property bool hasIcon: false
    property url iconSource
    property string eyebrowLabel: ""
    property string mode: ""
    property bool pinned: false
    property bool expanded: false
    property string title: ""
    property string subtitle: ""

    implicitHeight: 140

    Row {
        x: 22
        y: 20
        spacing: 6

        Text {
            text: header.eyebrow
            color: Theme.accent
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }

        Image {
            visible: header.hasIcon
            width: 13
            height: 13
            source: header.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            visible: header.eyebrowLabel !== ""
            text: header.eyebrowLabel
            color: Theme.accent
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 22
        y: 22
        text: header.mode
        color: header.pinned ? Theme.foreground : Theme.subtleForeground
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
    }

    Rectangle {
        x: 22
        y: 45
        width: header.expanded ? 92 : 18
        height: 2
        radius: 1
        color: Theme.accent

        Behavior on width {
            NumberAnimation { duration: 310; easing.type: Easing.OutCubic }
        }
    }

    Text {
        x: 22
        y: 74
        width: parent.width - 44
        text: header.title
        elide: Text.ElideRight
        color: Theme.foreground
        font.family: "DejaVu Sans"
        font.pixelSize: 24
        font.weight: Font.DemiBold
    }

    Text {
        x: 22
        y: 108
        width: parent.width - 44
        text: header.subtitle
        elide: Text.ElideRight
        color: Theme.subtleForeground
        font.family: "DejaVu Sans"
        font.pixelSize: 12
    }
}
