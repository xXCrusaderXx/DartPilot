import QtQuick
import QtQuick.Controls

// The calibration pattern full screen on a second display; a click or Esc closes it.
Window {
    id: patternWindow

    color: "white"
    title: "DartPilot calibration pattern"

    Image {
        anchors.fill: parent
        anchors.margins: 24
        fillMode: Image.PreserveAspectFit
        source: "image://charuco/pattern"
        sourceSize.width: patternWindow.width
        smooth: false
    }

    Label {
        id: closeHint

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: "Click or press Esc to close"
        color: "#777777"

        SequentialAnimation on opacity {
            running: patternWindow.visible

            PauseAnimation {
                duration: 2500
            }
            NumberAnimation {
                to: 0
                duration: 800
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
