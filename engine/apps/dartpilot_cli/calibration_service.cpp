#include "calibration_service.hpp"

#include <linux/videodev2.h>

#include <algorithm>
#include <array>
#include <cstdio>
#include <ctime>
#include <exception>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "base64.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/capture/white_balance.hpp"
#include "dartpilot/geometry/board_plane.hpp"
#include "dartpilot/geometry/board_refinement.hpp"
#include "dartpilot/geometry/board_view.hpp"
#include "white_balance_sweep.hpp"

namespace dartpilot::cli
{
namespace
{
using json = nlohmann::json;

// As the setup GUI: frames averaged for a board detection
constexpr int kDetectionFrames = 10;
// The automatic exposure settles in about 25 s after the cameras start.
constexpr auto kExposureSettle = std::chrono::seconds(25);
// Sector numbers counter-clockwise from 20, the order of the image sectors after the one the user picked
constexpr std::array<int, 20> kSectorsCounterClockwiseFromTwenty = {20, 5, 12, 9, 14, 11, 8, 16, 7, 19, 3, 17, 2, 15, 10, 6, 13, 4, 18, 1};
// Provisional quality gate in board millimetres on held-out wires, as in the setup GUI; #48 sets the error budget.
constexpr double kGoodHeldOut_mm = 0.5;
constexpr double kFairHeldOut_mm = 1.0;

// The board image: a square of 600 px with the board and a little of its surround, sharp up to the outer edge of the
// number ring, from a few frames averaged against noise
constexpr int kBoardImageSize_px = 600;
constexpr double kBoardImageRadius_mm = 250.0;
constexpr double kBoardImageSharp_mm = 222.0;
constexpr int kBoardImageFrames = 5;

// Calibration monitoring, as the setup GUI's check: a fresh detection matches its own refinement within 0.4 to 1.0 mm in
// the light it was made in and within about 1.6 mm under other light; a camera that moved or sits on another port is
// off by far more. Another camera's calibration that fits kSwapFactor times better marks swapped ports.
constexpr double kGoodCheck_mm = 1.0;
constexpr double kOffCheck_mm = 2.5;
constexpr double kSwapFactor = 3.0;
constexpr int kCheckFrames = 10;
constexpr auto kDetailedCheckInterval = std::chrono::seconds(2);
constexpr auto kBackgroundCheckInterval = std::chrono::seconds(60);

json point (const cv::Point2f& p) { return {p.x, p.y}; }

std::string utcNow ()
{
    const std::time_t now = std::time(nullptr);
    std::tm utc{};
    gmtime_r(&now, &utc);
    std::array<char, 32> text{};
    std::strftime(text.data(), text.size(), "%Y-%m-%dT%H:%M:%SZ", &utc);
    return text.data();
}

std::string lensSource (geometry::IntrinsicsSource source)
{
    switch(source)
    {
        case geometry::IntrinsicsSource::OwnCalibration:
            return "own";
        case geometry::IntrinsicsSource::ModelPrior:
            return "model";
        case geometry::IntrinsicsSource::BoardOnly:
            return "board";
    }
    return "board";
}
}  // namespace

CalibrationService::CalibrationService (api::Server& server, const FrameFeed& previews, std::vector<capture::CameraDevice> devices,
                                        std::filesystem::path calibration_directory, std::chrono::steady_clock::time_point started)
    : server_(server)
    , previews_(previews)
    , devices_(std::move(devices))
    , directory_(std::move(calibration_directory))
    , cameras_started_(started)
    , detections_(devices_.size())
    , checks_(devices_.size())
{
    server_.setCalibrationStatus(status());
    server_.onCalibration([this] (const api::CalibrationRequest& request) { return handle(request); });
    checker_ = std::thread([this] { runChecks(); });
}

CalibrationService::~CalibrationService ()
{
    server_.onCalibration({});
    stop_ = true;
    if(checker_.joinable())
    {
        checker_.join();
    }
    std::lock_guard lock(mutex_);
    if(worker_.joinable())
    {
        worker_.join();
    }
}

std::optional<std::size_t> CalibrationService::cameraIndex (const json& body) const
{
    const std::string id = body.value("camera", std::string());
    for(std::size_t i = 0; i < devices_.size(); ++i)
    {
        if("usb-" + devices_[i].usb_port == id)
        {
            return i;
        }
    }
    return std::nullopt;
}

bool CalibrationService::startJob (std::function<json()> job)
{
    if(busy_.exchange(true))
    {
        return false;
    }
    std::lock_guard lock(mutex_);
    if(worker_.joinable())
    {
        worker_.join();
    }
    worker_ = std::thread(
        [this, job = std::move(job)]
        {
            // A failing step must not take the engine down with it.
            json last;
            try
            {
                last = job();
            }
            catch(const std::exception& error)
            {
                std::fprintf(stderr, "Calibration step failed: %s\n", error.what());
            }
            busy_ = false;
            if(!last.is_null())
            {
                server_.publishEvent(last);
            }
        });
    return true;
}

std::optional<api::Server::CalibrationError> CalibrationService::handle (const api::CalibrationRequest& request)
{
    const auto busy = api::Server::CalibrationError{"busy", "Another calibration step is running"};
    if(request.type == "subscribe_calibration_check" || request.type == "unsubscribe_calibration_check")
    {
        if(request.type == "subscribe_calibration_check")
        {
            ++subscribers_;
        }
        else if(subscribers_ > 0)
        {
            --subscribers_;
        }
        return std::nullopt;
    }
    if(request.type == "tune_white_balance")
    {
        return startJob([this] { return tuneWhiteBalance(); }) ? std::nullopt : std::optional(busy);
    }
    if(request.type == "get_board_image")
    {
        if(!geometry::loadExtrinsics((directory_ / geometry::kExtrinsicsFileName).string()))
        {
            return api::Server::CalibrationError{"not_calibrated", "The cameras are not refined yet"};
        }
        const int size_px = std::clamp(request.body.value("size_px", kBoardImageSize_px), 64, 2048);
        const double radius_mm = std::clamp(request.body.value("radius_mm", kBoardImageRadius_mm), 100.0, 300.0);
        return startJob([this, size_px, radius_mm] { return boardImage(size_px, radius_mm); }) ? std::nullopt : std::optional(busy);
    }
    if(request.type == "refine_cameras")
    {
        if(geometry::refinementInputs(directory_, setupCameras(), mode_).empty())
        {
            return api::Server::CalibrationError{"no_board_planes", "No camera has a measured board yet"};
        }
        return startJob([this] { return refine(); }) ? std::nullopt : std::optional(busy);
    }
    const auto camera = cameraIndex(request.body);
    if(!camera)
    {
        return api::Server::CalibrationError{"unknown_camera", "No camera " + request.body.value("camera", std::string())};
    }
    if(request.type == "detect_board")
    {
        return startJob([this, c = *camera] { return detectBoard(c); }) ? std::nullopt : std::optional(busy);
    }
    if(request.type == "set_sector_20")
    {
        const auto& p = request.body.at("point_px");
        return setSectorTwenty(*camera, cv::Point2f(p.at(0).get<float>(), p.at(1).get<float>()));
    }
    return api::Server::CalibrationError{"unknown_type", "Unknown calibration request " + request.type};
}

void CalibrationService::waitInterruptibly (std::chrono::steady_clock::duration duration)
{
    const auto end = std::chrono::steady_clock::now() + duration;
    while(!stop_ && std::chrono::steady_clock::now() < end)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
}

cv::Mat CalibrationService::averageFrames (std::size_t camera, int count)
{
    cv::Mat sum;
    int summed = 0;
    std::optional<std::uint32_t> last;
    const auto give_up = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while(summed < count && !stop_ && std::chrono::steady_clock::now() < give_up)
    {
        std::vector<std::uint8_t> jpeg;
        std::uint32_t sequence = 0;
        if(!previews_.latest(camera, jpeg, sequence) || (last && *last == sequence))
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            continue;
        }
        last = sequence;
        const cv::Mat image = cv::imdecode(jpeg, cv::IMREAD_COLOR);
        if(image.empty())
        {
            continue;
        }
        if(sum.empty())
        {
            sum = cv::Mat::zeros(image.size(), CV_32FC3);
        }
        cv::accumulate(image, sum);
        ++summed;
    }
    if(summed < count)
    {
        return {};
    }
    cv::Mat mean;
    sum.convertTo(mean, CV_8UC3, 1.0 / summed);
    return mean;
}

