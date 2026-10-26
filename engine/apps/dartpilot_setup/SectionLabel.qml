import QtQuick
import QtQuick.Controls

// Small caps heading over a group of controls or a checklist
Label {
    font.pixelSize: Tokens.captionSize
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    color: Tokens.textMuted
}
