pragma Singleton

import QtQuick

// Colours, spacing and type sizes shared by all pages.
QtObject {
    readonly property color background: "#0f1216"
    readonly property color sidebar: "#13171d"
    readonly property color surface: "#1a1f27"
    readonly property color surfaceRaised: "#222833"
    readonly property color border: "#2a313d"
    readonly property color text: "#e6e9ef"
    readonly property color textMuted: "#98a2b3"
    readonly property color accent: "#38bdf8"
    readonly property color good: "#34d399"
    readonly property color warning: "#fbbf24"
    readonly property color bad: "#f87171"
    // Board colours for illustrations of the physical dartboard
    readonly property color boardRed: "#c0392b"
    readonly property color boardGreen: "#1e8449"
    readonly property color boardDark: "#1c1c1c"
    readonly property color boardLight: "#efe6d2"

    readonly property int radius: 12
    readonly property int spacing: 16
    readonly property int titleSize: 22
    readonly property int headingSize: 16
    readonly property int bodySize: 14
    readonly property int captionSize: 12
}
