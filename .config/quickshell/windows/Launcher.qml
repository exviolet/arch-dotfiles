pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../components"

PanelWindow {
    id: launcher

    required property var outputScreen
    required property var launcherController

    readonly property int columns: 5
    readonly property int rows: 4
    readonly property int cellWidth: 193
    readonly property int cellHeight: 112
    readonly property int cardPadding: 16
    readonly property int queryHeight: 52
    readonly property int headerHeight: 22
    readonly property int windowRowHeight: 34
    readonly property int maxWindowRows: 4

    readonly property int cardWidth: columns * cellWidth + cardPadding * 2
    readonly property int visibleWindowRows: Math.min(launcher.windowResults.length, launcher.maxWindowRows)
    readonly property int windowSectionHeight: launcher.windowResults.length === 0
        ? 0
        : launcher.headerHeight + launcher.visibleWindowRows * launcher.windowRowHeight + 10
    readonly property int cardHeight: {
        const base = launcher.cardPadding * 2 + launcher.queryHeight + 12

        if (launcher.calcMode) return base + launcher.calcPanelHeight
        if (launcher.searchMode)
            return base + launcher.headerHeight
                + Math.max(1, launcher.visibleSearchRows) * launcher.searchRowHeight
        if (launcher.emojiMode)
            return base + launcher.headerHeight
                + Math.max(1, launcher.visibleEmojiRows) * launcher.emojiRowHeight

        return base + launcher.windowSectionHeight + launcher.headerHeight
            + launcher.rows * launcher.cellHeight
    }
    readonly property var hermesCommand: ["/home/ex1te/.local/bin/hermes", "desktop"]

    property string query: ""

    // The launcher's first prefix mode. `calc` swallows the whole query: apps
    // and windows are hidden, because "calc 2+2" is not a search for anything.
    readonly property int calcPanelHeight: 92

    readonly property int searchRowHeight: 42
    readonly property int maxSearchRows: 7

    readonly property bool searchMode: {
        const lowered = launcher.query.replace(/^\s+/, "").toLowerCase()
        return lowered === "search" || lowered.startsWith("search ")
    }

    readonly property string searchExpression: {
        if (!launcher.searchMode) return ""
        return launcher.query.replace(/^\s+/, "").slice(6).trim()
    }

    readonly property var searchResults: launcher.searchMode
        ? QuicklinkService.rowsFor(launcher.searchExpression)
        : []

    readonly property int visibleSearchRows: Math.min(launcher.searchResults.length, launcher.maxSearchRows)

    readonly property int emojiRowHeight: 34
    readonly property int maxEmojiRows: 8

    readonly property bool emojiMode: {
        const lowered = launcher.query.replace(/^\s+/, "").toLowerCase()
        return lowered === "emoji" || lowered.startsWith("emoji ")
    }

    readonly property string emojiExpression: {
        if (!launcher.emojiMode) return ""
        return launcher.query.replace(/^\s+/, "").slice(5).trim()
    }

    readonly property var emojiResults: launcher.emojiMode
        ? EmojiService.search(launcher.emojiExpression)
        : []

    readonly property int visibleEmojiRows: Math.min(launcher.emojiResults.length, launcher.maxEmojiRows)

    onEmojiModeChanged: if (launcher.emojiMode) EmojiService.ensureLoaded()

    readonly property bool calcMode: {
        const lowered = launcher.query.replace(/^\s+/, "").toLowerCase()
        return lowered === "calc" || lowered.startsWith("calc ")
    }

    readonly property string calcExpression: {
        if (!launcher.calcMode) return ""
        return launcher.query.replace(/^\s+/, "").slice(4).trim()
    }

    onCalcExpressionChanged: if (launcher.calcMode) CalcService.evaluate(launcher.calcExpression)

    // One flat index across both sections: [windows..., apps...]. Keeping a
    // single index is what lets arrow keys cross the section boundary without
    // the two views fighting over focus.
    property int selectedIndex: 0

    readonly property int windowCount: launcher.windowResults.length
    readonly property bool selectionIsWindow: launcher.selectedIndex < launcher.windowCount
    readonly property int selectedAppIndex: launcher.selectedIndex - launcher.windowCount
    readonly property int totalCount: {
        if (launcher.emojiMode) return launcher.emojiResults.length
        if (launcher.searchMode) return launcher.searchResults.length
        return launcher.windowCount + launcher.results.length
    }

    // niri reports a window class, which is only loosely related to the desktop
    // entry id: "Hermes" vs "hermes", "sendoff-desktop" vs "dev.sendoff.app".
    // heuristicLookup covers both by also consulting StartupWMClass.
    function entryForAppId(appId: string): var {
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry) return entry

        // Window rules commonly alias a class as "App-Variant" (see the
        // Alacritty-Float scratch terminal), which matches nothing on its own.
        const dash = appId.indexOf("-")
        return dash > 0 ? DesktopEntries.heuristicLookup(appId.slice(0, dash)) : null
    }

    function workspaceLabel(workspaceId: var): string {
        const workspaces = NiriService.workspaces
        for (let index = 0; index < workspaces.length; ++index) {
            if (workspaces[index].id === workspaceId) {
                const workspace = workspaces[index]
                return workspace.name !== "" ? workspace.name : String(workspace.idx)
            }
        }
        return ""
    }

    // Open windows, most recently focused first, filtered by the same query as
    // the app grid. Matching on title is the point: two Helium windows are only
    // distinguishable by what they are showing.
    readonly property var windowResults: {
        if (launcher.calcMode || launcher.emojiMode || launcher.searchMode) return []

        const needle = launcher.query.trim().toLowerCase()
        const windows = NiriService.windows
        const matches = []

        for (let index = 0; index < windows.length; ++index) {
            const window = windows[index]
            const entry = launcher.entryForAppId(String(window.app_id || ""))
            const appName = entry ? String(entry.name || "") : String(window.app_id || "")

            if (needle !== "") {
                const haystack = (String(window.title || "") + " " + appName + " "
                    + String(window.app_id || "")).toLowerCase()
                if (haystack.indexOf(needle) === -1) continue
            }

            matches.push({
                "id": window.id,
                "title": String(window.title || ""),
                "appName": appName,
                "icon": entry ? launcher.iconFor(entry) : "",
                "workspace": launcher.workspaceLabel(window.workspace_id),
                "focused": window.is_focused,
                "stamp": window.focus_timestamp
            })
        }

        matches.sort((left, right) => right.stamp - left.stamp)
        return matches
    }

    readonly property var results: {
        if (launcher.calcMode || launcher.emojiMode || launcher.searchMode) return []

        const entries = DesktopEntries.applications.values
        const needle = launcher.query.trim().toLowerCase()
        const matches = []

        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index]
            if (entry.noDisplay) continue

            const name = String(entry.name || "")
            const score = AppUsageService.score(String(entry.id || ""))

            if (needle === "") {
                matches.push({ "entry": entry, "rank": 2, "name": name, "score": score })
                continue
            }

            const rank = launcher.rankEntry(entry, name, needle)
            if (rank >= 0) matches.push({ "entry": entry, "rank": rank, "name": name, "score": score })
        }

        // Frecency breaks ties inside a rank tier but never jumps a tier, so
        // typing the start of a name still wins over a well-used entry that
        // only matches on metadata.
        matches.sort((left, right) => {
            if (left.rank !== right.rank) return left.rank - right.rank
            if (left.score !== right.score) return right.score - left.score
            return left.name.localeCompare(right.name)
        })

        return matches.map(match => match.entry)
    }

    // 0 = name starts with the query, 1 = name contains it, 2 = only metadata
    // matches. -1 means no match at all.
    function rankEntry(entry: var, name: string, needle: string): int {
        const lowered = name.toLowerCase()
        if (lowered.startsWith(needle)) return 0
        if (lowered.indexOf(needle) !== -1) return 1

        const haystack = [
            String(entry.genericName || ""),
            String(entry.comment || ""),
            (entry.keywords || []).join(" "),
            (entry.categories || []).join(" ")
        ].join(" ").toLowerCase()

        return haystack.indexOf(needle) !== -1 ? 2 : -1
    }

    readonly property var runningByEntryId: {
        const map = ({})
        const windows = NiriService.windows

        for (let index = 0; index < windows.length; ++index) {
            const window = windows[index]
            const appId = String(window.app_id || "")
            if (appId === "") continue

            const entry = launcher.entryForAppId(appId)
            if (!entry) continue

            const key = String(entry.id)
            if (!map[key]) map[key] = []
            map[key].push(window)
        }

        for (const key in map)
            map[key].sort((left, right) => right.focus_timestamp - left.focus_timestamp)

        return map
    }

    function windowsFor(entry: var): var {
        return launcher.runningByEntryId[String(entry.id || "")] || []
    }

    function iconFor(entry: var): string {
        const name = String(entry.icon || "")
        return name !== "" ? Quickshell.iconPath(name, true) : ""
    }

    function setSelection(index: int): void {
        if (launcher.totalCount === 0) return
        launcher.selectedIndex = Math.max(0, Math.min(launcher.totalCount - 1, index))

        if (launcher.searchMode)
            searchList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
        else if (launcher.emojiMode)
            emojiList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
        else if (launcher.selectionIsWindow)
            windowList.positionViewAtIndex(launcher.selectedIndex, ListView.Contain)
        else
            grid.positionViewAtIndex(launcher.selectedAppIndex, GridView.Contain)
    }

    // Left/Right step through the flat list, so they never trap the selection
    // in a section. Up/Down respect each section's own shape: one row at a time
    // in the window list, a whole grid row in the app grid.
    function moveHorizontal(delta: int): void {
        launcher.setSelection(launcher.selectedIndex + delta)
    }

    function moveVertical(delta: int): void {
        if (launcher.emojiMode || launcher.searchMode) {
            launcher.setSelection(launcher.selectedIndex + delta)
            return
        }

        if (launcher.selectionIsWindow) {
            launcher.setSelection(launcher.selectedIndex + delta)
            return
        }

        const appIndex = launcher.selectedAppIndex
        if (delta < 0 && appIndex < launcher.columns) {
            // Leaving the top grid row upwards lands on the last window.
            launcher.setSelection(launcher.windowCount > 0 ? launcher.windowCount - 1 : 0)
            return
        }

        const nextApp = appIndex + delta * launcher.columns
        if (nextApp < 0 || nextApp >= launcher.results.length) return
        launcher.setSelection(launcher.windowCount + nextApp)
    }

    function focusWindowAt(index: int): void {
        const window = launcher.windowResults[index]
        if (!window) return
        NiriService.focusWindow(window.id)
        launcher.launcherController.hideLauncher()
    }

    function launchApp(index: int): void {
        const entry = launcher.results[index]
        if (!entry) return

        const entryId = String(entry.id || "").toLowerCase()
        AppUsageService.record(String(entry.id || ""))
        if (entryId === "hermes" || entryId === "hermes.desktop")
            Quickshell.execDetached(launcher.hermesCommand)
        else
            entry.execute()
        launcher.launcherController.hideLauncher()
    }

    function focusApp(index: int): void {
        const entry = launcher.results[index]
        if (!entry) return

        const windows = launcher.windowsFor(entry)
        if (windows.length === 0) {
            // Nothing to focus, so fall back to the plain launch.
            launcher.launchApp(index)
            return
        }

        NiriService.focusWindow(windows[0].id)
        launcher.launcherController.hideLauncher()
    }

    // Enter always starts a new instance; Shift+Enter focuses an existing
    // window. A selected window row focuses either way — there is nothing to
    // launch from it.
    function submit(event: var): void {
        if (launcher.calcMode) {
            if (!CalcService.hasResult) return
            CalcService.copyResult()
            launcher.launcherController.hideLauncher()
            return
        }

        if (launcher.searchMode) {
            const row = launcher.searchResults[launcher.selectedIndex]
            if (!row) return
            QuicklinkService.activate(row)
            launcher.launcherController.hideLauncher()
            return
        }

        if (launcher.emojiMode) {
            const picked = launcher.emojiResults[launcher.selectedIndex]
            if (!picked) return
            EmojiService.copy(String(picked.glyph))
            launcher.launcherController.hideLauncher()
            return
        }

        if (launcher.selectionIsWindow) {
            launcher.focusWindowAt(launcher.selectedIndex)
            return
        }

        if (event.modifiers & Qt.ShiftModifier)
            launcher.focusApp(launcher.selectedAppIndex)
        else
            launcher.launchApp(launcher.selectedAppIndex)
    }

    function resetSelection(): void {
        launcher.selectedIndex = 0
        windowList.positionViewAtBeginning()
        grid.positionViewAtBeginning()
    }

    onWindowResultsChanged: launcher.resetSelection()
    onResultsChanged: launcher.resetSelection()

    onVisibleChanged: {
        if (visible) {
            queryInput.text = launcher.launcherController.launcherPrefill
            queryInput.cursorPosition = queryInput.text.length
            queryInput.forceActiveFocus()
        } else {
            queryInput.clear()
            launcher.selectedIndex = 0
        }
    }

    screen: outputScreen
    visible: launcherController.launcherVisible
        && (launcherController.launcherScreen === "" || launcherController.launcherScreen === outputScreen.name)
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

    // Backdrop. Clicking anywhere outside the card dismisses the launcher.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: launcher.launcherController.hideLauncher()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: launcher.cardWidth
        height: launcher.cardHeight
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        Behavior on height {
            NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
        }

        // Swallow clicks so they do not reach the dismissing backdrop.
        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: queryField

            x: launcher.cardPadding
            y: launcher.cardPadding
            width: parent.width - launcher.cardPadding * 2
            height: launcher.queryHeight
            radius: 10
            color: Theme.surface
            border.width: 1
            border.color: queryInput.activeFocus ? Theme.accent : Theme.border

            ThemeIcon {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                size: 18
                name: "search"
                color: queryInput.activeFocus ? Theme.accent : Theme.subtleForeground
            }

            TextInput {
                id: queryInput

                x: 46
                width: parent.width - 166
                anchors.verticalCenter: parent.verticalCenter
                // Deliberately not bound to launcher.query: typing assigns
                // text directly and would break the binding. The query is a
                // one-way mirror of this field, cleared on hide.
                color: Theme.foreground
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                font.family: "DejaVu Sans"
                font.pixelSize: 15
                clip: true

                onTextChanged: launcher.query = text

                Text {
                    anchors.fill: parent
                    visible: queryInput.text === ""
                    text: "Search windows and applications"
                    color: Theme.subtleForeground
                    font: queryInput.font
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onEscapePressed: launcher.launcherController.hideLauncher()
                Keys.onReturnPressed: event => launcher.submit(event)
                Keys.onEnterPressed: event => launcher.submit(event)
                Keys.onUpPressed: launcher.moveVertical(-1)
                Keys.onDownPressed: launcher.moveVertical(1)
                Keys.onLeftPressed: launcher.moveHorizontal(-1)
                Keys.onRightPressed: launcher.moveHorizontal(1)
                Keys.onTabPressed: launcher.moveHorizontal(1)
                Keys.onBacktabPressed: launcher.moveHorizontal(-1)
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - width - 14
                // Surfaces the action for the current selection only when it
                // would actually do something.
                text: {
                    if (launcher.searchMode)
                        return launcher.searchResults.length === 0
                            ? "no matches"
                            : "⏎ open · " + String(launcher.searchResults.length)
                    if (launcher.emojiMode)
                        return launcher.emojiResults.length === 0
                            ? (EmojiService.loaded ? "no matches" : "…")
                            : "⏎ copy · " + String(launcher.emojiResults.length)
                    if (launcher.calcMode)
                        return CalcService.hasResult ? "⏎ copy" : (CalcService.busy ? "…" : "qalc")
                    if (launcher.totalCount === 0) return "no matches"
                    if (launcher.selectionIsWindow) return "⏎ focus"

                    const selected = launcher.results[launcher.selectedAppIndex]
                    if (selected && launcher.windowsFor(selected).length > 0)
                        return "⇧⏎ focus · " + String(launcher.results.length)
                    return String(launcher.results.length)
                }
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }
        }

        ThemeIcon {
            visible: launcher.searchMode
            x: launcher.cardPadding + 4
            y: queryField.y + queryField.height + 12
            size: 11
            name: "search"
            color: Theme.subtleForeground
        }

        Text {
            id: searchHeader

            visible: launcher.searchMode
            x: launcher.cardPadding + 20
            y: queryField.y + queryField.height + 12
            text: "QUICKLINKS"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        ListView {
            id: searchList

            visible: launcher.searchMode
            x: launcher.cardPadding
            y: searchHeader.y + launcher.headerHeight
            width: parent.width - launcher.cardPadding * 2
            height: launcher.visibleSearchRows * launcher.searchRowHeight
            model: launcher.searchResults
            currentIndex: launcher.searchMode ? launcher.selectedIndex : -1
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: searchRow

                required property int index
                required property var modelData

                readonly property bool active: launcher.searchMode
                    && launcher.selectedIndex === searchRow.index

                width: searchList.width
                height: launcher.searchRowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    anchors.bottomMargin: 2
                    radius: 8
                    color: searchRow.active
                        ? Theme.raisedSurface
                        : (searchHover.hovered ? Theme.surface : "transparent")
                    antialiasing: true
                    border.width: 1
                    border.color: searchRow.active ? Theme.accent : "transparent"

                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }
                }

                Text {
                    id: rowEmoji

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(searchRow.modelData.emoji)
                    font.pixelSize: 15
                }

                Text {
                    id: rowTitle

                    anchors.left: rowEmoji.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    text: String(searchRow.modelData.title)
                    color: searchRow.active ? Theme.foreground : Theme.mutedForeground
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    anchors.left: rowTitle.left
                    anchors.right: rowTitle.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: String(searchRow.modelData.subtitle)
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: searchHover
                }

                TapHandler {
                    onTapped: {
                        launcher.setSelection(searchRow.index)
                        QuicklinkService.activate(searchRow.modelData)
                        launcher.launcherController.hideLauncher()
                    }
                }
            }
        }

        ThemeIcon {
            visible: launcher.emojiMode
            x: launcher.cardPadding + 4
            y: queryField.y + queryField.height + 12
            size: 11
            name: "search"
            color: Theme.subtleForeground
        }

        Text {
            id: emojiHeader

            visible: launcher.emojiMode
            x: launcher.cardPadding + 20
            y: queryField.y + queryField.height + 12
            text: "EMOJI"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        ListView {
            id: emojiList

            visible: launcher.emojiMode
            x: launcher.cardPadding
            y: emojiHeader.y + launcher.headerHeight
            width: parent.width - launcher.cardPadding * 2
            height: launcher.visibleEmojiRows * launcher.emojiRowHeight
            model: launcher.emojiResults
            currentIndex: launcher.emojiMode ? launcher.selectedIndex : -1
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: emojiRow

                required property int index
                required property var modelData

                readonly property bool active: launcher.emojiMode
                    && launcher.selectedIndex === emojiRow.index

                width: emojiList.width
                height: launcher.emojiRowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    anchors.bottomMargin: 2
                    radius: 8
                    color: emojiRow.active
                        ? Theme.raisedSurface
                        : (emojiHover.hovered ? Theme.surface : "transparent")
                    antialiasing: true
                    border.width: 1
                    border.color: emojiRow.active ? Theme.accent : "transparent"

                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }
                }

                Text {
                    id: glyph

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(emojiRow.modelData.glyph)
                    font.pixelSize: 17
                }

                Text {
                    anchors.left: glyph.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(emojiRow.modelData.name)
                    color: emojiRow.active ? Theme.foreground : Theme.mutedForeground
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: emojiHover
                }

                TapHandler {
                    onTapped: {
                        launcher.setSelection(emojiRow.index)
                        EmojiService.copy(String(emojiRow.modelData.glyph))
                        launcher.launcherController.hideLauncher()
                    }
                }
            }
        }

        Rectangle {
            visible: launcher.calcMode
            x: launcher.cardPadding
            y: queryField.y + queryField.height + 12
            width: parent.width - launcher.cardPadding * 2
            height: launcher.calcPanelHeight
            radius: 12
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            Text {
                x: 16
                y: 12
                text: "QALC"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 6
                text: {
                    if (launcher.calcExpression === "") return "2+2 · 1 GiB to MB · 100 USD to EUR"
                    if (CalcService.hasResult) return CalcService.result
                    return CalcService.busy ? "…" : "не считается"
                }
                color: CalcService.hasResult ? Theme.foreground : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: CalcService.hasResult ? 22 : 12
                font.weight: CalcService.hasResult ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }

        ThemeIcon {
            visible: launcher.windowResults.length > 0
            x: launcher.cardPadding + 4
            y: queryField.y + queryField.height + 12
            size: 11
            name: "app-window"
            color: Theme.subtleForeground
        }

        Text {
            id: windowsHeader

            visible: launcher.windowResults.length > 0
            x: launcher.cardPadding + 20
            y: queryField.y + queryField.height + 12
            text: "OPEN WINDOWS"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        ListView {
            id: windowList

            visible: launcher.windowResults.length > 0
            x: launcher.cardPadding
            y: windowsHeader.y + launcher.headerHeight
            width: parent.width - launcher.cardPadding * 2
            height: launcher.visibleWindowRows * launcher.windowRowHeight
            model: launcher.windowResults
            currentIndex: launcher.selectionIsWindow ? launcher.selectedIndex : -1
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: windowRow

                required property int index
                required property var modelData

                readonly property bool active: launcher.selectionIsWindow
                    && launcher.selectedIndex === windowRow.index

                width: windowList.width
                height: launcher.windowRowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    anchors.bottomMargin: 2
                    radius: 8
                    color: windowRow.active
                        ? Theme.raisedSurface
                        : (rowHover.hovered ? Theme.surface : "transparent")
                    antialiasing: true
                    border.width: 1
                    border.color: windowRow.active ? Theme.accent : "transparent"

                    // No fill animation: on a fast pointer sweep a fade
                    // leaves several tiles lit at once, which reads as the
                    // highlight lagging behind the cursor.
                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }
                }

                Rectangle {
                    visible: windowRow.modelData.focused
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 14
                    radius: 1
                    color: Theme.accent
                }

                Image {
                    id: windowIcon

                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    sourceSize.width: 18
                    sourceSize.height: 18
                    fillMode: Image.PreserveAspectFit
                    source: windowRow.modelData.icon
                    visible: source !== ""
                }

                Text {
                    x: 42
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 300
                    text: windowRow.modelData.title
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }

                Text {
                    x: parent.width - 190
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130
                    text: windowRow.modelData.appName
                    color: Theme.subtleForeground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    font.family: "DejaVu Sans"
                    font.pixelSize: 10
                }

                Text {
                    x: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    visible: text !== ""
                    text: windowRow.modelData.workspace === ""
                        ? ""
                        : "ws" + windowRow.modelData.workspace
                    color: Theme.subtleForeground
                    horizontalAlignment: Text.AlignRight
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                HoverHandler {
                    id: rowHover
                }

                TapHandler {
                    onTapped: {
                        launcher.selectedIndex = windowRow.index
                        launcher.focusWindowAt(windowRow.index)
                    }
                }
            }
        }

        ThemeIcon {
            visible: !launcher.calcMode && !launcher.emojiMode && !launcher.searchMode
            x: launcher.cardPadding + 4
            y: appsHeader.y
            size: 11
            name: "view-grid"
            color: Theme.subtleForeground
        }

        Text {
            id: appsHeader

            visible: !launcher.calcMode && !launcher.emojiMode && !launcher.searchMode
            x: launcher.cardPadding + 20
            y: launcher.windowResults.length === 0
                ? queryField.y + queryField.height + 12
                : windowList.y + windowList.height + 10
            text: "APPLICATIONS"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        GridView {
            id: grid

            visible: !launcher.calcMode && !launcher.emojiMode && !launcher.searchMode
            x: launcher.cardPadding
            y: appsHeader.y + launcher.headerHeight
            width: parent.width - launcher.cardPadding * 2
            height: launcher.rows * launcher.cellHeight
            cellWidth: launcher.cellWidth
            cellHeight: launcher.cellHeight
            model: launcher.results
            currentIndex: launcher.selectionIsWindow ? -1 : launcher.selectedAppIndex
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: appCell

                required property int index
                required property var modelData

                readonly property bool active: !launcher.selectionIsWindow
                    && launcher.selectedAppIndex === appCell.index
                readonly property var openWindows: launcher.windowsFor(appCell.modelData)

                width: launcher.cellWidth
                height: launcher.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 10
                    color: appCell.active
                        ? Theme.raisedSurface
                        : (cellHover.hovered ? Theme.surface : "transparent")
                    antialiasing: true
                    border.width: 1
                    border.color: appCell.active ? Theme.accent : "transparent"

                    // No fill animation: on a fast pointer sweep a fade
                    // leaves several tiles lit at once, which reads as the
                    // highlight lagging behind the cursor.
                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }
                }

                // Running marker: a bar on the left edge of the tile, with a
                // count only when more than one window is open.
                Rectangle {
                    visible: appCell.openWindows.length > 0
                    x: 8
                    y: 22
                    width: 2
                    height: 32
                    radius: 1
                    color: Theme.accent
                }

                Text {
                    visible: appCell.openWindows.length > 1
                    x: 14
                    y: 30
                    text: String(appCell.openWindows.length)
                    color: Theme.accent
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }

                Image {
                    id: appIcon

                    y: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 48
                    sourceSize.width: 48
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectFit
                    source: launcher.iconFor(appCell.modelData)
                    visible: source !== ""
                }

                Text {
                    y: 70
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(appCell.modelData.name || "")
                    color: Theme.foreground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                }

                Text {
                    y: 86
                    width: parent.width - 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: String(appCell.modelData.genericName || "")
                    visible: text !== ""
                    color: Theme.subtleForeground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "DejaVu Sans"
                    font.pixelSize: 9
                }

                HoverHandler {
                    id: cellHover
                }

                TapHandler {
                    onTapped: {
                        launcher.selectedIndex = launcher.windowCount + appCell.index
                        launcher.launchApp(appCell.index)
                    }
                }
            }
        }
    }
}
