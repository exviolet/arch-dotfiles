import QtQuick

import "../../services"

Item {
    id: control

    required property string label
    required property bool checked
    signal toggled()

    width: 42
    height: 34
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onToggleAction: toggled()
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 22
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.track
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.foreground
        opacity: control.enabled ? 1 : 0.5

        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: width
            radius: width / 2
            color: control.checked ? Theme.accentForeground : Theme.foreground
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled()
    }
}
