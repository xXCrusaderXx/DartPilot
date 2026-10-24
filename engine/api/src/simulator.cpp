#include "dartpilot/api/simulator.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <ctime>
#include <optional>
#include <random>
#include <string>

namespace dartpilot::api
{
namespace
{
std::int64_t monotonicNowNs ()
{
    timespec now{};
    ::clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<std::int64_t>(now.tv_sec) * 1'000'000'000 + now.tv_nsec;
}

// Targets a player aims at, as board points in the middle of T20, T19, D16, the bull and S20 (checked in ApiTest)
constexpr std::array<std::array<double, 2>, 5> kTargets = {{{0.0, 103.0}, {-31.83, -97.96}, {-134.30, -97.57}, {0.0, 0.0}, {0.0, 60.0}}};

const std::array<const char*, 3> kCameras = {"sim-1", "sim-2", "sim-3"};

void sleepInterruptibly (std::chrono::milliseconds duration, const std::atomic<bool>& stop)
{
    const auto end = std::chrono::steady_clock::now() + duration;
    while(!stop && std::chrono::steady_clock::now() < end)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
}
}  // namespace

Simulator::Simulator (Server& server, SimulatorSettings settings)
    : server_(server)
    , settings_(settings)
{
}

Simulator::~Simulator ()
{
    stop();
    if(settings_.board_state)
    {
        server_.onCheckBoard({});
        server_.onStoreEmptyReference({});
    }
    if(settings_.diagnosis)
    {
        server_.onDiagnosis({});
        server_.onCalibration({});
    }
}

BoardStateInfo Simulator::boardState (bool occupied)
{
    BoardStateInfo board;
    for(const char* camera : kCameras)
    {
        CameraBoardState state;
        state.camera = camera;
        state.state = occupied ? "occupied" : "empty";
        if(occupied)
        {
            // In the simulated previews' 640x360 image, above the bull
            state.image_point_px = std::array<double, 2>{320.0, 150.0};
            state.reason = "object on the board (simulated)";
        }
        state.image_size_px = {640, 360};
        board.cameras.push_back(state);
    }
    board.state = combineBoardState(board.cameras);
    board.reference_stored = true;
    return board;
}

nlohmann::json Simulator::exampleDiagnosis (bool running)
{
    using json = nlohmann::json;
    const auto finding =
        [] (const char* severity, const char* check, json camera, const char* code, json values, const char* message, const char* hint)
    {
        return json{{"severity", severity}, {"check", check},     {"camera", camera}, {"code", code},
                    {"values", values},     {"message", message}, {"hint", hint}};
    };
    json periods = json::array();
    periods.push_back({{"start_s", 40.0}, {"end_s", 42.5}, {"empty", true}, {"cameras", json::array()}});
    periods.push_back({{"start_s", 47.1},
                       {"end_s", 49.6},
                       {"empty", false},
                       {"cameras", json::array()},
                       {"board_mm", {0.0, 103.0}},
                       {"agreeing_cameras", {"sim-1", "sim-2", "sim-3"}},
                       {"worst_plane_mm", 0.4}});
    periods.push_back({{"start_s", 53.0}, {"end_s", 55.5}, {"empty", true}, {"cameras", json::array()}});
    for(auto& period : periods)
    {
        for(int c = 0; c < 3; ++c)
        {
            json camera{{"brightness", 112.0}};
            if(period["empty"])
            {
                camera["calibration_mm"] = c == 1 ? 1.4 : 0.5;
                camera["shift_px"] = {c == 1 && period["start_s"] == 53.0 ? 0.6 : 0.0, 0.0};
            }
            else
            {
                camera["dart"] = c == 2 ? "cut" : "seen";
                camera["axis_length_px"] = 240.0;
            }
            period["cameras"].push_back(camera);
        }
    }
    return {{"type", "diagnosis"},
            {"running", running},
            {"step", "insert_dart"},
            {"state", "measured"},
            {"elapsed_s", 20.0},
            {"session_id", ""},
            {"duration_s", 20.0},
            {"cameras", {"sim-1", "sim-2", "sim-3"}},
            {"findings",
             {finding("warning", "drift", "sim-2", "drift", {{"px", 0.6}, {"minutes", 0.2}}, "The image moved by 0.60 px within 0.2 min.",
                      "Let the cameras run for about 10 minutes before calibrating and playing, so they are warm; if it keeps moving, tighten the "
                      "camera's mount."),
              finding("warning", "calibration", "sim-2", "calibration_off", {{"mm", 1.4}}, "The board is 1.40 mm off this camera's calibration.",
                      "If the camera or the board moved, calibrate the camera again and refine all cameras (extrinsic page, step 5)."),
              finding("info", "darts", nullptr, "darts_located", {{"located", 1}, {"darts", 1}, {"abstained", 0}},
                      "1 of 1 darts located, 0 abstained.", "")}},
            {"periods", periods}};
}

nlohmann::json Simulator::exampleCalibrationStatus ()
{
    using json = nlohmann::json;
    json cameras = json::array();
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        cameras.push_back({{"camera", kCameras[c]},
                           {"intrinsics", c == 2 ? "none" : "valid"},
                           {"board_plane_mm", c == 1 ? 0.62 : 0.41},
                           {"refined", true},
                           {"white_balance_kelvin", 3000}});
    }
    return {{"cameras", cameras}, {"refinement_stale", false}, {"extrinsics_created", "2026-10-24T17:41:00Z"}};
}

