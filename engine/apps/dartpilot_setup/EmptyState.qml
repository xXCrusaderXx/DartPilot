import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shown instead of a page that has nothing to show yet: what is missing and the one action that helps.
ColumnLayout {
    id: empty

    property string title
    property string detail
    property string action
    signal triggered

    spacing: Tokens.spaceMd

    Label {
        Layout.alignment: Qt.AlignHCenter
        text: empty.title
        font.pixelSize: Tokens.titleSize
        font.weight: Font.Bold
        color: Tokens.text
    }
    Label {
        Layout.alignment: Qt.AlignHCenter
        Layout.maximumWidth: 560
        text: empty.detail
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        color: Tokens.textMuted
    }
    Button {
        Layout.alignment: Qt.AlignHCenter
        visible: empty.action !== ""
        text: empty.action
        highlighted: true
        onClicked: empty.triggered()
    }
}
