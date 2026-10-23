#pragma once

#include <memory>
#include <optional>
#include <string>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/intrinsics.hpp"

// ChArUco calibration target, shown on a tablet or printed.
namespace dartpilot::geometry
{
struct CharucoTarget
{
    int squares_x = 10;
    int squares_y = 7;
    float marker_to_square = 0.7f;
    // cv::aruco::PredefinedDictionaryType; DICT_4X4_50 holds the 35 markers of a 10x7 board
    int dictionary = 0;

    int cornerCount () const { return (squares_x - 1) * (squares_y - 1); }
    // e.g. "charuco 10x7 DICT_4X4_50 marker 0.70"
    std::string describe () const;
    // e.g. "charuco-10x7-DICT_4X4_50-marker-0.70.png"
    std::string imageFileName () const;
    // Size of the pattern image that the setup GUI saves and docs/calibration ships: 2000 px wide, square cells
    cv::Size imageSize_px () const;

    // For a tablet, a second display or a print: the default
    static CharucoTarget tablet () { return {}; }
    // For a phone in landscape: about 2:1 like its screen, so the cells come out almost twice as large as with the
    // tablet target, with slightly larger markers in them; they stay readable from further away
    static CharucoTarget phone () { return {8, 4, 0.75f, 0}; }

    bool operator==(const CharucoTarget&) const = default;
};

// False when DartPilot was built with an OpenCV older than 4.7, which has no ChArUco detector.
bool charucoAvailable ();

class CharucoFinder
{
   public:
    explicit CharucoFinder (const CharucoTarget& target = {});
    ~CharucoFinder ();
    CharucoFinder (const CharucoFinder&) = delete;
    CharucoFinder& operator=(const CharucoFinder&) = delete;

    const CharucoTarget& target () const { return target_; }
    // Interpolated chessboard corners in an 8-bit grayscale image; nothing if fewer than six are found or OpenCV fails
    std::optional<CalibrationView> detect (const cv::Mat& gray) const;
    // Pattern image of the given size for display on a screen; empty without ChArUco support
    cv::Mat patternImage (const cv::Size& size_px) const;

   private:
    struct Impl;
    CharucoTarget target_;
    std::unique_ptr<Impl> impl_;
};
}  // namespace dartpilot::geometry