json CalibrationService::detectBoard (std::size_t camera)
{
    const cv::Mat image = averageFrames(camera, kDetectionFrames);
    const auto detection = image.empty() ? std::nullopt : geometry::detectBoard(image);
    {
        std::lock_guard lock(mutex_);
        detections_[camera] = detection;
    }
    json message = {{"type", "board_detection"},
                    {"camera", "usb-" + devices_[camera].usb_port},
                    {"ok", detection.has_value()},
                    {"code", detection ? "found" : "not_found"},
                    {"image_size_px", {image.cols, image.rows}},
                    {"ellipses", json::array()},
                    {"wires_px", json::array()},
                    {"points_px", json::array()}};
    if(detection)
    {
        for(const auto& circle : detection->circles)
        {
            message["ellipses"].push_back(
                {{"center_px", point(circle.center)}, {"axes_px", {circle.size.width / 2.0, circle.size.height / 2.0}}, {"angle_deg", circle.angle}});
        }
        // From the bull to a little beyond the double ring
        const auto& outer = detection->circles.back();
        const float reach_px = 0.6f * std::max(outer.size.width, outer.size.height);
        for(const auto& wire : detection->wires)
        {
            message["wires_px"].push_back({wire[0], wire[1], wire[0] + wire[2] * reach_px, wire[1] + wire[3] * reach_px});
        }
        for(const auto& p : detection->points)
        {
            message["points_px"].push_back(point(p.image_px));
        }
    }
    return message;
}

