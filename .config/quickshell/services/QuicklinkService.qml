pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The `search` prefix: bookmarks and web-search prefixes, the last thing the
// rofi search menu did.
//
// Two tables, both tiny and both hand-edited. What the rofi version also had
// and this one deliberately drops: a log of every open, a per-prefix query
// history, and a sort-mode toggle. The query history had not been touched
// since February while the bookmarks were used the same day, so it was carried
// by inertia rather than need. Frecency survives — it is the ordering that
// makes the list useful — and lives in AppUsageService under "quicklink:"
// keys, sharing one store and one scoring rule with the app grid.
Singleton {
    id: root

    readonly property string dataDir: Quickshell.env("HOME") + "/.config/quickshell/data"
    readonly property string quicklinksPath: root.dataDir + "/quicklinks.tsv"
    readonly property string groupsPath: root.dataDir + "/search-groups.tsv"

    // [{ emoji, name, kind, action }] — kind is url, path or cmd.
    property var links: []

    // [{ prefix, sub, emoji, name, template, base }]
    property var groups: []

    function usageKey(name: string): string {
        return "quicklink:" + name
    }

    // $HOME is the only thing the table uses, and expanding it here keeps the
    // action out of a shell.
    function expand(path: string): string {
        const home = Quickshell.env("HOME")
        return String(path).replace(/^\$HOME/, home).replace(/^~/, home)
    }

    function open(link: var): void {
        if (!link) return

        AppUsageService.record(root.usageKey(String(link.name)))

        const action = String(link.action)
        if (link.kind === "cmd") {
            runner.command = ["/usr/sbin/sh", "-c", action]
            runner.running = true
            return
        }

        const target = link.kind === "path" ? root.expand(action) : action
        runner.command = ["/usr/sbin/xdg-open", target]
        runner.running = true
    }

    function urlFor(group: var, query: string): string {
        if (!group) return ""
        const trimmed = query.trim()
        if (trimmed === "") return String(group.base)
        return String(group.template).replace("%s", encodeURIComponent(trimmed))
    }

    function search(group: var, query: string): void {
        const url = root.urlFor(group, query)
        if (url === "") return

        AppUsageService.record(root.usageKey(String(group.prefix) + ":" + String(group.sub)))
        runner.command = ["/usr/sbin/xdg-open", url]
        runner.running = true
    }

    function groupFor(prefix: string, sub: string): var {
        for (let index = 0; index < root.groups.length; ++index) {
            const group = root.groups[index]
            if (group.prefix === prefix && group.sub === sub) return group
        }
        return null
    }

    // Editing is a rare operation on a file of twenty lines, so it happens in a
    // real editor rather than through six CRUD modes typed into a prompt.
    function edit(which: string): void {
        const path = which === "groups" ? root.groupsPath : root.quicklinksPath
        editor.command = ["/usr/sbin/alacritty", "--class", "Alacritty-Float",
                          "-e", "/usr/sbin/nvim", path]
        editor.running = true
    }

    // One row shape for a heterogeneous list: bookmarks, prefixes, the search
    // about to be run, and the two editing commands.
    function rowsFor(input: string): var {
        const text = String(input)
        const trimmed = text.trim()
        const lowered = trimmed.toLowerCase()

        if (lowered === "edit!" || lowered === "pedit!") {
            const groups = lowered === "pedit!"
            return [{
                "kind": "edit",
                "emoji": "✎",
                "title": groups ? "Править поисковые префиксы" : "Править закладки",
                "subtitle": groups ? "search-groups.tsv" : "quicklinks.tsv",
                "payload": groups ? "groups" : "links"
            }]
        }

        const tokens = trimmed === "" ? [] : trimmed.split(/\s+/)
        const rows = []

        // "g s кошки" — prefix, sub, then everything else is the query.
        if (tokens.length >= 2) {
            const group = root.groupFor(tokens[0], tokens[1])
            if (group) {
                const query = tokens.slice(2).join(" ")
                rows.push({
                    "kind": "search",
                    "emoji": String(group.emoji),
                    "title": query === ""
                        ? String(group.name)
                        : String(group.name) + ": " + query,
                    "subtitle": root.urlFor(group, query),
                    "payload": { "prefix": group.prefix, "sub": group.sub, "query": query }
                })
                return rows
            }
        }

        const needle = lowered

        for (let index = 0; index < root.links.length; ++index) {
            const link = root.links[index]
            if (needle !== "" && link.name.toLowerCase().indexOf(needle) === -1) continue

            rows.push({
                "kind": "link",
                "emoji": String(link.emoji),
                "title": String(link.name),
                "subtitle": String(link.action),
                "payload": link,
                "score": AppUsageService.score(root.usageKey(String(link.name)))
            })
        }

        rows.sort((left, right) => {
            const byScore = (right.score || 0) - (left.score || 0)
            return byScore !== 0 ? byScore : left.title.localeCompare(right.title)
        })

        for (let index = 0; index < root.groups.length; ++index) {
            const group = root.groups[index]
            const key = String(group.prefix) + " " + String(group.sub)

            if (needle !== ""
                && key.indexOf(needle) !== 0
                && group.name.toLowerCase().indexOf(needle) === -1) continue

            rows.push({
                "kind": "group",
                "emoji": String(group.emoji),
                "title": String(group.name),
                "subtitle": key + " …",
                "payload": { "prefix": group.prefix, "sub": group.sub }
            })
        }

        return rows
    }

    function activate(row: var): void {
        if (!row) return

        if (row.kind === "link") {
            root.open(row.payload)
            return
        }

        if (row.kind === "search") {
            root.search(root.groupFor(row.payload.prefix, row.payload.sub), String(row.payload.query))
            return
        }

        if (row.kind === "group") {
            // No query typed yet: the prefix's own landing page.
            root.search(root.groupFor(row.payload.prefix, row.payload.sub), "")
            return
        }

        if (row.kind === "edit") root.edit(String(row.payload))
    }

    function parseLinks(text: string): void {
        const parsed = []
        const lines = String(text).split("\n")

        for (let index = 0; index < lines.length; ++index) {
            const line = lines[index]
            if (line.trim() === "" || line.startsWith("#")) continue

            const fields = line.split("\t")
            if (fields.length < 4) continue

            parsed.push({
                "emoji": fields[0],
                "name": fields[1],
                "kind": fields[2],
                "action": fields[3]
            })
        }

        root.links = parsed
    }

    function parseGroups(text: string): void {
        const parsed = []
        const lines = String(text).split("\n")

        for (let index = 0; index < lines.length; ++index) {
            const line = lines[index]
            if (line.trim() === "" || line.startsWith("#")) continue

            const fields = line.split("\t")
            if (fields.length < 6) continue

            parsed.push({
                "prefix": fields[0],
                "sub": fields[1],
                "emoji": fields[2],
                "name": fields[3],
                "template": fields[4],
                "base": fields[5]
            })
        }

        root.groups = parsed
    }

    // preload matters: without it FileView waits to be asked, onLoaded never
    // fires on its own, and the tables stay empty until something calls text().
    FileView {
        id: linksFile

        path: root.quicklinksPath
        preload: true
        watchChanges: true
        printErrors: true

        onLoaded: root.parseLinks(linksFile.text())
        onFileChanged: {
            linksFile.reload()
            root.parseLinks(linksFile.text())
        }
    }

    FileView {
        id: groupsFile

        path: root.groupsPath
        preload: true
        watchChanges: true
        printErrors: true

        onLoaded: root.parseGroups(groupsFile.text())
        onFileChanged: {
            groupsFile.reload()
            root.parseGroups(groupsFile.text())
        }
    }

    Process {
        id: runner
    }

    Process {
        id: editor
    }
}
