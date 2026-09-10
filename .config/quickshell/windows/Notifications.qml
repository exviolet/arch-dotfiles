pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

import "../services"

// Notification popups, top-right, clear of the rail strip.
//
// Only the cards take input: the window spans the corner but its mask is the
// card column, so everything else on screen keeps its clicks.
PanelWindow {
    id: notifications

    required property var outputScreen

    readonly property int cardWidth: 392
    readonly property int cardSpacing: 10
    readonly property int topMargin: 12

    // Clears the rail's 46px compact strip with a gap of its own.
    readonly property int rightMargin: 58

    screen: outputScreen
    visible: NotificationService.hasPopups
        && (NiriService.focusedOutput === "" || NiriService.focusedOutput === outputScreen.name)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    updatesEnabled: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        right: true
        top: true
        bottom: true
    }

    implicitWidth: cardWidth + rightMargin

    mask: Region {
        x: notifications.width - notifications.cardWidth - notifications.rightMargin
        y: notifications.topMargin
        width: notifications.cardWidth
        height: column.height
    }

    Column {
        id: column

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: notifications.rightMargin
        anchors.topMargin: notifications.topMargin
        width: notifications.cardWidth
        spacing: notifications.cardSpacing

        // Arrival and expiry are system state, not pointer state, so they get
        // to animate. Hover below deliberately does not.
        add: Transition {
            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { properties: "x"; from: 24; to: 0; duration: 160; easing.type: Easing.OutCubic }
        }

        move: Transition {
            NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: NotificationService.popups

            delegate: Rectangle {
                id: card

                required property var modelData

                readonly property var notification: card.modelData.notification
                readonly property bool critical: card.notification.urgency === NotificationUrgency.Critical
                readonly property string iconSource: NotificationService.iconFor(card.notification)
                readonly property var actionList: {
                    // "default" belongs to the card body, not the button row.
                    const all = card.notification.actions
                    const shown = []
                    for (let index = 0; index < all.length; ++index) {
                        if (all[index].identifier !== "default") shown.push(all[index])
                    }
                    return shown
                }
                readonly property bool hasDefaultAction: {
                    const all = card.notification.actions
                    for (let index = 0; index < all.length; ++index) {
                        if (all[index].identifier === "default") return true
                    }
                    return false
                }

                width: notifications.cardWidth
                height: body.implicitHeight + 28
                radius: 14
                color: Theme.background
                border.width: 1
                border.color: Theme.border

                // The stripe is the whole critical treatment. An earlier pass
                // also tinted the border and the app name; three accents on one
                // card read as shouting, and the stripe alone matches the
                // accent bar the rail already uses.
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height - 24
                    radius: 2
                    visible: card.critical
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (card.hasDefaultAction) {
                            NotificationService.invokeAction(card.modelData.id, "default")
                            return
                        }

                        NotificationService.dismiss(card.modelData.id)
                    }
                }

                Column {
                    id: body

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 18

                        Image {
                            id: appIcon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            visible: card.iconSource !== ""
                            source: card.iconSource
                            sourceSize.width: 28
                            sourceSize.height: 28
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            anchors.left: appIcon.visible ? appIcon.right : parent.left
                            anchors.leftMargin: appIcon.visible ? 8 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(card.notification.appName || "Notification")
                            font.pixelSize: 11
                            font.letterSpacing: 0.4
                            color: Theme.subtleForeground
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - 90)
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "✕"
                            font.pixelSize: 11
                            color: Theme.subtleForeground

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                onClicked: NotificationService.dismiss(card.modelData.id)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: String(card.notification.summary || "")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.foreground
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: String(card.notification.body || "")
                        // Senders may send the small HTML subset the spec
                        // allows, and we advertise bodyMarkup support.
                        textFormat: Text.StyledText
                        font.pixelSize: 12
                        color: Theme.mutedForeground
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 5
                        lineHeight: 1.15
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }

                    Row {
                        spacing: 8
                        visible: card.actionList.length > 0
                        topPadding: 2

                        Repeater {
                            model: card.actionList

                            delegate: Rectangle {
                                id: actionButton

                                required property var modelData

                                width: actionLabel.implicitWidth + 22
                                height: 26
                                radius: 8
                                color: actionArea.containsMouse ? Theme.raisedSurface : Theme.surface
                                border.width: 1
                                border.color: actionArea.containsMouse ? Theme.accent : Theme.border

                                Behavior on border.color {
                                    ColorAnimation { duration: 110 }
                                }

                                Text {
                                    id: actionLabel

                                    anchors.centerIn: parent
                                    text: String(actionButton.modelData.text || actionButton.modelData.identifier)
                                    font.pixelSize: 11
                                    color: Theme.foreground
                                }

                                MouseArea {
                                    id: actionArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: NotificationService.invokeAction(
                                        card.modelData.id,
                                        String(actionButton.modelData.identifier))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