std::vector<nlohmann::json> Simulator::exampleCalibrationEvents (const CalibrationRequest& request)
{
    using json = nlohmann::json;
    constexpr double kPi = 3.14159265358979323846;
    const std::string camera = request.body.value("camera", std::string());
    const auto index = static_cast<std::size_t>(std::find(kCameras.begin(), kCameras.end(), camera) - kCameras.begin());
    // The projection of the simulated previews: 640x360, each camera turned by 120 degrees and squeezed vertically
    const double view = static_cast<double>(index % kCameras.size()) * 2.0 * kPi / 3.0;
    const auto project = [&] (double x_mm, double y_mm)
    {
        const double xr = x_mm * std::cos(view) - y_mm * std::sin(view);
        const double yr = x_mm * std::sin(view) + y_mm * std::cos(view);
        return json{320.0 + 0.9 * xr, 180.0 - 0.55 * 0.9 * yr};
    };
    const scoring::BoardGeometry geometry;
    std::vector<json> events;
    if(request.type == "detect_board")
    {
        json ellipses = json::array(), wires = json::array(), points = json::array();
        const double outer_bull = geometry.outer_bull_radius_mm;
        const double treble = 0.5 * (geometry.triple_inner_radius_mm + geometry.triple_outer_radius_mm);
        const double double_centre = 0.5 * (geometry.double_inner_radius_mm + geometry.double_outer_radius_mm);
        for(const double radius : {outer_bull, treble, double_centre})
        {
            ellipses.push_back({{"center_px", {320.0, 180.0}}, {"axes_px", {0.9 * radius, 0.495 * radius}}, {"angle_deg", 0.0}});
        }
        for(int k = 0; k < 20; ++k)
        {
            const double phi = (9.0 + 18.0 * k) * kPi / 180.0;
            const json from = project(outer_bull * std::cos(phi), outer_bull * std::sin(phi));
            const json to = project(1.2 * double_centre * std::cos(phi), 1.2 * double_centre * std::sin(phi));
            wires.push_back({from[0], from[1], to[0], to[1]});
            for(const double radius : {outer_bull, treble, double_centre})
            {
                points.push_back(project(radius * std::cos(phi), radius * std::sin(phi)));
            }
        }
        events.push_back({{"type", "board_detection"},
                          {"camera", camera},
                          {"ok", true},
                          {"code", "found"},
                          {"image_size_px", {640, 360}},
                          {"ellipses", ellipses},
                          {"wires_px", wires},
                          {"points_px", points}});
    }
    else if(request.type == "set_sector_20")
    {
        // Sectors clockwise from the top of the board
        constexpr std::array<int, 20> kClockwise = {20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5};
        json sectors = json::array();
        for(std::size_t i = 0; i < kClockwise.size(); ++i)
        {
            const double phi = (90.0 - 18.0 * static_cast<double>(i)) * kPi / 180.0;
            sectors.push_back({{"sector", kClockwise[i]}, {"label_px", project(134.0 * std::cos(phi), 134.0 * std::sin(phi))}});
        }
        events.push_back({{"type", "board_plane"},
                          {"camera", camera},
                          {"fit_mm", 0.41},
                          {"worst_mm", 0.93},
                          {"rms_px", 0.38},
                          {"lens_corrected", index != 2},
                          {"sectors", sectors}});
    }
    else if(request.type == "refine_cameras")
    {
        events.push_back({{"type", "refinement"}, {"state", "running"}});
        json cameras = json::array();
        for(std::size_t c = 0; c < kCameras.size(); ++c)
        {
            const double held_out_mm = c == 2 ? 0.71 : 0.42 + 0.1 * static_cast<double>(c);
            cameras.push_back({{"camera", kCameras[c]},
                               {"held_out_mm", held_out_mm},
                               {"quality", held_out_mm <= 0.5 ? "good" : "fair"},
                               {"uncertainty_mm", 0.3},
                               {"focal_px", 1012.0},
                               {"lens_from", c == 2 ? "model" : "own"},
                               {"advice", held_out_mm <= 0.5 ? json(nullptr) : json(c == 2 ? "lens_calibration" : "detect_again")}});
        }
        events.push_back(
            {{"type", "refinement"}, {"state", "done"}, {"cameras", cameras}, {"board", {{"outer_bull_mm", 15.9}, {"treble_centre_mm", 103.0}}}});
    }
    else if(request.type == "tune_white_balance")
    {
        const auto found = [] (int kelvin) { return kelvin <= 3400; };
        const auto message = [&] (const std::string& state, int up_to_kelvin, std::optional<int> kelvin_now, bool chosen)
        {
            json cameras = json::array();
            for(const char* id : kCameras)
            {
                json found_at = json::array();
                for(int kelvin = 2800; kelvin <= up_to_kelvin; kelvin += 200)
                {
                    found_at.push_back({{"kelvin", kelvin}, {"found", found(kelvin)}});
                }
                cameras.push_back({{"camera", id}, {"found_at", found_at}, {"chosen_kelvin", chosen ? json(3000) : json(nullptr)}});
            }
            json event = {{"type", "white_balance"}, {"state", state}, {"cameras", cameras}};
            if(kelvin_now)
            {
                event["kelvin_now"] = *kelvin_now;
            }
            if(state == "settling")
            {
                event["settle_s"] = 0.0;
            }
            return event;
        };
        events.push_back(message("settling", 0, std::nullopt, false));
        for(int kelvin = 2800; kelvin <= 6400; kelvin += 200)
        {
            events.push_back(message("sweeping", kelvin, kelvin, false));
        }
        events.push_back(message("done", 6400, std::nullopt, true));
    }
    return events;
}

