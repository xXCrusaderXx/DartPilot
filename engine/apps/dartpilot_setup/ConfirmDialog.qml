import QtQuick
import QtQuick.Controls

// Asks before a step that cannot be undone; Enter confirms, Esc cancels.
Dialog {
    id: dialog

    property string text
    property string confirmText: "OK"

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(parent.width - 2 * Tokens.spaceXl, 480)
    modal: true
    focus: true
    padding: Tokens.spaceXl

    background: Rectangle {
        radius: Tokens.radius
        color: Tokens.surface
        border.color: Tokens.border
    }

    Overlay.modal: Rectangle {
        color: Tokens.scrim
    }

    Label {
        width: parent.width
        text: dialog.text
        wrapMode: Text.WordWrap
        color: Tokens.text
    }

    footer: DialogButtonBox {
        background: null

        Button {
            text: "Cancel"
            flat: true
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }
        Button {
            text: dialog.confirmText
            highlighted: true
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
    }
}
