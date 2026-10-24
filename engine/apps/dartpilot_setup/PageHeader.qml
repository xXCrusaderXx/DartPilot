import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Title and one-line description at the top of a page.
ColumnLayout {
    id: header

    property string title
    property string description

    spacing: 4

    Label {
        text: header.title
        font.pixelSize: Tokens.titleSize
        font.weight: Font.Bold
        color: Tokens.text
    }
    Label {
        Layout.fillWidth: true
        text: header.description
        font.pixelSize: Tokens.bodySize
        color: Tokens.textMuted
        wrapMode: Text.WordWrap
    }
}