std::optional<api::Server::CalibrationError> CalibrationService::setSectorTwenty (std::size_t camera, const cv::Point2f& point_px)
{
    std::optional<geometry::BoardDetection> detection;
    {
        std::lock_guard lock(mutex_);
        detection = detections_[camera];
    }
    if(!detection)
    {
        return api::Server::CalibrationError{"no_detection", "Detect the board of this camera first"};
    }
    const auto twenty = geometry::sectorAt(*detection, point_px);
    if(!twenty)
    {
        return api::Server::CalibrationError{"outside_board", "The point is not in a sector of the board"};
    }
    const std::string& usb_port = devices_[camera].usb_port;
    geometry::StoredBoardPlane plane;
    plane.twenty_sector = *twenty;
    plane.usb_port = usb_port;
    plane.created = utcNow();
    plane.correspondences = geometry::orientBoard(*detection, *twenty);
    const auto lens = geometry::referenceIntrinsics(directory_, usb_port, mode_);
    const auto fit = geometry::fitBoardPlane(plane.correspondences, lens ? &lens->calibration : nullptr);
    if(!fit)
    {
        return api::Server::CalibrationError{"fit_failed", "The board plane could not be fitted"};
    }
    plane.fit = *fit;
    std::error_code error;
    std::filesystem::create_directories(directory_, error);
    if(!geometry::saveBoardPlane((directory_ / geometry::boardPlaneFileName(usb_port)).string(), plane))
    {
        return api::Server::CalibrationError{"save_failed", "Cannot write the board plane"};
    }
    json sectors = json::array();
    for(int s = 0; s < geometry::kRadialWireCount; ++s)
    {
        cv::Point2f sum(0, 0);
        int n = 0;
        for(const auto& p : detection->points)
        {
            if((p.wire == s || p.wire == (s + 1) % geometry::kRadialWireCount) && p.circle != geometry::BoardCircle::OuterBull)
            {
                sum += p.image_px;
                ++n;
            }
        }
        if(n > 0)
        {
            const int number = kSectorsCounterClockwiseFromTwenty[(s - *twenty + geometry::kRadialWireCount) % geometry::kRadialWireCount];
            sectors.push_back({{"sector", number}, {"label_px", point(sum * (1.0f / static_cast<float>(n)))}});
        }
    }
    server_.publishEvent({{"type", "board_plane"},
                          {"camera", "usb-" + usb_port},
                          {"fit_mm", fit->rms_mm},
                          {"worst_mm", fit->worst_mm},
                          {"rms_px", fit->rms_px},
                          {"lens_corrected", fit->undistorted},
                          {"sectors", sectors}});
    publishStatus();
    return std::nullopt;
}

