#pragma once

#include <array>
#include <string>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"

// Known positions for the reference measurement of #14: a dart pushed by hand into a corner where a radial wire meets
// a ring wire, its point against both wires, or into the centre of the bull. Where its centre then lies follows from
// the measured board and the thickness of wire and point.
namespace dartpilot::fusion
{
// Distance of the point's centre from each wire it touches: half a wire (about 1.2 mm) and half a steel point (about
// 2.3 mm). The uncertainty of a target is about 0.5 mm, from the spread of these thicknesses and how the point sits.
inline constexpr double kCornerOffset_mm = 1.8;

struct ReferenceTarget
{
    cv::Point2d board_mm;
    // bull_centre or corner
    std::string kind;
    // The sector numbers on either side of the radial wire, in clockwise order; empty for the bull centre
    std::vector<int> wires;
    // The field the point sits in, e.g. D20, T6 or S20, and an English label of the whole target
    std::string field;
    std::string label;
};

// The ten targets in the order the user places them: the bull centre, four outer double corners, four inner treble
// corners and one corner at the outer bull, spread around the board.
std::vector<ReferenceTarget> referenceTargets (const geometry::BoardModel& board);
}  // namespace dartpilot::fusion
