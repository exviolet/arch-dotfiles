import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: root

    readonly property var items: SystemTray.items.values.slice().sort((left, right) => {
        const categoryDelta = categoryRank(left) - categoryRank(right)
        if (categoryDelta !== 0) return categoryDelta
        return label(left).localeCompare(label(right))
    })
    readonly property int itemCount: items.length

    function categoryRank(item: var): int {
        if (!item) return 9
        if (item.category === Category.SystemServices) return 0
        if (item.category === Category.Hardware) return 1
        if (item.category === Category.Communications) return 2
        return 3
    }

    function label(item: var): string {
        if (!item) return "Unknown service"
        const id = String(item.id || "").toLowerCase()
        if (id.indexOf("nm-applet") !== -1) return "Network"
        if (id.indexOf("blueman") !== -1) return "Bluetooth"
        if (id.indexOf("spotify") !== -1) return "Spotify"
        if (id.indexOf("telegram") !== -1) return "Telegram"
        if (id.indexOf("claude") !== -1) return "Claude"
        const title = String(item.title || item.tooltipTitle || item.id || "Service").trim()
        return title === "" ? "Service" : title
    }

    function detail(item: var): string {
        if (!item) return "Unavailable"
        const id = String(item.id || "").toLowerCase()
        if (id.indexOf("nm-applet") !== -1) return "Connections and network settings"
        if (id.indexOf("blueman") !== -1) return "Bluetooth enabled"
        if (id.indexOf("spotify") !== -1) return "Playback and app controls"
        if (id.indexOf("telegram") !== -1) return "Messages and app controls"
        if (id.indexOf("claude") !== -1) return "Desktop app controls"
        const description = String(item.tooltipDescription || "").trim()
        if (description !== "") return description
        const tooltip = String(item.tooltipTitle || "").trim()
        if (tooltip !== "" && tooltip.toLowerCase() !== label(item).toLowerCase()) return tooltip
        if (item.onlyMenu) return "App menu available"
        if (item.hasMenu) return "App actions available"
        return "Background application"
    }

    function categoryLabel(item: var): string {
        if (!item) return "SERVICE"
        if (item.category === Category.Hardware) return "HARDWARE"
        if (item.category === Category.SystemServices) return "SYSTEM"
        if (item.category === Category.Communications) return "COMMS"
        return "APP"
    }

    function statusLabel(item: var): string {
        if (!item) return "OFFLINE"
        if (item.status === Status.NeedsAttention) return "ATTENTION"
        if (item.status === Status.Passive) return "PASSIVE"
        return "ACTIVE"
    }

    function iconSource(item: var): string {
        if (!item) return ""
        const id = String(item.id || "").toLowerCase()
        if (id.indexOf("claude") !== -1) return Quickshell.iconPath("claude-desktop", true)
        return String(item.icon || "")
    }

    function itemAt(index: int): var {
        return index >= 0 && index < items.length ? items[index] : null
    }

    function activate(index: int): bool {
        const item = itemAt(index)
        if (!item || item.onlyMenu) return false
        item.activate()
        return true
    }

    function secondaryActivate(index: int): bool {
        const item = itemAt(index)
        if (!item) return false
        item.secondaryActivate()
        return true
    }

    function snapshot(): var {
        const result = []
        for (let index = 0; index < items.length; ++index) {
            const item = items[index]
            result.push({
                "index": index,
                "id": String(item.id || ""),
                "label": label(item),
                "detail": detail(item),
                "status": statusLabel(item),
                "category": categoryLabel(item),
                "hasMenu": item.hasMenu,
                "onlyMenu": item.onlyMenu,
                "icon": iconSource(item)
            })
        }
        return {
            "count": items.length,
            "items": result
        }
    }
}
