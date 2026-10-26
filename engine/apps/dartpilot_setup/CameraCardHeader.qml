import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Camera N" and its USB port at the top of a camera card; children, such as a status chip, go to the right, or to a
// second line where the card is too narrow for both.
GridLayout {
    id: header

    // 1-based, in the order of the camera list
    property int number
    property string usbPort
    default property alias trailing: extra.data
    readonly property bool narrow: width < name.implicitWidth + extra.implicitWidth + columnSpacing

    Layout.fillWidth: true
    columns: narrow ? 1 : 2
    columnSpacing: Tokens.spaceMd
    rowSpacing: Tokens.spaceSm

    RowLayout {
        id: name

        spacing: Tokens.spaceMd

        Label {
            text: "Camera " + header.number
            font.pixelSize: Tokens.headingSize
            font.weight: Font.Bold
        }
        Chip {
            text: "USB " + header.usbPort
        }
    }
    RowLayout {
        id: extra

        Layout.alignment: header.narrow ? Qt.AlignLeft : Qt.AlignRight
        spacing: Tokens.spaceMd
    }
}
