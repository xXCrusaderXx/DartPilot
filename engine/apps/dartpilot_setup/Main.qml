import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

ApplicationWindow {
    id: window

    width: 1600
    height: 1000
    visible: true
    title: "DartPilot Setup"

    CameraFinder {
        id: finder
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Label {
                text: finder.cameras.length === 1 ? "1 camera found" : finder.cameras.length + " cameras found"
            }
            Button {
                text: "Search again"
                onClicked: finder.refresh()
            }
            Item {
                Layout.fillWidth: true
            }
            Label {
                text: "Cameras are named by USB port; keep each camera on its port."
                opacity: 0.7
            }
        }
    }

    ScrollView {
        id: scroll

        anchors.fill: parent
        anchors.margins: 8
        contentWidth: availableWidth

        GridLayout {
            width: scroll.availableWidth
            columns: finder.cameras.length > 1 ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: finder.cameras

                delegate: CameraPane {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                }
            }
        }
    }
}
