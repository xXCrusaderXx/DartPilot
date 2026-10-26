pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Cross-camera check with a pin (#13, #48): click where one pin enters the board in every camera; the calibration of
// each camera maps its click onto the board, and the cameras should agree.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras

    spacing: Tokens.spacing

    PinCheck {
        id: check

        cameras: page.cameras
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing

        PageHeader {
            Layout.fillWidth: true
            title: "Pin check"
            description: "Put a pin or a dart into the board, then click in every camera exactly where it enters the board. A magnifier follows the pointer. The cameras should put it on the same board point."
        }
        ComboBox {
            Layout.preferredWidth: 300
            model: ["Pin anywhere on the board", "Pin exactly in the bull centre"]
            currentIndex: check.reference === "bull" ? 1 : 0
            onActivated: index => check.reference = index === 1 ? "bull" : "none"
            ToolTip.visible: hovered
            ToolTip.text: "With the pin in the centre of the bull, each camera's distance from the true point is shown as well."
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing

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

                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Tokens.spaceMd

                            CameraCardHeader {
                                number: pane.index + 1
                                usbPort: pane.modelData.usbPort

                                Chip {
                                    text: view.picked ? "Clicked" : "Click the pin"
                                    tone: view.picked ? Tokens.good : Tokens.textMuted
                                    dot: true
                                }
                            }

                            PinView {
                                id: view

                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 9 / 16
                                devicePath: page.active ? pane.modelData.path : ""
                                usbPort: pane.modelData.usbPort
                                onPointPicked: (usbPort, x, y) => check.setPoint(usbPort, x, y)

                                Connections {
                                    target: check

                                    function onResultChanged() {
                                        if (check.count === 0 && view.picked)
                                            view.clearPick();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Card {
            Layout.preferredWidth: 380
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spaceMd

                Label {
                    text: "Result"
                    font.pixelSize: Tokens.headingSize
                    font.weight: Font.DemiBold
                }
                Chip {
                    visible: check.count >= 2
                    text: "Spread " + check.spreadMm.toFixed(2) + " mm"
                    tone: Tokens.qualityTone(check.quality)
                    dot: true

                    HoverHandler {
                        id: spreadHover
                    }
                    ToolTip.visible: spreadHover.hovered
                    ToolTip.text: "Largest distance between the board points of two cameras. Green up to 1 mm, yellow up to 2 mm."
                }
                Repeater {
                    model: check.points

                    delegate: Label {
                        required property var modelData

                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Camera " + modelData.number + ":  x " + modelData.xMm.toFixed(1) + " mm, y " + modelData.yMm.toFixed(1) + " mm  ·  " + modelData.label + (modelData.errorMm !== undefined ? "  ·  " + modelData.errorMm.toFixed(2) + " mm from the centre" : "")
                    }
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Tokens.qualityTone(check.quality)
                    text: check.summary
                }
                RowLayout {
                    spacing: Tokens.spaceSm

                    Button {
                        text: "Save"
                        highlighted: true
                        enabled: check.count >= 2
                        onClicked: saveFailedLabel.visible = !check.save()
                        ToolTip.visible: hovered
                        ToolTip.text: "Keeps this measurement for the error budget (#48); then move the pin and measure again"
                    }
                    Button {
                        text: "Clear"
                        flat: true
                        enabled: check.count > 0
                        onClicked: check.clear()
                    }
                }
                Label {
                    id: saveFailedLabel

                    visible: false
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Tokens.bad
                    text: "Saving failed. Check that the calibration directory is writable."
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Tokens.captionSize
                    color: Tokens.textMuted
                    text: check.savedCount === 0 ? "No measurement saved with the current calibration yet. Ten pins spread over the board, also near the edge, make a good set." : check.savedCount + " measurements saved with the current calibration, median spread " + check.savedMedianSpreadMm.toFixed(2) + " mm."
                }
                Item {
                    Layout.fillHeight: true
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Tokens.captionSize
                    color: Tokens.textMuted
                    text: "Click the tip where it enters the board, not the shaft or the flight: the calibration maps the click onto the playing surface. A thin pin is easier to click precisely than a dart."
                }
            }
        }
    }
}
