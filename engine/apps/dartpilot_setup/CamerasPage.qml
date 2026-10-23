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
        description: "Keep the exposure automatic: the cameras amplify only in automatic mode, so manual exposure is too dark at 30 fps. Keep 30 fps, set the focus before calibrating, and keep each camera on its USB port."
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
