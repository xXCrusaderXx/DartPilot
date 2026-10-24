pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// Extrinsic calibration from the dartboard (#13, #47): detect the board per camera, click the sector 20, and fit the
// board plane. The full pose and lens refinement (ADR 0006) follow.
ColumnLayout {
    id: page

    required property bool active
    required property var cameras
    // Per camera index: true once a board plane is stored
    property var planes: ({})
    readonly property bool allPlanes: cameras.length > 0 && cameras.every((c, i) => planes[i] === true)

    function setPlane(index, done) {
        const next = Object.assign({}, planes);
        next[index] = done;
        planes = next;
    }

    spacing: Tokens.spacing

    PageHeader {
        Layout.fillWidth: true
        title: "Extrinsic calibration"
        description: "Each camera's view of the board, computed from the dartboard itself: no extra target, no measuring. Remove all darts, detect the board, then click the sector 20."
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

                    // Equal preferred widths, so a long warning does not widen one tile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1

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
                                text: !tile.modelData.hasIntrinsics ? "Intrinsics missing" : tile.modelData.intrinsicsWarning !== "" ? "Intrinsics for other settings" : "Intrinsics saved"
                                tone: tile.modelData.hasIntrinsics && tile.modelData.intrinsicsWarning === "" ? Tokens.good : Tokens.warning
                                dot: true
                            }
                            Chip {
                                text: board.hasPlane ? "Board fit " + board.rmsMm.toFixed(2) + " mm" : "Board: not yet"
                                tone: !board.hasPlane ? Tokens.textMuted : board.rmsMm <= 0.5 ? Tokens.good : board.rmsMm <= 1.0 ? Tokens.warning : Tokens.bad
                                dot: true
                            }
                        }
                        Label {
                            visible: tile.modelData.intrinsicsWarning !== ""
                            Layout.fillWidth: true
                            text: tile.modelData.intrinsicsWarning
                            color: Tokens.warning
                            wrapMode: Text.WordWrap
                            font.pixelSize: Tokens.captionSize
                        }
                        ExtrinsicView {
                            id: board

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            devicePath: page.active ? tile.modelData.path : ""
                            usbPort: tile.modelData.usbPort
                            onResultChanged: page.setPlane(tile.index, hasPlane)
                            Component.onCompleted: page.setPlane(tile.index, hasPlane)
                        }
                        RowLayout {
                            Button {
                                text: board.state === "detecting" ? "Detecting …" : board.hasPlane ? "Detect again" : "Detect board"
                                highlighted: !board.hasPlane
                                enabled: board.state !== "detecting" && page.active
                                onClicked: board.detect()
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: board.hasPlane
                                text: "worst " + board.worstMm.toFixed(2) + " mm, " + board.rmsPx.toFixed(2) + " px" + (board.undistorted ? ", lens corrected" : ", without lens correction")
                                color: Tokens.textMuted
                                font.pixelSize: Tokens.captionSize
                                elide: Text.ElideRight
                            }
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
                        title: "Intrinsics (optional)",
                        text: "With a saved intrinsic calibration the lens distortion is removed before the fit; without one the fit contains it.",
                        ready: page.cameras.length > 0 && page.cameras.every(c => c.hasIntrinsics && c.intrinsicsWarning === "")
                    },
                    {
                        title: "Empty board",
                        text: "Remove all darts; nothing may cover the wires.",
                        ready: page.allPlanes
                    },
                    {
                        title: "Board detection",
                        text: "\"Detect board\" on every camera finds the rings and the 20 radial wires: 60 points per camera (#47).",
                        ready: page.allPlanes
                    },
                    {
                        title: "Orientation",
                        text: "Click the sector 20 in every camera, then check that the numbers match the board.",
                        ready: page.allPlanes
                    },
                    {
                        title: "Camera poses and lens refinement",
                        text: "Pose, focal length and distortion per camera from these points (#13, ADR 0006). Next step.",
                        ready: false
                    },
                    {
                        title: "Check",
                        text: "Board fit error per camera in millimetres: green up to 0.5 mm, yellow up to 1 mm.",
                        ready: page.allPlanes
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
                    text: "The board plane is fitted as a homography per camera. The full camera pose and the lens refinement from the board follow with #13."
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
