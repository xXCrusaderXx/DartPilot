#pragma once

#include <array>
#include <string>

// Board point in mm to sector and ring, in the board coordinates of docs/board-coordinates.md.
namespace dartpilot::scoring
{
// Sector numbers clockwise from the top (the middle of sector 20 is the +y axis)
constexpr std::array<int, 20> kSectorsClockwiseFromTop = {20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5};

// Ring boundaries and wire rotation of one board. The defaults are the nominal tournament dimensions;
// a measured board model replaces them.
struct BoardGeometry
{
    double bull_radius_mm = 6.35;
    double outer_bull_radius_mm = 15.9;
    double triple_inner_radius_mm = 99.0;
    double triple_outer_radius_mm = 107.0;
    double double_inner_radius_mm = 162.0;
    double double_outer_radius_mm = 170.0;
    // Counter-clockwise rotation of the radial wires from their nominal angles 9 + k * 18 degrees
    double wire_rotation_deg = 0.0;

    // Radii are positive and strictly increasing, and the rotation is finite
    bool isValid () const;
};

enum class Ring
{
    InnerBull,
    OuterBull,
    InnerSingle,
    Triple,
    OuterSingle,
    Double,
    Miss,
};

struct Score
{
    Ring ring = Ring::Miss;
    // 1 to 20; 0 for the bulls and a miss
    int sector = 0;
    // 0 for a miss
    int multiplier = 0;
    int points = 0;
    // Distance to the nearest ring boundary
    double ring_boundary_distance_mm = 0.0;
    // Distance to the nearest radial wire, measured perpendicular to it; infinite where there are no radial wires
    // (inside the outer bull and outside the double ring)
    double sector_boundary_distance_mm = 0.0;
    // Smaller of the two: how far the point may move before its score can change
    double boundary_distance_mm = 0.0;
};

// Deterministic: the same point and geometry always give the same score. A point exactly on a ring boundary belongs to
// the region further out, a point exactly on a radial wire to the sector counter-clockwise from it.
Score score (double x_mm, double y_mm, const BoardGeometry& geometry = {});

// "T20", "D16", "S5", "25", "50" or "miss"
std::string label (const Score& score);
}  // namespace dartpilot::scoring