json CalibrationService::refine ()
{
    server_.publishEvent({{"type", "refinement"}, {"state", "running"}});
    const auto inputs = geometry::refinementInputs(directory_, setupCameras(), mode_);
    const auto refinement = inputs.empty() ? std::nullopt : geometry::refineBoardCameras(inputs);
    if(!refinement)
    {
        return {{"type", "refinement"}, {"state", "failed"}, {"code", inputs.empty() ? "no_board_planes" : "pose_failed"}};
    }
    geometry::StoredExtrinsics stored;
    stored.created = utcNow();
    stored.refinement = *refinement;
    stored.inputs = inputs;
    std::error_code error;
    std::filesystem::create_directories(directory_, error);
    if(!geometry::saveExtrinsics((directory_ / geometry::kExtrinsicsFileName).string(), stored))
    {
        return {{"type", "refinement"}, {"state", "failed"}, {"code", "save_failed"}};
    }
    json cameras = json::array();
    for(const auto& camera : refinement->cameras)
    {
        const double held_out_mm = camera.held_out_rms_mm;
        const std::string quality = held_out_mm <= kGoodHeldOut_mm ? "good" : held_out_mm <= kFairHeldOut_mm ? "fair" : "poor";
        json advice = nullptr;
        if(quality != "good")
        {
            advice = camera.source == geometry::IntrinsicsSource::OwnCalibration ? "detect_again" : "lens_calibration";
        }
        cameras.push_back({{"camera", "usb-" + camera.usb_port},
                           {"held_out_mm", held_out_mm},
                           {"quality", quality},
                           {"uncertainty_mm", camera.uncertainty_mm},
                           {"focal_px", camera.intrinsics.camera_matrix(0, 0)},
                           {"lens_from", lensSource(camera.source)},
                           {"advice", advice}});
    }
    publishStatus();
    const auto& radii = refinement->board.radii_mm;
    return {{"type", "refinement"},
            {"state", "done"},
            {"cameras", cameras},
            {"board",
             {{"outer_bull_mm", radii[static_cast<int>(geometry::BoardCircle::OuterBull)]},
              {"treble_centre_mm", radii[static_cast<int>(geometry::BoardCircle::TripleCentre)]}}}};
}

json CalibrationService::tuneWhiteBalance ()
{
    std::vector<SweepCamera> sweep;
    for(const auto& device : devices_)
    {
        sweep.push_back({device.path, {}});
    }
    const auto message = [&] (const std::string& state, std::optional<int> kelvin_now, bool chosen)
    {
        json cameras = json::array();
        for(std::size_t c = 0; c < sweep.size(); ++c)
        {
            json found_at = json::array();
            for(const auto& [kelvin, found] : sweep[c].found_at_K)
            {
                found_at.push_back({{"kelvin", kelvin}, {"found", found}});
            }
            json camera = {{"camera", "usb-" + devices_[c].usb_port}, {"found_at", found_at}, {"chosen_kelvin", nullptr}};
            if(chosen)
            {
                if(const auto kelvin = capture::chooseWhiteBalance(sweep[c].found_at_K))
                {
                    camera["chosen_kelvin"] = *kelvin;
                }
                else
                {
                    camera["code"] = "board_not_found_at_any";
                }
            }
            cameras.push_back(camera);
        }
        json event = {{"type", "white_balance"}, {"state", state}, {"cameras", cameras}};
        if(kelvin_now)
        {
            event["kelvin_now"] = *kelvin_now;
        }
        if(state == "settling")
        {
            event["settle_s"] =
                std::max(0.0, std::chrono::duration<double>(cameras_started_ + kExposureSettle - std::chrono::steady_clock::now()).count());
        }
        return event;
    };
    server_.publishEvent(message("settling", std::nullopt, false));
    waitInterruptibly(cameras_started_ + kExposureSettle - std::chrono::steady_clock::now());
    server_.publishEvent(message("sweeping", capture::kMinWhiteBalance_K, false));
    const bool complete = sweepWhiteBalance(
        sweep, [this] (std::chrono::steady_clock::duration duration) { waitInterruptibly(duration); }, [this] (std::size_t c)
        { return averageFrames(c, kWhiteBalanceFrames); }, [&] (int kelvin) { server_.publishEvent(message("sweeping", kelvin, false)); }, stop_);
    bool any_failed = !complete;
    for(std::size_t c = 0; complete && c < sweep.size(); ++c)
    {
        const auto path = directory_ / capture::whiteBalanceFileName(devices_[c].usb_port);
        const auto chosen = capture::chooseWhiteBalance(sweep[c].found_at_K);
        std::error_code error;
        std::filesystem::create_directories(directory_, error);
        if(!chosen || !capture::saveWhiteBalance(path.string(), *chosen, sweep[c].found_at_K))
        {
            any_failed = true;
        }
        // The camera keeps the stored value, or its previous one if none was found.
        capture::CameraControls(devices_[c].path).set(V4L2_CID_WHITE_BALANCE_TEMPERATURE, capture::storedWhiteBalance(path.string()));
    }
    publishStatus();
    return message(any_failed ? "failed" : "done", std::nullopt, true);
}

