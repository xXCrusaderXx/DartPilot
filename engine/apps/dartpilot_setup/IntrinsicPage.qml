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
    // Kept here, so refreshing the camera list after a save neither switches the camera nor resets the dropdown
    property int selected: 0
    readonly property var camera: selected >= 0 && selected < cameras.length ? cameras[selected] : null

    // The last press of "Save calibration" wrote nothing
    property bool saveFailed: false

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
            model: page.cameras
            textRole: "lensChoice"
            currentIndex: page.selected
            // A new model resets the index and choosing an entry breaks the binding, so the selection is set again.
            onModelChanged: Qt.callLater(() => currentIndex = page.selected)
            // The views belong to one camera; switching starts over.
            onActivated: index => {
                page.selected = index;
                page.saveFailed = false;
                view.clearViews();
            }
        }
    }

    // Why the stored calibration of this camera does not apply, e.g. taken in another mode
    Label {
        visible: page.camera !== null && page.camera.intrinsicsWarning !== ""
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Tokens.warning
        text: page.camera ? "The stored calibration does not apply: " + page.camera.intrinsicsWarning : ""
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spaceMd

            RowLayout {
                spacing: Tokens.spaceSm

                Chip {
                    text: "Corners " + view.cornersInFrame + " / " + view.totalCorners
                    tone: Tokens.qualityTone(view.cornersQuality)
                    dot: true
                }
                Chip {
                    text: view.viewCount + (view.viewCount === 1 ? " view" : " views")
                    tone: view.viewsQuality === "" ? Tokens.accent : Tokens.qualityTone(view.viewsQuality)
                }
                Chip {
                    text: "Coverage " + Math.round(view.coverage * 100) + "%"
                    tone: Tokens.qualityTone(view.coverageQuality)
                }
                Item {
                    Layout.fillWidth: true
                }
                FpsChip {
                    stream: view
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: Tokens.spaceSm

                IntrinsicView {
                    id: view

                    anchors.fill: parent
                    devicePath: page.active && page.camera ? page.camera.path : ""
                    usbPort: page.camera ? page.camera.usbPort : ""
                    cameraName: page.camera ? page.camera.name : ""
                }
            }

            HintBanner {
                text: view.hint
            }
        }

        ScrollView {
            id: side

            Layout.preferredWidth: Tokens.sidePanelWidth
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: side.availableWidth
                spacing: Tokens.spaceMd

                StepCard {
                    Layout.fillWidth: true
                    step: 1
                    title: "Pattern"
                    // Shown, printed or on another device: the pattern is ready once the camera captured a view of it
                    done: view.viewCount > 0

                    RowLayout {
                        spacing: Tokens.spaceSm

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
                        radius: Tokens.radiusSmall
                        color: Tokens.paper

                        Image {
                            anchors.fill: parent
                            anchors.margins: Tokens.spaceSm
                            source: "image://charuco/pattern/" + view.target
                            sourceSize.width: 600
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceMd

                        Rectangle {
                            implicitWidth: 160
                            implicitHeight: 160
                            radius: Tokens.radiusSmall
                            color: Tokens.paper

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
                            spacing: Tokens.spaceXs

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
                            ToolTip.visible: hovered
                            ToolTip.text: "Shortcut: C"

                            Shortcut {
                                sequence: "C"
                                enabled: page.active && view.cornersInFrame >= 6
                                onActivated: view.capture()
                            }
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
                        spacing: Tokens.spaceXxs
                        model: view.views

                        delegate: Rectangle {
                            id: entry

                            required property var modelData

                            width: ListView.view.width
                            height: 34
                            radius: Tokens.radiusSmall
                            color: entry.modelData.outlier ? Tokens.tint(Tokens.bad, 0.12) : Tokens.surfaceRaised

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.spaceMd

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
                                    Accessible.name: "Remove view " + (entry.modelData.index + 1)
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Remove this view"
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
                            radius: Tokens.radiusSmall
                            color: selected ? Tokens.tint(Tokens.accent, Tokens.tintFill) : Tokens.surfaceRaised
                            border.color: selected || activeFocus ? Tokens.accent : "transparent"
                            border.width: activeFocus ? 2 : 1
                            // A choice like a radio button: reachable with Tab, chosen with Space or Enter
                            activeFocusOnTab: true
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: "Lens model " + modelData.model
                            Accessible.checked: selected
                            Keys.onSpacePressed: view.model = modelRow.modelData.model
                            Keys.onReturnPressed: view.model = modelRow.modelData.model

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.spaceMd
                                anchors.rightMargin: Tokens.spaceMd

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
                        radius: Tokens.radiusSmall
                        readonly property color tone: Tokens.qualityTone(view.quality)
                        color: Tokens.tint(tone, Tokens.tintFillSoft)
                        border.color: Tokens.tint(tone, Tokens.tintBorder)

                        ColumnLayout {
                            id: qualityColumn

                            anchors.fill: parent
                            anchors.margins: Tokens.spaceMd
                            spacing: Tokens.spaceSm

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
                        radius: Tokens.radiusSmall
                        color: Tokens.surfaceRaised

                        Label {
                            id: resultLabel

                            anchors.fill: parent
                            anchors.margins: Tokens.spaceMd
                            text: view.resultText
                            wrapMode: Text.WrapAnywhere
                            font.family: Tokens.codeFont
                            font.pixelSize: Tokens.captionSize
                        }
                    }
                    Button {
                        text: "Save calibration"
                        enabled: view.calibrated
                        onClicked: {
                            page.saveFailed = view.save() === "";
                            if (!page.saveFailed)
                                page.saved();
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        font.pixelSize: Tokens.captionSize
                        color: page.saveFailed ? Tokens.bad : view.savedPath !== "" ? Tokens.good : Tokens.textMuted
                        text: page.saveFailed ? "Saving failed. Check that " + view.calibrationDirectory() + " is writable." : view.savedPath !== "" ? "Saved to " + view.savedPath : "Will be saved to " + view.calibrationDirectory()
                    }
                }
            }
        }
    }
}
