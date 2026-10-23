pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Scaffold for the extrinsic calibration from the dartboard (#13). The pose solving follows once
// the board coordinate convention (#11) and the wire detection (#47) exist.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras

    spacing: Tokens.spacing

    PageHeader {
        Layout.fillWidth: true
        title: "Extrinsic calibration"
        description: "Each camera's pose relative to the board, computed from the dartboard itself: no extra target, no measuring."
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Tokens.spacing

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: page.cameras.length > 1 ? 2 : 1
            columnSpacing: Tokens.spacing
            rowSpacing: Tokens.spacing

            Repeater {
                model: page.cameras

                delegate: Card {
                    id: tile

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        RowLayout {
                            Label {
                                text: "Camera " + (tile.index + 1)
                                font.pixelSize: Tokens.headingSize
                                font.weight: Font.Bold
                            }
                            Chip {
                                text: "USB " + tile.modelData.usbPort
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8

                            Chip {
                                text: tile.modelData.hasIntrinsics ? "Intrinsics saved" : "Intrinsics missing"
                                tone: tile.modelData.hasIntrinsics ? Tokens.good : Tokens.warning
                                dot: true
                            }
                            Chip {
                                text: "Pose: not yet"
                                tone: Tokens.textMuted
                                dot: true
                            }
                        }
                        CameraView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            devicePath: page.active ? tile.modelData.path : ""
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 400
            Layout.maximumWidth: 400
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: [
                    {
                        title: "Intrinsics",
                        text: "Calibrate every camera on the previous page.",
                        ready: page.cameras.length > 0 && page.cameras.every(c => c.hasIntrinsics)
                    },
                    {
                        title: "Empty board",
                        text: "Remove all darts; nothing may cover the wires.",
                        ready: false
                    },
                    {
                        title: "Wire detection",
                        text: "Radial and ring wires and their intersections in every view (#47).",
                        ready: false
                    },
                    {
                        title: "Orientation",
                        text: "Confirm that 20 is at the top.",
                        ready: false
                    },
                    {
                        title: "Camera poses",
                        text: "Solve each pose and refine all three against the board model (#13).",
                        ready: false
                    },
                    {
                        title: "Check",
                        text: "Uncertainty in board millimetres: green, yellow or red.",
                        ready: false
                    }
                ]

                delegate: StepCard {
                    id: stepCard

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    step: index + 1
                    title: modelData.title
                    done: modelData.ready

                    Label {
                        Layout.fillWidth: true
                        text: stepCard.modelData.text
                        color: Tokens.textMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: notice.implicitHeight + 24
                radius: Tokens.radius
                color: Qt.rgba(Tokens.warning.r, Tokens.warning.g, Tokens.warning.b, 0.10)
                border.color: Qt.rgba(Tokens.warning.r, Tokens.warning.g, Tokens.warning.b, 0.35)

                Label {
                    id: notice

                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Not available yet: this needs the board coordinate convention (#11) and the wire detection (#47)."
                    color: Tokens.warning
                    wrapMode: Text.WordWrap
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}
