pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import "../../services"

Item {
    id: surface

    required property bool pinned
    required property bool expanded

    property var menuOwner: null
    property var menuHandle: null
    property var menuStack: []
    readonly property bool menuVisible: menuOwner !== null && menuHandle !== null
    readonly property url backIconSource: Qt.resolvedUrl("../../icons/iconoir/nav-arrow-left.svg")
    readonly property url forwardIconSource: Qt.resolvedUrl("../../icons/iconoir/nav-arrow-right.svg")

    function openMenu(item: var): void {
        if (!item || !item.hasMenu) return
        menuOwner = item
        menuStack = []
        menuHandle = item.menu
    }

    function closeMenu(): void {
        menuHandle = null
        menuOwner = null
        menuStack = []
    }

    function enterSubmenu(entry: var): void {
        if (!entry || !entry.hasChildren) return
        menuStack = menuStack.concat([menuHandle])
        menuHandle = entry
    }

    function leaveSubmenu(): void {
        if (menuStack.length === 0) {
            closeMenu()
            return
        }
        const previous = menuStack[menuStack.length - 1]
        menuStack = menuStack.slice(0, -1)
        menuHandle = previous
    }

    function triggerEntry(entry: var): void {
        if (!entry || !entry.enabled || entry.isSeparator) return
        if (entry.hasChildren) {
            enterSubmenu(entry)
            return
        }
        entry.triggered()
        closeMenu()
    }

    QsMenuOpener {
        id: rootMenuOpener
        menu: surface.menuVisible && surface.menuOwner ? surface.menuOwner.menu : null
    }

    QsMenuOpener {
        id: menuOpener
        menu: surface.menuVisible ? surface.menuHandle : null
    }

    SurfaceHeader {
        width: parent.width
        eyebrow: "TRAY /"
        iconSource: Qt.resolvedUrl("../../icons/iconoir/app-notification.svg")
        eyebrowLabel: "SERVICES"
        mode: surface.menuVisible ? "MENU" : String(TrayService.itemCount) + " LIVE"
        pinned: surface.pinned
        expanded: surface.expanded
        title: surface.menuVisible ? TrayService.label(surface.menuOwner) : "Background services"
        subtitle: surface.menuVisible ? "Application actions" : "Native app actions and menus"
    }

    Item {
        visible: !surface.menuVisible
        x: 22
        y: 158
        width: parent.width - 44
        height: Math.max(0, TrayService.itemCount * 74)

        Column {
            width: parent.width
            spacing: 8

            Repeater {
                model: TrayService.items

                Rectangle {
                    id: trayItem
                    required property var modelData
                    required property int index
                    readonly property bool attention: TrayService.statusLabel(modelData) === "ATTENTION"

                    function openMenu(): void {
                        surface.openMenu(modelData)
                    }

                    width: parent.width
                    height: 66
                    radius: 12
                    color: trayItemMouse.containsMouse ? Theme.surface : Theme.raisedSurface
                    border.width: 1
                    border.color: attention ? Theme.warningAccent : Theme.border

                    Image {
                        id: trayAppIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        source: TrayService.iconSource(trayItem.modelData)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        visible: trayAppIcon.status !== Image.Ready
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        horizontalAlignment: Text.AlignHCenter
                        text: TrayService.label(trayItem.modelData).slice(0, 1).toUpperCase()
                        color: Theme.accent
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        x: 56
                        y: 12
                        width: parent.width - 146
                        text: TrayService.label(trayItem.modelData)
                        elide: Text.ElideRight
                        color: Theme.foreground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }

                    Text {
                        x: 56
                        y: 35
                        width: parent.width - 146
                        text: TrayService.detail(trayItem.modelData)
                        elide: Text.ElideRight
                        color: Theme.subtleForeground
                        font.family: "DejaVu Sans"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 13
                        y: 10
                        text: trayItem.attention ? "ATTENTION" : TrayService.categoryLabel(trayItem.modelData)
                        color: trayItem.attention ? Theme.warningAccent : Theme.subtleForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 7
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    MouseArea {
                        id: trayItemMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                trayItem.openMenu()
                            } else {
                                TrayService.activate(trayItem.index)
                            }
                        }
                    }

                    Rectangle {
                        visible: trayItem.modelData.hasMenu
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        y: 31
                        width: 56
                        height: 25
                        radius: 8
                        color: trayMenuMouse.containsMouse ? Theme.background : "transparent"
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "MENU"
                            color: Theme.foreground
                            font.family: "DejaVu Sans Mono"
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.5
                        }

                        MouseArea {
                            id: trayMenuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: trayItem.openMenu()
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: surface.menuVisible
        x: 22
        y: 150
        width: parent.width - 44
        height: Math.max(180, parent.height - 224)

        Rectangle {
            id: menuBack
            width: parent.width
            height: 34
            radius: 10
            color: menuBackMouse.containsMouse ? Theme.raisedSurface : "transparent"
            border.width: 1
            border.color: Theme.border

            Image {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: surface.backIconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                x: 32
                anchors.verticalCenter: parent.verticalCenter
                text: surface.menuStack.length > 0 ? "BACK" : "SERVICES"
                color: Theme.foreground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.7
            }

            MouseArea {
                id: menuBackMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: surface.leaveSubmenu()
            }
        }

        ListView {
            id: menuList
            y: 44
            width: parent.width
            height: parent.height - 44
            clip: true
            spacing: 3
            model: menuOpener.children
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: trayAction
                required property var modelData
                required property int index
                readonly property bool checkable: Number(modelData.buttonType) !== 0
                readonly property bool checked: Number(modelData.checkState) === Number(Qt.Checked)

                width: menuList.width - (menuList.contentHeight > menuList.height ? 8 : 0)
                height: modelData.isSeparator ? 13 : 39
                opacity: modelData.enabled || modelData.isSeparator ? 1 : 0.42

                Rectangle {
                    visible: trayAction.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width
                    height: 1
                    color: Theme.border
                }

                Rectangle {
                    visible: !trayAction.modelData.isSeparator
                    anchors.fill: parent
                    radius: 9
                    color: trayActionMouse.containsMouse ? Theme.raisedSurface : "transparent"
                    border.width: trayAction.modelData.hasChildren ? 1 : 0
                    border.color: Theme.border
                }

                Rectangle {
                    visible: !trayAction.modelData.isSeparator && trayAction.checkable
                    x: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13
                    height: 13
                    radius: Number(trayAction.modelData.buttonType) === 2 ? 7 : 4
                    color: trayAction.checked ? Theme.accent : "transparent"
                    border.width: 1
                    border.color: trayAction.checked ? Theme.accent : Theme.subtleForeground

                    Rectangle {
                        visible: trayAction.checked
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 3
                        color: Theme.background
                    }
                }

                Text {
                    visible: !trayAction.modelData.isSeparator
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (trayAction.modelData.hasChildren ? 64 : 44)
                    text: String(trayAction.modelData.text || "")
                    elide: Text.ElideRight
                    color: Theme.foreground
                    font.family: "DejaVu Sans"
                    font.pixelSize: 11
                    font.weight: trayAction.modelData.hasChildren ? Font.DemiBold : Font.Normal
                }

                Image {
                    visible: !trayAction.modelData.isSeparator && trayAction.modelData.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    source: surface.forwardIconSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Timer {
                    id: submenuHoverTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        if (trayActionMouse.containsMouse && trayAction.modelData.hasChildren)
                            surface.enterSubmenu(trayAction.modelData)
                    }
                }

                MouseArea {
                    id: trayActionMouse
                    visible: !trayAction.modelData.isSeparator
                    anchors.fill: parent
                    enabled: trayAction.modelData.enabled
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: {
                        if (trayAction.modelData.hasChildren)
                            submenuHoverTimer.start()
                    }
                    onExited: submenuHoverTimer.stop()
                    onClicked: {
                        submenuHoverTimer.stop()
                        surface.triggerEntry(trayAction.modelData)
                    }
                }
            }
        }
    }
}
