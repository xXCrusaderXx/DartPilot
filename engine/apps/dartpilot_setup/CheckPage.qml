pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Calibration check: every camera detects the empty board every few seconds and compares the points with where its
// stored refinement puts them, so a camera that was moved or plugged into another port is noticed.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras

    spacing: Tokens.spacing

    PageHeader {
        Layout.fillWidth: true
        title: "Calibration check"
        description: "Each camera finds the empty board again and compares it with its calibration: blue rings where the calibration expects the points, green dots where they are now. Darts in the board pause the check."
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

                delegate: Card {
                    id: pane

                    required property var modelData
                    required property int index
                    readonly property color tone: Tokens.qualityTone(view.quality)

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spaceMd

                        CameraCardHeader {
                            number: pane.index + 1
                            usbPort: pane.modelData.usbPort

                            Chip {
                                text: view.checkState === "checked" ? (view.swappedWith !== "" ? "Wrong port?" : view.rmsMm.toFixed(2) + " mm") : view.checkState === "noboard" ? "No board" : view.checkState === "nocalibration" ? "Not calibrated" : "Checking"
                                tone: pane.tone
                                dot: true

                                HoverHandler {
                                    id: checkHover
                                }
                                ToolTip.visible: checkHover.hovered
                                ToolTip.text: "Distance between the points found now and where the calibration expects them, in board millimetres. Green up to 1 mm, yellow up to 2.5 mm."
                            }
                        }

                        CheckView {
                            id: view

                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            devicePath: page.active ? pane.modelData.path : ""
                            usbPort: pane.modelData.usbPort
                        }

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: view.quality === "" ? Tokens.textMuted : pane.tone
                            text: view.qualityText
                        }
                        Label {
                            visible: view.checkState === "checked"
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: Tokens.captionSize
                            color: Tokens.textMuted
                            text: "In the image " + view.rmsPx.toFixed(2) + " px, common shift " + view.shiftPx.toFixed(1) + " px · check " + view.checks
                        }
                    }
                }
            }
        }
    }
}
