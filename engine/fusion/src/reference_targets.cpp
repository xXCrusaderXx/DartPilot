#include "dartpilot/fusion/reference_targets.hpp"

#include <cmath>

namespace dartpilot::fusion
{
namespace
{
// Sectors clockwise from the top of the board
constexpr std::array<int, 20> kClockwise = {20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5};
// Half the width of the double and treble rings (8 mm), from the measured centre line to the wires
constexpr double kRingHalfWidth_mm = 4.0;
constexpr double kPi = 3.14159265358979323846;

enum class Ring
{
    DoubleOuter,
    TrebleInner,
    OuterBull,
};

// The corner at the wire after the clockwise sector index `wire` (between kClockwise[wire] and the next), on the side
// of `inside_sector` (either of the two), inside the field the ring wire bounds.
ReferenceTarget corner (const geometry::BoardModel& board, Ring ring, int wire, int inside_sector)
{
    const auto& r = board.radii_mm;
    double wire_mm = 0.0, radial = 0.0;
    std::string prefix;
    switch(ring)
    {
        case Ring::DoubleOuter:
            wire_mm = r[static_cast<int>(geometry::BoardCircle::DoubleCentre)] + kRingHalfWidth_mm;
            radial = -1.0;
            prefix = "D";
            break;
        case Ring::TrebleInner:
            wire_mm = r[static_cast<int>(geometry::BoardCircle::TripleCentre)] - kRingHalfWidth_mm;
            radial = -1.0;
            prefix = "S";
            break;
        case Ring::OuterBull:
            wire_mm = r[static_cast<int>(geometry::BoardCircle::OuterBull)];
            radial = 1.0;
            prefix = "S";
            break;
    }
    const int a = kClockwise[static_cast<std::size_t>(wire)], b = kClockwise[static_cast<std::size_t>((wire + 1) % 20)];
    // The wire lies 9 degrees clockwise beyond the centre of its first sector; angles clockwise from the top
    const double wire_angle = (18.0 * wire + 9.0) * kPi / 180.0;
    const double side = inside_sector == a ? -1.0 : 1.0;
    const double radius = wire_mm + radial * kCornerOffset_mm;
    const double angle = wire_angle + side * kCornerOffset_mm / radius;
    ReferenceTarget target;
    target.board_mm = cv::Point2d(radius * std::sin(angle), radius * std::cos(angle));
    target.kind = "corner";
    target.wires = {a, b};
    target.field = prefix + std::to_string(inside_sector);
    const char* where = ring == Ring::DoubleOuter ? "outer double wire" : ring == Ring::TrebleInner ? "inner treble wire" : "outer bull wire";
    target.label = target.field + ", corner of the " + std::to_string(a) + "/" + std::to_string(b) + " wire and the " + where;
    return target;
}
}  // namespace

std::vector<ReferenceTarget> referenceTargets (const geometry::BoardModel& board)
{
    std::vector<ReferenceTarget> targets;
    ReferenceTarget bull;
    bull.kind = "bull_centre";
    bull.field = "Bull";
    bull.label = "Centre of the bull";
    targets.push_back(bull);
    // The wires 20/1, 6/13, 3/19 and 11/14, a quarter turn apart
    const std::array<std::pair<int, int>, 4> wires = {{{0, 20}, {4, 6}, {10, 3}, {15, 11}}};
    for(const auto& [wire, sector] : wires)
    {
        targets.push_back(corner(board, Ring::DoubleOuter, wire, sector));
    }
    for(const auto& [wire, sector] : wires)
    {
        targets.push_back(corner(board, Ring::TrebleInner, wire, sector));
    }
    targets.push_back(corner(board, Ring::OuterBull, 0, 20));
    return targets;
}
}  // namespace dartpilot::fusion
