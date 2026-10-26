import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One line of a guide's checklist, with a green tick
RowLayout {
    id: item

    required property string modelData

    Layout.fillWidth: true
    spacing: Tokens.spaceMd

    Rectangle {
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: Tokens.spaceXxs
        implicitWidth: 18
        implicitHeight: 18
        radius: width / 2
        color: Tokens.tint(Tokens.good, 0.18)

        Label {
            anchors.centerIn: parent
            text: "✓"
            font.pixelSize: Tokens.captionSize
            color: Tokens.good
        }
    }
    Label {
        Layout.fillWidth: true
        text: item.modelData
        wrapMode: Text.WordWrap
        color: Tokens.text
    }
}
