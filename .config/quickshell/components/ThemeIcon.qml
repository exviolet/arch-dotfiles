import QtQuick
import QtQuick.Effects

// An Iconoir glyph tinted to an arbitrary colour.
//
// The SVGs ship with stroke="currentColor", which means nothing to Qt's SVG
// renderer, so they are stored with a white stroke and recoloured here. That
// keeps one file per icon usable in both themes and in every selection state,
// unlike the rail's older icons which have the accent colour baked in.
Item {
    id: root

    required property string name
    property color color: "#ffffff"
    property int size: 24

    implicitWidth: root.size
    implicitHeight: root.size

    Image {
        id: source

        anchors.fill: parent
        source: root.name === "" ? "" : Qt.resolvedUrl("../icons/iconoir/" + root.name + ".svg")
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: source
        colorization: 1
        colorizationColor: root.color
    }
}
