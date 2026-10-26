import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// One camera: live view, focus grid and V4L2 controls.
Card {
    id: pane

    required property var modelData
    required property int index
    // False while the page is hidden, so the camera is released
    property bool active: true

    readonly property color statusTone: view.error !== "" ? Tokens.bad : !running.checked ? Tokens.textMuted : view.fps >= 29 ? Tokens.good : Tokens.warning

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spaceMd

        CameraCardHeader {
            number: pane.index + 1
            usbPort: pane.modelData.usbPort

            Chip {
                text: view.error !== "" ? "Error" : !running.checked ? "Off" : view.fps > 0 ? view.fps.toFixed(1) + " fps" : "Starting"
                tone: pane.statusTone
                dot: true
            }
            Switch {
                id: running

                text: "Live"
                checked: true
                ToolTip.visible: hovered
                ToolTip.text: checked ? "Stop this camera" : "Start this camera"
            }
        }

        CameraView {
            id: view

            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            devicePath: pane.active && running.checked ? pane.modelData.path : ""
            focusEnabled: focusSwitch.checked
        }

        Label {
            visible: view.error !== ""
            Layout.fillWidth: true
            text: view.error
            color: Tokens.bad
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: Tokens.spaceLg
            rowSpacing: Tokens.spaceXs
            enabled: running.checked

            SectionLabel {
                text: "Exposure"
                Layout.columnSpan: 3
            }
            Switch {
                readonly property var ctl: view.controls.autoExposure

                text: "Automatic"
                enabled: ctl.available
                checked: ctl.value === 3
                onToggled: view.setControl("autoExposure", checked ? 3 : 1)
            }
            SpinBox {
                id: exposureBox

                readonly property var ctl: view.controls.exposure

                enabled: ctl.available && !ctl.inactive
                from: ctl.available ? ctl.minimum : 0
                to: ctl.available ? ctl.maximum : 0
                stepSize: 10
                editable: true
                value: ctl.available ? ctl.value : 0
                onValueModified: view.setControl("exposure", value)
            }
            Label {
                text: exposureBox.ctl.available ? (exposureBox.ctl.value / 10).toFixed(1) + " ms" : ""
                color: Tokens.textMuted
                Layout.fillWidth: true
            }
            Switch {
                readonly property var ctl: view.controls.dynamicFramerate

                Layout.columnSpan: 3
                text: "Keep 30 fps in dim light"
                enabled: ctl.available
                checked: ctl.value === 0
                onToggled: view.setControl("dynamicFramerate", checked ? 0 : 1)
            }

            SectionLabel {
                text: "White balance"
                Layout.columnSpan: 3
                Layout.topMargin: Tokens.spaceSm
            }
            Switch {
                readonly property var ctl: view.controls.autoWhiteBalance

                text: "Automatic"
                enabled: ctl.available
                checked: ctl.value === 1
                onToggled: view.setControl("autoWhiteBalance", checked ? 1 : 0)
            }
            SpinBox {
                readonly property var ctl: view.controls.whiteBalance

                enabled: ctl.available && !ctl.inactive
                from: ctl.available ? ctl.minimum : 0
                to: ctl.available ? ctl.maximum : 0
                stepSize: 100
                editable: true
                value: ctl.available ? ctl.value : 0
                onValueModified: view.setControl("whiteBalance", value)
            }
            Label {
                text: "Kelvin"
                color: Tokens.textMuted
                Layout.fillWidth: true
            }

            SectionLabel {
                text: "Focus"
                Layout.columnSpan: 3
                Layout.topMargin: Tokens.spaceSm
            }
            Switch {
                id: focusSwitch

                text: "Sharpness grid"
            }
            Button {
                text: "Reset peaks"
                flat: true
                enabled: focusSwitch.checked
                onClicked: view.resetPeaks()
            }
            Label {
                Layout.fillWidth: true
                text: focusSwitch.checked ? "Click a cell to follow it." : ""
                color: Tokens.textMuted
            }
        }
    }
}
