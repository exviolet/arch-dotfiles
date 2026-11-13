import QtQuick
import QtQuick.Controls.Basic as Controls

import "../../services"

Rectangle {
    id: setting
    required property string label
    required property bool available
    required property int level
    property int maximum: 100
    signal requested(int value)

    height: 48
    radius: 12
    color: Theme.raisedSurface

    onLevelChanged: {
        if (!slider.pressed) slider.value = level
    }

    Text {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: setting.label
        color: Theme.foreground
        font.family: "DejaVu Sans"
        font.pixelSize: 12
    }

    Text {
        id: percentage
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: setting.available ? Math.round(slider.value) + "%" : "N/A"
        color: Theme.subtleForeground
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 10
    }

    Controls.Slider {
        id: slider
        anchors.right: percentage.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(parent.width - 150, parent.width * 0.48))
        height: 32
        from: 0
        to: setting.maximum
        stepSize: 1
        enabled: setting.available
        Accessible.name: setting.label
        Component.onCompleted: value = setting.level
        onPressedChanged: {
            if (!pressed && Math.round(value) !== setting.level)
                setting.requested(Math.round(value))
        }
        onMoved: {
            if (!pressed) setting.requested(Math.round(value))
        }

        background: Rectangle {
            x: slider.leftPadding
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Theme.track

            Rectangle {
                width: parent.width * slider.visualPosition
                height: parent.height
                radius: 2
                color: slider.enabled ? Theme.foreground : Theme.subtleForeground
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 12
            height: width
            radius: 6
            color: slider.enabled ? Theme.foreground : Theme.subtleForeground
            border.width: slider.activeFocus ? 2 : 0
            border.color: Theme.accent
        }
    }
}
