import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Card for one step of a workflow, with a numbered badge; done turns the badge green.
Card {
    id: card

    property int step
    property string title
    property bool done: false
    default property alias content: body.data

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spaceMd

        RowLayout {
            spacing: Tokens.spaceMd

            Rectangle {
                implicitWidth: Tokens.chipHeight
                implicitHeight: Tokens.chipHeight
                radius: height / 2
                color: card.done ? Tokens.good : Tokens.tint(Tokens.accent, 0.18)

                Label {
                    anchors.centerIn: parent
                    text: card.done ? "✓" : card.step
                    font.pixelSize: Tokens.captionSize
                    font.weight: Font.Bold
                    color: card.done ? Tokens.background : Tokens.accent
                }
            }
            Label {
                text: card.title
                font.pixelSize: Tokens.headingSize
                font.weight: Font.DemiBold
            }
        }
        ColumnLayout {
            id: body

            Layout.fillWidth: true
            spacing: Tokens.spaceSm
        }
    }
}
