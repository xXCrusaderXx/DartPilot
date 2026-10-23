pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// How to capture good calibration views: the animated guide and a checklist.
Dialog {
    id: dialog

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 1100)
    modal: true
    title: "How to capture calibration views"
    padding: 24

    background: Rectangle {
        radius: Tokens.radius
        color: Tokens.surface
        border.color: Tokens.border
    }

    header: Label {
        text: dialog.title
        padding: 24
        bottomPadding: 8
        font.pixelSize: Tokens.titleSize
        font.weight: Font.Bold
        color: Tokens.text
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.6)
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        CaptureGuide {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            running: dialog.visible
        }

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.alignment: Qt.AlignTop
            spacing: 10

            Label {
                text: "BEFORE YOU START"
                font.pixelSize: Tokens.captionSize
                font.weight: Font.DemiBold
                color: Tokens.textMuted
            }
            Repeater {
                model: ["The focus is final; the camera stays in its mount and is not touched. Exposure stays automatic.", "Screen brightness about 50 %, auto-rotation and auto-brightness off. A tablet works better than a phone.", "No reflections from lamps or windows on the screen."]

                delegate: ChecklistItem {}
            }
            Label {
                text: "WHILE CAPTURING"
                font.pixelSize: Tokens.captionSize
                font.weight: Font.DemiBold
                color: Tokens.textMuted
                Layout.topMargin: 8
            }
            Repeater {
                model: ["Cover the whole image: centre, corners and edges.", "Tilt by 30 to 45 degrees in all directions, and vary the distance between about 20 and 40 cm.", "Hold still for a moment at each pose; the view is captured automatically.", "15 to 25 views are enough. Remove views marked red after calibrating."]

                delegate: ChecklistItem {}
            }
        }
    }

    footer: DialogButtonBox {
        background: null

        Button {
            text: "Got it"
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }

    component ChecklistItem: RowLayout {
        id: item

        required property string modelData

        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            implicitWidth: 18
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(Tokens.good.r, Tokens.good.g, Tokens.good.b, 0.18)

            Label {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 11
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
}
