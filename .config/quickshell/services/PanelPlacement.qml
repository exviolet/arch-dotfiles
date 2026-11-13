pragma Singleton

import Quickshell
import QtCore
import QtQuick

Singleton {
    id: root

    readonly property int railThickness: 46
    readonly property int islandGap: 8
    readonly property int islandHeight: 42
    readonly property int islandReservation: islandHeight + 2 * islandGap
    readonly property var edges: [
        { "id": "top", "title": "Сверху", "icon": "↑" },
        { "id": "bottom", "title": "Снизу", "icon": "↓" },
        { "id": "left", "title": "Слева", "icon": "←" },
        { "id": "right", "title": "Справа", "icon": "→" }
    ]
    readonly property var dockPositions: edges.concat([
        { "id": "island", "title": "Остров сверху", "icon": "◉" }
    ])
    readonly property var backgrounds: [
        { "id": "solid", "title": "Сплошной", "icon": "●" },
        { "id": "transparent", "title": "Прозрачный", "icon": "○" },
        { "id": "matte", "title": "Матовое стекло", "icon": "◐" }
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
        if (kind === "dock" && edge === "island") return "top"
        if (root.edges.some(option => option.id === edge)) return edge
        if (kind === "rail") return "right"

        const screens = Quickshell.screens
        for (const screen of screens)
            if (screen.name === "eDP-1") return output === "eDP-1" ? "bottom" : ""
        return screens.length > 0 && screens[0].name === output ? "bottom" : ""
    }

    function dockPositionFor(output: string): string {
        return root.positions[output]?.dock === "island" ? "island" : root.edgeFor("dock", output)
    }

    function setEdge(kind: string, output: string, edge: string): void {
        if ((kind !== "rail" && kind !== "dock") || output === "") return
        const options = kind === "dock" ? root.dockPositions : root.edges
        if (edge !== "" && !options.some(option => option.id === edge)) return
        root.saveOption(output, kind, edge)
    }

    function backgroundFor(output: string): string {
        const background = root.positions[output]?.background
        return root.backgrounds.some(option => option.id === background) ? background : "solid"
    }

    function setBackground(output: string, background: string): void {
        if (output === "" || !root.backgrounds.some(option => option.id === background)) return
        root.saveOption(output, "background", background === "solid" ? "" : background)
    }

    function saveOption(output: string, kind: string, value: string): void {
        const next = Object.assign({}, root.positions)
        const placement = Object.assign({}, next[output])
        if (value === "") delete placement[kind]
        else placement[kind] = value

        if (Object.keys(placement).length === 0) delete next[output]
        else next[output] = placement
        store.positionsJson = JSON.stringify(next)
        store.sync()
    }

    function dropEdge(x: real, y: real, width: real, height: real): string {
        if (x < 0 || x >= width || y < 0 || y >= height) return ""

        const distances = [y, height - 1 - y, x, width - 1 - x]
        const closest = Math.min(...distances)
        return closest <= 64 ? root.edges[distances.indexOf(closest)].id : ""
    }

    Settings {
        id: store
        location: "file://" + Quickshell.stateDir + "/panel-placement.ini"
        property string positionsJson: "{}"
    }
}
