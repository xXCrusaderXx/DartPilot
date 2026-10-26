import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Sidebar entry with an icon glyph, a title and a subtitle.
ItemDelegate {
    id: nav

    property string glyph
    property string subtitle
    property bool selected: false

    Layout.fillWidth: true
    implicitHeight: 60
    leftPadding: Tokens.spaceLg

    background: Rectangle {
        radius: Tokens.radiusSmall
        color: nav.selected ? Tokens.tint(Tokens.accent, Tokens.tintFill) : nav.hovered ? Tokens.surface : "transparent"

        Rectangle {
            visible: nav.selected
            width: 3
            height: parent.height - 20
            radius: 2
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.accent
        }
    }

    contentItem: RowLayout {
        spacing: Tokens.spaceMd

        Label {
            text: nav.glyph
            font.pixelSize: Tokens.iconSize
            color: nav.selected ? Tokens.accent : Tokens.textMuted
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }
        ColumnLayout {
            spacing: Tokens.spaceXxs

            Label {
                text: nav.text
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
                color: nav.selected ? Tokens.text : Tokens.textMuted
            }
            Label {
                text: nav.subtitle
                font.pixelSize: Tokens.captionSize
                color: Tokens.textMuted
                opacity: 0.8
            }
        }
    }
}
