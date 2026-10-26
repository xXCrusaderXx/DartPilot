pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// How the board calibration works: an animation of detect, click the sector 20 and check, and a checklist.
GuideDialogBase {
    id: dialog

    // 0 detect, 1 click, 2 check
    property int phase: 0

    title: "How to calibrate the board"

    SequentialAnimation {
        running: dialog.visible
        loops: Animation.Infinite

        ScriptAction {
            script: {
                dialog.phase = 0;
                board.numbered = false;
                board.detection = 0;
                cursor.opacity = 0;
                cursor.x = stage.width * 0.85;
                cursor.y = stage.height * 0.85;
            }
        }
        NumberAnimation {
            target: board
            property: "detection"
            from: 0
            to: 1
            duration: 1800
            easing.type: Easing.InOutQuad
        }
        PauseAnimation {
            duration: 400
        }
        ScriptAction {
            script: dialog.phase = 1
        }
        NumberAnimation {
            target: cursor
            property: "opacity"
            to: 1
            duration: 200
        }
        ParallelAnimation {
            NumberAnimation {
                target: cursor
                property: "x"
                to: stage.width / 2 - 4
                duration: 1000
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: cursor
                property: "y"
                to: stage.height / 2 - board.boardRadius * 0.62
                duration: 1000
                easing.type: Easing.InOutCubic
            }
        }
        ScriptAction {
            script: ripple.restart()
        }
        PauseAnimation {
            duration: 300
        }
        ScriptAction {
            script: {
                dialog.phase = 2;
                board.numbered = true;
            }
        }
        PauseAnimation {
            duration: 2600
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Tokens.spaceXl

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spaceMd

            Rectangle {
                id: stage

                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.62
                radius: Tokens.radiusSmall
                color: Tokens.background
                border.color: Tokens.border
                clip: true

                BoardIllustration {
                    id: board

                    readonly property real boardRadius: Math.min(width, height) / 2 * 0.78

                    anchors.fill: parent
                }

                Rectangle {
                    id: rippleCircle

                    width: 44
                    height: 44
                    radius: width / 2
                    x: cursor.x - 22 + 4
                    y: cursor.y - 22 + 4
                    color: "transparent"
                    border.color: Tokens.warning
                    border.width: 3
                    opacity: 0
                    scale: 0.3

                    ParallelAnimation {
                        id: ripple

                        NumberAnimation {
                            target: rippleCircle
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: 500
                        }
                        NumberAnimation {
                            target: rippleCircle
                            property: "scale"
                            from: 0.3
                            to: 1.4
                            duration: 500
                        }
                    }
                }

                // A simple mouse pointer
                Canvas {
                    id: cursor

                    width: 22
                    height: 30
                    opacity: 0
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.beginPath();
                        ctx.moveTo(2, 2);
                        ctx.lineTo(2, 24);
                        ctx.lineTo(8, 18);
                        ctx.lineTo(13, 28);
                        ctx.lineTo(17, 26);
                        ctx.lineTo(12, 16);
                        ctx.lineTo(20, 16);
                        ctx.closePath();
                        ctx.fillStyle = Tokens.text;
                        ctx.strokeStyle = Tokens.background;
                        ctx.lineWidth = 1.5;
                        ctx.fill();
                        ctx.stroke();
                    }
                }

                Chip {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Tokens.spaceSm
                    text: ["1  Detect board", "2  Click the sector 20", "3  Check the numbers"][dialog.phase]
                    tone: Tokens.accent
                    dot: true
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Tokens.text
                text: ["The rings and the 20 radial wires are found from the colours of the board.", "The colours repeat every second sector, so you tell DartPilot once which sector is the 20.", "Every sector gets its number. If they match the real board, the camera is done."][dialog.phase]
            }
        }

        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spaceMd

            SectionLabel {
                text: "Before you start"
            }
            Repeater {
                model: ["Remove all darts; nothing may cover the board, also not a hand.", "Light the board evenly; strong glare on the rings can hide them.", "The cameras stay in their mounts. After moving a camera or the board, calibrate it again."]

                delegate: ChecklistItem {}
            }
            SectionLabel {
                text: "For every camera"
                Layout.topMargin: Tokens.spaceSm
            }
            Repeater {
                model: ["Choose the camera at the top and press \"Detect board\".", "Click anywhere into the sector 20, between the bull and the double ring.", "Check that the numbers match the board. If not, click the sector 20 again.", "The board fit in millimetres says how well the board was found: green up to 0.5 mm."]

                delegate: ChecklistItem {}
            }
            SectionLabel {
                text: "Then, once for all cameras"
                Layout.topMargin: Tokens.spaceSm
            }
            Repeater {
                model: ["Press \"Refine all cameras\": poses, lenses and the actual board size are fitted to the points of all cameras together.", "Each camera gets its error on wires the fit did not see: green up to 0.5 mm. Refine again after detecting any board again."]

                delegate: ChecklistItem {}
            }
        }
    }
}
