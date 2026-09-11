pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import "../../services"

// What the lock screen looks like. Lives apart from Lock.qml because it is
// rendered two ways: inside the real WlSessionLockSurface, and inside an
// ordinary window through previewLock() so the design can be iterated on
// without any risk of locking the session behind a broken surface.
FocusScope {
    id: face

    required property string outputName
    required property var lockController

    // The preview has an escape hatch; the real lock must not.
    property bool preview: false

    readonly property string wallpaper: LockService.wallpaperFor(face.outputName)

    signal dismissed

    function submit(): void {
        if (passwordInput.text === "") return
        LockService.authenticate(passwordInput.text)
        passwordInput.clear()
    }

    focus: true
    Keys.onEscapePressed: if (face.preview) face.dismissed()

    // Declaring focus is not enough: the item tree is built before the surface
    // is mapped, so the grab has to be taken again once it actually appears.
    onVisibleChanged: if (face.visible) passwordInput.forceActiveFocus()
    Component.onCompleted: if (face.visible) passwordInput.forceActiveFocus()

    // A disabled TextInput drops active focus, so every failed attempt used to
    // leave the field dead until it was clicked.
    Connections {
        target: LockService

        function onAuthenticatingChanged(): void {
            if (!LockService.authenticating) passwordInput.forceActiveFocus()
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    // A keyboard grab you can only leave by keyboard is a trap: if the key
    // handler is what broke, there is no way to say so. Preview only.
    MouseArea {
        anchors.fill: parent
        enabled: face.preview
        onClicked: face.dismissed()
    }

    Image {
        anchors.fill: parent
        visible: face.wallpaper !== ""
        source: face.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    // Doubles as the whole background when there is no wallpaper to read.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: face.wallpaper === "" ? 1 : 0.62
    }

    Column {
        anchors.centerIn: parent
        spacing: 14

        Rectangle {
            id: field

            width: 320
            height: 52
            radius: 12
            color: Theme.background
            border.width: 2
            border.color: LockService.statusIsError
                ? Theme.accent
                : (passwordInput.activeFocus ? Theme.accent : Theme.border)
            opacity: 0.96

            Behavior on border.color {
                ColorAnimation { duration: 140 }
            }

            TextInput {
                id: passwordInput

                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                font.pixelSize: 16
                color: Theme.foreground
                enabled: !LockService.authenticating
                focus: true
                clip: true

                onAccepted: face.submit()

                // The preview grabs the keyboard exclusively, so its way out
                // must not depend on the key reaching the parent handler.
                Keys.onEscapePressed: if (face.preview) face.dismissed()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: passwordInput.text === "" && !LockService.authenticating
                    text: "Пароль"
                    font.pixelSize: 15
                    color: Theme.subtleForeground
                }

                Text {
                    anchors.centerIn: parent
                    visible: LockService.authenticating
                    text: "Проверяю…"
                    font.pixelSize: 14
                    color: Theme.mutedForeground
                }
            }
        }

        Item {
            width: field.width
            height: 18

            Text {
                anchors.centerIn: parent
                visible: LockService.status !== ""
                text: LockService.status
                font.pixelSize: 12
                color: LockService.statusIsError ? Theme.accent : Theme.mutedForeground
            }

            // Layout and charge, the two readouts hyprlock had been failing to
            // show since its helper scripts went missing.
            Row {
                anchors.centerIn: parent
                visible: LockService.status === ""
                spacing: 10

                Text {
                    text: face.lockController.keyboardLayoutCode(NiriService.keyboardLayout)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: face.lockController.keyboardLayoutColor(NiriService.keyboardLayout)
                }

                Text {
                    text: "·"
                    font.pixelSize: 12
                    color: Theme.subtleForeground
                }

                Text {
                    text: PowerService.batteryPercent + "%" + (PowerService.charging ? " ↑" : "")
                    font.pixelSize: 12
                    color: Theme.mutedForeground
                }
            }
        }
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 64
        anchors.bottomMargin: 52
        spacing: 2

        Text {
            anchors.right: parent.right
            text: Quickshell.env("USER") || ""
            font.pixelSize: 18
            color: Theme.mutedForeground
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: 64
            font.weight: Font.DemiBold
            color: Theme.foreground
        }

        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            font.pixelSize: 15
            color: Theme.mutedForeground
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        visible: face.preview
        text: "Предпросмотр — Esc закрывает. Сессия не заблокирована."
        font.pixelSize: 12
        color: Theme.subtleForeground
    }
}
