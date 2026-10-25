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

// When a board counts as occupied (checkBoard)
struct BoardCheckSettings
{
    // Without a reference: a board whose wire crossings are further than this from the calibration is partly hidden
    // (unhidden boards check within about 1 mm under the light they were calibrated in, #92).
    double hidden_board_mm = 2.5;
    // An object found against the reference is confirmed only if it still stands out when every pixel may match the
    // reference anywhere within edge_tolerance_px: a camera that warmed up since the reference was stored zooms and
    // softens its image a little, which leaves traces along every wire and number, but a dart is far wider than that.
    // It needs min_confirmed_px pixels that differ by more than confirm_level in some colour channel.
    int edge_tolerance_px = 2;
    double confirm_level = 30.0;
    int min_confirmed_px = 150;
};

// One camera, on a still, averaged image (8-bit or float BGR):
// - with an empty-board reference of this camera, the board is occupied if an object stands out from the reference
//   (tip_candidates::observeDart), else empty;
// - without one, the board is occupied if its wires cannot be found where the calibration puts them (darts and hands
//   hide them), else unknown, since a dart in a field may leave every wire visible.
// reference and calibration may be null.
BoardCheck checkBoard (const cv::Mat& image, const cv::Mat* reference, const RefinedCamera* calibration, const BoardModel& board,
                       const BoardCheckSettings& settings = {});

// The empty-board reference of a camera is a PNG next to its calibration, empty-usb-<port>.png.
std::string emptyReferenceFileName (std::string_view usb_port);
bool saveEmptyReference (const std::string& path, const cv::Mat& image);
// Empty if the file is missing or unreadable
cv::Mat loadEmptyReference (const std::string& path);
}  // namespace dartpilot::geometry
