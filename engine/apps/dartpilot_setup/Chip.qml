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
    implicitHeight: 26
    radius: height / 2
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.14)
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.35)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: chip.dot
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
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
