#include "dartpilot/replay/diagnosis.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <sstream>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "dartpilot/geometry/board_state.hpp"
#include "dartpilot/geometry/dart_location.hpp"
#include "dartpilot/scoring/score.hpp"
#include "dartpilot/session/json.hpp"
#include "dartpilot/tip_candidates/dart_observation.hpp"

namespace dartpilot::replay
{
namespace
{
using session::jsonString;

// Mean brightness change between frames at a quarter of the size; a still image measures about 1 (#101).
constexpr double kStillMotion = 2.5;
// A still period lasts at least this long; up to kFramesToAverage frames from its middle are averaged.
constexpr double kMinStill_s = 1.5;
constexpr int kFramesToAverage = 30;
// Thresholds of the findings, provisional until the error budget (#48)
constexpr double kLostWarning = 0.01;
constexpr double kLostProblem = 0.05;
constexpr double kDriftWarning_px = 0.3;
constexpr double kDriftProblem_px = 1.0;
constexpr double kCalibrationWarning_mm = 1.0;
constexpr double kCalibrationProblem_mm = 2.5;
constexpr double kLightChange = 0.10;
// A light change that involves a period this early after the start is the automatic exposure settling.
constexpr double kExposureSettle_s = 30.0;
constexpr double kPlaneWarning_mm = 1.0;
// A share of dart periods from which a camera's trouble with darts is reported
constexpr double kDartTroubleShare = 0.3;
// Pixels changed by more than this, after aligning two empty boards, count as a change of the board
constexpr double kBoardChangeLevel = 25.0;
constexpr double kBoardChangeShare = 0.0005;

std::string number (double value, int decimals = 2)
{
    std::array<char, 64> text{};
    std::snprintf(text.data(), text.size(), "%.*f", decimals, value);
    return text.data();
}

double median (std::vector<double> values)
{
    if(values.empty())
    {
        return 0.0;
    }
    std::nth_element(values.begin(), values.begin() + values.size() / 2, values.end());
    return values[values.size() / 2];
}

// Motion and capture of one camera
struct CameraTrack
{
    std::vector<std::int64_t> exposure_ns;
    std::vector<double> motion;
    std::size_t lost = 0;
};

CameraTrack track (const session::RecordedSession& session, std::size_t camera)
{
    CameraTrack t;
    session::FrameReader reader(session, camera);
    const auto& frames = session.cameras[camera].frames;
    cv::Mat previous;
    for(std::size_t f = 0; f < frames.size(); ++f)
    {
        t.exposure_ns.push_back(frames[f].exposure_ns);
        if(f > 0 && frames[f].sequence > frames[f - 1].sequence + 1)
        {
            t.lost += frames[f].sequence - frames[f - 1].sequence - 1;
        }
        cv::Mat gray = cv::imdecode(reader.read(f), cv::IMREAD_REDUCED_GRAYSCALE_4);
        if(gray.empty())
        {
            t.motion.push_back(1e9);
            continue;
        }
        gray.convertTo(gray, CV_32F);
        t.motion.push_back(previous.empty() || previous.size() != gray.size() ? 1e9 : cv::mean(cv::abs(gray - previous))[0]);
        previous = gray;
    }
    return t;
}

// Mean of up to kFramesToAverage frames from the middle of [start_ns, end_ns]
cv::Mat averaged (const session::RecordedSession& session, std::size_t camera, std::int64_t start_ns, std::int64_t end_ns)
{
    const auto& frames = session.cameras[camera].frames;
    std::vector<std::size_t> inside;
    for(std::size_t f = 0; f < frames.size(); ++f)
    {
        if(frames[f].exposure_ns >= start_ns && frames[f].exposure_ns <= end_ns)
        {
            inside.push_back(f);
        }
    }
    if(inside.empty())
    {
        return {};
    }
    const std::size_t take = std::min<std::size_t>(kFramesToAverage, inside.size());
    const std::size_t first = (inside.size() - take) / 2;
    session::FrameReader reader(session, camera);
    cv::Mat sum;
    int count = 0;
    for(std::size_t i = first; i < first + take; ++i)
    {
        const cv::Mat image = cv::imdecode(reader.read(inside[i]), cv::IMREAD_COLOR);
        if(image.empty())
        {
            continue;
        }
        if(sum.empty())
        {
            sum = cv::Mat::zeros(image.size(), CV_32FC3);
        }
        if(image.size() == sum.size())
        {
            cv::accumulate(image, sum);
            ++count;
        }
    }
    return count > 0 ? cv::Mat(sum / count) : cv::Mat();
}

// Share of pixels that changed between two empty boards, after aligning them
double boardChange (const cv::Mat& before, const cv::Mat& after)
{
    cv::Mat a, b;
    cv::cvtColor(before, a, cv::COLOR_BGR2GRAY);
    cv::cvtColor(after, b, cv::COLOR_BGR2GRAY);
    cv::Mat window;
    cv::createHanningWindow(window, a.size(), CV_32F);
    const cv::Point2d shift = cv::phaseCorrelate(a, b, window);
    cv::warpAffine(a, a, cv::Matx23d(1, 0, shift.x, 0, 1, shift.y), a.size(), cv::INTER_LINEAR, cv::BORDER_REPLICATE);
    a *= cv::mean(b)[0] / std::max(1.0, cv::mean(a)[0]);
    cv::Mat difference;
    cv::absdiff(a, b, difference);
    return static_cast<double>(cv::countNonZero(difference > kBoardChangeLevel)) / static_cast<double>(difference.total());
}
}  // namespace

std::string_view toString (Severity severity)
{
    switch(severity)
    {
        case Severity::Info:
            return "info";
        case Severity::Warning:
            return "warning";
        case Severity::Problem:
            return "problem";
    }
    return "info";
}

std::optional<Diagnosis> diagnoseSession (const session::RecordedSession& session, const geometry::StoredExtrinsics* extrinsics, std::string& error)
{
    if(session.cameras.empty() || session.cameras[0].frames.empty())
    {
        error = "The session has no frames.";
        return std::nullopt;
    }
    Diagnosis diagnosis;
    diagnosis.session_id = session.session_id;
    const std::size_t camera_count = session.cameras.size();
    std::vector<const geometry::RefinedCamera*> calibrations(camera_count, nullptr);
    for(std::size_t c = 0; c < camera_count; ++c)
    {
        diagnosis.cameras.push_back(session.cameras[c].id);
        if(extrinsics)
        {
            for(const auto& refined : extrinsics->refinement.cameras)
            {
                if(refined.usb_port == session.cameras[c].usb_port)
                {
                    calibrations[c] = &refined;
                }
            }
        }
    }
    const auto add = [&] (Severity severity, std::string check, std::string camera, std::string message, std::string hint)
    { diagnosis.findings.push_back({severity, std::move(check), std::move(camera), std::move(message), std::move(hint)}); };

    // Capture
    std::vector<CameraTrack> tracks;
    for(std::size_t c = 0; c < camera_count; ++c)
    {
        tracks.push_back(track(session, c));
        const auto& t = tracks.back();
        const double share = static_cast<double>(t.lost) / static_cast<double>(t.lost + t.exposure_ns.size());
        if(share > kLostWarning)
        {
            add(share > kLostProblem ? Severity::Problem : Severity::Warning, "capture", session.cameras[c].id,
                "Lost " + number(100.0 * share, 1) + " % of its frames.",
                "Plug the camera into another USB port or a powered hub, and close other programs that use the cameras.");
        }
    }
    const std::int64_t start_ns = tracks[0].exposure_ns.front();
    diagnosis.duration_s = static_cast<double>(tracks[0].exposure_ns.back() - start_ns) * 1e-9;

    // Still periods on the clock of the first camera; every camera must be still
    std::vector<std::size_t> cursor(camera_count, 0);
    std::vector<std::pair<std::int64_t, std::int64_t>> stills;
    std::optional<std::int64_t> still_since;
    for(std::size_t f = 0; f <= tracks[0].exposure_ns.size(); ++f)
    {
        bool still = f < tracks[0].exposure_ns.size();
        if(still)
        {
            const std::int64_t t = tracks[0].exposure_ns[f];
            for(std::size_t c = 0; c < camera_count && still; ++c)
            {
                auto& i = cursor[c];
                while(i + 1 < tracks[c].exposure_ns.size() && tracks[c].exposure_ns[i + 1] <= t)
                {
                    ++i;
                }
                still = tracks[c].motion[i] < kStillMotion;
            }
        }
        if(still && !still_since)
        {
            still_since = tracks[0].exposure_ns[f];
        }
        if(!still && still_since)
        {
            const std::int64_t end = tracks[0].exposure_ns[f - 1];
            if(static_cast<double>(end - *still_since) * 1e-9 >= kMinStill_s)
            {
                stills.emplace_back(*still_since, end);
            }
            still_since.reset();
        }
    }
    if(stills.size() < 2)
    {
        add(Severity::Problem, "still", "", "Only " + std::to_string(stills.size()) + " still moments in " + number(diagnosis.duration_s, 0) + " s.",
            "Hold each state still for a few seconds with the hand out of view; if the image never settles, check for vibrations.");
    }

    // Periods: the first one is the empty board; every later one without an object becomes the new reference, as after
    // a takeout, so that changes of the board and a drifting camera do not add up.
    std::vector<cv::Mat> reference(camera_count), last_empty(camera_count);
    std::vector<int> board_changes(camera_count, 0);
    for(std::size_t k = 0; k < stills.size(); ++k)
    {
        Period period;
        period.start_s = static_cast<double>(stills[k].first - start_ns) * 1e-9;
        period.end_s = static_cast<double>(stills[k].second - start_ns) * 1e-9;
        period.cameras.resize(camera_count);
        std::vector<cv::Mat> means(camera_count);
        std::vector<std::optional<tip_candidates::DartObservation>> observations(camera_count);
        for(std::size_t c = 0; c < camera_count; ++c)
        {
            means[c] = averaged(session, c, stills[k].first, stills[k].second);
            if(!means[c].empty())
            {
                period.cameras[c].brightness = cv::mean(means[c])[0];
                if(k > 0 && !reference[c].empty())
                {
                    observations[c] = tip_candidates::observeDart(means[c], reference[c]);
                }
            }
        }
        if(k == 0 && extrinsics)
        {
            for(std::size_t c = 0; c < camera_count; ++c)
            {
                if(!means[c].empty() &&
                   geometry::checkBoard(means[c], nullptr, calibrations[c], extrinsics->refinement.board).state == geometry::BoardState::Occupied)
                {
                    add(Severity::Problem, "board", session.cameras[c].id, "The board was not empty at the start: its wires are partly hidden.",
                        "Start the test with an empty board; everything after it is compared with this first image.");
                }
            }
        }
        period.empty = std::none_of(observations.begin(), observations.end(), [] (const auto& o) { return o.has_value(); });
        if(period.empty)
        {
            for(std::size_t c = 0; c < camera_count; ++c)
            {
                if(means[c].empty())
                {
                    continue;
                }
                if(calibrations[c])
                {
                    cv::Mat image;
                    means[c].convertTo(image, CV_8UC3);
                    if(const auto detection = geometry::detectBoard(image))
                    {
                        if(const auto check = geometry::checkCalibration(*detection, *calibrations[c], extrinsics->refinement.board))
                        {
                            period.cameras[c].calibration_mm = check->rms_mm;
                            period.cameras[c].shift_px = cv::Point2d(check->mean_shift_px.x, check->mean_shift_px.y);
                        }
                    }
                }
                if(!last_empty[c].empty() && boardChange(last_empty[c], means[c]) > kBoardChangeShare)
                {
                    ++board_changes[c];
                }
                last_empty[c] = means[c];
                reference[c] = means[c];
            }
        }
        else
        {
            std::vector<geometry::DartView> views;
            std::vector<int> view_camera;
            for(std::size_t c = 0; c < camera_count; ++c)
            {
                auto& pc = period.cameras[c];
                if(!observations[c])
                {
                    pc.dart = "none";
                    continue;
                }
                pc.dart = observations[c]->cut ? "cut" : "seen";
                pc.axis_length_px = observations[c]->axis_length_px;
                if(calibrations[c])
                {
                    views.push_back({calibrations[c], *observations[c]});
                    view_camera.push_back(static_cast<int>(c));
                }
            }
            if(const auto location = views.size() >= 2 ? geometry::locateDart(views) : std::nullopt)
            {
                period.board_mm = cv::Point2d(location->board_mm.x, location->board_mm.y);
                for(std::size_t i = 0; i < location->views.size(); ++i)
                {
                    period.agreeing_cameras.push_back(view_camera[location->views[i]]);
                    period.worst_plane_mm = std::max(period.worst_plane_mm, std::abs(location->plane_distance_mm[i]));
                }
            }
        }
        diagnosis.periods.push_back(std::move(period));
    }

    // Findings per camera from the empty periods: drift, calibration, light, changes of the board
    for(std::size_t c = 0; c < camera_count; ++c)
    {
        const std::string& id = session.cameras[c].id;
        std::vector<double> calibration_mm, brightness, brightness_s;
        std::optional<cv::Point2d> first_shift;
        double first_s = 0.0, drift_px = 0.0, drift_span_s = 0.0;
        int empty_periods = 0, board_missing = 0;
        for(const auto& period : diagnosis.periods)
        {
            if(!period.empty)
            {
                continue;
            }
            ++empty_periods;
            const auto& pc = period.cameras[c];
            brightness.push_back(pc.brightness);
            brightness_s.push_back(period.start_s);
            if(!pc.calibration_mm)
            {
                ++board_missing;
                continue;
            }
            calibration_mm.push_back(*pc.calibration_mm);
            if(!first_shift)
            {
                first_shift = pc.shift_px;
                first_s = period.start_s;
            }
            else
            {
                const double moved = cv::norm(*pc.shift_px - *first_shift);
                if(moved > drift_px)
                {
                    drift_px = moved;
                    drift_span_s = period.start_s - first_s;
                }
            }
        }
        if(!calibrations[c])
        {
            add(Severity::Warning, "calibration", id, "No refinement for this camera: calibration and darts were not checked.",
                "Calibrate it on the extrinsic page and refine all cameras (step 5).");
            continue;
        }
        if(empty_periods > 0 && board_missing == empty_periods)
        {
            add(Severity::Problem, "calibration", id, "The board was not found on any empty board.",
                "Check the camera's view and focus, and the light on the board.");
        }
        if(!calibration_mm.empty())
        {
            const double level_mm = median(calibration_mm);
            if(level_mm > kCalibrationWarning_mm)
            {
                add(level_mm > kCalibrationProblem_mm ? Severity::Problem : Severity::Warning, "calibration", id,
                    "The board is " + number(level_mm) + " mm off this camera's calibration.",
                    "If the camera or the board moved, calibrate the camera again and refine all cameras (extrinsic page, step 5).");
            }
        }
        if(drift_px > kDriftWarning_px)
        {
            add(drift_px > kDriftProblem_px ? Severity::Problem : Severity::Warning, "drift", id,
                "The image moved by " + number(drift_px) + " px within " + number(drift_span_s / 60.0, 1) + " min.",
                "Let the cameras run for about 10 minutes before calibrating and playing, so they are warm; if it keeps moving, "
                "tighten the camera's mount.");
        }
        if(brightness.size() >= 2)
        {
            const auto [low, high] = std::minmax_element(brightness.begin(), brightness.end());
            if(*high - *low > kLightChange * std::max(1.0, *low))
            {
                const double low_s = brightness_s[low - brightness.begin()], high_s = brightness_s[high - brightness.begin()];
                add(Severity::Warning, "light", id,
                    "The empty board's brightness changed by " + number(100.0 * (*high - *low) / std::max(1.0, *low), 0) + " % (" + number(*low, 0) +
                        " at " + number(low_s, 0) + " s, " + number(*high, 0) + " at " + number(high_s, 0) + " s).",
                    std::min(low_s, high_s) < kExposureSettle_s
                        ? "After the cameras start, their automatic exposure needs a moment: begin the test about 30 s after starting them, and "
                          "keep the ring light on."
                        : "Use the ring light and keep daylight and room light constant during the test.");
            }
        }
        if(board_changes[c] > 0)
        {
            add(Severity::Info, "board", id, "The empty board changed " + std::to_string(board_changes[c]) + " times between darts.",
                "Usually fibres pushed out by darts or a slight change of focus; harmless, as the reference is refreshed after every takeout.");
        }
    }

    // Darts
    int darts = 0, located = 0;
    std::vector<int> cut(camera_count, 0), cut_lost(camera_count, 0), none(camera_count, 0), disagreed(camera_count, 0);
    std::vector<double> planes;
    for(const auto& period : diagnosis.periods)
    {
        if(period.empty)
        {
            continue;
        }
        ++darts;
        if(period.board_mm)
        {
            ++located;
            if(period.agreeing_cameras.size() >= 3)
            {
                planes.push_back(period.worst_plane_mm);
            }
        }
        for(std::size_t c = 0; c < camera_count; ++c)
        {
            const auto& pc = period.cameras[c];
            cut[c] += pc.dart == "cut" ? 1 : 0;
            cut_lost[c] += pc.dart == "cut" && std::find(period.agreeing_cameras.begin(), period.agreeing_cameras.end(), static_cast<int>(c)) ==
                                                   period.agreeing_cameras.end()
                               ? 1
                               : 0;
            none[c] += pc.dart == "none" ? 1 : 0;
            const bool agreed =
                std::find(period.agreeing_cameras.begin(), period.agreeing_cameras.end(), static_cast<int>(c)) != period.agreeing_cameras.end();
            disagreed[c] += pc.dart == "seen" && period.board_mm && !agreed ? 1 : 0;
        }
    }
    if(darts == 0)
    {
        add(Severity::Warning, "darts", "", "No dart was found in the test.",
            "Put darts into the board one at a time and take the hand away each time.");
    }
    else
    {
        add(located * 3 < darts * 2 ? Severity::Warning : Severity::Info, "darts", "",
            std::to_string(located) + " of " + std::to_string(darts) + " darts located, " + std::to_string(darts - located) + " abstained.",
            located * 3 < darts * 2 ? "See the findings per camera for why darts were not located." : "");
        for(std::size_t c = 0; c < camera_count; ++c)
        {
            const std::string& id = session.cameras[c].id;
            // A dart whose flight leaves the image is still located from its point and barrel; only cuts that cost the camera
            // its part in the location are worth moving the camera for.
            if(cut_lost[c] > kDartTroubleShare * darts)
            {
                add(Severity::Warning, "darts", id,
                    "Cut " + std::to_string(cut[c]) + " of " + std::to_string(darts) + " darts at the image border, and could not help locate " +
                        std::to_string(cut_lost[c]) + " of them.",
                    "Tilt or move the camera so that the board and about 15 cm above it are in view, then calibrate it again.");
            }
            else if(cut[c] > kDartTroubleShare * darts)
            {
                add(Severity::Info, "darts", id, "Cut " + std::to_string(cut[c]) + " of " + std::to_string(darts) + " darts at the image border.",
                    "Harmless while the darts are still located; more of the space above the board in view would make it more robust.");
            }
            if(none[c] > kDartTroubleShare * darts)
            {
                add(Severity::Warning, "darts", id, "Did not see " + std::to_string(none[c]) + " of " + std::to_string(darts) + " darts.",
                    "Check that the camera sees the whole board; dark darts on dark sectors need good light.");
            }
            if(disagreed[c] > kDartTroubleShare * darts)
            {
                add(Severity::Warning, "consistency", id,
                    "Disagreed with the other cameras on " + std::to_string(disagreed[c]) + " of " + std::to_string(darts) + " darts.",
                    "Run the calibration check; if it is off, calibrate this camera again and refine all cameras.");
            }
        }
    }
    if(!planes.empty())
    {
        const double level_mm = median(planes);
        add(level_mm > kPlaneWarning_mm ? Severity::Warning : Severity::Info, "consistency", "",
            "Where three cameras saw a dart, they agreed within " + number(level_mm) + " mm (median).",
            level_mm > kPlaneWarning_mm ? "Refine all cameras again; if one camera stands out, calibrate it first." : "");
    }
    std::stable_sort(diagnosis.findings.begin(), diagnosis.findings.end(),
                     [] (const Finding& a, const Finding& b) { return static_cast<int>(a.severity) > static_cast<int>(b.severity); });
    return diagnosis;
}

std::string toJson (const Diagnosis& diagnosis)
{
    std::ostringstream json;
    json << "{\n  \"session_id\": " << jsonString(diagnosis.session_id) << ",\n  \"duration_s\": " << number(diagnosis.duration_s, 1)
         << ",\n  \"cameras\": [";
    for(std::size_t c = 0; c < diagnosis.cameras.size(); ++c)
    {
        json << (c == 0 ? "" : ", ") << jsonString(diagnosis.cameras[c]);
    }
    json << "],\n  \"findings\": [";
    for(std::size_t i = 0; i < diagnosis.findings.size(); ++i)
    {
        const auto& f = diagnosis.findings[i];
        json << (i == 0 ? "\n" : ",\n") << "    {\"severity\": " << jsonString(std::string(toString(f.severity)))
             << ", \"check\": " << jsonString(f.check) << ", \"camera\": " << (f.camera.empty() ? "null" : jsonString(f.camera))
             << ", \"message\": " << jsonString(f.message) << ", \"hint\": " << jsonString(f.hint) << "}";
    }
    json << "\n  ],\n  \"periods\": [";
    for(std::size_t k = 0; k < diagnosis.periods.size(); ++k)
    {
        const auto& p = diagnosis.periods[k];
        json << (k == 0 ? "\n" : ",\n") << "    {\"start_s\": " << number(p.start_s) << ", \"end_s\": " << number(p.end_s)
             << ", \"empty\": " << (p.empty ? "true" : "false") << ", \"cameras\": [";
        for(std::size_t c = 0; c < p.cameras.size(); ++c)
        {
            const auto& pc = p.cameras[c];
            json << (c == 0 ? "" : ", ") << "{\"brightness\": " << number(pc.brightness, 1);
            if(pc.calibration_mm)
            {
                json << ", \"calibration_mm\": " << number(*pc.calibration_mm) << ", \"shift_px\": [" << number(pc.shift_px->x) << ", "
                     << number(pc.shift_px->y) << "]";
            }
            if(!pc.dart.empty())
            {
                json << ", \"dart\": " << jsonString(pc.dart) << ", \"axis_length_px\": " << number(pc.axis_length_px, 0);
            }
            json << "}";
        }
        json << "]";
        if(p.board_mm)
        {
            json << ", \"board_mm\": [" << number(p.board_mm->x) << ", " << number(p.board_mm->y) << "], \"agreeing_cameras\": [";
            for(std::size_t i = 0; i < p.agreeing_cameras.size(); ++i)
            {
                json << (i == 0 ? "" : ", ") << jsonString(diagnosis.cameras[p.agreeing_cameras[i]]);
            }
            json << "], \"worst_plane_mm\": " << number(p.worst_plane_mm);
        }
        json << "}";
    }
    json << "\n  ]\n}\n";
    return json.str();
}

std::string toMarkdown (const Diagnosis& diagnosis)
{
    std::ostringstream md;
    md << "# Setup diagnosis\n\nSession `" << diagnosis.session_id << "`, " << number(diagnosis.duration_s, 0) << " s, " << diagnosis.cameras.size()
       << " cameras.\n\n## Findings\n\n";
    if(diagnosis.findings.empty())
    {
        md << "Nothing to report.\n";
    }
    for(const auto& f : diagnosis.findings)
    {
        md << "- **" << toString(f.severity) << "** (" << f.check << (f.camera.empty() ? "" : ", " + f.camera) << "): " << f.message;
        if(!f.hint.empty())
        {
            md << " " << f.hint;
        }
        md << "\n";
    }
    md << "\n## Still periods\n\n| # | Time | Board | Result |\n| - | - | - | - |\n";
    for(std::size_t k = 0; k < diagnosis.periods.size(); ++k)
    {
        const auto& p = diagnosis.periods[k];
        md << "| " << k << " | " << number(p.start_s, 1) << "–" << number(p.end_s, 1) << " s | ";
        if(p.empty)
        {
            md << "empty | ";
            for(std::size_t c = 0; c < p.cameras.size(); ++c)
            {
                const auto& pc = p.cameras[c];
                md << (c == 0 ? "" : ", ") << diagnosis.cameras[c] << ": " << (pc.calibration_mm ? number(*pc.calibration_mm) + " mm" : "no board");
            }
        }
        else
        {
            md << "dart | ";
            if(p.board_mm)
            {
                md << scoring::label(scoring::score(p.board_mm->x, p.board_mm->y)) << " at (" << number(p.board_mm->x, 1) << ", "
                   << number(p.board_mm->y, 1) << ") mm, " << p.agreeing_cameras.size() << " cameras within " << number(p.worst_plane_mm) << " mm";
            }
            else
            {
                md << "abstained";
            }
            md << " (";
            for(std::size_t c = 0; c < p.cameras.size(); ++c)
            {
                md << (c == 0 ? "" : ", ") << p.cameras[c].dart;
            }
            md << ")";
        }
        md << " |\n";
    }
    return md.str();
}
}  // namespace dartpilot::replay
