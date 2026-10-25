#pragma once

#include <optional>
#include <vector>

#include "dartpilot/geometry/dart_location.hpp"

// The shape of a dart in the board, measured with the calibrated cameras (#120): its axis in 3D from the axis planes
// of the cameras that agree on its point, its length from the far end each camera sees, and its width along the axis
// from the object each camera found. From the width: the flight (the wide far part) and the barrel (the widest part
// near the point).
namespace dartpilot::geometry
{
struct DartShape
{
    // From the entry point to the far end of the flight
    double total_mm = 0.0;
    double flight_mm = 0.0;
    double barrel_mm = 0.0;
    double barrel_diameter_mm = 0.0;
    // From the entry point to where the barrel starts; the thin point is often too faint to be part of the object, so
    // this is the least certain value
    double point_mm = 0.0;
    // Width along the axis, one value per mm from the entry point, the largest any camera sees
    std::vector<double> width_mm;
    // Unit direction of the axis from the entry point outwards, in board coordinates
    cv::Vec3d direction;
    int cameras = 0;
};

// views as given to locateDart, location its result. Nothing if fewer than two used views cross at a usable angle, or
// no camera sees the far end of the dart.
std::optional<DartShape> measureDart (const std::vector<DartView>& views, const DartLocation& location);
}  // namespace dartpilot::geometry
