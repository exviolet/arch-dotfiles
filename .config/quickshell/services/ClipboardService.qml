pragma Singleton

import Quickshell
import Quickshell.Io
import QtCore
import QtQuick

// cliphist history, with image entries decoded to files so they can actually
// be previewed. The rofi menu this replaces piped the same list through
// -dmenu, which renders images as the literal text "[[ binary data ... ]]".
//
// A singleton because the clipboard window is instantiated once per screen
// through Variants, and each instance would otherwise spawn its own decoders.
Singleton {
    id: root

    // Guard against a single huge entry stalling the UI while it renders.
    readonly property int previewLimit: 16384

    // [{ id, text, isImage, format, width, height, sizeLabel, pinned }]
    property var entries: []
    property bool ready: false

    // id -> decoded thumbnail path, for image entries only.
    property var previews: ({})

    // Full content of the selected entry, decoded on demand and capped.
    property string selectedId: ""
    property string selectedText: ""
    property bool selectedLoading: false

    readonly property string runtimeDir: {
        const runtime = String(Quickshell.env("XDG_RUNTIME_DIR") || "")
        return (runtime !== "" ? runtime : "/tmp") + "/quickshell/clipboard"
    }

    // Pins outlive cliphist's history limit, so their content lives in the
    // cache directory rather than the runtime one.
    readonly property string pinDir: {
        const cache = String(Quickshell.env("XDG_CACHE_HOME") || "")
        const base = cache !== "" ? cache : String(Quickshell.env("HOME")) + "/.cache"
        return base + "/quickshell/clipboard-pins"
    }

    // id -> { id, text, isImage, format, width, height, sizeLabel, path }
    property var pins: ({})

    readonly property var pinnedEntries: {
        const list = []
        for (const id in root.pins) list.push(root.pins[id])
        list.sort((left, right) => Number(right.id) - Number(left.id))
        return list
    }

    // Decode queue for thumbnails.
    property var pending: []
    property string decoding: ""
    property var formats: ({})

    function mimeFor(format: string): string {
        const lowered = String(format).toLowerCase()
        // "image/" + extension is wrong for jpg, so map explicitly.
        if (lowered === "jpg" || lowered === "jpeg") return "image/jpeg"
        if (lowered === "gif") return "image/gif"
        if (lowered === "webp") return "image/webp"
        if (lowered === "bmp") return "image/bmp"
        return "image/png"
    }

    function extensionFor(entry: var): string {
        return entry.isImage ? String(entry.format || "png") : "txt"
    }

    function parseLine(line: string): var {
        const tab = line.indexOf("\t")
        if (tab <= 0) return null

        const id = line.slice(0, tab)
        const text = line.slice(tab + 1)

        // cliphist renders binary entries as "[[ binary data 95 KiB png 507x207 ]]"
        const match = /^\[\[\s*binary data\s+(.+?)\s+(\w+)\s+(\d+)x(\d+)\s*\]\]$/.exec(text)
        if (match) {
            return {
                "id": id,
                "text": text,
                "isImage": true,
                "format": match[2],
                "width": Number(match[3]),
                "height": Number(match[4]),
                "sizeLabel": match[1],
                "pinned": false
            }
        }

        return {
            "id": id,
            "text": text,
            "isImage": false,
            "format": "",
            "width": 0,
            "height": 0,
            "sizeLabel": "",
            "pinned": false
        }
    }

    function refresh(): void {
        listProcess.running = false
        listProcess.running = true
    }

    function previewPath(id: string): string {
        if (root.pins[id]) return root.pins[id].path
        return root.previews[id] || ""
    }

    function isPinned(id: string): bool {
        return root.pins[id] !== undefined
    }

    // Thumbnails ------------------------------------------------------------

    // Delegates ask for a preview as they are created, so only the rows the
    // list actually realises get decoded. Decoding runs one at a time to keep
    // a long scroll from spawning a process storm.
    function requestPreview(id: string, format: string): void {
        if (root.previews[id] || root.pins[id]) return
        if (root.decoding === id) return
        if (root.pending.indexOf(id) !== -1) return

        const nextFormats = Object.assign({}, root.formats)
        nextFormats[id] = format
        root.formats = nextFormats

        root.pending = root.pending.concat([id])
        root.pumpDecoder()
    }

    function pumpDecoder(): void {
        if (root.decoding !== "") return
        if (root.pending.length === 0) return

        const id = root.pending[0]
        root.pending = root.pending.slice(1)
        root.decoding = id

        const path = root.runtimeDir + "/" + id + "." + String(root.formats[id] || "png")
        decodeProcess.command = ["/usr/sbin/sh", "-c",
            "mkdir -p " + root.runtimeDir
            + " && /usr/sbin/cliphist decode " + id + " > " + path]
        decodeProcess.running = true
    }

    function finishDecode(): void {
        const id = root.decoding
        if (id === "") return

        const next = Object.assign({}, root.previews)
        next[id] = root.runtimeDir + "/" + id + "." + String(root.formats[id] || "png")
        root.previews = next

        root.decoding = ""
        root.pumpDecoder()
    }

    // Full-content preview --------------------------------------------------

    function selectEntry(entry: var): void {
        if (!entry) {
            root.selectedId = ""
            root.selectedText = ""
            return
        }

        if (root.selectedId === entry.id) return
        root.selectedId = entry.id
        root.selectedText = ""

        // Images are shown from their decoded file; only text needs a read.
        if (entry.isImage) {
            root.selectedLoading = false
            previewTimer.stop()
            return
        }

        root.selectedLoading = true
        previewTimer.restart()
    }

    function loadSelectedText(): void {
        const id = root.selectedId
        if (id === "") return

        const pin = root.pins[id]
        const source = pin
            ? "cat " + pin.path
            : "/usr/sbin/cliphist decode " + id

        previewProcess.command = ["/usr/sbin/sh", "-c",
            source + " | head -c " + String(root.previewLimit)]
        previewProcess.running = true
    }

    // Mutations -------------------------------------------------------------

    // Images need an explicit type: wl-copy defaults to text/plain, which is
    // what made the old script paste garbage for screenshots.
    function copy(entry: var): void {
        const type = entry.isImage ? " --type " + root.mimeFor(entry.format) : ""
        const pin = root.pins[entry.id]

        copyProcess.command = pin
            ? ["/usr/sbin/sh", "-c", "/usr/sbin/wl-copy" + type + " < " + pin.path]
            : ["/usr/sbin/sh", "-c",
               "/usr/sbin/cliphist decode " + entry.id + " | /usr/sbin/wl-copy" + type]
        copyProcess.running = true
    }

    // cliphist identifies an entry to delete by the same "id<TAB>preview" line
    // it prints in `list`, read from stdin. Rather than quoting arbitrary
    // clipboard text into a shell, pick the line back out of `list` by its
    // numeric id — that is the only value interpolated here.
    function remove(entry: var): void {
        if (root.pins[entry.id]) root.unpin(entry)

        deleteProcess.command = ["/usr/sbin/sh", "-c",
            "/usr/sbin/cliphist list"
            + " | awk -F'\\t' -v id=" + entry.id + " '$1 == id'"
            + " | /usr/sbin/cliphist delete"]
        deleteProcess.running = true
    }

    function togglePin(entry: var): void {
        if (root.pins[entry.id]) root.unpin(entry)
        else root.pin(entry)
    }

    // The content is decoded to a file rather than kept in the settings blob:
    // it keeps images working and avoids quoting arbitrary text into a shell.
    function pin(entry: var): void {
        const path = root.pinDir + "/" + entry.id + "." + root.extensionFor(entry)

        const next = Object.assign({}, root.pins)
        next[entry.id] = {
            "id": entry.id,
            "text": entry.text,
            "isImage": entry.isImage,
            "format": entry.format,
            "width": entry.width,
            "height": entry.height,
            "sizeLabel": entry.sizeLabel,
            "pinned": true,
            "path": path
        }
        root.pins = next
        store.pinsJson = JSON.stringify(next)

        pinProcess.command = ["/usr/sbin/sh", "-c",
            "mkdir -p " + root.pinDir
            + " && /usr/sbin/cliphist decode " + entry.id + " > " + path]
        pinProcess.running = true
    }

    function unpin(entry: var): void {
        const pin = root.pins[entry.id]
        if (!pin) return

        const next = Object.assign({}, root.pins)
        delete next[entry.id]
        root.pins = next
        store.pinsJson = JSON.stringify(next)

        unpinProcess.command = ["/usr/sbin/rm", "-f", pin.path]
        unpinProcess.running = true
    }

    Timer {
        id: previewTimer

        // Debounced so holding an arrow key does not spawn a decode per row.
        interval: 80
        repeat: false
        onTriggered: root.loadSelectedText()
    }

    Process {
        id: listProcess

        command: ["/usr/sbin/cliphist", "list"]
        // Loaded when the window opens rather than at startup: the history is
        // hundreds of entries and goes stale the moment anything is copied.
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                const next = []

                for (let index = 0; index < lines.length; ++index) {
                    const parsed = root.parseLine(lines[index])
                    if (!parsed) continue
                    // Pinned entries are listed in their own section, so drop
                    // the history copy to avoid showing them twice.
                    if (root.pins[parsed.id]) continue
                    next.push(parsed)
                }

                root.entries = next
                root.ready = true
            }
        }
    }

    Process {
        id: decodeProcess

        onExited: (exitCode, exitStatus) => root.finishDecode()
    }

    Process {
        id: previewProcess

        stdout: StdioCollector {
            onStreamFinished: {
                root.selectedText = text
                root.selectedLoading = false
            }
        }
    }

    // The settings file lives in pinDir, and is written the moment something
    // is pinned — before any pin command has had a chance to create it.
    Process {
        id: initProcess

        command: ["/usr/sbin/mkdir", "-p", root.pinDir]
        running: true
    }

    Process { id: copyProcess }
    Process { id: pinProcess }
    Process { id: unpinProcess }

    Process {
        id: deleteProcess

        onExited: (exitCode, exitStatus) => root.refresh()
    }

    Settings {
        id: store

        location: "file://" + root.pinDir + "/pins.ini"

        property string pinsJson: "{}"

        Component.onCompleted: {
            try {
                root.pins = JSON.parse(pinsJson) || {}
            } catch (error) {
                root.pins = ({})
            }
        }
    }
}
