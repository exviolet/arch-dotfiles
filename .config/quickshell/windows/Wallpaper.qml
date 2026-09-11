pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

import "../services"

// The wallpaper picker: a grid of what is in the wallpapers directory.
//
// A window rather than a launcher prefix because the whole point is the
// preview — a wallpaper picked from a list of file names is a guess.
PanelWindow {
    id: picker

    required property var outputScreen
    required property var wallpaperController

    readonly property int columns: 4
    readonly property int cellWidth: 196
    readonly property int cellHeight: 130
    readonly property int cardPadding: 20
    readonly property int headerHeight: 46

    readonly property int rows: Math.max(1, Math.ceil(WallpaperService.files.length / picker.columns))
    readonly property int visibleRows: Math.min(picker.rows, 3)
    readonly property int cardWidth: picker.columns * picker.cellWidth + picker.cardPadding * 2
    readonly property int cardHeight: picker.cardPadding * 2 + picker.headerHeight
        + picker.visibleRows * picker.cellHeight

    property int selectedIndex: 0

    function setSelection(index: int): void {
        const count = WallpaperService.files.length
        if (count === 0) return

        picker.selectedIndex = Math.max(0, Math.min(count - 1, index))
        grid.positionViewAtIndex(picker.selectedIndex, GridView.Contain)
    }

    function applySelected(): void {
        const path = WallpaperService.files[picker.selectedIndex]
        if (!path) return

        WallpaperService.apply(String(path))
        picker.wallpaperController.hideWallpaper()
    }

    screen: outputScreen
    visible: wallpaperController.wallpaperVisible
        && (wallpaperController.wallpaperScreen === "" || wallpaperController.wallpaperScreen === outputScreen.name)
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

    onVisibleChanged: {
        if (!picker.visible) return

        WallpaperService.refresh()
        picker.selectedIndex = 0
        grid.positionViewAtBeginning()
        grid.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: picker.wallpaperController.hideWallpaper()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: picker.cardWidth
        height: picker.cardHeight
        radius: 14
        color: Theme.background
        border.width: 1
        border.color: Theme.border

        MouseArea {
            anchors.fill: parent
        }

        Text {
            x: picker.cardPadding + 4
            y: picker.cardPadding
            text: "WALLPAPER"
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        Text {
            x: parent.width - width - picker.cardPadding - 4
            y: picker.cardPadding
            text: WallpaperService.files.length === 0
                ? "…"
                : String(picker.selectedIndex + 1) + " / " + String(WallpaperService.files.length)
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        GridView {
            id: grid

            x: picker.cardPadding
            y: picker.cardPadding + picker.headerHeight
            width: parent.width - picker.cardPadding * 2
            height: picker.visibleRows * picker.cellHeight
            cellWidth: picker.cellWidth
            cellHeight: picker.cellHeight
            model: WallpaperService.files
            currentIndex: picker.selectedIndex
            clip: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds

            Keys.onEscapePressed: picker.wallpaperController.hideWallpaper()
            Keys.onReturnPressed: picker.applySelected()
            Keys.onEnterPressed: picker.applySelected()
            Keys.onLeftPressed: picker.setSelection(picker.selectedIndex - 1)
            Keys.onRightPressed: picker.setSelection(picker.selectedIndex + 1)
            Keys.onUpPressed: picker.setSelection(picker.selectedIndex - picker.columns)
            Keys.onDownPressed: picker.setSelection(picker.selectedIndex + picker.columns)

            delegate: Item {
                id: cell

                required property int index
                required property var modelData

                readonly property bool active: picker.selectedIndex === cell.index
                readonly property bool inUse: WallpaperService.isCurrent(String(cell.modelData))

                width: picker.cellWidth
                height: picker.cellHeight

                Rectangle {
                    id: frame

                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 10
                    color: Theme.surface
                    border.width: cell.active ? 2 : 1
                    border.color: cell.active ? Theme.accent : Theme.border

                    Behavior on border.color {
                        ColorAnimation { duration: 110 }
                    }

                    // Rectangle.clip crops to the bounding box, not to the
                    // rounded shape, so a square thumbnail pokes out past every
                    // corner. The picture is masked instead.
                    Image {
                        id: thumbnail

                        anchors.fill: parent
                        anchors.margins: 2
                        source: "file://" + String(cell.modelData)
                        fillMode: Image.PreserveAspectCrop
                        // Some of these are several megabytes; never decode
                        // them at full size for a thumbnail.
                        sourceSize.width: picker.cellWidth * 2
                        asynchronous: true
                        cache: true
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        id: thumbnailMask

                        anchors.fill: thumbnail
                        visible: false
                        layer.enabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: frame.radius - 2
                        }
                    }

                    MultiEffect {
                        anchors.fill: thumbnail
                        source: thumbnail
                        maskEnabled: true
                        maskSource: thumbnailMask
                    }

                    // The one already on screen, so you can tell what you are
                    // about to replace.
                    Rectangle {
                        visible: cell.inUse
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accent
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        picker.setSelection(cell.index)
                        picker.applySelected()
                    }
                }
            }
        }
    }
}
