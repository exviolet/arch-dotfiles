pragma ComponentBehavior: Bound

import QtQuick

import "../../services"

// Claude plan burn and token volume.
//
// Two kinds of number, from two different places: the percentages come from
// the status line file and are exact but only as fresh as the last render; the
// token totals are aggregated out of the transcripts every time this opens.
Item {
    id: surface

    required property bool pinned
    required property bool expanded
    required property bool active

    // Re-reading takes about half a second, so do it on entry rather than on a
    // timer — nobody watches this panel idle.
    onActiveChanged: if (surface.active) ClaudeUsageService.refreshTokens()

    // The panel does not scroll, so the list is capped rather than allowed to
    // push the token sections off the bottom of the screen. herdr's own
    // sidebar is the complete view; this one is the glance.
    readonly property int agentLimit: 6
    readonly property var visibleAgents: AgentService.agents.slice(0, surface.agentLimit)
    readonly property int hiddenAgents: Math.max(0, AgentService.agents.length - surface.agentLimit)

    function agentTone(status: string): color {
        if (status === "blocked") return Theme.accent
        if (status === "working") return Theme.warningAccent
        if (status === "done") return Theme.layoutUs
        return Theme.subtleForeground
    }

    function toneFor(percent: real): color {
        if (ClaudeUsageService.stale) return Theme.mutedForeground
        if (percent >= 80) return Theme.accent
        if (percent >= 50) return Theme.warningAccent
        return Theme.foreground
    }

    SurfaceHeader {
        width: parent.width
        eyebrow: "USAGE /"
        iconSource: Qt.resolvedUrl("../../icons/iconoir/asterisk.svg")
        eyebrowLabel: "CLAUDE"
        mode: ClaudeUsageService.stale ? "STALE" : ClaudeUsageService.percentLabel(ClaudeUsageService.fivePercent) + "%"
        pinned: surface.pinned
        expanded: surface.expanded
        title: ClaudeUsageService.percentLabel(ClaudeUsageService.fivePercent) + "% of session"
        subtitle: {
            const left = ClaudeUsageService.countdown(ClaudeUsageService.fiveResetsAt)
            return left === "" ? "5-HOUR WINDOW" : "5-HOUR WINDOW / RESETS IN " + left.toUpperCase()
        }
    }

    Repeater {
        model: [
            {
                "label": "5-HOUR SESSION",
                "percent": ClaudeUsageService.fivePercent,
                "resets": ClaudeUsageService.fiveResetsAt,
                "offset": 0
            },
            {
                "label": "7-DAY WINDOW",
                "percent": ClaudeUsageService.sevenPercent,
                "resets": ClaudeUsageService.sevenResetsAt,
                "offset": 1
            }
        ]

        delegate: Rectangle {
            id: card

            required property var modelData

            readonly property real percent: Math.max(0, Number(card.modelData.percent))
            readonly property string resetLabel: ClaudeUsageService.countdown(Number(card.modelData.resets))

            x: 22
            y: 158 + card.modelData.offset * 98
            width: surface.width - 44
            height: 86
            radius: 14
            color: Theme.raisedSurface
            border.width: 1
            border.color: Theme.border

            Text {
                x: 14
                y: 13
                text: String(card.modelData.label)
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 13
                text: card.resetLabel === "" ? "" : "RESETS IN " + card.resetLabel.toUpperCase()
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Text {
                x: 14
                y: 31
                text: ClaudeUsageService.percentLabel(Number(card.modelData.percent)) + "%"
                color: surface.toneFor(card.percent)
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }

            Rectangle {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                width: parent.width - 28
                height: 6
                radius: 3
                color: Theme.track

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(3, parent.width * Math.min(1, card.percent / 100))
                    radius: 3
                    color: surface.toneFor(card.percent)

                    Behavior on width {
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // Both token sections share one shape: a label, a bar scaled against the
    // largest value in its own section, and the count.
    component TokenRow: Item {
        id: row

        required property string label
        required property double value
        required property double peak
        required property bool highlight

        width: surface.width - 44
        height: 22

        Text {
            id: rowLabel

            anchors.verticalCenter: parent.verticalCenter
            width: 74
            text: row.label
            color: row.highlight ? Theme.foreground : Theme.mutedForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: row.highlight ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        Rectangle {
            id: rowTrack

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: rowLabel.right
            anchors.leftMargin: 8
            anchors.right: rowValue.left
            anchors.rightMargin: 10
            height: 5
            radius: 2.5
            color: Theme.track

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: row.peak > 0
                    ? Math.max(3, parent.width * Math.min(1, row.value / row.peak))
                    : 3
                radius: 2.5
                color: row.highlight ? Theme.accent : Theme.subtleForeground

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
            }
        }

        Text {
            id: rowValue

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: 52
            horizontalAlignment: Text.AlignRight
            text: ClaudeUsageService.compact(row.value)
            color: row.highlight ? Theme.foreground : Theme.mutedForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }
    }

    Column {
        x: 22
        y: 368
        width: surface.width - 44
        spacing: 12
        visible: ClaudeUsageService.tokensReady

        Column {
            width: parent.width
            visible: AgentService.ready && AgentService.agents.length > 0

            spacing: 6

            Text {
                text: "AGENTS / " + AgentService.agents.length
                    + (AgentService.blockedCount > 0 ? " · " + AgentService.blockedCount + " ЖДУТ" : "")
                color: AgentService.blockedCount > 0 ? Theme.accent : Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: surface.visibleAgents

                delegate: Rectangle {
                    id: agentRow

                    required property var modelData

                    width: surface.width - 44
                    height: 38
                    radius: 8
                    color: "transparent"

                    Rectangle {
                        id: statusDot

                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: surface.agentTone(String(agentRow.modelData.status))
                    }

                    Text {
                        id: agentLabel

                        anchors.left: statusDot.right
                        anchors.leftMargin: 10
                        anchors.right: agentStatus.left
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        text: String(agentRow.modelData.label)
                        color: agentRow.modelData.focused ? Theme.foreground : Theme.mutedForeground
                        font.pixelSize: 11
                        font.weight: agentRow.modelData.focused ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.left: agentLabel.left
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        text: String(agentRow.modelData.project)
                        color: Theme.subtleForeground
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Text {
                        id: agentStatus

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: AgentService.statusLabel(String(agentRow.modelData.status))
                        color: surface.agentTone(String(agentRow.modelData.status))
                        font.family: "DejaVu Sans Mono"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                    }

                }
            }

            Text {
                visible: surface.hiddenAgents > 0
                text: "+ ещё " + surface.hiddenAgents
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                text: "TOKENS BY DAY"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: ClaudeUsageService.tokenDays

                delegate: TokenRow {
                    required property var modelData
                    required property int index

                    label: ClaudeUsageService.dayLabel(String(modelData.date))
                    value: Number(modelData.tokens)
                    peak: ClaudeUsageService.tokenDayPeak
                    // Today is the row you are actually adding to.
                    highlight: index === ClaudeUsageService.tokenDays.length - 1
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Text {
                text: "TOKENS BY MODEL"
                color: Theme.subtleForeground
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }

            Repeater {
                model: ClaudeUsageService.tokenModels

                delegate: TokenRow {
                    required property var modelData
                    required property int index

                    label: ClaudeUsageService.modelLabel(String(modelData.model))
                    value: Number(modelData.tokens)
                    peak: ClaudeUsageService.tokenModelPeak
                    highlight: index === 0
                }
            }
        }

        Text {
            width: parent.width
            text: "ВСЕГО " + ClaudeUsageService.compact(ClaudeUsageService.tokenTotal)
                + (ClaudeUsageService.tokensLoading ? " · обновляю…" : "")
            color: Theme.subtleForeground
            font.family: "DejaVu Sans Mono"
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }
    }

    Text {
        x: 22
        y: 368
        width: surface.width - 44
        visible: !ClaudeUsageService.tokensReady
        text: ClaudeUsageService.tokensLoading ? "Считаю токены…" : "Токены недоступны"
        color: Theme.mutedForeground
        font.family: "DejaVu Sans Mono"
        font.pixelSize: 10
    }
}
