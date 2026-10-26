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
    // Illustrations of the capture guide: the backdrop, a device frame and its edge
    readonly property color stage: "#0b0e12"
    readonly property color deviceFrame: "#2b2f36"
    readonly property color deviceBorder: "#454b55"
    readonly property color gridLine: Qt.rgba(1, 1, 1, 0.06)
    // The calibration pattern needs white paper and a plain grey for its caption
    readonly property color paper: "white"
    readonly property color paperCaption: "#595959"
    // Dims the page behind a dialog
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.6)

    // Spacing scale; every gap, margin and padding is one of these
    readonly property int spaceXxs: 2
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24
    readonly property int spacing: spaceLg

    readonly property int radiusSmall: 8
    readonly property int radius: 12

    readonly property int titleSize: 22
    readonly property int brandSize: 18
    readonly property int headingSize: 16
    readonly property int bodySize: 14
    readonly property int captionSize: 12
    readonly property int iconSize: 20
    // Text read standing at the board, about 1.5 m away
    readonly property int glanceSize: 26
    readonly property string codeFont: "monospace"

    readonly property int sidebarWidth: 260
    // The column of step cards beside a camera view
    readonly property int sidePanelWidth: 420
    readonly property int chipHeight: 26

    // Opacity of a tone's fill behind content and of its border, for chips, banners and tinted boxes
    readonly property real tintFill: 0.14
    readonly property real tintFillSoft: 0.10
    readonly property real tintBorder: 0.35

    function tint(tone, alpha) {
        return Qt.rgba(tone.r, tone.g, tone.b, alpha);
    }

    // good, fair or poor as a status colour; anything else, such as no result yet, is muted
    function qualityTone(quality) {
        return quality === "good" ? good : quality === "fair" ? warning : quality === "poor" ? bad : textMuted;
    }
}
