import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Scope {
    id: root

    readonly property bool ready: Pipewire.ready
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var audioDevices: Pipewire.nodes.values.filter(node => node.audio !== null && !node.isStream)
    readonly property var sinks: audioDevices.filter(node => node.type === PwNodeType.AudioSink).slice().sort((left, right) => {
        const kindOrder = { "INTERNAL": 0, "BLUETOOTH": 1, "HDMI": 2, "OUTPUT": 3 }
        const leftKind = root.kind(left)
        const rightKind = root.kind(right)
        const kindDifference = (kindOrder[leftKind] ?? 9) - (kindOrder[rightKind] ?? 9)
        if (kindDifference !== 0) return kindDifference
        return root.label(left).localeCompare(root.label(right))
    })
    readonly property bool sinkReady: sink !== null && sink.ready && sink.audio !== null
    readonly property bool sourceReady: source !== null && source.ready && source.audio !== null
    readonly property real maxVolume: 1.5
    readonly property real volume: sinkReady ? sink.audio.volume : 0
    readonly property bool muted: sinkReady && sink.audio.muted
    readonly property int volumePercent: Math.round(Math.max(0, volume) * 100)

    PwObjectTracker {
        objects: root.audioDevices
    }

    function label(node: var): string {
        if (!node) return "No output"
        if (String(node.nickname || "") !== "") return String(node.nickname)
        if (String(node.description || "") !== "") return String(node.description)
        return String(node.name || "Unknown output")
    }

    function kind(node: var): string {
        if (!node) return "UNAVAILABLE"
        const name = String(node.name || "").toLowerCase()
        const labelText = root.label(node).toLowerCase()
        if (name.indexOf("bluez") !== -1) return "BLUETOOTH"
        if (labelText.indexOf("speaker") !== -1) return "INTERNAL"
        if (name.indexOf("hdmi") !== -1 || labelText.indexOf("hdmi") !== -1 || labelText.indexOf("displayport") !== -1) return "HDMI"
        return "OUTPUT"
    }

    function setVolume(value: real): bool {
        if (!sinkReady) return false
        sink.audio.volume = Math.max(0, Math.min(maxVolume, value))
        return true
    }

    function toggleMute(): bool {
        if (!sinkReady) return false
        sink.audio.muted = !sink.audio.muted
        return true
    }

    function selectSink(id: int): bool {
        for (let index = 0; index < sinks.length; ++index) {
            const candidate = sinks[index]
            if (candidate.id === id) {
                Pipewire.preferredDefaultAudioSink = candidate
                return true
            }
        }
        return false
    }

    function state(): var {
        const routes = []
        for (let index = 0; index < sinks.length; ++index) {
            const node = sinks[index]
            routes.push({
                "id": node.id,
                "label": label(node),
                "kind": kind(node),
                "active": sink !== null && node.id === sink.id
            })
        }
        return {
            "ready": ready,
            "sinkReady": sinkReady,
            "sinkId": sink ? sink.id : -1,
            "sink": label(sink),
            "volume": volume,
            "maxVolume": maxVolume,
            "muted": muted,
            "routes": routes
        }
    }
}
