import QtQuick

// A dartboard drawn from the nominal geometry: sectors, rings, optionally the detected wires and the sector numbers.
// Used by the extrinsic guide; no image asset.
Canvas {
    id: canvas

    // 0..1: how much of the detected circles and wires is drawn
    property real detection: 0
    // Sector numbers with 20 highlighted, as after the click
    property bool numbered: false

    readonly property var order: [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

    onDetectionChanged: requestPaint()
    onNumberedChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height / 2;
        const r = Math.min(width, height) / 2 * 0.78;
        const scale = r / 170.0;
        const rad = deg => deg * Math.PI / 180;
        // Sector i (clockwise from the top) spans -90 + 18 i +- 9 degrees on screen.
        for (let i = 0; i < 20; ++i) {
            const a0 = rad(-90 + 18 * i - 9), a1 = rad(-90 + 18 * i + 9);
            const darkSector = i % 2 === 0;
            const ring = darkSector ? Tokens.boardRed : Tokens.boardGreen;
            const single = darkSector ? Tokens.boardDark : Tokens.boardLight;
            const bands = [[170, 162, ring], [162, 107, single], [107, 99, ring], [99, 15.9, single]];
            for (const band of bands) {
                ctx.beginPath();
                ctx.arc(cx, cy, band[0] * scale, a0, a1);
                ctx.arc(cx, cy, band[1] * scale, a1, a0, true);
                ctx.closePath();
                ctx.fillStyle = band[2];
                ctx.fill();
            }
        }
        ctx.beginPath();
        ctx.arc(cx, cy, 15.9 * scale, 0, 2 * Math.PI);
        ctx.fillStyle = Tokens.boardGreen;
        ctx.fill();
        ctx.beginPath();
        ctx.arc(cx, cy, 6.35 * scale, 0, 2 * Math.PI);
        ctx.fillStyle = Tokens.boardRed;
        ctx.fill();

        // Detected circles and wires, drawn in as the detection progresses
        if (detection > 0) {
            ctx.strokeStyle = Tokens.accent;
            ctx.lineWidth = 2;
            for (const radius of [15.9, 103, 166]) {
                ctx.beginPath();
                ctx.arc(cx, cy, radius * scale, rad(-90), rad(-90 + 360 * detection));
                ctx.stroke();
            }
            const wires = Math.floor(20 * detection);
            for (let i = 0; i < wires; ++i) {
                const a = rad(-90 + 18 * i + 9);
                ctx.beginPath();
                ctx.moveTo(cx + Math.cos(a) * 15.9 * scale, cy + Math.sin(a) * 15.9 * scale);
                ctx.lineTo(cx + Math.cos(a) * 180 * scale, cy + Math.sin(a) * 180 * scale);
                ctx.stroke();
            }
        }

        // Sector numbers on the outer singles
        if (numbered) {
            ctx.font = "bold " + Math.round(11 * scale * 1.6) + "px sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            for (let i = 0; i < 20; ++i) {
                const a = rad(-90 + 18 * i);
                const x = cx + Math.cos(a) * 134 * scale, y = cy + Math.sin(a) * 134 * scale;
                const twenty = order[i] === 20;
                ctx.beginPath();
                ctx.arc(x, y, 12 * scale * 1.3, 0, 2 * Math.PI);
                ctx.fillStyle = twenty ? Tokens.warning : Tokens.tint(Tokens.background, 0.85);
                ctx.fill();
                ctx.fillStyle = twenty ? Tokens.background : Tokens.text;
                ctx.fillText(order[i], x, y);
            }
        }
    }
}
