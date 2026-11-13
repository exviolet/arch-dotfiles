pragma Singleton

import Quickshell
import QtCore
import QtQuick

Singleton {
    id: root

    readonly property int railThickness: 46
    readonly property var edges: [
        { "id": "top", "title": "Сверху", "icon": "↑" },
        { "id": "bottom", "title": "Снизу", "icon": "↓" },
        { "id": "left", "title": "Слева", "icon": "←" },
        { "id": "right", "title": "Справа", "icon": "→" }
    ]
    readonly property var positions: {
        try {
            return JSON.parse(store.positionsJson) || ({})
        } catch (error) {
            return ({})
        }
    }

    function edgeFor(kind: string, output: string): string {
        const edge = root.positions[output]?.[kind]
        if (root.edges.some(option => option.id === edge)) return edge
        if (kind === "rail") return "right"

        const screens = Quickshell.screens
        for (const screen of screens)
            if (screen.name === "eDP-1") return output === "eDP-1" ? "bottom" : ""
        return screens.length > 0 && screens[0].name === output ? "bottom" : ""
    }

    function setEdge(kind: string, output: string, edge: string): void {
        if ((kind !== "rail" && kind !== "dock") || output === "") return
        if (edge !== "" && !root.edges.some(option => option.id === edge)) return
        const next = Object.assign({}, root.positions)
        const placement = Object.assign({}, next[output])
        if (edge === "") delete placement[kind]
        else placement[kind] = edge

        if (Object.keys(placement).length === 0) delete next[output]
        else next[output] = placement
        store.positionsJson = JSON.stringify(next)
        store.sync()
    }

    Settings {
        id: store
        location: "file://" + Quickshell.stateDir + "/panel-placement.ini"
        property string positionsJson: "{}"
    }
}
