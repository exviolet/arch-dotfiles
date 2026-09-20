pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick

import "../services"
import "../components"

PanelWindow {
    id: clipboard

    required property var outputScreen
    required property var clipboardController

    readonly property int cardPadding: 16
    readonly property int queryHeight: 52
    readonly property int textRowHeight: 34
    readonly property int imageRowHeight: 78
    readonly property int listWidth: 400
    readonly property int cardWidth: 1060
    readonly property int bodyHeight: 504
    readonly property int tabsHeight: 30
    readonly property int cardHeight: cardPadding * 2 + queryHeight + 12
        + tabsHeight + 8 + bodyHeight

    property string query: ""
    property int selectedIndex: 0
    // Reset on every open: a remembered tab means eventually opening the
    // clipboard and being shown nine snippets instead of the history.
    property string activeTab: "TEXT"

    readonly property bool searching: clipboard.query.trim() !== ""
    readonly property var selectedEntry: clipboard.results[clipboard.selectedIndex] || null

    readonly property var tabs: {
        let texts = 0
        let images = 0
        const entries = ClipboardService.entries

        for (let index = 0; index < entries.length; ++index) {
            if (entries[index].isImage) ++images
            else ++texts
        }

        return [
            { "id": "TEXT", "label": "TEXT", "count": texts },
            { "id": "IMAGES", "label": "IMAGES", "count": images },
            { "id": "PINNED", "label": "PINNED", "count": ClipboardService.pinnedEntries.length }
        ]
    }

    // The newest entry in the whole history is whatever the clipboard already
    // holds, so copying it back does nothing. Pins keep their cliphist ids and
    // the newest entry can be one of them, so the head is the largest id across
    // both lists rather than simply entries[0].
    //
    // A function, not a binding: results binds to the same two lists, and QML
    // does not order the two re-evaluations. As a property this read stale on
    // the load that mattered — the first one, where the lists went from empty
    // to full — and every open started on row one again.
    function headId(): string {
        let bestId = ""
        let bestNumber = -1
        const lists = [ClipboardService.entries, ClipboardService.pinnedEntries]

        for (let outer = 0; outer < lists.length; ++outer) {
            const list = lists[outer]
            for (let index = 0; index < list.length; ++index) {
                const number = Number(list[index].id)
                if (number > bestNumber) {
                    bestNumber = number
                    bestId = String(list[index].id)
                }
            }
        }

        return bestId
    }

    // Exact match first, then prefix, then start of any word, then a plain
    // substring. Within a tier cliphist's own recency order is kept.
    function rankText(text: string, needle: string): int {
        const lowered = text.toLowerCase()
        if (lowered === needle) return 0
        if (lowered.startsWith(needle)) return 1
        if (new RegExp("\\b" + needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).test(lowered)) return 2
        return lowered.indexOf(needle) !== -1 ? 3 : -1
    }

    function matchesOf(entries: var, needle: string, group: string): var {
        const matches = []

        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index]
            // Image entries have no text to match, so let their format and
            // dimensions stand in: "png" or "1920" both find screenshots.
            const haystack = entry.isImage
                ? entry.format + " " + entry.width + "x" + entry.height + " image"
                : entry.text

            if (needle === "") {
                matches.push({ "entry": entry, "rank": 0, "order": index, "group": group })
                continue
            }

            const rank = clipboard.rankText(haystack, needle)
            if (rank >= 0) matches.push({ "entry": entry, "rank": rank, "order": index, "group": group })
        }

        matches.sort((left, right) => {
            if (left.rank !== right.rank) return left.rank - right.rank
            return left.order - right.order
        })

        return matches
    }

    readonly property var results: {
        const needle = clipboard.query.trim().toLowerCase()

        // A query ranks across every group at once. Typing "admin" has always
        // been the shortest path to a pinned snippet, and scoping the search to
        // the open tab would take that away — which is the whole reason pins
        // can afford to leave the top of the list.
        if (needle !== "") {
            const pinned = clipboard.matchesOf(ClipboardService.pinnedEntries, needle, "PINNED")
            const history = clipboard.matchesOf(ClipboardService.entries, needle, "HISTORY")

            return pinned.concat(history).map(match => Object.assign({}, match.entry, {
                "group": match.group
            }))
        }

        if (clipboard.activeTab === "PINNED")
            return ClipboardService.pinnedEntries.map(entry => Object.assign({}, entry, { "group": "" }))

        const wantImages = clipboard.activeTab === "IMAGES"
        const entries = ClipboardService.entries
        const browsed = []

        for (let index = 0; index < entries.length; ++index) {
            if (entries[index].isImage !== wantImages) continue
            browsed.push(Object.assign({}, entries[index], { "group": "" }))
        }

        return browsed
    }

    function cycleTab(step: int): void {
        if (clipboard.searching) return

        const order = ["TEXT", "IMAGES", "PINNED"]
        const at = order.indexOf(clipboard.activeTab)
        clipboard.activeTab = order[(at + step + order.length) % order.length]
    }

    // Skipped in the pinned tab and while searching: there the first row is an
    // ordinary candidate, not the copy that is already in hand.
    function initialIndex(): int {
        if (clipboard.results.length < 2) return 0
        if (clipboard.searching || clipboard.activeTab === "PINNED") return 0
        return String(clipboard.results[0].id) === clipboard.headId() ? 1 : 0
    }

    function pinOrdinal(entry: var): int {
        if (!entry) return 0

        const pins = ClipboardService.pinnedEntries
        for (let index = 0; index < pins.length && index < 9; ++index)
            if (String(pins[index].id) === String(entry.id)) return index + 1

        return 0
    }

    function setSelection(index: int): void {
        if (clipboard.results.length === 0) return
        clipboard.selectedIndex = Math.max(0, Math.min(clipboard.results.length - 1, index))
        list.positionViewAtIndex(clipboard.selectedIndex, ListView.Contain)
    }

    function copySelected(): void {
        if (!clipboard.selectedEntry) return
        ClipboardService.copy(clipboard.selectedEntry)
        clipboard.clipboardController.hideClipboard()
    }

    // Pin and delete keep the window open: both are things you do repeatedly
    // while tidying up, unlike copying.
    function pinSelected(): void {
        if (!clipboard.selectedEntry) return
        ClipboardService.togglePin(clipboard.selectedEntry)
    }

    function deleteSelected(): void {
        if (!clipboard.selectedEntry) return
        ClipboardService.remove(clipboard.selectedEntry)
    }

    // Nine pins is exactly what a digit row covers, so the snippets that gave up
    // the top of the list get something better in exchange: one keystroke, from
    // any tab, without arrowing anywhere.
    function copyPin(ordinal: int): void {
        const pins = ClipboardService.pinnedEntries
        if (ordinal < 1 || ordinal > pins.length) return

        ClipboardService.copy(pins[ordinal - 1])
        clipboard.clipboardController.hideClipboard()
    }

    onSelectedEntryChanged: ClipboardService.selectEntry(clipboard.selectedEntry)

    onResultsChanged: {
        clipboard.selectedIndex = clipboard.initialIndex()
        list.positionViewAtBeginning()
        ClipboardService.selectEntry(clipboard.results[clipboard.selectedIndex] || null)
    }

    onVisibleChanged: {
        if (visible) {
            ClipboardService.refresh()
            queryInput.forceActiveFocus()
        } else {
            queryInput.clear()
            clipboard.selectedIndex = 0
            clipboard.activeTab = "TEXT"
        }
    }

    screen: outputScreen
    visible: clipboardController.clipboardVisible
        && (clipboardController.clipboardScreen === "" || clipboardController.clipboardScreen === outputScreen.name)
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

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: clipboard.clipboardController.hideClipboard()
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: clipboard.cardWidth
        height: clipboard.cardHeight
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: queryField

            x: clipboard.cardPadding
            y: clipboard.cardPadding
            width: parent.width - clipboard.cardPadding * 2
            height: clipboard.queryHeight
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
                width: parent.width - 336
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.foreground
                selectionColor: Theme.accent
                selectedTextColor: Theme.background
                font.family: "DejaVu Sans"
                font.pixelSize: 15
                clip: true

                onTextChanged: clipboard.query = text

                Text {
                    anchors.fill: parent
                    visible: queryInput.text === ""
                    text: "Search clipboard history"
                    color: Theme.subtleForeground
                    font: queryInput.font
                    verticalAlignment: Text.AlignVCenter
                }

                Keys.onEscapePressed: clipboard.clipboardController.hideClipboard()
                Keys.onReturnPressed: clipboard.copySelected()
                Keys.onEnterPressed: clipboard.copySelected()
                Keys.onUpPressed: clipboard.setSelection(clipboard.selectedIndex - 1)
                Keys.onDownPressed: clipboard.setSelection(clipboard.selectedIndex + 1)
                // Tab and Backtab used to duplicate Down and Up. The arrows are
                // still there, so nothing is lost by spending the pair on the
                // one navigation the list did not have.
                Keys.onTabPressed: clipboard.cycleTab(1)
                Keys.onBacktabPressed: clipboard.cycleTab(-1)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        clipboard.pinSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        clipboard.deleteSelected()
                        event.accepted = true
                    } else if ((event.modifiers & Qt.AltModifier)
                            && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        clipboard.copyPin(event.key - Qt.Key_0)
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width - width - 14
                text: {
                    if (!ClipboardService.ready) return "loading"
                    if (clipboard.results.length === 0) return "no matches"
                    const keys = clipboard.searching ? "" : "⇥ tab · ⌥1-9 pinned · "
                    return keys + "^P pin · ⇧Del remove · " + String(clipboard.results.length)
                }
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }
        }

        // Browse tabs. The three kinds are retrieved differently — history by
        // position, images by eye, pins by name — and sharing one vertical axis
        // made the cheapest of them the most expensive: nine pins, then fifty-odd
        // text rows, before the first screenshot.
        Row {
            id: tabBar

            x: clipboard.cardPadding
            y: queryField.y + queryField.height + 12
            height: clipboard.tabsHeight
            spacing: 6
            // While there is a query the list is one ranked run across every
            // group, so the tabs describe nothing and stop answering.
            opacity: clipboard.searching ? 0.3 : 1
            enabled: !clipboard.searching

            Repeater {
                model: clipboard.tabs

                Rectangle {
                    id: tabChip

                    required property var modelData

                    readonly property bool current: clipboard.activeTab === tabChip.modelData.id

                    width: tabLabel.width + 22
                    height: clipboard.tabsHeight
                    radius: 8
                    color: tabChip.current
                        ? Theme.raisedSurface
                        : (tabHover.hovered ? Theme.surface : "transparent")
                    border.width: 1
                    border.color: tabChip.current ? Theme.accent : Theme.border

                    Row {
                        id: tabLabel

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: tabChip.modelData.label
                            color: tabChip.current ? Theme.foreground : Theme.subtleForeground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                        }

                        Text {
                            text: String(tabChip.modelData.count)
                            color: Theme.subtleForeground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 9
                        }
                    }

                    HoverHandler { id: tabHover }

                    TapHandler {
                        onTapped: clipboard.activeTab = tabChip.modelData.id
                    }
                }
            }
        }

        ListView {
            id: list

            x: clipboard.cardPadding
            y: tabBar.y + tabBar.height + 8
            width: clipboard.listWidth
            height: clipboard.bodyHeight
            model: clipboard.results
            currentIndex: clipboard.selectedIndex
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            section.property: "group"
            section.criteria: ViewSection.FullString
            // A browsed tab holds one kind, so its header would say what the
            // lit chip already says.
            section.delegate: Item {
                required property string section

                width: list.width
                height: section === "" ? 0 : 20
                visible: section !== ""

                Text {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.section
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                }
            }

            delegate: Item {
                id: entryRow

                required property int index
                required property var modelData

                readonly property bool active: clipboard.selectedIndex === entryRow.index
                readonly property int ordinal: clipboard.pinOrdinal(entryRow.modelData)
                readonly property string preview: entryRow.modelData.isImage
                    ? ClipboardService.previewPath(entryRow.modelData.id)
                    : ""

                width: list.width
                height: entryRow.modelData.isImage ? clipboard.imageRowHeight : clipboard.textRowHeight

                // Decoding happens per realised delegate, so only rows the list
                // actually shows cost a process.
                Component.onCompleted: {
                    if (entryRow.modelData.isImage)
                        ClipboardService.requestPreview(entryRow.modelData.id, entryRow.modelData.format)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 2
                    radius: 8
                    color: entryRow.active
                        ? Theme.raisedSurface
                        : (rowHover.hovered ? Theme.surface : "transparent")
                    antialiasing: true
                    border.width: 1
                    border.color: entryRow.active ? Theme.accent : "transparent"

                    // No fill animation: on a fast pointer sweep a fade
                    // leaves several tiles lit at once, which reads as the
                    // highlight lagging behind the cursor.
                    Behavior on border.color {
                        ColorAnimation { duration: 90 }
                    }
                }

                // The digit is the Alt shortcut, not the row number: it stays
                // with its entry in the pinned tab and in search results alike.
                Rectangle {
                    id: ordinalBadge

                    visible: entryRow.ordinal > 0
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17
                    height: 17
                    radius: 5
                    color: "transparent"
                    border.width: 1
                    border.color: entryRow.active ? Theme.accent : Theme.border

                    Text {
                        anchors.centerIn: parent
                        text: String(entryRow.ordinal)
                        color: entryRow.active ? Theme.foreground : Theme.subtleForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 10
                    }
                }

                Text {
                    visible: !entryRow.modelData.isImage
                    x: entryRow.ordinal > 0 ? 35 : 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (entryRow.ordinal > 0 ? 49 : 26)
                    text: entryRow.modelData.text
                    color: Theme.foreground
                    elide: Text.ElideRight
                    font.family: "DejaVu Sans"
                    font.pixelSize: 12
                    font.weight: Font.Normal
                }

                Rectangle {
                    visible: entryRow.modelData.isImage
                    x: 10
                    y: 6
                    width: 92
                    height: parent.height - 14
                    radius: 6
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        source: entryRow.preview === "" ? "" : "file://" + entryRow.preview
                    }
                }

                Text {
                    visible: entryRow.modelData.isImage
                    x: 114
                    y: 20
                    text: entryRow.modelData.format.toUpperCase() + " · "
                        + entryRow.modelData.width + "×" + entryRow.modelData.height
                    color: Theme.foreground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                }

                Text {
                    visible: entryRow.modelData.isImage
                    x: 114
                    y: 40
                    text: entryRow.modelData.sizeLabel
                    color: Theme.subtleForeground
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                }

                HoverHandler {
                    id: rowHover
                }

                TapHandler {
                    onTapped: {
                        clipboard.selectedIndex = entryRow.index
                        clipboard.copySelected()
                    }
                }
            }
        }

        // Preview pane. The list row can only ever show a truncated single
        // line: cliphist's own list output collapses newlines and cuts at 100
        // characters, so the full content has to be decoded separately.
        Rectangle {
            id: preview

            x: list.x + list.width + 12
            y: tabBar.y
            width: parent.width - list.width - clipboard.cardPadding * 2 - 12
            height: list.y + list.height - tabBar.y
            radius: 10
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            clip: true

            Text {
                anchors.centerIn: parent
                visible: clipboard.selectedEntry === null
                text: "nothing selected"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }

            Image {
                anchors.fill: parent
                anchors.margins: 14
                visible: clipboard.selectedEntry !== null && clipboard.selectedEntry.isImage
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                source: {
                    if (!clipboard.selectedEntry || !clipboard.selectedEntry.isImage) return ""
                    const path = ClipboardService.previewPath(clipboard.selectedEntry.id)
                    return path === "" ? "" : "file://" + path
                }
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                visible: clipboard.selectedEntry !== null && !clipboard.selectedEntry.isImage
                contentWidth: width
                contentHeight: previewText.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: previewText

                    width: parent.width
                    text: ClipboardService.selectedLoading ? "…" : ClipboardService.selectedText
                    color: Theme.foreground
                    wrapMode: Text.Wrap
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 11
                }
            }

            Text {
                x: 14
                y: parent.height - height - 10
                visible: clipboard.selectedEntry !== null
                    && !clipboard.selectedEntry.isImage
                    && ClipboardService.selectedText.length >= ClipboardService.previewLimit
                text: "preview truncated at " + String(ClipboardService.previewLimit) + " bytes"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
            }
        }
    }
}
