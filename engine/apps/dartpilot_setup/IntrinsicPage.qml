pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Intrinsic calibration of one camera with the ChArUco pattern (#44, #45).
ColumnLayout {
    id: page

    required property bool active
    required property var cameras
    readonly property var camera: cameraBox.currentIndex >= 0 && cameraBox.currentIndex < cameras.length ? cameras[cameraBox.currentIndex] : null

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

    GuideDialog {
        id: guideDialog

        property bool shownOnce: false
    }

    PatternWindow {
        id: patternWindow

        visible: false
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing

        PageHeader {
            Layout.fillWidth: true
            title: "Intrinsic calibration"
            description: "Focal length, principal point and lens distortion of one camera, from views of a ChArUco pattern on a tablet or a flat print."
        }
        Button {
            text: "Guide"
            flat: true
            onClicked: guideDialog.open()
        }
        ComboBox {
            id: cameraBox

            Layout.preferredWidth: 340
            model: page.cameras.map((c, i) => "Camera " + (i + 1) + "  ·  USB " + c.usbPort + (c.hasIntrinsics ? "  ·  calibrated" : ""))
            // The views belong to one camera; switching starts over.
            onActivated: view.clearViews()
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
                    text: "Corners " + view.cornersInFrame + " / " + view.totalCorners
                    tone: view.cornersInFrame >= view.totalCorners * 0.4 ? Tokens.good : view.cornersInFrame > 0 ? Tokens.warning : Tokens.textMuted
                    dot: true
                }
                Chip {
                    text: view.viewCount + (view.viewCount === 1 ? " view" : " views")
                    tone: view.viewCount >= 15 ? Tokens.good : Tokens.accent
                }
                Chip {
                    text: "Coverage " + Math.round(view.coverage * 100) + "%"
                    tone: view.coverage >= 0.75 ? Tokens.good : view.coverage >= 0.4 ? Tokens.warning : Tokens.textMuted
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

                IntrinsicView {
                    id: view

                    anchors.fill: parent
                    devicePath: page.active && page.camera ? page.camera.path : ""
                    usbPort: page.camera ? page.camera.usbPort : ""
                    cameraName: page.camera ? page.camera.name : ""
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
                    text: "→  " + view.hint
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
                    title: "Pattern"
                    done: patternPath.text !== "" && patternPath.text !== "Saving failed"

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: "Show this pattern full screen on a tablet or a second display, or print it and lay it flat on glass. Its size does not matter."
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 0.7
                        radius: 8
                        color: "white"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: "image://charuco/pattern"
                            sourceSize.width: 600
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            implicitWidth: 160
                            implicitHeight: 160
                            radius: 8
                            color: "white"

                            // Rendered at the displayed size and not scaled, so every module stays whole pixels and scans reliably.
                            Image {
                                anchors.fill: parent
                                source: "image://charuco/qr"
                                sourceSize.width: width
                                smooth: false
                                fillMode: Image.Pad
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Label {
                                Layout.fillWidth: true
                                text: "On a phone or tablet"
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: Tokens.textMuted
                                text: "Scan the code to open the pattern, then show it full screen in landscape with maximum brightness."
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: Tokens.captionSize
                                color: Tokens.textMuted
                                text: view.patternDownloadUrl()
                            }
                        }
                    }
                    RowLayout {
                        Button {
                            text: "Show full screen"
                            highlighted: true
                            enabled: view.charucoAvailable
                            onClicked: patternWindow.showFullScreen()
                        }
                        Button {
                            text: "Save image"
                            flat: true
                            enabled: view.charucoAvailable
                            onClicked: patternPath.text = view.savePattern() || "Saving failed"
                        }
                    }
                    Label {
                        id: patternPath

                        visible: text !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Tokens.captionSize
                        color: Tokens.textMuted
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 2
                    title: "Views"
                    done: view.viewCount >= 15 && view.coverage >= 0.75

                    CaptureGuide {
                        Layout.fillWidth: true
                        visible: view.viewCount < 3
                        running: visible && page.active && !guideDialog.visible
                    }
                    Switch {
                        text: "Capture automatically when still"
                        checked: view.autoCapture
                        onToggled: view.autoCapture = checked
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        value: view.coverage
                    }
                    RowLayout {
                        Button {
                            text: "Capture now"
                            highlighted: true
                            enabled: view.cornersInFrame >= 6
                            onClicked: view.capture()
                        }
                        Button {
                            text: "Clear all"
                            flat: true
                            enabled: view.viewCount > 0
                            onClicked: view.clearViews()
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 220)
                        clip: true
                        spacing: 2
                        model: view.views

                        delegate: Rectangle {
                            id: entry

                            required property var modelData

                            width: ListView.view.width
                            height: 34
                            radius: 8
                            color: entry.modelData.outlier ? Qt.rgba(Tokens.bad.r, Tokens.bad.g, Tokens.bad.b, 0.12) : Tokens.surfaceRaised

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12

                                Label {
                                    text: "View " + (entry.modelData.index + 1)
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: entry.modelData.corners + " corners" + (entry.modelData.rmsPx !== undefined ? "  ·  " + entry.modelData.rmsPx.toFixed(2) + " px" : "")
                                    color: entry.modelData.outlier ? Tokens.bad : Tokens.textMuted
                                }
                                ToolButton {
                                    text: "✕"
                                    onClicked: view.removeView(entry.modelData.index)
                                }
                            }
                        }
                    }
                }

                StepCard {
                    Layout.fillWidth: true
                    step: 3
                    title: "Calibrate"
                    done: view.savedPath !== ""

                    RowLayout {
                        Label {
                            text: "Distortion model"
                            color: Tokens.textMuted
                        }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["standard", "rational", "fisheye"]
                            currentIndex: model.indexOf(view.model)
                            onActivated: view.model = currentText
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Tokens.captionSize
                        color: Tokens.textMuted
                        text: "For the 100° lens, compare the RMS of standard, rational and fisheye. Red views have more than twice the median error."
                    }
                    RowLayout {
                        Button {
                            text: view.calibrating ? "Calibrating…" : "Calibrate"
                            highlighted: true
                            enabled: view.viewCount >= 3 && !view.calibrating
                            onClicked: view.calibrate()
                        }
                        BusyIndicator {
                            running: view.calibrating
                            visible: running
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                        }
                    }
                    Rectangle {
                        visible: view.resultText !== ""
                        Layout.fillWidth: true
                        implicitHeight: resultLabel.implicitHeight + 20
                        radius: 8
                        color: Tokens.surfaceRaised

                        Label {
                            id: resultLabel

                            anchors.fill: parent
                            anchors.margins: 10
                            text: view.resultText
                            wrapMode: Text.WrapAnywhere
                            font.family: "monospace"
                            font.pixelSize: Tokens.captionSize
                        }
                    }
                    Button {
                        text: "Save calibration"
                        enabled: view.calibrated
                        onClicked: {
                            if (view.save() !== "")
                                page.saved();
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Tokens.captionSize
                        color: view.savedPath !== "" ? Tokens.good : Tokens.textMuted
                        text: view.savedPath !== "" ? "Saved to " + view.savedPath : "Saved to " + view.calibrationDirectory()
                    }
                }
            }
        }
    }
}
