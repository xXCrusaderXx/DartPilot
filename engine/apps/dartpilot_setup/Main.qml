import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import DartPilotSetup

ApplicationWindow {
    id: window

    // Page shown at start: 0 cameras, 1 intrinsic, 2 extrinsic
    property int initialPage: 0
    property int page: initialPage

    width: 1600
    height: 1000
    visible: true
    title: "DartPilot Setup"
    color: Tokens.background

    Material.theme: Material.Dark
    Material.accent: Tokens.accent
    Material.primary: Tokens.accent
    Material.background: Tokens.background
    Material.foreground: Tokens.text

    CameraFinder {
        id: finder
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: Tokens.sidebar

            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Tokens.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                RowLayout {
                    Layout.bottomMargin: 24
                    Layout.topMargin: 8
                    spacing: 12

                    Image {
                        source: "icons/dartpilot.svg"
                        sourceSize.width: 40
                        sourceSize.height: 40
                    }
                    ColumnLayout {
                        spacing: 0

                        Label {
                            text: "DartPilot"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: Tokens.text
                        }
                        Label {
                            text: "Setup and diagnostics"
                            font.pixelSize: Tokens.captionSize
                            color: Tokens.textMuted
                        }
                    }
                }

                NavButton {
                    text: "Cameras"
                    subtitle: "Live view, exposure, focus"
                    glyph: "◉"
                    selected: window.page === 0
                    onClicked: window.page = 0
                }
                NavButton {
                    text: "Intrinsic calibration"
                    subtitle: "Lens and sensor, per camera"
                    glyph: "◎"
                    selected: window.page === 1
                    onClicked: window.page = 1
                }
                NavButton {
                    text: "Extrinsic calibration"
                    subtitle: "Camera poses to the board"
                    glyph: "⌖"
                    selected: window.page === 2
                    onClicked: window.page = 2
                }

                Item {
                    Layout.fillHeight: true
                }

                Card {
                    Layout.fillWidth: true
                    padding: 12

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Chip {
                            text: finder.cameras.length === 1 ? "1 camera connected" : finder.cameras.length + " cameras connected"
                            tone: finder.cameras.length > 0 ? Tokens.good : Tokens.bad
                            dot: true
                        }
                        Button {
                            Layout.fillWidth: true
                            text: "Search again"
                            flat: true
                            onClicked: finder.refresh()
                        }
                    }
                }
            }
        }

        // Only the visible page streams; the others release their cameras.
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            currentIndex: window.page

            CamerasPage {
                active: window.page === 0
                cameras: finder.cameras
            }
            IntrinsicPage {
                active: window.page === 1
                cameras: finder.cameras
                onSaved: finder.refresh()
            }
            ExtrinsicPage {
                active: window.page === 2
                cameras: finder.cameras
                onSaved: finder.refresh()
            }
        }
    }
}
