#pragma once

#include <optional>
#include <vector>

#include <opencv2/core.hpp>

// What one camera sees of a dart or a pin: the object against an image of the empty board, the centre line of its
// narrow part and its visible ends. Where it enters the board follows from several cameras (geometry::locateDart).
namespace dartpilot::tip_candidates
{
// How a dart is found in the difference between an image and the board before it (observeDart). Defaults measured on
// the reference setup, cameras about 45 cm from the board.
struct ObservationSettings
{
    // An object needs this many clearly changed pixels; a dart at the far side of the board still has several hundred.
    int min_strong_pixels = 150;
    // Separate parts of one dart: how far apart they may be, how clearly a part must stand out to be added, and how
    // often parts are added in turn
    int merge_distance_px = 20;
    int min_merged_strong_pixels = 15;
    int merge_passes = 3;
    // Thresholds in robust standard deviations of the difference image, with floors in grey levels for very clean images
    double strong_sigmas = 8.0;
    double weak_sigmas = 4.0;
    double min_strong = 12.0;
    double min_weak = 6.0;
    // Width of the cross-sections along the object whose middles make up the axis
    double bin_px = 2.0;
    // A cross-section with a gap wider than this splits into parts, each with its own middle (#27), so the axis of a
    // dart beside another one in the same cross-section is not pulled between them; 0 takes one middle per section.
    double section_gap_px = 0.0;
    // The largest shift between image and empty board that is taken for a drifting camera and compensated
    double max_drift_px = 5.0;
    // A slight zoom or rotation of a drifting camera is measured in tiles x by y: tiles plainer than min_tile_contrast,
    // or whose correlation is below min_tile_response, are not measured; tiles off the fit by more than tile_outlier_px
    // (a dart) are dropped. With fewer than min_tiles left, or a zoom or rotation beyond max_linear, only the shift of
    // the whole image is compensated; so is one that moves no image corner by more than min_linear_px.
    int tiles_x = 8;
    int tiles_y = 5;
    int min_tiles = 12;
    double min_tile_response = 0.1;
    double min_tile_contrast = 5.0;
    double tile_outlier_px = 0.4;
    double max_linear = 0.01;
    double min_linear_px = 0.3;
    // The tone curve onto the empty board: a level counts with this many pixels, the middle 96 % of the pixels must
    // span min_tone_range levels, and levels further than tone_outlier from the curve are dropped.
    int min_tone_pixels = 50;
    int min_tone_range = 60;
    double tone_outlier = 12.0;
    // Closing bridges gaps up to about this size inside the object, such as between the edges of a plain barrel.
    int close_px = 9;
    // Middles within this distance of a line are on the axis; the axis spans at least min_axis_span_px.
    double axis_tolerance_px = 1.5;
    double min_axis_span_px = 30.0;
    // An object not cut off by the image border must be this long to be a dart: whole darts measured 146 px or more,
    // the changes of the board that looked like objects 90 px or less (#121).
    double min_whole_dart_px = 100.0;
    // Half width of the band in which an end is followed, and how far beyond the last axis point
    double band_px = 2.0;
    double max_reach_px = 120.0;
    int min_axis_points = 8;
    // An end this close to the image border is not taken: the dart may go on beyond it.
    int border_px = 5;
};

// When a camera's view changed as a whole (viewChange). Measured on the reference setup, a dart changed at most 10 of
// the cells x cells of the image (after aligning the shift of the whole image), a knocked camera 23 to 59; and a shift
// beyond moved_camera_px that explains most of the difference is a moved camera as well.
struct ViewChangeSettings
{
    int cells = 8;
    // A pixel changed by more than this grey level; a cell changed with this share of such pixels
    double changed_level = 25.0;
    double changed_cell_share = 0.002;
    int max_cells_for_a_dart = 16;
    double moved_camera_px = 3.0;
    // Only the image outside this radius on the board is compared (with a calibrated camera; 0 compares everything):
    // a camera that moved shifts the surround and the room as well, a board or number ring that moved does not.
    double ignore_inside_mm = 230.0;
    // Cells with less of the compared region than this share are left out
    double min_cell_region_share = 0.2;
    // The shift explains the change when what is left after it is at most this share of the change
    double explained_share = 0.5;
};

struct DartObservation
{
    // Centre line of the narrow part of the object (point, barrel, shaft), one point per 2 px along its axis. The flight
    // is left out: it is wide, and in perspective its middle is not on the axis.
    std::vector<cv::Point2f> axis_px;
    // The two ends of the object along its axis, each refined to where the difference to the empty board fades. The
    // tip is one of them; an end at the image border is left out, because there the image cuts the object.
    std::vector<cv::Point2f> ends_px;
    // Distance between the first and the last axis point
    double axis_length_px = 0.0;
    // The object touches the image border, so the camera sees only part of it
    bool cut = false;
    int area_px = 0;
    // The object as one area (8-bit, the size of the image), for measuring its width along the axis
    cv::Mat mask;
};

// image and empty_board are images of the same camera, ideally means of several frames, 8-bit or float BGR. Nothing if
// no object large enough stands out from the empty board.
std::optional<DartObservation> observeDart (const cv::Mat& image, const cv::Mat& empty_board, const ObservationSettings& settings = {});
// The shift of the whole image if a camera's view changed as a whole from one still image to the next: it was knocked,
// tilted or sways. A dart changes one place of the image, a knocked camera the edges all over it. Nothing otherwise.
// region (8-bit, optional) limits the comparison to the pixels set in it, e.g. outside the board: a dart hitting the
// number ring or bouncing off moves the board and the ring a little, which changes their edges as a knock would.
std::optional<cv::Point2d> viewChange (const cv::Mat& before, const cv::Mat& after, const ViewChangeSettings& settings = {},
                                       const cv::Mat& region = {});
}  // namespace dartpilot::tip_candidates
