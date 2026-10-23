#pragma once

#include <opencv2/core.hpp>

// Focus measure for setting a manually focused lens.
namespace dartpilot::capture
{
// Gradient energy (Tenengrad) of an 8-bit grayscale image, divided by its squared mean intensity.
// Both scale with the square of the brightness, so the measure follows the focus, not the exposure.
// Returns 0 for an empty or black image.
double sharpness (const cv::Mat& gray);
}  // namespace dartpilot::capture