json CalibrationService::boardImage (int size_px, double radius_mm)
{
    const auto extrinsics = geometry::loadExtrinsics((directory_ / geometry::kExtrinsicsFileName).string());
    std::vector<const geometry::RefinedCamera*> cameras;
    std::vector<cv::Mat> images;
    for(std::size_t c = 0; c < devices_.size(); ++c)
    {
        const geometry::RefinedCamera* camera = nullptr;
        for(std::size_t r = 0; extrinsics && r < extrinsics->refinement.cameras.size(); ++r)
        {
            if(extrinsics->refinement.cameras[r].usb_port == devices_[c].usb_port)
            {
                camera = &extrinsics->refinement.cameras[r];
            }
        }
        cameras.push_back(camera);
        images.push_back(camera ? averageFrames(c, kBoardImageFrames) : cv::Mat());
    }
    const auto view = geometry::renderBoardView(cameras, images, size_px, radius_mm, std::min(radius_mm, kBoardImageSharp_mm));
    std::vector<std::uint8_t> jpeg;
    cv::imencode(".jpg", view.image, jpeg, {cv::IMWRITE_JPEG_QUALITY, 90});
    return {{"type", "board_image"},
            {"image_size_px", {view.image.cols, view.image.rows}},
            {"mm_per_px", view.mm_per_px},
            {"radius_mm", view.radius_mm},
            {"jpeg_base64", base64(jpeg)}};
}

void CalibrationService::runChecks ()
{
    auto last = std::chrono::steady_clock::now() - kBackgroundCheckInterval;
    while(!stop_)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        const auto now = std::chrono::steady_clock::now();
        const bool detailed = subscribers_ > 0;
        // In the background also while the board check sees something: a knocked camera makes it see the whole board as
        // changed, and that is exactly when the check must run. Darts that hide the board keep the previous verdict.
        const bool due = now - last >= (detailed ? kDetailedCheckInterval : kBackgroundCheckInterval);
        if(!due || busy_)
        {
            continue;
        }
        last = now;
        const auto extrinsics = geometry::loadExtrinsics((directory_ / geometry::kExtrinsicsFileName).string());
        for(std::size_t c = 0; c < devices_.size() && !stop_; ++c)
        {
            CameraCheck summary;
            const json event = checkCamera(c, extrinsics ? &*extrinsics : nullptr, summary);
            {
                std::lock_guard lock(checks_mutex_);
                if(summary.state != "no_board" || checks_[c].state.empty() || detailed)
                {
                    checks_[c] = summary;
                }
            }
            if(subscribers_ > 0)
            {
                server_.publishEvent(event);
            }
        }
        publishStatus();
    }
}

