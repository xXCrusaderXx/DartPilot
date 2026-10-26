import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts

// Sidebar entry with an icon glyph, a title and a subtitle.
ItemDelegate {
    id: nav

    property string glyph
    property string subtitle
    property bool selected: false
    // done, todo, blocked or empty (nothing to finish), from SetupProgress
    property string progress: "empty"

    Layout.fillWidth: true
    implicitHeight: 60
    leftPadding: Tokens.spaceLg

    background: Rectangle {
        radius: Tokens.radiusSmall
        color: nav.selected ? Tokens.tint(Tokens.accent, Tokens.tintFill) : nav.hovered ? Tokens.surface : "transparent"
        // Tab moves through the pages; the entry with the focus must show it.
        border.width: nav.visualFocus ? 2 : 0
        border.color: Tokens.accent

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
            Layout.fillWidth: true
            spacing: Tokens.spaceXxs

            Label {
                Layout.fillWidth: true
                text: nav.text
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
                color: nav.selected ? Tokens.text : Tokens.textMuted
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: nav.subtitle
                font.pixelSize: Tokens.captionSize
                color: Tokens.textMuted
                elide: Text.ElideRight
            }
        }
        // ✓ done, ● a step to take, – waits for an earlier step; shape as well as colour tells them apart
        Label {
            visible: nav.progress !== "empty"
            text: nav.progress === "done" ? "✓" : nav.progress === "todo" ? "●" : "–"
            color: nav.progress === "done" ? Tokens.good : nav.progress === "todo" ? Tokens.warning : Tokens.textMuted
            font.pixelSize: Tokens.bodySize
            font.weight: Font.Bold
            Accessible.name: nav.progress === "done" ? "Done" : nav.progress === "todo" ? "To do" : "Waits for an earlier step"
        }
    }
}
