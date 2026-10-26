import QtQuick
import QtQuick.Controls

// Frame of the guide dialogs: a large modal card with its title and a "Got it" button.
Dialog {
    id: dialog

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 80, 1100)
    modal: true
    padding: Tokens.spaceXl

    background: Rectangle {
        radius: Tokens.radius
        color: Tokens.surface
        border.color: Tokens.border
    }

    header: Label {
        text: dialog.title
        padding: Tokens.spaceXl
        bottomPadding: Tokens.spaceSm
        font.pixelSize: Tokens.titleSize
        font.weight: Font.Bold
        color: Tokens.text
    }

    Overlay.modal: Rectangle {
        color: Tokens.scrim
    }

    footer: DialogButtonBox {
        background: null

        Button {
            text: "Got it"
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }
}
