pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// How to capture good calibration views: the animated guide and a checklist.
GuideDialogBase {
    id: dialog

    title: "How to capture calibration views"

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spaceXl

        CaptureGuide {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            running: dialog.visible
        }

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spaceMd

            SectionLabel {
                text: "Before you start"
            }
            Repeater {
                model: ["The focus is final; the camera stays in its mount and is not touched. Exposure stays automatic.", "Screen brightness about 50 %, auto-rotation and auto-brightness off. A tablet works better than a phone.", "No reflections from lamps or windows on the screen."]

                delegate: ChecklistItem {}
            }
            SectionLabel {
                text: "While capturing"
                Layout.topMargin: Tokens.spaceSm
            }
            Repeater {
                model: ["Cover the whole image: centre, corners and edges.", "Tilt by 30 to 45 degrees in all directions, and vary the distance between about 20 and 40 cm.", "Hold still for a moment at each pose; the view is captured automatically.", "15 to 25 views are enough. Remove views marked red after calibrating."]

                delegate: ChecklistItem {}
            }
        }
    }
}
