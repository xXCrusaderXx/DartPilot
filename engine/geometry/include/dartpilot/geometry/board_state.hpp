#pragma once

#include <optional>
#include <string>
#include <string_view>

#include <opencv2/core.hpp>

#include "dartpilot/geometry/board_refinement.hpp"

// Is the board empty? Checked before the engine takes its empty-board reference and before each turn (#121): a dart
// left in the board would become part of the reference, so it would be missed and the next dart near it misread.
namespace dartpilot::geometry
{
enum class BoardState
{
    Empty,
    Occupied,
    // Not decidable: no reference and nothing seen, or the camera is not calibrated
    Unknown,
};

std::string_view toString (BoardState state);

struct BoardCheck
{
    BoardState state = BoardState::Unknown;
    // Middle of the object seen, in pixels of the camera's full image, for marking it
    std::optional<cv::Point2d> image_point_px;
    // Why, in a sentence for logs and the user; empty when the board is empty
    std::string reason;
};

// One camera, on a still, averaged image (8-bit or float BGR):
// - with an empty-board reference of this camera, the board is occupied if an object stands out from the reference
//   (tip_candidates::observeDart), else empty;
// - without one, the board is occupied if its wires cannot be found where the calibration puts them (darts and hands
//   hide them), else unknown, since a dart in a field may leave every wire visible.
// reference and calibration may be null.
BoardCheck checkBoard (const cv::Mat& image, const cv::Mat* reference, const RefinedCamera* calibration, const BoardModel& board);

// The empty-board reference of a camera is a PNG next to its calibration, empty-usb-<port>.png.
std::string emptyReferenceFileName (std::string_view usb_port);
bool saveEmptyReference (const std::string& path, const cv::Mat& image);
// Empty if the file is missing or unreadable
cv::Mat loadEmptyReference (const std::string& path);
}  // namespace dartpilot::geometry
