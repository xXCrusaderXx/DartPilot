import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import DartPilotSetup

ApplicationWindow {
    id: window

    // Page shown at start; see --page in main.cpp
    property int initialPage: 0
    property int page: initialPage

    // The sidebar, a camera view and the step column need this much; the start size fits the screen.
    minimumWidth: 1180
    minimumHeight: 720
    width: Math.max(minimumWidth, Math.min(1600, Screen.desktopAvailableWidth - 80))
    height: Math.max(minimumHeight, Math.min(1000, Screen.desktopAvailableHeight - 80))
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

    // One refiner for the whole app: the extrinsic page runs it, the progress reads it.
    BoardRefiner {
        id: boardRefiner

        cameras: finder.cameras
    }

    SetupProgress {
        id: setupProgress

        cameras: finder.cameras
        refined: boardRefiner.hasResult
        refinementStale: boardRefiner.stale
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: Tokens.sidebarWidth
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
                anchors.margins: Tokens.spaceLg
                spacing: Tokens.spaceSm

                RowLayout {
                    Layout.bottomMargin: Tokens.spaceXl
                    Layout.topMargin: Tokens.spaceSm
                    spacing: Tokens.spaceMd

                    Image {
                        source: "icons/dartpilot.svg"
                        sourceSize.width: 40
                        sourceSize.height: 40
                    }
                    ColumnLayout {
                        spacing: 0

                        Label {
                            text: "DartPilot"
                            font.pixelSize: Tokens.brandSize
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
                    progress: setupProgress.states[0]
                    onClicked: window.page = 0
                }
                NavButton {
                    text: "Intrinsic calibration"
                    subtitle: "Lens and sensor, per camera"
                    glyph: "◎"
                    selected: window.page === 1
                    progress: setupProgress.states[1]
                    onClicked: window.page = 1
                }
                NavButton {
                    text: "Extrinsic calibration"
                    subtitle: "Camera poses to the board"
                    glyph: "⌖"
                    selected: window.page === 2
                    progress: setupProgress.states[2]
                    onClicked: window.page = 2
                }
                NavButton {
                    text: "Calibration check"
                    subtitle: "Has a camera moved?"
                    glyph: "◈"
                    selected: window.page === 3
                    progress: setupProgress.states[3]
                    onClicked: window.page = 3
                }
                NavButton {
                    text: "Pin check"
                    subtitle: "Do the cameras agree?"
                    glyph: "⊕"
                    selected: window.page === 4
                    progress: setupProgress.states[4]
                    onClicked: window.page = 4
                }
                NavButton {
                    text: "Validation"
                    subtitle: "Guided test with darts"
                    glyph: "✓"
                    selected: window.page === 5
                    progress: setupProgress.states[5]
                    onClicked: window.page = 5
                }
                NavButton {
                    text: "Detection test"
                    subtitle: "Throw, rate, tune"
                    glyph: "➶"
                    selected: window.page === 6
                    progress: setupProgress.states[6]
                    onClicked: window.page = 6
                }

                Item {
                    Layout.fillHeight: true
                }

                Card {
                    Layout.fillWidth: true
                    padding: Tokens.spaceMd

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Tokens.spaceSm

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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Tokens.spaceXl
            spacing: Tokens.spacing

            // Every page but the camera list needs a camera; without one, say so in one place.
            EmptyState {
                visible: finder.cameras.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "No camera found"
                detail: "Plug the cameras into their USB ports and keep each one on its port; the calibration belongs to the port. Then search again."
                action: "Search again"
                onTriggered: finder.refresh()
            }

            // A page that waits for an earlier step says which one, with the way there.
            HintBanner {
                visible: finder.cameras.length > 0 && setupProgress.states[window.page] === "blocked"
                tone: Tokens.warning
                text: setupProgress.blockers[window.page] ?? ""

                Button {
                    readonly property int target: setupProgress.blockerPages[window.page] ?? -1

                    visible: target >= 0
                    text: "Go to " + ["cameras", "intrinsic calibration", "extrinsic calibration"][Math.max(0, target)]
                    highlighted: true
                    onClicked: window.page = target
                }
            }

            // Only the visible page streams; the others release their cameras.
            StackLayout {
                visible: finder.cameras.length > 0
                Layout.fillWidth: true
                Layout.fillHeight: true
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
                    refiner: boardRefiner
                    onSaved: finder.refresh()
                }
                CheckPage {
                    active: window.page === 3
                    cameras: finder.cameras
                }
                PinCheckPage {
                    active: window.page === 4
                    cameras: finder.cameras
                }
                ValidationPage {
                    active: window.page === 5
                    cameras: finder.cameras
                }
                DetectionPage {
                    active: window.page === 6
                    cameras: finder.cameras
                }
            }
        }
    }
}
