import QtQuick
import QtQuick.Controls.Material

// Rounded surface that groups related content.
Pane {
    padding: Tokens.spacing

    background: Rectangle {
        radius: Tokens.radius
        color: Tokens.surface
        border.color: Tokens.border
    }
}
