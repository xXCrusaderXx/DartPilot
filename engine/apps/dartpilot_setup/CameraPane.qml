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

    // Bumped whenever a control changes, so every control re-reads its state
    property int revision: 0
    readonly property bool streaming: running.checked && view.error === "" && view.fps > 0
    readonly property color statusTone: view.error !== "" ? Tokens.bad : !running.checked ? Tokens.textMuted : view.fps >= 29 ? Tokens.good : Tokens.warning

    // revision is passed in only so that bindings re-evaluate when it changes
    function control(name, revision) {
        return view.controlState(name);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            spacing: 10

            Label {
                text: "Camera " + (pane.index + 1)
                font.pixelSize: Tokens.headingSize
                font.weight: Font.Bold
            }
            Chip {
                text: "USB " + pane.modelData.usbPort
            }
            Item {
                Layout.fillWidth: true
            }
            Chip {
                text: view.error !== "" ? "Error" : !running.checked ? "Off" : view.fps > 0 ? view.fps.toFixed(1) + " fps" : "Starting"
                tone: pane.statusTone
                dot: true
            }
            Switch {
                id: running

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
            onControlsChanged: pane.revision++
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
            columnSpacing: 16
            rowSpacing: 4
            enabled: running.checked

            Label {
                text: "EXPOSURE"
                font.pixelSize: Tokens.captionSize
                font.weight: Font.DemiBold
                color: Tokens.textMuted
                Layout.columnSpan: 3
            }
            Switch {
                readonly property var ctl: pane.control("autoExposure", pane.revision)

                text: "Automatic"
                enabled: ctl.available
                checked: ctl.value === 3
                onToggled: view.setControl("autoExposure", checked ? 3 : 1)
            }
            SpinBox {
                id: exposureBox

                readonly property var ctl: pane.control("exposure", pane.revision)

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
                readonly property var ctl: pane.control("dynamicFramerate", pane.revision)

                Layout.columnSpan: 3
                text: "Keep 30 fps in dim light"
                enabled: ctl.available
                checked: ctl.value === 0
                onToggled: view.setControl("dynamicFramerate", checked ? 0 : 1)
            }

            Label {
                text: "WHITE BALANCE"
                font.pixelSize: Tokens.captionSize
                font.weight: Font.DemiBold
                color: Tokens.textMuted
                Layout.columnSpan: 3
                Layout.topMargin: 8
            }
            Switch {
                readonly property var ctl: pane.control("autoWhiteBalance", pane.revision)

                text: "Automatic"
                enabled: ctl.available
                checked: ctl.value === 1
                onToggled: view.setControl("autoWhiteBalance", checked ? 1 : 0)
            }
            SpinBox {
                readonly property var ctl: pane.control("whiteBalance", pane.revision)

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

            Label {
                text: "FOCUS"
                font.pixelSize: Tokens.captionSize
                font.weight: Font.DemiBold
                color: Tokens.textMuted
                Layout.columnSpan: 3
                Layout.topMargin: 8
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
