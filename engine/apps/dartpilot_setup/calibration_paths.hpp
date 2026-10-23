#pragma once

#include <QStandardPaths>
#include <QString>

#include "dartpilot/geometry/charuco.hpp"

namespace dartpilot::setup
{
// Calibrations are stored per user, outside the repository: ~/.local/share/dartpilot/calibration on Linux.
inline QString calibrationDirectory () { return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/dartpilot/calibration"; }

// The pattern image in the repository, for opening it on a phone or tablet
inline QString patternDownloadUrl ()
{
    return "https://raw.githubusercontent.com/xXCrusaderXx/DartPilot/dev/docs/calibration/" +
           QString::fromStdString(geometry::CharucoTarget{}.imageFileName());
}

// A calibration belongs to the USB port, because all reference cameras report the same serial number.
inline QString intrinsicsPath (const QString& usb_port) { return calibrationDirectory() + "/intrinsics-usb-" + usb_port + ".yml"; }
}  // namespace dartpilot::setup
