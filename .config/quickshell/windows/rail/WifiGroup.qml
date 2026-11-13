pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Networking

import "../../components"
import "../../services"

Column {
    id: group

    required property string title
    required property var networks

    visible: networks.length > 0
    spacing: 3

    Text {
        x: 5
        height: 22
        verticalAlignment: Text.AlignVCenter
        text: group.title.toUpperCase()
        color: Theme.subtleForeground
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 10
        font.letterSpacing: 1
    }

    Repeater {
        model: group.networks

        Rectangle {
            id: entry

            required property var modelData

            width: group.width
            height: 31
            radius: 6
            color: rowMouse.containsMouse || rowMouse.activeFocus ? Theme.surface : "transparent"

            Text {
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.connected ? "●" : "○"
                color: entry.modelData.connected ? Theme.foreground : Theme.subtleForeground
                font.pixelSize: 8
            }

            Text {
                x: 22
                anchors.right: securityIcon.visible ? securityIcon.left : signalLabel.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.name
                elide: Text.ElideRight
                color: entry.modelData.connected ? Theme.foreground : Theme.mutedForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 11
            }

            ThemeIcon {
                id: securityIcon
                anchors.right: signalLabel.left
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                size: 10
                name: "lock"
                color: Theme.subtleForeground
                visible: entry.modelData.security !== WifiSecurityType.Open
            }

            Text {
                id: signalLabel
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: NetworkService.signalPercent(entry.modelData) + "%"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                enabled: !entry.modelData.connected && !entry.modelData.stateChanging
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                Accessible.role: Accessible.Button
                Accessible.name: entry.modelData.name
                Accessible.onPressAction: connectNetwork()
                activeFocusOnTab: true
                Keys.onReturnPressed: connectNetwork()
                Keys.onSpacePressed: connectNetwork()
                onClicked: connectNetwork()

                function connectNetwork(): void {
                    NetworkService.connectNetwork(entry.modelData)
                }
            }
        }
    }
}
