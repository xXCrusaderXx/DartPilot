#pragma once

#include <array>
#include <cstddef>
#include <vector>

#include "dartpilot/scoring/score.hpp"

// The fields an uncertain board point may be in (#126): its normal distribution split along the board's wires.
namespace dartpilot::scoring
{
struct FieldCandidate
{
    // The most likely point of the distribution within this field
    double x_mm = 0.0;
    double y_mm = 0.0;
    Score score;
    double probability = 0.0;
};

// The fields of a point at (x_mm, y_mm) with covariance (xx, xy, yy in mm²), most likely first. Fields with the same
// label (the inner and outer single of a sector) count as one. Fields below min_probability are left out, at most
// max_candidates are returned. Empty for a covariance that is not positive definite. Deterministic: the distribution is
// evaluated on a fixed grid of whitened offsets out to 4 sigma.
std::vector<FieldCandidate> fieldCandidates (double x_mm, double y_mm, const std::array<double, 3>& covariance_mm2,
                                             const BoardGeometry& geometry = {}, double min_probability = 0.05, std::size_t max_candidates = 3);
}  // namespace dartpilot::scoring
