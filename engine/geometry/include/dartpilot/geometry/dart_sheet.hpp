#pragma once

#include <optional>
#include <string>
#include <vector>

#include <opencv2/core.hpp>

// Measuring a dart from a photo (#120): the dart lies on a printed A4 sheet with four ArUco markers in its corners,
// photographed from above with a phone. The markers give the sheet's plane in millimetres, so the dart is measured at
// about 10 px/mm, far finer than the board cameras see it: its length, and from its width along the axis the point,
// barrel, shaft and flight.
namespace dartpilot::geometry
{
// The sheet: A4 portrait, markers of DICT_4X4_50 with ids 40 to 43 (top left, top right, bottom right, bottom left)
struct DartSheet
{
    static constexpr double kWidth_mm = 210.0;
    static constexpr double kHeight_mm = 297.0;
    static constexpr double kMarker_mm = 30.0;
    static constexpr double kMargin_mm = 12.0;
    static constexpr int kFirstMarkerId = 40;
};

// The sheet as an image to print at 100 %, at the given resolution; empty without ArUco support
cv::Mat dartSheetImage (double px_per_mm = 300.0 / 25.4);

struct DartPhotoMeasure
{
    double total_mm = 0.0;
    double point_mm = 0.0;
    double barrel_mm = 0.0;
    double barrel_diameter_mm = 0.0;
    double shaft_mm = 0.0;
    double flight_mm = 0.0;
    // Width along the axis from the point, one value per mm
    std::vector<double> width_mm;
    // The dart on the sheet, turned so the point is on the left, for showing it
    cv::Mat image;
};

// Nothing, with the reason in why (sheet_not_found, dart_not_found), if the sheet or the dart cannot be found
std::optional<DartPhotoMeasure> measureDartPhoto (const cv::Mat& photo, std::string* why = nullptr);
}  // namespace dartpilot::geometry
