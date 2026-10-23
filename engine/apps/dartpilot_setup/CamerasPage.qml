pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// All cameras side by side with their controls and the focus grid.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras

    spacing: Tokens.spacing

    PageHeader {
        Layout.fillWidth: true
        title: "Cameras"
        description: "Fix exposure and white balance, keep 30 fps, and set the focus before calibrating. Cameras are named by USB port, so keep each one on its port."
    }

    ScrollView {
        id: scroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        GridLayout {
            width: scroll.availableWidth
            columns: page.cameras.length > 1 ? 2 : 1
            columnSpacing: Tokens.spacing
            rowSpacing: Tokens.spacing

            Repeater {
                model: page.cameras

                delegate: CameraPane {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    active: page.active
                }
            }
        }
    }
}
