import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DartPilotSetup

// One camera: live view, focus grid and V4L2 controls.
Frame {
    id: pane

    required property var modelData
    required property int index

    // Bumped whenever a control changes, so every control re-reads its state
    property int revision: 0

    // revision is passed in only so that bindings re-evaluate when it changes
    function control(name, revision) {
        return view.controlState(name);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Switch {
                id: running

                checked: true
            }
            Label {
                text: "Camera " + (pane.index + 1) + "  ·  USB port " + pane.modelData.usbPort
                font.bold: true
            }
            Item {
                Layout.fillWidth: true
            }
            Label {
                text: view.error !== "" ? view.error : running.checked ? view.fps.toFixed(1) + " fps" : "off"
                color: view.error !== "" || (running.checked && view.fps > 0 && view.fps < 29) ? "#e05050" : palette.windowText
            }
        }

        CameraView {
            id: view

            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            devicePath: running.checked ? pane.modelData.path : ""
            focusEnabled: focusSwitch.checked
            onControlsChanged: pane.revision++
        }

        GridLayout {
            columns: 4
            columnSpacing: 12
            enabled: running.checked

            CheckBox {
                readonly property var ctl: pane.control("autoExposure", pane.revision)

                text: "Auto exposure"
                enabled: ctl.available
                checked: ctl.value === 3
                onToggled: view.setControl("autoExposure", checked ? 3 : 1)
            }
            Label {
                text: "Exposure (100 µs)"
            }
            SpinBox {
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
                readonly property var ctl: pane.control("exposure", pane.revision)

                text: ctl.available ? "= " + (ctl.value / 10).toFixed(1) + " ms" : ""
                opacity: 0.7
            }

            CheckBox {
                readonly property var ctl: pane.control("dynamicFramerate", pane.revision)

                text: "Dynamic frame rate"
                enabled: ctl.available
                checked: ctl.value === 1
                onToggled: view.setControl("dynamicFramerate", checked ? 1 : 0)
            }
            Label {
                Layout.columnSpan: 3
                text: "Off keeps 30 fps; on, the camera lowers the frame rate in dim light."
                opacity: 0.7
            }

            CheckBox {
                readonly property var ctl: pane.control("autoWhiteBalance", pane.revision)

                text: "Auto white balance"
                enabled: ctl.available
                checked: ctl.value === 1
                onToggled: view.setControl("autoWhiteBalance", checked ? 1 : 0)
            }
            Label {
                text: "White balance (K)"
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
            Item {
                Layout.fillWidth: true
            }

            Switch {
                id: focusSwitch

                text: "Focus grid"
            }
            Button {
                text: "Reset peaks"
                enabled: focusSwitch.checked
                onClicked: view.resetPeaks()
            }
            Label {
                Layout.columnSpan: 2
                text: focusSwitch.checked ? "Click a cell to select it. Fix the exposure while focusing." : ""
                opacity: 0.7
            }
        }
    }
}
