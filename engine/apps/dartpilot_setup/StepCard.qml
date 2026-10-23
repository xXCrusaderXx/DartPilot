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
        spacing: 12

        RowLayout {
            spacing: 10

            Rectangle {
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: card.done ? Tokens.good : Qt.rgba(Tokens.accent.r, Tokens.accent.g, Tokens.accent.b, 0.18)

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
            spacing: 8
        }
    }
}
