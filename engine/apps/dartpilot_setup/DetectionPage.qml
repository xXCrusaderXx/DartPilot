pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// The detection test (#195): throw, see what the live detection made of each dart, rate it, pull, again. Every
// detection value can be changed while it runs; each camera shows the axis it found.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras
    // Index in test.darts of the dart a tap on the board corrects; -1 adds a missed dart
    property int selected: -1

    function toneOf(outcome) {
        return outcome === "right" ? Tokens.good : outcome === "abstained" ? Tokens.warning : outcome === "missed" ? Tokens.accent : Tokens.bad;
    }
    function outcomeText(outcome) {
        return {
            right: "right",
            wrong: "wrong field",
            abstained: "unsure",
            missed: "missed",
            falseAlarm: "no dart"
        }[outcome] || outcome;
    }
    function number(value, digits) {
        return value === undefined || value < 0 ? "–" : value.toFixed(digits);
    }

    spacing: Tokens.spacing

    DetectionTest {
        id: test

        cameras: page.cameras
        active: page.active
        onProblem: message => problemLabel.text = message
        // A value that could be set, or a profile that could be loaded or saved, ends the last problem.
        onParamsChanged: problemLabel.text = ""
        onProfilesChanged: problemLabel.text = ""
        onResultsChanged: if (page.selected >= test.darts.length) page.selected = -1
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing

        PageHeader {
            Layout.fillWidth: true
            title: "Detection test"
            description: "Throw, check each dart, pull, again. The live detection of dartpilot serve runs here on the cameras; every value below can be changed while it runs. Lines in the camera images: the axis each camera found (green seen, yellow cut by the border, red disagreeing)."
        }
        Chip {
            text: test.status === "ready" ? "Ready" : test.status === "not_calibrated" ? "Not calibrated" : "Waiting for an empty board"
            tone: test.status === "ready" ? Tokens.good : test.status === "not_calibrated" ? Tokens.bad : Tokens.warning
            dot: true
        }
        Button {
            text: "New test"
            flat: true
            onClicked: {
                page.selected = -1;
                test.restart();
            }
            ToolTip.visible: hovered
            ToolTip.text: "Empty board first. Starts a new log and counts from zero; the values stay."
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
                                markers: test.markers[pane.modelData.usbPort] || []
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.columnSpan: page.cameras.length > 1 ? 2 : 1

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Label {
                            text: "Detection values"
                            font.pixelSize: Tokens.headingSize
                            font.weight: Font.Bold
                        }
                        RowLayout {
                            spacing: 8

                            ComboBox {
                                id: profileBox

                                Layout.preferredWidth: 200
                                model: test.profiles
                            }
                            Button {
                                text: "Load"
                                enabled: profileBox.currentIndex >= 0
                                onClicked: test.loadProfile(profileBox.currentText)
                            }
                            TextField {
                                id: profileName

                                Layout.preferredWidth: 180
                                placeholderText: "Profile name"
                            }
                            Button {
                                text: "Save"
                                enabled: profileName.text.trim() !== ""
                                onClicked: test.saveProfile(profileName.text)
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Label {
                                text: "Revision " + test.revision
                                color: Tokens.textMuted
                            }
                            Button {
                                text: "All to defaults"
                                flat: true
                                onClicked: test.resetAllParams()
                            }
                        }
                        Label {
                            id: problemLabel

                            visible: text !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Tokens.bad
                        }
                        Repeater {
                            model: ["event_detection", "tip_candidates", "geometry", "fusion"]

                            delegate: ColumnLayout {
                                id: group

                                required property string modelData

                                Layout.fillWidth: true
                                spacing: 4

                                Label {
                                    Layout.topMargin: 8
                                    text: group.modelData
                                    font.weight: Font.Bold
                                    color: Tokens.accent
                                }
                                Repeater {
                                    model: test.params.filter(p => p.group === group.modelData)

                                    delegate: RowLayout {
                                        id: row

                                        required property var modelData
                                        readonly property bool changed: Math.abs(modelData.value - modelData.defaultValue) > 1e-9

                                        Layout.fillWidth: true
                                        spacing: 8

                                        Label {
                                            Layout.preferredWidth: 210
                                            text: row.modelData.name
                                            font.weight: row.changed ? Font.Bold : Font.Normal
                                            color: row.changed ? Tokens.warning : Tokens.text
                                            elide: Text.ElideRight
                                            ToolTip.visible: hoverArea.containsMouse
                                            ToolTip.text: row.modelData.description + "  Default " + row.modelData.defaultValue + (row.modelData.unit !== "" ? " " + row.modelData.unit : "") + "."

                                            MouseArea {
                                                id: hoverArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                            }
                                        }
                                        Slider {
                                            id: slider

                                            Layout.fillWidth: true
                                            from: row.modelData.min
                                            to: row.modelData.max
                                            stepSize: row.modelData.step
                                            snapMode: Slider.SnapAlways
                                            value: row.modelData.value
                                            onPressedChanged: if (!pressed && Math.abs(value - row.modelData.value) > 1e-9) test.setParam(row.modelData.name, value)
                                            // Arrow keys and the wheel move it without a press; a drag commits on release.
                                            onMoved: if (!pressed) test.setParam(row.modelData.name, value)
                                        }
                                        Label {
                                            Layout.preferredWidth: 90
                                            horizontalAlignment: Text.AlignRight
                                            text: (slider.pressed ? slider.value : row.modelData.value).toFixed(row.modelData.step >= 1 ? 0 : row.modelData.step >= 0.1 ? 1 : row.modelData.step >= 0.01 ? 2 : 4) + (row.modelData.unit !== "" ? " " + row.modelData.unit : "")
                                        }
                                        Button {
                                            text: "↺"
                                            flat: true
                                            enabled: row.changed
                                            onClicked: test.resetParam(row.modelData.name)
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Back to " + row.modelData.defaultValue
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ScrollView {
            id: side

            Layout.preferredWidth: 440
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: side.availableWidth
                spacing: 12

                Card {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        readonly property var counts: test.stats.counts || {}

                        Label {
                            text: "Counts"
                            font.pixelSize: Tokens.headingSize
                            font.weight: Font.Bold
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: ["right", "wrong", "abstained", "missed", "falseAlarm"]

                                delegate: Chip {
                                    required property string modelData

                                    text: page.outcomeText(modelData) + "  " + ((test.stats.counts || {})[modelData] || 0)
                                    tone: page.toneOf(modelData)
                                    dot: true
                                }
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Placed in the right field: " + (test.stats.placedRight === undefined ? "–" : Math.round(test.stats.placedRight * 100) + " %") + "   ·   Rounds " + (test.stats.rounds || 1) + ", takeouts " + (test.stats.takeouts || 0) + (test.stats.movedCameras > 0 ? ", camera moved " + test.stats.movedCameras + "×" : "")
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Tokens.textMuted
                            text: "Median: landing → result " + page.number(test.stats.latencyMedianMs, 0) + " ms, of it processing " + page.number(test.stats.processingMedianMs, 0) + " ms; pull → takeout " + page.number(test.stats.takeoutLatencyMedianMs, 0) + " ms; wrong fields off by " + page.number(test.stats.wrongErrorMedianMm, 1) + " mm"
                        }
                        Label {
                            text: "By dart of the round"
                            font.weight: Font.Bold
                            Layout.topMargin: 4
                        }
                        Repeater {
                            model: test.stats.byPosition || []

                            delegate: Label {
                                required property var modelData

                                font.pixelSize: Tokens.captionSize
                                text: "Dart " + modelData.position + ":  " + modelData.darts + " darts  ·  right " + (modelData.right || 0) + ", wrong " + (modelData.wrong || 0) + ", unsure " + (modelData.abstained || 0) + ", missed " + (modelData.missed || 0) + (modelData.falseAlarm ? ", no dart " + modelData.falseAlarm : "")
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6

                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Tokens.textMuted
                            text: page.selected >= 0 ? "Tap where dart " + (test.darts.length - page.selected) + " really is." : "Select a dart below to correct it, or tap the board to add a dart the engine missed."
                        }
                        BoardPicker {
                            Layout.fillWidth: true
                            marks: test.darts.filter(d => d.xMm !== undefined).map((d, i) => ({
                                        xMm: d.xMm,
                                        yMm: d.yMm,
                                        colour: page.toneOf(d.outcome),
                                        selected: test.darts.indexOf(d) === page.selected
                                    }))
                            onPicked: (xMm, yMm) => {
                                if (page.selected >= 0)
                                    test.correct(page.selected, xMm, yMm);
                                else
                                    test.addMissed(xMm, yMm);
                                page.selected = -1;
                            }
                        }
                    }
                }

                Repeater {
                    model: test.darts

                    delegate: Card {
                        id: dartCard

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        padding: 10
                        // Several children: a Pane then takes its content size from none of them.
                        contentHeight: dartColumn.implicitHeight

                        TapHandler {
                            onTapped: page.selected = page.selected === dartCard.index ? -1 : dartCard.index
                        }

                        Rectangle {
                            visible: page.selected === dartCard.index
                            x: -dartCard.leftPadding
                            y: -dartCard.topPadding
                            width: 4
                            height: dartCard.height
                            radius: 2
                            color: Tokens.accent
                        }
                        ColumnLayout {
                            id: dartColumn

                            width: parent.width
                            spacing: 4

                            RowLayout {
                                spacing: 8

                                Label {
                                    text: (test.darts.length - dartCard.index) + ".  " + (dartCard.modelData.label || (dartCard.modelData.detected ? "?" : "—"))
                                    font.pixelSize: Tokens.headingSize
                                    font.weight: Font.Bold
                                }
                                Chip {
                                    text: page.outcomeText(dartCard.modelData.outcome) + (dartCard.modelData.truthLabel ? " → " + dartCard.modelData.truthLabel : "")
                                    tone: page.toneOf(dartCard.modelData.outcome)
                                    dot: true
                                }
                                Item {
                                    Layout.fillWidth: true
                                }
                                Button {
                                    visible: dartCard.modelData.detected && dartCard.modelData.outcome !== "falseAlarm"
                                    text: "No dart"
                                    flat: true
                                    onClicked: test.reject(dartCard.index)
                                }
                                Button {
                                    visible: !dartCard.modelData.detected
                                    text: "Delete"
                                    flat: true
                                    onClicked: test.remove(dartCard.index)
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Tokens.captionSize
                                color: Tokens.textMuted
                                text: "Round " + dartCard.modelData.round + ", dart " + dartCard.modelData.position + (dartCard.modelData.detected ? "  ·  " + page.number(dartCard.modelData.latencyMs, 0) + " ms (" + page.number(dartCard.modelData.processingMs, 0) + " processing)  ·  confidence " + dartCard.modelData.confidence.toFixed(2) + "  ·  rev " + dartCard.modelData.revision + (dartCard.modelData.reason ? "  ·  " + dartCard.modelData.reason : "") + (dartCard.modelData.errorMm !== undefined ? "  ·  off by " + dartCard.modelData.errorMm.toFixed(1) + " mm" : "") : "")
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: dartCard.modelData.cameras

                                    delegate: Chip {
                                        required property var modelData

                                        text: "Cam " + modelData.number + " " + modelData.state + (modelData.used ? " ✓" : "")
                                        tone: modelData.state === "seen" ? Tokens.good : modelData.state === "cut" ? Tokens.warning : modelData.state === "disagrees" ? Tokens.bad : Tokens.textMuted
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Tokens.captionSize
                    color: Tokens.textMuted
                    text: "Log with every throw, rating, takeout and value change, and the averaged images of every still moment: " + test.logPath
                }
            }
        }
    }
}
