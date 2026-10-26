import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Camera N" and its USB port at the top of a camera card; children, such as a status chip, go to the right.
RowLayout {
    id: header

    // 1-based, in the order of the camera list
    property int number
    property string usbPort
    default property alias trailing: extra.data

    Layout.fillWidth: true
    spacing: Tokens.spaceMd

    Label {
        text: "Camera " + header.number
        font.pixelSize: Tokens.headingSize
        font.weight: Font.Bold
    }
    Chip {
        text: "USB " + header.usbPort
    }
    Item {
        Layout.fillWidth: true
    }
    RowLayout {
        id: extra

        spacing: Tokens.spaceMd
    }
}
