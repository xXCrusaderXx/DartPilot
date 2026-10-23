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

        target: view.target
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
            model: page.cameras.map((c, i) => "Camera " + (i + 1) + "  ·  USB " + c.usbPort + (c.hasIntrinsics ? (c.intrinsicsWarning === "" ? "  ·  calibrated" : "  ·  calibration not valid") : ""))
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

                    RowLayout {
                        spacing: 8

                        ButtonGroup {
                            id: targetGroup
                        }
                        Button {
                            text: "Tablet or print"
                            checkable: true
                            checked: view.target === "tablet"
                            ButtonGroup.group: targetGroup
                            onClicked: view.target = "tablet"
                        }
                        Button {
                            text: "Phone"
                            checkable: true
                            checked: view.target === "phone"
                            ButtonGroup.group: targetGroup
                            onClicked: view.target = "phone"
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Tokens.textMuted
                        text: view.target === "phone" ? "Larger cells for the small screen of a phone, so it can stay 30 to 40 cm away and reach the image corners. Views of both patterns can be mixed." : "Show this pattern full screen on a tablet or a second display, or print it and lay it flat on glass. Its size does not matter."
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * (view.target === "phone" ? 0.5 : 0.7)
                        radius: 8
                        color: "white"

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: "image://charuco/pattern/" + view.target
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
                                source: "image://charuco/qr/" + view.target
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
                                text: "Scan the code to open the pattern, then show it full screen in landscape at about 50 % brightness."
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: Tokens.captionSize
                                color: Tokens.textMuted
                                text: view.target !== "" ? view.patternDownloadUrl() : ""
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

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Tokens.captionSize
                        color: Tokens.textMuted
                        text: "Calibrates the standard, rational and fisheye model and checks each on views it did not see. The recommended model is the simplest one within 5 % of the best held-out error."
                    }
                    Label {
                        id: savedLabel

                        // Re-read when the camera, the page or a save changes
                        readonly property string summary: page.active && page.camera && view.savedPath !== "-" ? view.savedSummary() : ""

                        visible: summary !== ""
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: Tokens.captionSize
                        color: Tokens.textMuted
                        text: "Saved calibration: " + summary
                    }
                    RowLayout {
                        Button {
                            text: view.calibrating ? "Calibrating…" : "Calibrate"
                            highlighted: true
                            enabled: view.viewCount >= 3 && !view.calibrating
                            onClicked: view.calibrate()
                        }
                        Button {
                            visible: savedLabel.visible
                            text: "Load saved views"
                            flat: true
                            enabled: !view.calibrating
                            onClicked: view.loadSaved()
                        }
                        BusyIndicator {
                            running: view.calibrating
                            visible: running
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                        }
                    }

                    // One row per model: click to select it.
                    Repeater {
                        model: view.modelResults

                        delegate: Rectangle {
                            id: modelRow

                            required property var modelData
                            readonly property bool selected: modelData.model === view.model

                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 8
                            color: selected ? Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.14) : Tokens.surfaceRaised
                            border.color: selected ? Tokens.accent : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Label {
                                    Layout.preferredWidth: 72
                                    text: modelRow.modelData.model
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelRow.modelData.ok ? "fit " + modelRow.modelData.rmsPx.toFixed(2) + " px   held-out " + modelRow.modelData.heldOutRmsPx.toFixed(2) + " px" : "failed"
                                    color: modelRow.modelData.ok ? Tokens.textMuted : Tokens.bad
                                    font.pixelSize: Tokens.captionSize
                                }
                                Chip {
                                    visible: modelRow.modelData.recommended
                                    text: "recommended"
                                    tone: Tokens.good
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: view.model = modelRow.modelData.model
                            }
                        }
                    }

                    Rectangle {
                        id: qualityBox

                        visible: view.quality !== ""
                        Layout.fillWidth: true
                        implicitHeight: qualityColumn.implicitHeight + 20
                        radius: 8
                        readonly property color tone: view.quality === "good" ? Tokens.good : view.quality === "fair" ? Tokens.warning : Tokens.bad
                        color: Qt.rgba(tone.r, tone.g, tone.b, 0.10)
                        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.35)

                        ColumnLayout {
                            id: qualityColumn

                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Chip {
                                text: view.quality === "good" ? "Good" : view.quality === "fair" ? "Usable, can be better" : "Not good enough"
                                tone: qualityBox.tone
                                dot: true
                            }
                            Label {
                                Layout.fillWidth: true
                                text: view.qualityText
                                wrapMode: Text.WordWrap
                                font.pixelSize: Tokens.captionSize
                            }
                        }
                    }
                    Button {
                        visible: view.views.some(v => v.outlier === true)
                        text: "Remove red views"
                        flat: true
                        onClicked: view.removeOutlierViews()
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
