pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "lock"

// The real session lock. One surface per screen, created by the compositor.
//
// Nothing in here may throw while the session is locked: if this process dies
// without unlocking, the compositor keeps every screen locked and only a new
// lock client can release them. That recovery path is `sidecarctl unlock`.
// Iterate on the face through previewLock() instead of locking.
Scope {
    id: lock

    required property var lockController

    WlSessionLock {
        id: session

        locked: LockService.locked

        WlSessionLockSurface {
            id: surface

            color: Theme.background

            LockFace {
                anchors.fill: parent
                outputName: surface.screen ? surface.screen.name : ""
                lockController: lock.lockController
            }
        }
    }
}
