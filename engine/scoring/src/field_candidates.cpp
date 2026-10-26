#include "dartpilot/scoring/field_candidates.hpp"

#include <algorithm>
#include <cmath>
#include <map>
#include <string>

namespace dartpilot::scoring
{
namespace
{
constexpr double kGridReach_sigma = 4.0;
constexpr double kGridStep_sigma = 0.1;

struct Field
{
    double weight = 0.0;
    double best_weight = -1.0;
    FieldCandidate candidate;
};
}  // namespace

std::vector<FieldCandidate> fieldCandidates (double x_mm, double y_mm, const std::array<double, 3>& covariance_mm2, const BoardGeometry& geometry,
                                             double min_probability, std::size_t max_candidates)
{
    const auto [xx, xy, yy] = covariance_mm2;
    if(!(xx > 0.0) || !std::isfinite(xx) || !std::isfinite(xy) || !std::isfinite(yy))
    {
        return {};
    }
    // Cholesky factor L of the covariance: a point is the mean plus L times a whitened offset (u, v).
    const double l11 = std::sqrt(xx);
    const double l21 = xy / l11;
    const double rest = yy - l21 * l21;
    if(!(rest > 0.0))
    {
        return {};
    }
    const double l22 = std::sqrt(rest);

    std::map<std::string, Field> fields;
    double total = 0.0;
    const int steps = static_cast<int>(std::lround(kGridReach_sigma / kGridStep_sigma));
    for(int i = -steps; i <= steps; ++i)
    {
        for(int j = -steps; j <= steps; ++j)
        {
            const double u = i * kGridStep_sigma;
            const double v = j * kGridStep_sigma;
            // Equal cells in whitened space carry the same Jacobian, so the density alone weighs them.
            const double weight = std::exp(-0.5 * (u * u + v * v));
            const double px = x_mm + l11 * u;
            const double py = y_mm + l21 * u + l22 * v;
            const Score s = score(px, py, geometry);
            auto& field = fields[label(s)];
            field.weight += weight;
            total += weight;
            if(weight > field.best_weight)
            {
                field.best_weight = weight;
                field.candidate = {px, py, s, 0.0};
            }
        }
    }

    std::vector<FieldCandidate> candidates;
    for(auto& [name, field] : fields)
    {
        field.candidate.probability = field.weight / total;
        if(field.candidate.probability >= min_probability)
        {
            candidates.push_back(field.candidate);
        }
    }
    // Ties go by label, so the order never depends on the map's iteration alone.
    std::stable_sort(candidates.begin(), candidates.end(),
                     [] (const FieldCandidate& a, const FieldCandidate& b) { return a.probability > b.probability; });
    if(candidates.size() > max_candidates)
    {
        candidates.resize(max_candidates);
    }
    return candidates;
}
}  // namespace dartpilot::scoring
