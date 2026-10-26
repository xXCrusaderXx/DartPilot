#include "dartpilot/fusion/detection_params.hpp"

#include <cmath>
#include <cstdio>

#include "dartpilot/scoring/field_candidates.hpp"

namespace dartpilot::fusion
{
namespace
{
// A value kept in a field of DetectionSettings as it is
#define DETECTION_PARAM(name, group, unit, min, max, step, field, description)                                                    \
    DetectionParam                                                                                                                \
    {                                                                                                                             \
        name, group, description, unit, min, max, step, [] (const DetectionSettings& s) { return static_cast<double>(s.field); }, \
            [] (DetectionSettings& s, double v) { s.field = static_cast<std::remove_reference_t<decltype(s.field)>>(v); }         \
    }
// A time kept in nanoseconds, shown in milliseconds
#define DETECTION_PARAM_MS(name, group, min, max, step, field, description)                                                             \
    DetectionParam                                                                                                                      \
    {                                                                                                                                   \
        name, group, description, "ms", min, max, step, [] (const DetectionSettings& s) { return static_cast<double>(s.field) / 1e6; }, \
            [] (DetectionSettings& s, double v) { s.field = static_cast<std::int64_t>(std::llround(v * 1e6)); }                         \
    }

std::vector<DetectionParam> makeParams ()
{
    return {
        // event_detection: when the board counts as still
        DETECTION_PARAM_MS("sample_ms", "event_detection", 10, 200, 1, still.sample_interval_ns,
                           "How often every camera's latest frame is looked at; 33 ms is every frame at 30 fps."),
        DETECTION_PARAM_MS("motion_span_ms", "event_detection", 0, 500, 10, still.motion_span_ns,
                           "Each sample is also compared with the one this long before, so that a slowly moving hand still counts as motion."),
        DETECTION_PARAM(
            "still_motion", "event_detection", "grey", 0.5, 10, 0.1, still.still_motion,
            "Mean brightness change of the whole image (at a quarter of its size) above which a camera moves; image noise gives about 1."),
        DETECTION_PARAM("local_change", "event_detection", "grey", 5, 100, 1, still.local_change,
                        "A pixel (at a quarter of the size) changed by more than this counts towards local_change_px."),
        DETECTION_PARAM(
            "local_change_px", "event_detection", "px", 1, 500, 1, still.local_change_px,
            "A camera also moves when this many pixels changed by more than local_change: a dart landing changes 100 to 700, noise at most 2."),
        DETECTION_PARAM("settle_samples", "event_detection", "", 1, 60, 1, still.settle_samples,
                        "Samples in which every camera must be still before the board is measured: the flight must stop swinging."),
        DETECTION_PARAM("average_frames", "event_detection", "", 1, 20, 1, still.frames_to_average,
                        "Frames averaged per camera for one measurement of the board; more frames, less noise, more delay."),
        DETECTION_PARAM_MS("retry_ms", "event_detection", 500, 10000, 100, still.retry_interval_ns,
                           "While the engine waits for an empty board, a still board is measured again this often."),

        // tip_candidates: how a dart is found in one camera
        DETECTION_PARAM("min_strong_pixels", "tip_candidates", "px", 10, 2000, 1, tracker.observation.min_strong_pixels,
                        "An object needs this many clearly changed pixels; a dart at the far side of the board still has several hundred."),
        DETECTION_PARAM("strong_sigmas", "tip_candidates", "σ", 2, 20, 0.5, tracker.observation.strong_sigmas,
                        "A pixel is clearly changed above this many robust standard deviations of the difference image."),
        DETECTION_PARAM("weak_sigmas", "tip_candidates", "σ", 1, 10, 0.5, tracker.observation.weak_sigmas,
                        "A weakly changed pixel connected to a clearly changed one belongs to the object above this many standard deviations."),
        DETECTION_PARAM("min_strong", "tip_candidates", "grey", 1, 60, 1, tracker.observation.min_strong,
                        "Floor of the clear-change threshold for very clean images."),
        DETECTION_PARAM("min_weak", "tip_candidates", "grey", 1, 40, 1, tracker.observation.min_weak,
                        "Floor of the weak-change threshold for very clean images."),
        DETECTION_PARAM("merge_distance_px", "tip_candidates", "px", 0, 80, 1, tracker.observation.merge_distance_px,
                        "Parts of one dart this far apart are joined, e.g. across a shaft of the board's colour."),
        DETECTION_PARAM("min_merged_strong_pixels", "tip_candidates", "px", 1, 500, 1, tracker.observation.min_merged_strong_pixels,
                        "A part is joined only with this many clearly changed pixels."),
        DETECTION_PARAM("merge_passes", "tip_candidates", "", 0, 10, 1, tracker.observation.merge_passes, "How often parts are joined in turn."),
        DETECTION_PARAM("close_px", "tip_candidates", "px", 1, 31, 2, tracker.observation.close_px,
                        "Closing bridges gaps up to about this size inside the object, such as between the edges of a plain barrel."),
        DETECTION_PARAM("bin_px", "tip_candidates", "px", 0.5, 8, 0.5, tracker.observation.bin_px,
                        "Width of the cross-sections along the object whose middles make up its axis."),
        DETECTION_PARAM("section_gap_px", "tip_candidates", "px", 0, 20, 0.5, tracker.observation.section_gap_px,
                        "A cross-section of the object with a gap wider than this splits into parts with a middle each, so a dart beside "
                        "another one is not pulled between them. 0 takes one middle per cross-section."),
        DETECTION_PARAM("axis_tolerance_px", "tip_candidates", "px", 0.5, 5, 0.1, tracker.observation.axis_tolerance_px,
                        "Middles within this distance of a line are on the axis."),
        DETECTION_PARAM("min_axis_span_px", "tip_candidates", "px", 5, 200, 1, tracker.observation.min_axis_span_px,
                        "The axis spans at least this length."),
        DETECTION_PARAM("min_axis_points", "tip_candidates", "", 2, 50, 1, tracker.observation.min_axis_points,
                        "The axis needs at least this many middles."),
        DETECTION_PARAM(
            "min_whole_dart_px", "tip_candidates", "px", 20, 400, 1, tracker.observation.min_whole_dart_px,
            "An object not cut off by the image border must be this long to be a dart (whole darts 146 px or more, board changes 90 px or less)."),
        DETECTION_PARAM("band_px", "tip_candidates", "px", 0.5, 6, 0.5, tracker.observation.band_px,
                        "Half width of the band in which an end of the dart is followed beyond its axis."),
        DETECTION_PARAM("max_reach_px", "tip_candidates", "px", 10, 300, 1, tracker.observation.max_reach_px,
                        "How far beyond the last axis point an end is followed: the thin point may be too faint for the object's outline."),
        DETECTION_PARAM("border_px", "tip_candidates", "px", 0, 50, 1, tracker.observation.border_px,
                        "An end this close to the image border is not taken: the dart may go on beyond it."),
        DETECTION_PARAM("max_drift_px", "tip_candidates", "px", 0, 20, 0.5, tracker.observation.max_drift_px,
                        "The largest shift between image and board that is taken for a drifting camera and compensated."),
        DETECTION_PARAM("tiles_x", "tip_candidates", "", 2, 16, 1, tracker.observation.tiles_x,
                        "Tiles across in which a slight zoom or rotation of a drifting camera is measured."),
        DETECTION_PARAM("tiles_y", "tip_candidates", "", 2, 16, 1, tracker.observation.tiles_y, "Tiles down for the same."),
        DETECTION_PARAM("min_tiles", "tip_candidates", "", 3, 100, 1, tracker.observation.min_tiles,
                        "With fewer measured tiles only the shift of the whole image is compensated."),
        DETECTION_PARAM("min_tile_response", "tip_candidates", "", 0, 1, 0.01, tracker.observation.min_tile_response,
                        "A tile's correlation must reach this to be measured."),
        DETECTION_PARAM("min_tile_contrast", "tip_candidates", "grey", 0, 40, 0.5, tracker.observation.min_tile_contrast,
                        "Tiles plainer than this (standard deviation) are not measured."),
        DETECTION_PARAM("tile_outlier_px", "tip_candidates", "px", 0.05, 3, 0.05, tracker.observation.tile_outlier_px,
                        "A tile further than this off the fitted zoom and rotation (a dart in it) is dropped."),
        DETECTION_PARAM("max_linear", "tip_candidates", "", 0, 0.1, 0.001, tracker.observation.max_linear,
                        "A larger zoom or rotation is not a drift; only the shift is compensated."),
        DETECTION_PARAM("min_linear_px", "tip_candidates", "px", 0, 3, 0.05, tracker.observation.min_linear_px,
                        "A zoom or rotation that moves no image corner by more than this only fits noise and is ignored."),
        DETECTION_PARAM("min_tone_pixels", "tip_candidates", "px", 1, 1000, 1, tracker.observation.min_tone_pixels,
                        "A grey level counts for the tone curve onto the board with this many pixels."),
        DETECTION_PARAM("min_tone_range", "tip_candidates", "grey", 10, 200, 1, tracker.observation.min_tone_range,
                        "The middle 96 % of the pixels must span this many levels for a tone curve, so a small dart cannot bend it."),
        DETECTION_PARAM("tone_outlier", "tip_candidates", "grey", 1, 60, 1, tracker.observation.tone_outlier,
                        "Levels further than this from the tone curve are dropped."),
        DETECTION_PARAM("view_cells", "tip_candidates", "", 2, 32, 1, tracker.view_change.cells,
                        "The image is split into cells × cells to tell a knocked camera, which changes everywhere, from a dart."),
        DETECTION_PARAM("view_changed_level", "tip_candidates", "grey", 5, 100, 1, tracker.view_change.changed_level,
                        "A pixel changed by more than this counts for a changed cell."),
        DETECTION_PARAM("view_changed_cell_share", "tip_candidates", "", 0.0001, 0.05, 0.0001, tracker.view_change.changed_cell_share,
                        "A cell is changed with this share of changed pixels."),
        DETECTION_PARAM("view_max_cells_for_a_dart", "tip_candidates", "", 1, 200, 1, tracker.view_change.max_cells_for_a_dart,
                        "More changed cells than this are a moved camera (a dart changed at most 10 of 64, a knocked camera 23 to 59)."),
        DETECTION_PARAM("view_moved_camera_px", "tip_candidates", "px", 0.5, 20, 0.5, tracker.view_change.moved_camera_px,
                        "A shift of the whole image beyond this that explains the change is a moved camera."),
        DETECTION_PARAM("view_ignore_inside_mm", "tip_candidates", "mm", 0, 400, 5, tracker.view_change.ignore_inside_mm,
                        "Only the image outside this radius on the board tells a moved camera; a dart moving the board or its number ring does not. "
                        "0 compares the whole image."),
        DETECTION_PARAM("view_min_cell_region_share", "tip_candidates", "", 0, 1, 0.05, tracker.view_change.min_cell_region_share,
                        "Cells with less of the compared image than this share are left out."),
        DETECTION_PARAM("view_explained_share", "tip_candidates", "", 0.05, 1, 0.05, tracker.view_change.explained_share,
                        "The shift explains the change when at most this share of it is left after the shift."),

        // geometry: when views agree on the point, and when the board is occupied
        DETECTION_PARAM("min_cut_axis_px", "geometry", "px", 20, 400, 1, tracker.locate.min_cut_axis_px,
                        "A dart cut off by the image border must show this much axis to fix its direction."),
        DETECTION_PARAM("max_plane_distance_mm", "geometry", "mm", 0.2, 10, 0.1, tracker.locate.max_plane_distance_mm,
                        "The axis planes of agreeing cameras pass within this distance of their common point on the board."),
        DETECTION_PARAM("min_crossing_deg", "geometry", "°", 1, 60, 1, tracker.locate.min_crossing_deg,
                        "Two cameras alone must see the dart at least at this angle to each other on the board."),
        DETECTION_PARAM("max_end_distance_px", "geometry", "px", 1, 60, 1, tracker.locate.max_end_distance_px,
                        "The point's image lies at most this far from a visible end of the dart."),
        DETECTION_PARAM("plane_sigma_mm", "geometry", "mm", 0.05, 5, 0.05, tracker.locate.plane_sigma_mm,
                        "Uncertainty of one camera's axis plane on the board, for the covariance of the point."),
        DETECTION_PARAM("hidden_board_mm", "geometry", "mm", 0.5, 10, 0.1, tracker.board_check.hidden_board_mm,
                        "Without a stored empty board: wires further than this from the calibration mean the board is partly hidden."),
        DETECTION_PARAM("edge_tolerance_px", "geometry", "px", 0, 10, 1, tracker.board_check.edge_tolerance_px,
                        "An object against the empty board must stand out even when every pixel may match within this distance."),
        DETECTION_PARAM("confirm_level", "geometry", "grey", 5, 100, 1, tracker.board_check.confirm_level,
                        "A pixel stands out from the empty board by more than this in some colour channel."),
        DETECTION_PARAM("board_check_radius_mm", "geometry", "mm", 0, 300, 5, tracker.board_check.board_radius_mm,
                        "Only pixels on the board within this radius make it occupied, not the number ring, the surround or a hand at the edge. 0 "
                        "counts the whole image."),
        DETECTION_PARAM("min_confirmed_px", "geometry", "px", 10, 2000, 1, tracker.board_check.min_confirmed_px,
                        "An object on the board needs this many pixels that stand out."),

        // fusion: following the board from one still moment to the next
        DETECTION_PARAM("takeout_max_cameras", "fusion", "", 0, 3, 1, tracker.takeout_max_cameras,
                        "All darts are pulled when at most this many cameras still see something against the empty board."),
        DETECTION_PARAM("max_changes", "fusion", "", 1, 6, 1, tracker.max_changes,
                        "Changes looked at in one still moment: a dart pulled and another put in, and one more."),
        DETECTION_PARAM("pulled_reach_px", "fusion", "px", 5, 200, 1, tracker.pulled_reach_px,
                        "How far around a pulled dart's axis the board is taken as it is now, to cover its flight."),
        DETECTION_PARAM("patch_px", "fusion", "px", 0, 10, 1, tracker.patch_px,
                        "Half size of the patches along a change in which it is compared with the empty board."),
        DETECTION_PARAM("confidence_two_cameras", "fusion", "", 0, 1, 0.05, confidence.two_cameras, "Confidence of a dart located by two cameras."),
        DETECTION_PARAM("confidence_three_cameras", "fusion", "", 0, 1, 0.05, confidence.three_cameras,
                        "Confidence of a dart located by three or more cameras."),
        DETECTION_PARAM("confidence_abstained", "fusion", "", 0, 1, 0.05, confidence.abstained, "Confidence sent with an abstention."),
        DETECTION_PARAM("uncertain_field_probability", "fusion", "", 0, 1, 0.05, confidence.uncertain_field_probability,
                        "A located dart whose most likely field has less probability than this, from its covariance, is sent as uncertain "
                        "with the fields it may be in, for the player to pick. 0 sends every located dart as accepted."),
    };
}
#undef DETECTION_PARAM
#undef DETECTION_PARAM_MS

std::string number (double value)
{
    char text[32];
    std::snprintf(text, sizeof(text), "%g", value);
    return text;
}
}  // namespace

const std::vector<DetectionParam>& detectionParams ()
{
    static const std::vector<DetectionParam> params = makeParams();
    return params;
}

const DetectionParam* findDetectionParam (const std::string& name)
{
    for(const auto& param : detectionParams())
    {
        if(param.name == name)
        {
            return &param;
        }
    }
    return nullptr;
}

std::optional<std::string> setDetectionParam (DetectionSettings& settings, const std::string& name, double value)
{
    const auto* param = findDetectionParam(name);
    if(!param)
    {
        return "Unknown detection value " + name;
    }
    if(!std::isfinite(value) || value < param->min || value > param->max)
    {
        return name + " must be from " + number(param->min) + " to " + number(param->max);
    }
    // Sliders send whole steps as doubles, e.g. 6.0
    param->set(settings, param->step >= 1.0 ? std::round(value) : value);
    return std::nullopt;
}

std::string detectionParamsMarkdown ()
{
    std::string out = "| Name | Stage | Default | Range | Unit | Meaning |\n| - | - | - | - | - | - |\n";
    for(const auto& param : detectionParams())
    {
        out += "| `" + param.name + "` | " + param.group + " | " + number(param.defaultValue()) + " | " + number(param.min) + "–" +
               number(param.max) + " | " + param.unit + " | " + param.description + " |\n";
    }
    return out;
}
bool uncertainField (double x_mm, double y_mm, const cv::Matx22d& covariance_mm2, const scoring::BoardGeometry& geometry,
                     const ConfidenceSettings& settings)
{
    if(!(settings.uncertain_field_probability > 0.0))
    {
        return false;
    }
    const auto fields = scoring::fieldCandidates(x_mm, y_mm, {covariance_mm2(0, 0), covariance_mm2(0, 1), covariance_mm2(1, 1)}, geometry, 0.0, 1);
    return !fields.empty() && fields.front().probability < settings.uncertain_field_probability;
}
}  // namespace dartpilot::fusion
