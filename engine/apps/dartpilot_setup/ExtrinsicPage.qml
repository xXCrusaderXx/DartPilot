pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Extrinsic calibration of one camera from the dartboard (#13, #47): detect the board, click the sector 20, check the
// numbers and the fit. The full pose and lens refinement (ADR 0006) follow.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras
    // Kept here, so refreshing the camera list after a save does not jump back to the first camera
    property int selected: 0
    readonly property var camera: selected >= 0 && selected < cameras.length ? cameras[selected] : null

    signal saved

    spacing: Tokens.spacing

    // The guide opens by itself on the first visit of the page.
    onActiveChanged: {
        if (active && !guideDialog.shownOnce) {
            guideDialog.shownOnce = true;
            guideDialog.open();
        }
    }
    Component.onCompleted: activeChanged()

    ExtrinsicGuideDialog {
        id: guideDialog

        property bool shownOnce: false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing

        PageHeader {
            Layout.fillWidth: true
            title: "Extrinsic calibration"
            description: "Where each camera looks at the board, computed from the dartboard itself: no extra target, no measuring."
        }
        Button {
            text: "Guide"
            flat: true
            onClicked: guideDialog.open()
            ToolTip.visible: hovered
            ToolTip.text: "Show how the board calibration works"
        }
        ComboBox {
            id: cameraBox

            Layout.preferredWidth: 420
            model: page.cameras.map((c, i) => "Camera " + (i + 1) + "  ·  USB " + c.usbPort + (c.hasBoardPlane ? "  ·  board " + c.boardRmsMm.toFixed(2) + " mm" : "  ·  not yet"))
            currentIndex: page.selected
            onActivated: index => page.selected = index
            ToolTip.visible: hovered
            ToolTip.text: "Calibrate one camera after the other; the list shows each camera's board fit"
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                spacing: 8

                Chip {
                    text: !page.camera ? "" : page.camera.hasIntrinsics && page.camera.intrinsicsWarning === "" ? "Lens calibrated" : "Lens not calibrated"
                    tone: page.camera && page.camera.hasIntrinsics && page.camera.intrinsicsWarning === "" ? Tokens.good : Tokens.textMuted
                    dot: true

                    HoverHandler {
                        id: lensHover
                    }
                    ToolTip.visible: lensHover.hovered
                    ToolTip.text: "With an intrinsic calibration of this camera the lens distortion is removed before the board fit. It is optional."
                }
                Chip {
                    text: view.hasPlane ? "Board fit " + view.rmsMm.toFixed(2) + " mm" : "Board: not yet"
                    tone: !view.hasPlane ? Tokens.textMuted : view.rmsMm <= 0.5 ? Tokens.good : view.rmsMm <= 1.0 ? Tokens.warning : Tokens.bad
                    dot: true

                    HoverHandler {
                        id: fitHover
                    }
                    ToolTip.visible: fitHover.hovered
                    ToolTip.text: "Average distance between the detected board points and where they belong, in board millimetres. Green up to 0.5 mm, yellow up to 1 mm."
                }
                Item {
                    Layout.fillWidth: true
                }
                Chip {
                    text: view.error !== "" ? "Error" : view.fps > 0 ? view.fps.toFixed(1) + " fps" : "Starting"
                    tone: view.error !== "" ? Tokens.bad : view.fps >= 29 ? Tokens.good : Tokens.warning
                    dot: true
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 8

                ExtrinsicView {
                    id: view

                    anchors.fill: parent
                    devicePath: page.active && page.camera ? page.camera.path : ""
                    usbPort: page.camera ? page.camera.usbPort : ""
                    onResultChanged: page.saved()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: hintLabel.implicitHeight + 24
                radius: Tokens.radius
                color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.10)
                border.color: Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.35)

                Label {
                    id: hintLabel

                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16
                    text: "→  " + (view.state === "idle" ? (view.hasPlane ? "This camera is calibrated. Detect again after moving the camera or the board." : "Empty the board, then press \"Detect board\".") : view.message)
                    font.pixelSize: Tokens.headingSize
                    color: Tokens.text
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
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
                    done: view.state !== "idle" || view.hasPlane

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "Remove all darts and make sure nothing covers the board. Even light without strong glare on the rings helps."
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 2
                    title: "Detect the board"
                    done: view.state === "pick" || view.state === "done" || view.hasPlane

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "Averages ten frames and finds the rings and the 20 radial wires: 60 calibration points."
                    }
                    Button {
                        text: view.state === "detecting" ? "Detecting …" : view.hasPlane ? "Detect again" : "Detect board"
                        highlighted: !view.hasPlane
                        enabled: view.state !== "detecting" && page.active
                        onClicked: view.detect()
                        ToolTip.visible: hovered
                        ToolTip.text: "Takes about a second; the board must be empty"
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 3
                    title: "Click the sector 20"
                    done: view.state === "done" || view.hasPlane

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "The colours repeat every second sector, so DartPilot needs to be told once which one is the 20. Click anywhere into it in the camera image, between the bull and the double ring."
                    }
                    BoardIllustration {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 170
                        detection: 1
                        numbered: true
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 4
                    title: "Check"
                    // Done once checked and saved; how good the fit is shows the board fit chip
                    done: view.hasPlane

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "Every sector now shows its number. If they do not match the real board, click the sector 20 again."
                    }
                    GridLayout {
                        visible: view.hasPlane
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 4

                        Label {
                            text: "Board fit"
                            color: Tokens.textMuted
                        }
                        Label {
                            text: view.rmsMm.toFixed(2) + " mm  (worst " + view.worstMm.toFixed(2) + " mm)"
                        }
                        Label {
                            text: "In the image"
                            color: Tokens.textMuted
                        }
                        Label {
                            text: view.rmsPx.toFixed(2) + " px"
                        }
                        Label {
                            text: "Lens correction"
                            color: Tokens.textMuted
                        }
                        Label {
                            text: view.undistorted ? "yes" : "no"
                        }
                    }
                    Label {
                        visible: view.hasPlane
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Tokens.captionSize
                        color: Tokens.textMuted
                        text: "The fit still ignores the lens distortion of cameras without an intrinsic calibration and assumes the nominal board size; the refinement in the next step removes both."
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 5
                    title: "Pose and lens refinement"

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "Next: pose, focal length and distortion of every camera and the actual size of the board, from the points of all three cameras together (#13, ADR 0006)."
                    }
                }
            }
        }
    }
}
