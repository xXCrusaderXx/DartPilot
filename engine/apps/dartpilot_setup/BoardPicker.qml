import QtQuick
import DartPilotSetup

// The nominal board, drawn from the front. A tap reports its board point in mm (x right, y up from the centre);
// marks show darts at their board points.
Item {
    id: picker

    // Each: xMm, yMm, colour, selected
    property var marks: []
    readonly property real radiusMm: 200

    signal picked(real xMm, real yMm)

    implicitHeight: width

    function toItem(xMm, yMm) {
        const s = Math.min(width, height) / (2 * radiusMm);
        return Qt.point(width / 2 + xMm * s, height / 2 - yMm * s);
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const s = Math.min(width, height) / (2 * picker.radiusMm);
            const cx = width / 2, cy = height / 2;
            const order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
            const ring = (outer, inner, light, dark) => {
                for (let i = 0; i < 20; ++i) {
                    const a0 = (-90 - 9 + 18 * i) * Math.PI / 180, a1 = a0 + 18 * Math.PI / 180;
                    ctx.beginPath();
                    ctx.arc(cx, cy, outer * s, a0, a1);
                    ctx.arc(cx, cy, inner * s, a1, a0, true);
                    ctx.closePath();
                    ctx.fillStyle = i % 2 === 0 ? dark : light;
                    ctx.fill();
                }
            };
            ctx.fillStyle = Tokens.surface;
            ctx.fillRect(0, 0, width, height);
            ring(170, 162, Tokens.boardGreen, Tokens.boardRed);
            ring(162, 107, Tokens.boardLight, Tokens.boardDark);
            ring(107, 99, Tokens.boardGreen, Tokens.boardRed);
            ring(99, 15.9, Tokens.boardLight, Tokens.boardDark);
            ctx.beginPath();
            ctx.arc(cx, cy, 15.9 * s, 0, 2 * Math.PI);
            ctx.fillStyle = Tokens.boardGreen;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx, cy, 6.35 * s, 0, 2 * Math.PI);
            ctx.fillStyle = Tokens.boardRed;
            ctx.fill();
            ctx.fillStyle = Tokens.text;
            ctx.font = Math.round(13 * s * 1.4) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (let i = 0; i < 20; ++i) {
                const a = (-90 + 18 * i) * Math.PI / 180;
                ctx.fillText(String(order[i]), cx + Math.cos(a) * 185 * s, cy + Math.sin(a) * 185 * s);
            }
        }
    }

    Repeater {
        model: picker.marks

        // Shape as well as colour, so the outcomes stay apart without telling red from green
        delegate: Item {
            id: mark

            required property var modelData
            readonly property point at: picker.toItem(modelData.xMm, modelData.yMm)
            readonly property string shape: modelData.shape || "dot"

            x: at.x - width / 2
            y: at.y - height / 2
            width: modelData.selected ? 18 : 13
            height: width

            Rectangle {
                visible: mark.shape !== "cross"
                anchors.fill: parent
                radius: mark.shape === "square" ? 2 : width / 2
                color: mark.shape === "ring" ? "transparent" : mark.modelData.colour
                border.color: mark.shape === "ring" ? mark.modelData.colour : mark.modelData.selected ? Tokens.text : Tokens.background
                border.width: mark.shape === "ring" ? 3 : 2
            }
            Repeater {
                model: mark.shape === "cross" ? [45, -45] : []

                delegate: Rectangle {
                    required property int modelData

                    anchors.centerIn: parent
                    width: mark.width * 1.2
                    height: 3
                    radius: 1.5
                    rotation: modelData
                    color: mark.modelData.colour
                    border.color: mark.modelData.selected ? Tokens.text : "transparent"
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        onClicked: mouse => {
            const s = Math.min(picker.width, picker.height) / (2 * picker.radiusMm);
            picker.picked((mouse.x - picker.width / 2) / s, (picker.height / 2 - mouse.y) / s);
        }
    }
}
