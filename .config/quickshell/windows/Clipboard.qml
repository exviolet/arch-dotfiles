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
    readonly property int cardHeight: cardPadding * 2 + queryHeight + 12 + bodyHeight

    property string query: ""
    property int selectedIndex: 0

    readonly property var selectedEntry: clipboard.results[clipboard.selectedIndex] || null

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
        const pinned = clipboard.matchesOf(ClipboardService.pinnedEntries, needle, "PINNED")
        const history = clipboard.matchesOf(ClipboardService.entries, needle, "HISTORY")

        return pinned.concat(history).map(match => Object.assign({}, match.entry, {
            "group": match.group
        }))
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

    onSelectedEntryChanged: ClipboardService.selectEntry(clipboard.selectedEntry)

    onResultsChanged: {
        clipboard.selectedIndex = 0
        list.positionViewAtBeginning()
        ClipboardService.selectEntry(clipboard.results[0] || null)
    }

    onVisibleChanged: {
        if (visible) {
            ClipboardService.refresh()
            queryInput.forceActiveFocus()
        } else {
            queryInput.clear()
            clipboard.selectedIndex = 0
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
                Keys.onTabPressed: clipboard.setSelection(clipboard.selectedIndex + 1)
                Keys.onBacktabPressed: clipboard.setSelection(clipboard.selectedIndex - 1)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        clipboard.pinSelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        clipboard.deleteSelected()
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
                    return "^P pin · ⇧Del remove · " + String(clipboard.results.length)
                }
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 10
            }
        }

        ListView {
            id: list

            x: clipboard.cardPadding
            y: queryField.y + queryField.height + 12
            width: clipboard.listWidth
            height: clipboard.bodyHeight
            model: clipboard.results
            currentIndex: clipboard.selectedIndex
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            section.property: "group"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                required property string section

                width: list.width
                height: 20

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

                Text {
                    visible: !entryRow.modelData.isImage
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26
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
            y: list.y
            width: parent.width - list.width - clipboard.cardPadding * 2 - 12
            height: clipboard.bodyHeight
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
