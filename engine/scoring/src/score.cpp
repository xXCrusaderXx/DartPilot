#include "dartpilot/scoring/score.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numbers>

namespace dartpilot::scoring
{
namespace
{
constexpr double kSectorWidth_deg = 18.0;
constexpr double kHalfSectorWidth_deg = kSectorWidth_deg / 2.0;

double degrees (double radians) { return radians * 180.0 / std::numbers::pi; }

double radians (double degrees) { return degrees * std::numbers::pi / 180.0; }

// Angle in [0, 360)
double normalised (double angle_deg)
{
    const double wrapped = std::fmod(angle_deg, 360.0);
    return wrapped < 0.0 ? wrapped + 360.0 : wrapped;
}
}  // namespace

bool BoardGeometry::isValid () const
{
    const std::array<double, 6> radii = {bull_radius_mm,         outer_bull_radius_mm,   triple_inner_radius_mm,
                                         triple_outer_radius_mm, double_inner_radius_mm, double_outer_radius_mm};
    if(!(radii.front() > 0.0) || !std::isfinite(wire_rotation_deg))
    {
        return false;
    }
    return std::adjacent_find(radii.begin(), radii.end(), [] (double inner, double outer) { return !(inner < outer); }) == radii.end() &&
           std::isfinite(radii.back());
}

Score score (double x_mm, double y_mm, const BoardGeometry& geometry)
{
    Score result;
    const double r_mm = std::hypot(x_mm, y_mm);
    const std::array<double, 6> boundaries = {geometry.bull_radius_mm,         geometry.outer_bull_radius_mm,   geometry.triple_inner_radius_mm,
                                              geometry.triple_outer_radius_mm, geometry.double_inner_radius_mm, geometry.double_outer_radius_mm};

    // Half-open rings [inner, outer): a point on a boundary counts as further out.
    const auto ring_index = static_cast<int>(std::upper_bound(boundaries.begin(), boundaries.end(), r_mm) - boundaries.begin());
    constexpr std::array<Ring, 7> kRings = {Ring::InnerBull,   Ring::OuterBull, Ring::InnerSingle, Ring::Triple,
                                            Ring::OuterSingle, Ring::Double,    Ring::Miss};
    result.ring = kRings[ring_index];

    result.ring_boundary_distance_mm = std::numeric_limits<double>::infinity();
    for(const double boundary : boundaries)
    {
        result.ring_boundary_distance_mm = std::min(result.ring_boundary_distance_mm, std::abs(r_mm - boundary));
    }

    // Angle relative to the wires, so that sector 6 spans [-9, 9) degrees and each next sector counter-clockwise
    // starts where the previous one ends.
    const double phi_deg = normalised(degrees(std::atan2(y_mm, x_mm)) - geometry.wire_rotation_deg);
    const double from_boundary_deg = normalised(phi_deg + kHalfSectorWidth_deg);
    const auto counter_clockwise_index = std::min(static_cast<int>(from_boundary_deg / kSectorWidth_deg), 19);
    // The middle of sector 6 (index 5 clockwise from the top) lies at 0 degrees.
    const int clockwise_index = ((5 - counter_clockwise_index) % 20 + 20) % 20;
    const int sector = kSectorsClockwiseFromTop[clockwise_index];

    const bool has_radial_wires = result.ring != Ring::InnerBull && result.ring != Ring::OuterBull && result.ring != Ring::Miss;
    if(has_radial_wires)
    {
        const double into_sector_deg = from_boundary_deg - counter_clockwise_index * kSectorWidth_deg;
        const double to_wire_deg = std::min(into_sector_deg, kSectorWidth_deg - into_sector_deg);
        result.sector_boundary_distance_mm = r_mm * std::sin(radians(to_wire_deg));
    }
    else
    {
        result.sector_boundary_distance_mm = std::numeric_limits<double>::infinity();
    }
    result.boundary_distance_mm = std::min(result.ring_boundary_distance_mm, result.sector_boundary_distance_mm);

    switch(result.ring)
    {
        case Ring::InnerBull:
            result.multiplier = 2;
            result.points = 50;
            break;
        case Ring::OuterBull:
            result.multiplier = 1;
            result.points = 25;
            break;
        case Ring::InnerSingle:
        case Ring::OuterSingle:
            result.sector = sector;
            result.multiplier = 1;
            break;
        case Ring::Triple:
            result.sector = sector;
            result.multiplier = 3;
            break;
        case Ring::Double:
            result.sector = sector;
            result.multiplier = 2;
            break;
        case Ring::Miss:
            break;
    }
    if(result.sector != 0)
    {
        result.points = result.sector * result.multiplier;
    }
    return result;
}

std::string label (const Score& score)
{
    switch(score.ring)
    {
        case Ring::InnerBull:
            return "50";
        case Ring::OuterBull:
            return "25";
        case Ring::InnerSingle:
        case Ring::OuterSingle:
            return "S" + std::to_string(score.sector);
        case Ring::Triple:
            return "T" + std::to_string(score.sector);
        case Ring::Double:
            return "D" + std::to_string(score.sector);
        case Ring::Miss:
            break;
    }
    return "miss";
}
}  // namespace dartpilot::scoring
