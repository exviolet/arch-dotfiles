pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property bool dark: true

    readonly property color background: root.dark ? "#171817" : "#f4f2ee"
    readonly property color surface: root.dark ? "#222321" : "#e9e6df"
    readonly property color raisedSurface: root.dark ? "#292a28" : "#dfdcd5"
    readonly property color foreground: root.dark ? "#f0efeb" : "#1d1e1c"
    readonly property color mutedForeground: root.dark ? "#9c9d98" : "#666862"
    readonly property color subtleForeground: root.dark ? "#8f918b" : "#6e706a"
    readonly property color border: root.dark ? "#343633" : "#d6d3cc"
    readonly property color track: root.dark ? "#30322f" : "#dedbd4"
    readonly property color accent: "#d14d41"
    readonly property color warningAccent: "#d08a32"
    readonly property color layoutUs: "#356ea3"
    readonly property color layoutRu: root.dark ? "#b53f37" : "#a93832"
    readonly property color layoutKk: root.dark ? "#d0a13c" : "#bd841e"
}
