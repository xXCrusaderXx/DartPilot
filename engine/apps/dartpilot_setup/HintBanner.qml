import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The instruction for the current step under a camera view; the tone marks a failure. Children go after the text.
Rectangle {
    id: banner

    property string text
    property color tone: Tokens.accent
    default property alias trailing: extra.data

    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 2 * Tokens.spaceMd
    radius: Tokens.radius
    color: Tokens.tint(tone, Tokens.tintFillSoft)
    border.color: Tokens.tint(tone, Tokens.tintBorder)

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Tokens.spaceMd
        anchors.leftMargin: Tokens.spaceLg
        spacing: Tokens.spaceMd

        Label {
            Layout.fillWidth: true
            text: "→  " + banner.text
            font.pixelSize: Tokens.headingSize
            color: Tokens.text
            wrapMode: Text.WordWrap
            verticalAlignment: Text.AlignVCenter
        }
        RowLayout {
            id: extra

            spacing: Tokens.spaceSm
        }
    }
}
