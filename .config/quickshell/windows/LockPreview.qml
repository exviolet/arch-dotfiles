pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "lock"

// The lock face in an ordinary window, so authentication and layout can be
// tried without handing the session to the compositor's lock.
//
// This is not a dev-only crutch: a lock surface is the one window you cannot
// debug while it is up, because a broken one leaves no way back in. Iterating
// here and only then locking is the workflow, not a shortcut.
PanelWindow {
    id: preview

    required property var outputScreen
    required property var lockController

    screen: outputScreen
    visible: lockController.lockPreviewVisible
        && (lockController.lockPreviewScreen === "" || lockController.lockPreviewScreen === outputScreen.name)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    updatesEnabled: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    LockFace {
        anchors.fill: parent
        outputName: preview.outputScreen.name
        lockController: preview.lockController
        preview: true

        onDismissed: preview.lockController.hideLockPreview()
    }
}