void Simulator::publishBoard (bool occupied)
{
    occupied_ = occupied;
    if(settings_.board_state)
    {
        server_.setBoardState(boardState(occupied));
    }
}

std::array<double, 2> Simulator::target (int index) { return kTargets[static_cast<std::size_t>(index / 3) % kTargets.size()]; }

Throw Simulator::makeDart (std::uint32_t seed, int index, const SimulatorSettings& settings)
{
    // Every dart has its own generator from (seed, index), so a dart does not depend on how many came before.
    std::seed_seq sequence{seed, static_cast<std::uint32_t>(index)};
    std::mt19937 random(sequence);
    std::uniform_real_distribution<double> unit(0.0, 1.0);
    const auto target = Simulator::target(index);
    // Box-Muller from the uniform generator, so the scatter is the same with every standard library
    const double radius = settings.scatter_mm * std::sqrt(-2.0 * std::log(1.0 - unit(random)));
    const double angle = 2.0 * 3.14159265358979323846 * unit(random);

    Throw dart;
    const bool abstain = unit(random) < settings.abstain_rate;
    const double sigma_mm = abstain ? 4.0 : 0.8 + 0.4 * unit(random);
    dart.board_point = BoardPoint{target[0] + radius * std::cos(angle), target[1] + radius * std::sin(angle),
                                  std::array<double, 3>{sigma_mm * sigma_mm, 0.0, sigma_mm * sigma_mm}};
    dart.accepted = !abstain;
    dart.confidence = abstain ? 0.35 + 0.2 * unit(random) : 0.85 + 0.14 * unit(random);
    if(abstain)
    {
        dart.reason = "tip occluded in two cameras (simulated)";
    }
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        const bool used = !abstain || c == 0;
        dart.cameras.push_back({kCameras[c], used, {}, used ? "" : "tip occluded"});
    }
    dart.processing_latency_ms = 30.0 + 20.0 * unit(random);
    return dart;
}

