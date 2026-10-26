#pragma once

#include <optional>
#include <string_view>
#include <vector>

#include <opencv2/core.hpp>

#include "dartpilot/tip_candidates/dart_observation.hpp"

// Tip candidates per camera: pixel position, 2x2 covariance, confidence and shaft line.
namespace dartpilot::tip_candidates
{
// Module name, used by the CLI and the smoke test
std::string_view moduleName ();

// The baseline tip (#18): the pixel of an 8-bit mask that lies furthest in direction, ties broken by the first in row
// order. Nothing for an empty mask.
std::optional<cv::Point2f> extremePoint (const cv::Mat& mask, const cv::Point2f& direction);

// Where a candidate comes from (#26, technical plan 5.2): an end of the axis as observeDart refines it, the outermost
// pixel of the object along its axis, or an end of the object's skeleton
enum class CandidateSource
{
    AxisEnd,
    ContourEnd,
    SkeletonEnd,
};

// axis_end, contour_end, skeleton_end
const char* sourceName (CandidateSource source);

struct TipCandidate
{
    cv::Point2f pixel_px;
    CandidateSource source = CandidateSource::AxisEnd;
    // How uncertain the position is (#28): the spread of all candidates at the same end of the dart, plus the
    // scatter of the axis across its direction, never less than 0.5 px each way, scaled to match measured errors
    cv::Matx22f covariance_px2 = cv::Matx22f::eye();
    // 0 to 1, falling with the size of that uncertainty: 1 where the generators agree to a pixel
    float confidence = 1.0f;

    bool operator==(const TipCandidate&) const = default;
};

// Several places where one camera's view of a dart may have its tip: from each generator one candidate at each end of
// the object's axis, none within border_px of the image border, where the image cuts the object. Which one is the tip
// is left to the geometry. Each candidate states its uncertainty and confidence (#28). Deterministic; empty for an
// observation without an axis.
std::vector<TipCandidate> tipCandidates (const DartObservation& observation, int border_px = 5);
}  // namespace dartpilot::tip_candidates