json CalibrationService::checkCamera (std::size_t camera, const geometry::StoredExtrinsics* extrinsics, CameraCheck& summary)
{
    const std::string& port = devices_[camera].usb_port;
    json event = {{"type", "calibration_check"},  {"camera", "usb-" + port},   {"mm", nullptr},          {"shift_px", nullptr}, {"count", 0},
                  {"expected_px", json::array()}, {"found_px", json::array()}, {"image_size_px", {0, 0}}};
    summary.checked_at = utcNow();
    const geometry::RefinedCamera* own = nullptr;
    for(std::size_t r = 0; extrinsics && r < extrinsics->refinement.cameras.size(); ++r)
    {
        if(extrinsics->refinement.cameras[r].usb_port == port)
        {
            own = &extrinsics->refinement.cameras[r];
        }
    }
    if(!own)
    {
        summary.state = "not_calibrated";
        event["state"] = summary.state;
        return event;
    }
    const cv::Mat image = averageFrames(camera, kCheckFrames);
    event["image_size_px"] = {image.cols, image.rows};
    const auto detection = image.empty() ? std::nullopt : geometry::detectBoard(image);
    if(!detection)
    {
        summary.state = "no_board";
        event["state"] = summary.state;
        return event;
    }
    const auto check = geometry::checkCalibration(*detection, *own, extrinsics->refinement.board);
    // Another camera's calibration that fits far better means the cameras were plugged into other ports.
    std::optional<geometry::CalibrationCheck> best_other;
    std::string other_port;
    for(const auto& refined : extrinsics->refinement.cameras)
    {
        if(refined.usb_port == port)
        {
            continue;
        }
        auto other = geometry::checkCalibration(*detection, refined, extrinsics->refinement.board);
        if(other && (!best_other || other->rms_mm < best_other->rms_mm))
        {
            best_other = std::move(other);
            other_port = refined.usb_port;
        }
    }
    if(!check)
    {
        summary.state = "no_board";
        event["state"] = summary.state;
        return event;
    }
    summary.mm = check->rms_mm;
    const bool swapped = best_other && best_other->rms_mm * kSwapFactor <= check->rms_mm && best_other->rms_mm <= kOffCheck_mm;
    summary.state = swapped ? "wrong_port" : check->rms_mm <= kGoodCheck_mm ? "ok" : check->rms_mm <= kOffCheck_mm ? "off" : "moved";
    event["state"] = summary.state;
    event["mm"] = check->rms_mm;
    event["shift_px"] = {check->mean_shift_px.x, check->mean_shift_px.y};
    event["count"] = check->points;
    for(std::size_t i = 0; i < detection->points.size() && i < check->predicted_px.size(); ++i)
    {
        event["found_px"].push_back(point(detection->points[i].image_px));
        event["expected_px"].push_back(point(check->predicted_px[i]));
    }
    if(swapped)
    {
        event["fits_camera"] = "usb-" + other_port;
    }
    return event;
}

std::vector<geometry::SetupCamera> CalibrationService::setupCameras () const
{
    std::vector<geometry::SetupCamera> cameras;
    for(const auto& device : devices_)
    {
        cameras.push_back({device.usb_port, device.name});
    }
    return cameras;
}

json CalibrationService::status () const
{
    const auto extrinsics = geometry::loadExtrinsics((directory_ / geometry::kExtrinsicsFileName).string());
    json cameras = json::array();
    for(const auto& device : devices_)
    {
        json camera = {{"camera", "usb-" + device.usb_port}};
        if(geometry::referenceIntrinsics(directory_, device.usb_port, mode_))
        {
            camera["intrinsics"] = "valid";
        }
        else if(geometry::loadIntrinsics((directory_ / geometry::intrinsicsFileName(device.usb_port)).string()))
        {
            camera["intrinsics"] = "invalid";
            camera["intrinsics_reason"] = "other_capture_mode";
        }
        else
        {
            camera["intrinsics"] = "none";
        }
        const auto plane = geometry::loadBoardPlane((directory_ / geometry::boardPlaneFileName(device.usb_port)).string());
        camera["board_plane_mm"] = plane ? json(plane->fit.rms_mm) : json(nullptr);
        bool refined = false;
        for(const auto& refined_camera : extrinsics ? extrinsics->refinement.cameras : std::vector<geometry::RefinedCamera>{})
        {
            refined = refined || refined_camera.usb_port == device.usb_port;
        }
        camera["refined"] = refined;
        camera["white_balance_kelvin"] = capture::storedWhiteBalance((directory_ / capture::whiteBalanceFileName(device.usb_port)).string());
        {
            std::lock_guard lock(checks_mutex_);
            const auto& check = checks_[&device - devices_.data()];
            camera["check"] =
                check.state.empty()
                    ? json(nullptr)
                    : json{{"state", check.state}, {"mm", check.mm ? json(*check.mm) : json(nullptr)}, {"checked_at", check.checked_at}};
        }
        cameras.push_back(camera);
    }
    return {{"cameras", cameras},
            {"refinement_stale",
             extrinsics ? geometry::refinementStale(*extrinsics, geometry::refinementInputs(directory_, setupCameras(), mode_)) : false},
            {"extrinsics_created", extrinsics ? json(extrinsics->created) : json(nullptr)}};
}

void CalibrationService::publishStatus () { server_.setCalibrationStatus(status()); }
}  // namespace dartpilot::cli
