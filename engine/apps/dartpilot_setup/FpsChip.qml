import QtQuick

// A camera's frame rate, or why there is none; the tone comes from the view's fpsQuality.
Chip {
    id: chip

    required property var stream
    // False while the camera is switched off on purpose
    property bool live: true

    text: chip.stream.error !== "" ? "Error" : !chip.live ? "Off" : chip.stream.fps > 0 ? chip.stream.fps.toFixed(1) + " fps" : "Starting"
    tone: chip.stream.error === "" && !chip.live ? Tokens.textMuted : Tokens.qualityTone(chip.stream.fpsQuality)
    dot: true
}
