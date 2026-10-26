import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Small rounded status label; tone colours the dot, the text and a faint fill.
Rectangle {
    id: chip

    property string text
    property color tone: Tokens.textMuted
    property bool dot: false

    implicitWidth: row.implicitWidth + 20
    implicitHeight: Tokens.chipHeight
    radius: height / 2
    color: Tokens.tint(tone, Tokens.tintFill)
    border.color: Tokens.tint(tone, Tokens.tintBorder)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spaceSm

        Rectangle {
            visible: chip.dot
            implicitWidth: 8
            implicitHeight: 8
            radius: width / 2
            color: chip.tone
        }
        Label {
            text: chip.text
            color: chip.tone
            font.pixelSize: Tokens.captionSize
            font.weight: Font.DemiBold
        }
    }
}
