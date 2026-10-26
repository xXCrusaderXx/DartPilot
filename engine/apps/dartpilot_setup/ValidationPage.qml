pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Guided validation (#48): empty board, a dart in the bull centre, then darts anywhere. Every step is measured by
// itself once the image is still; the results go to validation.jsonl.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras

    function toneOf(quality) {
        return quality === "good" ? Tokens.good : quality === "fair" ? Tokens.warning : quality === "poor" ? Tokens.bad : Tokens.textMuted;
    }

    spacing: Tokens.spacing

    ValidationRun {
        id: run

        cameras: page.cameras
        active: page.active
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing

        PageHeader {
            Layout.fillWidth: true
            title: "Validation"
            description: "A guided check of the whole chain with real darts: each camera against its calibration, then where all cameras together put a dart. Nothing to click: every step is measured when the image is still."
        }
        Button {
            text: "Start over"
            flat: true
            onClicked: run.restart()
            ToolTip.visible: hovered
            ToolTip.text: "Take a new empty-board reference and measure again from the beginning"
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: instructionLabel.implicitHeight + 24
        radius: Tokens.radius
        color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.10)
        border.color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.35)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            anchors.leftMargin: 16
            spacing: 12

            Label {
                id: instructionLabel

                Layout.fillWidth: true
                text: "→  " + run.instruction
                font.pixelSize: Tokens.headingSize
                wrapMode: Text.WordWrap
            }
            Chip {
                text: run.status === "measuring" ? "Measuring" : run.status === "moving" ? "Movement" : run.status === "waiting" ? "Waiting" : "Still"
                tone: run.status === "measuring" ? Tokens.accent : run.status === "moving" ? Tokens.warning : run.status === "waiting" ? Tokens.textMuted : Tokens.good
                dot: true
            }
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
                            spacing: 8

                            RowLayout {
                                spacing: 10

                                Label {
                                    text: "Camera " + (pane.index + 1)
                                    font.pixelSize: Tokens.headingSize
                                    font.weight: Font.Bold
                                }
                                Chip {
                                    text: "USB " + pane.modelData.usbPort
                                }
                            }
                            MarkerView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 9 / 16
                                devicePath: page.active ? pane.modelData.path : ""
                                markers: run.markers[pane.modelData.usbPort] || []
                            }
                        }
                    }
                }
            }
        }

        ScrollView {
            id: side

            Layout.preferredWidth: 420
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: side.availableWidth
                spacing: 12

                StepCard {
                    Layout.fillWidth: true
                    step: 1
                    title: "Empty board"
                    done: run.step !== "empty"

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "The reference for finding darts, and a check of every camera against its calibration."
                    }
                    Repeater {
                        model: run.calibrationChecks

                        delegate: Chip {
                            required property var modelData

                            text: "Camera " + modelData.number + "  ·  " + (modelData.found ? modelData.rmsMm.toFixed(2) + " mm" : "board not found")
                            tone: page.toneOf(modelData.quality)
                            dot: true
                        }
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 2
                    title: "Dart in the bull centre"
                    done: run.bull.located === true

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "The only point whose true position is known: how far from (0, 0) the cameras put it is the absolute error."
                    }
                    Label {
                        visible: run.bull.located !== undefined
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: run.bull.located ? (run.bull.errorMm <= 1.0 ? Tokens.good : run.bull.errorMm <= 2.0 ? Tokens.warning : Tokens.bad) : Tokens.bad
                        text: run.bull.located ? run.bull.errorMm.toFixed(2) + " mm from the centre, cameras " + run.bull.cameras + ", planes within " + run.bull.worstPlaneMm.toFixed(2) + " mm" : "Not located: the cameras do not agree on the dart."
                    }
                    Label {
                        visible: run.step === "darts" && run.bull.located === undefined
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.warning
                        text: "Skipped: the darts below show how well the cameras agree, not how far off they are."
                    }
                    Button {
                        visible: run.step === "bull"
                        text: "Skip"
                        flat: true
                        onClicked: run.skipBull()
                        ToolTip.visible: hovered
                        ToolTip.text: "Go on to darts anywhere without the bull reference"
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 3
                    title: "Darts anywhere"
                    done: run.locatedCount >= 8

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "One dart at a time, spread over the board and also near the double ring. Eight or more make a good set; each is saved."
                    }
                    Label {
                        visible: run.summary !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: run.summary
                    }
                    Repeater {
                        model: run.darts

                        delegate: Label {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.pixelSize: Tokens.captionSize
                            color: modelData.located ? Tokens.text : Tokens.warning
                            text: (run.darts.length - index) + ".  " + (modelData.located ? modelData.label + "  ·  x " + modelData.xMm.toFixed(1) + ", y " + modelData.yMm.toFixed(1) + " mm  ·  ±" + modelData.sdMm.toFixed(2) + " mm  ·  cameras " + modelData.cameras + ", planes within " + modelData.worstPlaneMm.toFixed(2) + " mm" : "abstained: the cameras do not agree")
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Tokens.captionSize
                    color: Tokens.textMuted
                    text: "Red cross: where the engine puts the dart, in every camera. Green rings: the visible ends each camera found. Results are appended to validation.jsonl in the calibration directory."
                }
            }
        }
    }
}