void Simulator::start ()
{
    stop();
    stop_ = false;
    if(settings_.board_state)
    {
        server_.onCheckBoard([this] { server_.setBoardState(boardState(occupied_)); });
        server_.onStoreEmptyReference(
            [this] (bool force) -> std::optional<std::string>
            {
                if(occupied_ && !force)
                {
                    return "board_not_empty";
                }
                // The darts are part of the new reference, so the board counts as empty from now on.
                publishBoard(false);
                return std::nullopt;
            });
    }
    if(settings_.diagnosis)
    {
        server_.onDiagnosis([this] (bool running) { server_.publishDiagnosis(exampleDiagnosis(running)); });
        server_.setCalibrationStatus(exampleCalibrationStatus());
        server_.onCalibration(
            [this] (const CalibrationRequest& request) -> std::optional<Server::CalibrationError>
            {
                const std::string camera = request.body.value("camera", std::string());
                if(request.type == "get_board_image")
                {
                    return Server::CalibrationError{"not_available", "Simulated cameras have no board image; draw the board"};
                }
                const bool needs_camera = request.type == "detect_board" || request.type == "set_sector_20";
                if(needs_camera && std::find(kCameras.begin(), kCameras.end(), camera) == kCameras.end())
                {
                    return Server::CalibrationError{"unknown_camera", "No camera " + camera};
                }
                for(const auto& event : exampleCalibrationEvents(request))
                {
                    server_.publishEvent(event);
                }
                return std::nullopt;
            });
    }
    publishBoard(settings_.occupied_at_start);
    thread_ = std::thread([this] { run(); });
}

void Simulator::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

void Simulator::run ()
{
    int index = 0;
    auto next_status = std::chrono::steady_clock::now();
    auto next_dart = std::chrono::steady_clock::now() + settings_.dart_interval;
    std::int64_t takeout_at_ns = 0;
    bool start_darts = settings_.occupied_at_start;
    const auto pulled_at = std::chrono::steady_clock::now() + settings_.takeout_delay;
    while(!stop_)
    {
        const auto now = std::chrono::steady_clock::now();
        if(settings_.camera_status && now >= next_status)
        {
            for(const char* camera : kCameras)
            {
                server_.publishCameraStatus({camera, "ok", 30.0, 0, 0, 110.0, 32.0});
            }
            next_status += std::chrono::seconds(1);
        }
        // Darts from before the start are pulled out without a takeout event, since no visit holds them
        if(start_darts && now >= pulled_at)
        {
            start_darts = false;
            publishBoard(false);
            next_dart = now + settings_.dart_interval;
        }
        if(running_ && takeout_at_ns != 0 && monotonicNowNs() >= takeout_at_ns)
        {
            server_.publishTakeout(monotonicNowNs(), 3);
            takeout_at_ns = 0;
            publishBoard(false);
            next_dart = now + settings_.dart_interval;
        }
        if(running_ && takeout_at_ns == 0 && !start_darts && now >= next_dart)
        {
            Throw dart = makeDart(settings_.seed, index, settings_);
            dart.event_ns = monotonicNowNs();
            server_.publishThrow(dart);
            publishBoard(true);
            ++index;
            if(index % 3 == 0)
            {
                takeout_at_ns = monotonicNowNs() + std::chrono::nanoseconds(settings_.takeout_delay).count();
            }
            next_dart = now + settings_.dart_interval;
        }
        sleepInterruptibly(std::chrono::milliseconds(50), stop_);
    }
}
}  // namespace dartpilot::api
