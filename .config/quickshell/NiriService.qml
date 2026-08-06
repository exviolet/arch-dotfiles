import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    property var workspaces: []
    property string focusedOutput: ""
    property string keyboardLayout: ""
    property bool overviewOpen: false
    property bool ready: false
    property bool connected: eventStream.running

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
            const layouts = message.KeyboardLayoutsChanged.keyboard_layouts
            if (layouts && layouts.names && layouts.names.length > layouts.current_idx)
                root.keyboardLayout = layouts.names[layouts.current_idx]
        } else if (message.KeyboardLayoutSwitched) {
            const layout = message.KeyboardLayoutSwitched
            if (layout.name) root.keyboardLayout = layout.name
        } else if (message.OverviewOpenedOrClosed) {
            root.overviewOpen = Boolean(message.OverviewOpenedOrClosed.is_open)
        }
    }

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
