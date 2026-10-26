import QtQuick
import QtQuick.Controls

// The calibration pattern full screen on a second display; a click or Esc closes it.
Window {
    id: patternWindow

    // tablet or phone
    property string target: "tablet"

    color: Tokens.paper
    title: "DartPilot calibration pattern"

    Image {
        id: pattern

        anchors.fill: parent
        anchors.margins: Tokens.spaceXl
        fillMode: Image.PreserveAspectFit
        source: "image://charuco/pattern/" + patternWindow.target
        // Rendered at the size it is shown: smooth: false must not resample the squares unevenly.
        sourceSize: Qt.size(pattern.width, pattern.height)
        smooth: false
    }

    Label {
        id: closeHint

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.spaceSm
        text: "Click or press Esc to close"
        color: Tokens.paperCaption

        SequentialAnimation on opacity {
            running: patternWindow.visible

            PauseAnimation {
                duration: 2500
            }
            // From full opacity each time, or the hint stays hidden on every later opening
            NumberAnimation {
                from: 1
                to: 0
                duration: 400
                easing.type: Easing.InQuad
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: patternWindow.close()
    }

    Shortcut {
        sequence: "Esc"
        onActivated: patternWindow.close()
    }
}
