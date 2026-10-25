#pragma once

#include <optional>
#include <string_view>

#include <opencv2/core.hpp>

// Tip candidates per camera: pixel position, 2x2 covariance, confidence and shaft line.
namespace dartpilot::tip_candidates
{
// Module name, used by the CLI and the smoke test
std::string_view moduleName ();

// The baseline tip (#18): the pixel of an 8-bit mask that lies furthest in direction, ties broken by the first in row
// order. Nothing for an empty mask.
std::optional<cv::Point2f> extremePoint (const cv::Mat& mask, const cv::Point2f& direction);
}  // namespace dartpilot::tip_candidates
