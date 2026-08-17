pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var workspaces: []
    property var windows: []
    property string focusedOutput: ""
    property var keyboardLayouts: []
    property int keyboardLayoutIndex: -1
    property string keyboardLayout: ""
    property bool overviewOpen: false
    property bool ready: false
    property bool connected: eventStream.running

    function copyWindow(window: var): var {
        const stamp = window.focus_timestamp
        return {
            "id": Number(window.id),
            "title": window.title || "",
            "app_id": window.app_id || "",
            "workspace_id": window.workspace_id,
            "is_focused": Boolean(window.is_focused),
            "focus_timestamp": stamp ? Number(stamp.secs) : 0
        }
    }

    function replaceWindows(list: var): void {
        const next = []
        for (let index = 0; index < list.length; ++index)
            next.push(root.copyWindow(list[index]))
        root.windows = next
    }

    // WindowOpenedOrChanged fires for both cases, so upsert rather than append.
    function upsertWindow(window: var): void {
        const incoming = root.copyWindow(window)
        const next = []
        let replaced = false

        for (let index = 0; index < root.windows.length; ++index) {
            const existing = root.windows[index]
            if (existing.id === incoming.id) {
                next.push(incoming)
                replaced = true
            } else {
                // niri reports focus exclusively, so a newly focused window
                // implies every other one lost focus.
                next.push(incoming.is_focused && existing.is_focused
                    ? Object.assign({}, existing, { "is_focused": false })
                    : existing)
            }
        }

        if (!replaced) next.push(incoming)
        root.windows = next
    }

    function removeWindow(id: int): void {
        const next = []
        for (let index = 0; index < root.windows.length; ++index) {
            if (root.windows[index].id !== id)
                next.push(root.windows[index])
        }
        root.windows = next
    }

    function setWindowFocus(id: var): void {
        const focused = id === null || id === undefined ? -1 : Number(id)
        const next = []
        for (let index = 0; index < root.windows.length; ++index) {
            const window = root.windows[index]
            next.push(Object.assign({}, window, { "is_focused": window.id === focused }))
        }
        root.windows = next
    }

    function setWindowFocusTimestamp(id: int, stamp: var): void {
        const seconds = stamp ? Number(stamp.secs) : 0
        const next = []
        for (let index = 0; index < root.windows.length; ++index) {
            const window = root.windows[index]
            next.push(window.id === id
                ? Object.assign({}, window, { "focus_timestamp": seconds })
                : window)
        }
        root.windows = next
    }

    function windowsForAppIds(ids: var): var {
        const wanted = ids.map(id => String(id).toLowerCase())
        return root.windows
            .filter(window => wanted.indexOf(String(window.app_id).toLowerCase()) !== -1)
            .slice()
            .sort((left, right) => right.focus_timestamp - left.focus_timestamp)
    }

    function focusWindow(id: int): void {
        windowAction.exec(["/usr/sbin/niri", "msg", "action", "focus-window", "--id", String(id)])
    }

    function copyWorkspace(workspace: var): var {
        return {
            "id": Number(workspace.id),
            "idx": Number(workspace.idx),
            "name": workspace.name || "",
            "output": workspace.output || "",
            "is_urgent": Boolean(workspace.is_urgent),
            "is_active": Boolean(workspace.is_active),
            "is_focused": Boolean(workspace.is_focused),
            "active_window_id": workspace.active_window_id
        }
    }

    function replaceWorkspaces(items: var): void {
        const next = []
        for (let index = 0; index < items.length; index++) {
            const workspace = root.copyWorkspace(items[index])
            next.push(workspace)
            if (workspace.is_focused) root.focusedOutput = workspace.output
        }
        root.workspaces = next
        root.ready = true
    }

    function activateWorkspace(event: var): void {
        let output = ""
        for (let index = 0; index < root.workspaces.length; index++) {
            if (root.workspaces[index].id === Number(event.id)) {
                output = root.workspaces[index].output
                break
            }
        }
        if (output === "") return

        const next = []
        for (let index = 0; index < root.workspaces.length; index++) {
            const workspace = root.copyWorkspace(root.workspaces[index])
            if (workspace.output === output) workspace.is_active = workspace.id === Number(event.id)
            if (event.focused) workspace.is_focused = workspace.id === Number(event.id)
            next.push(workspace)
        }

        root.workspaces = next
        if (event.focused) root.focusedOutput = output
    }

    function setUrgency(event: var): void {
        const next = []
        for (let index = 0; index < root.workspaces.length; index++) {
            const workspace = root.copyWorkspace(root.workspaces[index])
            if (workspace.id === Number(event.id)) workspace.is_urgent = Boolean(event.urgent)
            next.push(workspace)
        }
        root.workspaces = next
    }

    function replaceKeyboardLayouts(layouts: var): void {
        if (!layouts || !layouts.names) return
        root.keyboardLayouts = layouts.names.slice()
        root.setKeyboardLayoutIndex(Number(layouts.current_idx))
    }

    function setKeyboardLayoutIndex(index: int): void {
        if (index < 0 || index >= root.keyboardLayouts.length) return
        root.keyboardLayoutIndex = index
        root.keyboardLayout = String(root.keyboardLayouts[index])
    }

    function handleLine(line: string): void {
        if (line.trim() === "") return

        let message
        try {
            message = JSON.parse(line)
        } catch (error) {
            console.warn("NiriService: invalid event", error)
            return
        }

        if (message.WorkspacesChanged) {
            root.replaceWorkspaces(message.WorkspacesChanged.workspaces || [])
        } else if (message.WorkspaceActivated) {
            root.activateWorkspace(message.WorkspaceActivated)
        } else if (message.WorkspaceUrgencyChanged) {
            root.setUrgency(message.WorkspaceUrgencyChanged)
        } else if (message.KeyboardLayoutsChanged) {
            root.replaceKeyboardLayouts(message.KeyboardLayoutsChanged.keyboard_layouts)
        } else if (message.KeyboardLayoutSwitched) {
            root.setKeyboardLayoutIndex(Number(message.KeyboardLayoutSwitched.idx))
        } else if (message.OverviewOpenedOrClosed) {
            root.overviewOpen = Boolean(message.OverviewOpenedOrClosed.is_open)
        } else if (message.WindowsChanged) {
            root.replaceWindows(message.WindowsChanged.windows || [])
        } else if (message.WindowOpenedOrChanged) {
            root.upsertWindow(message.WindowOpenedOrChanged.window)
        } else if (message.WindowClosed) {
            root.removeWindow(Number(message.WindowClosed.id))
        } else if (message.WindowFocusChanged) {
            root.setWindowFocus(message.WindowFocusChanged.id)
        } else if (message.WindowFocusTimestampChanged) {
            root.setWindowFocusTimestamp(
                Number(message.WindowFocusTimestampChanged.id),
                message.WindowFocusTimestampChanged.focus_timestamp)
        }
    }

    Process { id: windowAction }

    Process {
        id: eventStream
        command: ["/usr/sbin/niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }

        onExited: (exitCode, exitStatus) => {
            root.ready = false
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: eventStream.running = true
    }
}
