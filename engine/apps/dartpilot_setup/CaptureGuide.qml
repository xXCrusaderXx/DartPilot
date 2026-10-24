pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Animated illustration of a good capture: a tablet with the pattern moves through the camera image,
// tilts, comes closer and goes further, and each view is captured while it is held still.
ColumnLayout {
    id: guide

    property bool running: visible

    // Tablet centre in the image (0..1), tilt in degrees, size relative to the default, covered 3x3 zone
    readonly property var poses: [
        {
            x: 0.5,
            y: 0.5,
            yaw: 0,
            pitch: 0,
            scale: 1.0,
            zone: 4,
            caption: "Start in the centre with the whole pattern visible."
        },
        {
            x: 0.24,
            y: 0.27,
            yaw: 0,
            pitch: 0,
            scale: 0.85,
            zone: 0,
            caption: "Cover the corners: the lens distorts most at the edges."
        },
        {
            x: 0.76,
            y: 0.27,
            yaw: 0,
            pitch: 0,
            scale: 0.85,
            zone: 2,
            caption: "Cover the corners: the lens distorts most at the edges."
        },
        {
            x: 0.76,
            y: 0.73,
            yaw: 0,
            pitch: 0,
            scale: 0.85,
            zone: 8,
            caption: "Cover the corners: the lens distorts most at the edges."
        },
        {
            x: 0.24,
            y: 0.73,
            yaw: 0,
            pitch: 0,
            scale: 0.85,
            zone: 6,
            caption: "Cover the corners: the lens distorts most at the edges."
        },
        {
            x: 0.26,
            y: 0.5,
            yaw: 40,
            pitch: 0,
            scale: 0.95,
            zone: 3,
            caption: "Tilt the pattern by 30 to 45 degrees to the left and right ..."
        },
        {
            x: 0.74,
            y: 0.5,
            yaw: -40,
            pitch: 0,
            scale: 0.95,
            zone: 5,
            caption: "Tilt the pattern by 30 to 45 degrees to the left and right ..."
        },
        {
            x: 0.5,
            y: 0.28,
            yaw: 0,
            pitch: 35,
            scale: 0.95,
            zone: 1,
            caption: "... and up and down."
        },
        {
            x: 0.5,
            y: 0.72,
            yaw: 0,
            pitch: -35,
            scale: 0.95,
            zone: 7,
            caption: "... and up and down."
        },
        {
            x: 0.5,
            y: 0.5,
            yaw: 15,
            pitch: -10,
            scale: 1.45,
            zone: 4,
            caption: "Come closer until the pattern fills most of the image ..."
        },
        {
            x: 0.5,
            y: 0.5,
            yaw: -15,
            pitch: 10,
            scale: 0.6,
            zone: 4,
            caption: "... and step back. Hold still at every pose: the view is captured."
        }
    ]
    property int step: 0
    property var covered: [false, false, false, false, false, false, false, false, false]
    readonly property var pose: poses[step]

    spacing: 10

    Timer {
        // Move for 700 ms, hold still, capture at 1500 ms, next pose at 2200 ms
        interval: 2200
        repeat: true
        running: guide.running
        onTriggered: {
            const next = (guide.step + 1) % guide.poses.length;
            if (next === 0)
                guide.covered = [false, false, false, false, false, false, false, false, false];
            guide.step = next;
            holdTimer.restart();
        }
    }
    Timer {
        id: holdTimer

        interval: 1500
        onTriggered: {
            const covered = guide.covered.slice();
            covered[guide.pose.zone] = true;
            guide.covered = covered;
            flash.restart();
        }
    }

    Rectangle {
        id: stage

        Layout.fillWidth: true
        Layout.preferredHeight: width * 9 / 16
        radius: 10
        color: "#0b0e12"
        border.color: Tokens.border
        clip: true

        Grid {
            anchors.fill: parent
            columns: 3

            Repeater {
                model: 9

                delegate: Rectangle {
                    required property int index

                    width: stage.width / 3
                    height: stage.height / 3
                    color: guide.covered[index] ? Qt.rgba(Tokens.good.r, Tokens.good.g, Tokens.good.b, 0.22) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Behavior on color {
                        ColorAnimation {
                            duration: 300
                        }
                    }
                }
            }
        }

        Rectangle {
            id: tablet

            readonly property real baseWidth: stage.width * 0.36

            width: baseWidth * guide.pose.scale
            height: width * 0.72
            x: stage.width * guide.pose.x - width / 2
            y: stage.height * guide.pose.y - height / 2
            radius: width * 0.05
            color: "#2b2f36"
            border.color: "#454b55"

            transform: [
                Rotation {
                    origin.x: tablet.width / 2
                    origin.y: tablet.height / 2
                    axis {
                        x: 0
                        y: 1
                        z: 0
                    }
                    angle: guide.pose.yaw

                    Behavior on angle {
                        NumberAnimation {
                            duration: 700
                            easing.type: Easing.InOutCubic
                        }
                    }
                },
                Rotation {
                    origin.x: tablet.width / 2
                    origin.y: tablet.height / 2
                    axis {
                        x: 1
                        y: 0
                        z: 0
                    }
                    angle: guide.pose.pitch

                    Behavior on angle {
                        NumberAnimation {
                            duration: 700
                            easing.type: Easing.InOutCubic
                        }
                    }
                }
            ]

            Behavior on x {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 700
                    easing.type: Easing.InOutCubic
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: parent.width * 0.04
                source: "image://charuco/pattern/tablet"
                sourceSize.width: 400
                fillMode: Image.PreserveAspectFit
            }
        }

        Rectangle {
            id: flashRect

            anchors.fill: parent
            color: "white"
            opacity: 0

            NumberAnimation on opacity {
                id: flash

                running: false
                from: 0.35
                to: 0
                duration: 350
            }
        }

        Chip {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            text: "Camera image"
            tone: Tokens.textMuted
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        text: guide.pose.caption
        wrapMode: Text.WordWrap
        color: Tokens.text
        font.pixelSize: Tokens.bodySize
    }

    Row {
        spacing: 6

        Repeater {
            model: guide.poses.length

            delegate: Rectangle {
                required property int index

                width: index === guide.step ? 18 : 6
                height: 6
                radius: 3
                color: index === guide.step ? Tokens.accent : Tokens.border

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
