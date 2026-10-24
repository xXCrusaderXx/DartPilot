#pragma once

#include <QStandardPaths>
#include <QString>

#include "dartpilot/geometry/calibration_store.hpp"
#include "dartpilot/geometry/charuco.hpp"

namespace dartpilot::setup
{
// Calibrations are stored per user, outside the repository: ~/.local/share/dartpilot/calibration on Linux.
inline QString calibrationDirectory () { return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/dartpilot/calibration"; }

// Reference capture mode of the setup GUI (docs/adr/0002); stored calibrations are checked against it.
constexpr int kReferenceWidth_px = 1280;
constexpr int kReferenceHeight_px = 720;
constexpr int kReferenceFps = 30;
inline const char* const kReferencePixelFormat = "MJPG 1280x720 30fps";
inline geometry::ReferenceMode referenceMode () { return {cv::Size(kReferenceWidth_px, kReferenceHeight_px), kReferencePixelFormat}; }

// The pattern image in the repository, for opening it on a phone or tablet
inline QString patternDownloadUrl (const geometry::CharucoTarget& target)
{
    return "https://raw.githubusercontent.com/xXCrusaderXx/DartPilot/dev/docs/calibration/" + QString::fromStdString(target.imageFileName());
}

// A calibration belongs to the USB port, because all reference cameras report the same serial number.
inline QString intrinsicsPath (const QString& usb_port)
{
    return calibrationDirectory() + "/" + QString::fromStdString(geometry::intrinsicsFileName(usb_port.toStdString()));
}

// Board plane (orientation and homography) of the camera on that USB port
inline QString boardPlanePath (const QString& usb_port)
{
    return calibrationDirectory() + "/" + QString::fromStdString(geometry::boardPlaneFileName(usb_port.toStdString()));
}

// Joint refinement of all cameras: poses, refined lenses and the measured board (#13)
inline QString extrinsicsPath () { return calibrationDirectory() + "/" + geometry::kExtrinsicsFileName; }
}  // namespace dartpilot::setup
