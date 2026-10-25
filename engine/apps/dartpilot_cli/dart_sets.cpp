#include "dart_sets.hpp"

#include <algorithm>
#include <fstream>
#include <random>

#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>

#include "base64.hpp"
#include "dartpilot/session/session_writer.hpp"

namespace dartpilot::cli
{
using json = nlohmann::json;

namespace
{
// Space around the dart in its picture
constexpr int kCropMargin_px = 24;
// A set's dimensions are the medians of its placements; a placement whose length differs from the median by more than
// this is a mismeasurement and left out
constexpr double kOutlier_mm = 10.0;

double median (std::vector<double> values)
{
    std::nth_element(values.begin(), values.begin() + values.size() / 2, values.end());
    return values[values.size() / 2];
}

json dimsJson (const geometry::DartShape& shape)
{
    return {{"total_mm", shape.total_mm},
            {"barrel_mm", shape.barrel_mm},
            {"barrel_diameter_mm", shape.barrel_diameter_mm},
            {"flight_mm", shape.flight_mm}};
}

std::string newId ()
{
    std::random_device random;
    char id[9];
    std::snprintf(id, sizeof(id), "%08x", random());
    return id;
}

// The smallest rectangle around the set pixels of a mask
cv::Rect boundingBox (const cv::Mat& mask)
{
    std::vector<cv::Point> points;
    cv::findNonZero(mask, points);
    if(points.empty())
    {
        return {};
    }
    int x0 = points[0].x, y0 = points[0].y, x1 = x0, y1 = y0;
    for(const auto& p : points)
    {
        x0 = std::min(x0, p.x);
        y0 = std::min(y0, p.y);
        x1 = std::max(x1, p.x);
        y1 = std::max(y1, p.y);
    }
    return {x0, y0, x1 - x0 + 1, y1 - y0 + 1};
}
}  // namespace

DartSets::DartSets (api::Server& server, LiveDetection& detection, const std::vector<capture::CameraDevice>& devices,
                    const std::filesystem::path& calibration_directory)
    : server_(server)
    , detection_(detection)
    , calibration_directory_(calibration_directory)
    , extrinsics_(geometry::loadExtrinsics((calibration_directory / "extrinsics.yml").string()))
{
    for(const auto& device : devices)
    {
        ports_.push_back(device.usb_port);
        const geometry::RefinedCamera* calibration = nullptr;
        if(extrinsics_)
        {
            for(const auto& refined : extrinsics_->refinement.cameras)
            {
                if(refined.usb_port == device.usb_port)
                {
                    calibration = &refined;
                }
            }
        }
        calibrations_.push_back(calibration);
    }
    load();
    using Error = std::optional<api::Server::CalibrationError>;
    server_.onCalibrationRequest("list_dart_sets",
                                 [this] (const api::CalibrationRequest&) -> Error
                                 {
                                     publishSets();
                                     return std::nullopt;
                                 });
    server_.onCalibrationRequest("start_dart_set",
                                 [this] (const api::CalibrationRequest& request) { return start(request.body.value("name", std::string())); });
    server_.onCalibrationRequest("cancel_dart_set",
                                 [this] (const api::CalibrationRequest&) -> Error
                                 {
                                     cancel();
                                     return std::nullopt;
                                 });
    server_.onCalibrationRequest(
        "get_dart_set_image",
        [this] (const api::CalibrationRequest& request) -> Error
        {
            const std::string id = request.body.value("id", std::string());
            const std::string camera = request.body.value("camera", std::string());
            {
                std::lock_guard lock(mutex_);
                if(std::none_of(sets_.begin(), sets_.end(), [&] (const Set& s) { return s.id == id; }))
                {
                    return api::Server::CalibrationError{"unknown_set", "No dart set " + id};
                }
            }
            std::ifstream in(directory() / (id + "-" + camera + ".jpg"), std::ios::binary);
            if(!in)
            {
                return api::Server::CalibrationError{"unknown_camera", "No picture of set " + id + " from " + camera};
            }
            const std::vector<std::uint8_t> jpeg((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
            server_.publishEvent({{"type", "dart_set_image"}, {"id", id}, {"camera", camera}, {"jpeg_base64", base64(jpeg)}});
            return std::nullopt;
        });
    server_.onCalibrationRequest("rename_dart_set",
                                 [this] (const api::CalibrationRequest& request) -> Error
                                 {
                                     const std::string id = request.body.value("id", std::string());
                                     const std::string name = request.body.value("name", std::string());
                                     if(name.empty())
                                     {
                                         return api::Server::CalibrationError{"bad_request", "A dart set needs a name"};
                                     }
                                     {
                                         std::lock_guard lock(mutex_);
                                         const auto it = std::find_if(sets_.begin(), sets_.end(), [&] (const Set& s) { return s.id == id; });
                                         if(it == sets_.end())
                                         {
                                             return api::Server::CalibrationError{"unknown_set", "No dart set " + id};
                                         }
                                         it->name = name;
                                         if(!save(*it))
                                         {
                                             return api::Server::CalibrationError{"save_failed", "Cannot write the dart set"};
                                         }
                                     }
                                     publishSets();
                                     return std::nullopt;
                                 });
    server_.onCalibrationRequest("delete_dart_set",
                                 [this] (const api::CalibrationRequest& request) -> Error
                                 {
                                     const std::string id = request.body.value("id", std::string());
                                     {
                                         std::lock_guard lock(mutex_);
                                         const auto it = std::find_if(sets_.begin(), sets_.end(), [&] (const Set& s) { return s.id == id; });
                                         if(it == sets_.end())
                                         {
                                             return api::Server::CalibrationError{"unknown_set", "No dart set " + id};
                                         }
                                         std::error_code ignored;
                                         std::filesystem::remove(directory() / (id + ".json"), ignored);
                                         for(const auto& camera : it->cameras)
                                         {
                                             std::filesystem::remove(directory() / (id + "-" + camera + ".jpg"), ignored);
                                         }
                                         sets_.erase(it);
                                         if(active_ == id)
                                         {
                                             active_.reset();
                                         }
                                     }
                                     publishSets();
                                     return std::nullopt;
                                 });
    server_.onCalibrationRequest(
        "set_active_darts",
        [this] (const api::CalibrationRequest& request) -> Error
        {
            const auto& id = request.body.contains("id") ? request.body["id"] : json(nullptr);
            {
                std::lock_guard lock(mutex_);
                if(id.is_null())
                {
                    active_.reset();
                }
                else if(!id.is_string() || std::none_of(sets_.begin(), sets_.end(), [&] (const Set& s) { return s.id == id.get<std::string>(); }))
                {
                    return api::Server::CalibrationError{"unknown_set", "No dart set " + id.dump()};
                }
                else
                {
                    active_ = id.get<std::string>();
                }
            }
            publishSets();
            return std::nullopt;
        });
    publishSets();
}

DartSets::~DartSets ()
{
    for(const char* type :
        {"list_dart_sets", "start_dart_set", "cancel_dart_set", "get_dart_set_image", "rename_dart_set", "delete_dart_set", "set_active_darts"})
    {
        server_.onCalibrationRequest(type, {});
    }
    bool capturing = false;
    {
        std::lock_guard lock(mutex_);
        capturing = capture_.has_value();
    }
    if(capturing)
    {
        detection_.intercept({});
    }
}

void DartSets::load ()
{
    std::error_code ignored;
    for(const auto& entry : std::filesystem::directory_iterator(directory(), ignored))
    {
        if(entry.path().extension() != ".json")
        {
            continue;
        }
        std::ifstream in(entry.path());
        const json stored = json::parse(in, nullptr, false);
        if(stored.is_discarded() || !stored.contains("id"))
        {
            continue;
        }
        Set set;
        set.id = stored.value("id", std::string());
        set.name = stored.value("name", std::string());
        set.created_utc = stored.value("created_utc", std::string());
        set.dims = stored.value("dims", json::object());
        set.placements = stored.value("placements", json::array());
        set.cameras = stored.value("cameras", std::vector<std::string>());
        sets_.push_back(std::move(set));
    }
    std::sort(sets_.begin(), sets_.end(), [] (const Set& a, const Set& b) { return a.created_utc < b.created_utc; });
}

bool DartSets::save (const Set& set) const
{
    std::error_code ignored;
    std::filesystem::create_directories(directory(), ignored);
    std::ofstream out(directory() / (set.id + ".json"));
    out << json{{"id", set.id},          {"name", set.name}, {"created_utc", set.created_utc}, {"dims", set.dims}, {"placements", set.placements},
                {"cameras", set.cameras}}
               .dump(2)
        << "\n";
    return static_cast<bool>(out);
}

json DartSets::setJson (const Set& set) const
{
    json images = json::array();
    for(const auto& camera : set.cameras)
    {
        images.push_back({{"camera", camera}});
    }
    return {{"id", set.id}, {"name", set.name}, {"dims", set.dims}, {"created_utc", set.created_utc}, {"images", images}};
}

void DartSets::publishSets ()
{
    json sets = json::array();
    json active = nullptr;
    {
        std::lock_guard lock(mutex_);
        for(const auto& set : sets_)
        {
            sets.push_back(setJson(set));
        }
        if(active_)
        {
            active = *active_;
        }
    }
    server_.publishState({{"type", "dart_sets"}, {"sets", sets}, {"active", active}});
}

void DartSets::publishCapture ()
{
    json message;
    {
        std::lock_guard lock(mutex_);
        if(!capture_)
        {
            return;
        }
        message = {{"type", "dart_set_capture"},
                   {"state", capture_->state},
                   {"waiting_for", capture_->state == "waiting"                                 ? "dart"
                                   : capture_->state == "placed" || capture_->state == "failed" ? "pull"
                                                                                                : ""},
                   {"placed", static_cast<int>(capture_->shapes.size())},
                   {"needed", kPlacements},
                   {"camera_states", capture_->camera_states}};
        if(!capture_->reason.empty())
        {
            message["reason"] = capture_->reason;
        }
        if(capture_->state == "done" && !sets_.empty())
        {
            message["set"] = setJson(sets_.back());
        }
    }
    server_.publishState(message);
}

std::optional<api::Server::CalibrationError> DartSets::start (const std::string& name)
{
    if(name.empty())
    {
        return api::Server::CalibrationError{"bad_request", "A dart set needs a name"};
    }
    if(!extrinsics_ || detection_.unavailableReason())
    {
        return api::Server::CalibrationError{"not_calibrated", "The cameras are not refined yet"};
    }
    {
        std::lock_guard lock(mutex_);
        if(capture_ || detection_.intercepted())
        {
            return api::Server::CalibrationError{"busy", "Another measurement is running"};
        }
        capture_ = Capture{};
        capture_->name = name;
        capture_->state = "waiting";
        capture_->crops.resize(ports_.size());
        capture_->crop_areas.assign(ports_.size(), 0);
    }
    detection_.intercept([this] (const fusion::TrackerUpdate& update, const std::vector<cv::Mat>& means) { onUpdate(update, means); });
    publishCapture();
    return std::nullopt;
}

void DartSets::cancel ()
{
    detection_.intercept({});
    {
        std::lock_guard lock(mutex_);
        if(!capture_)
        {
            return;
        }
        capture_->state = "cancelled";
    }
    publishCapture();
    std::lock_guard lock(mutex_);
    capture_.reset();
}

void DartSets::onUpdate (const fusion::TrackerUpdate& update, const std::vector<cv::Mat>& means)
{
    bool complete = false;
    {
        std::lock_guard lock(mutex_);
        if(!capture_)
        {
            return;
        }
        auto& capture = *capture_;
        if(capture.state == "placed" || capture.state == "failed")
        {
            int still_seen = 0;
            for(std::size_t c = 0; c < means.size() && c < capture.before.size(); ++c)
            {
                still_seen += !capture.before[c].empty() && tip_candidates::observeDart(means[c], capture.before[c]) ? 1 : 0;
            }
            // As the tracker decides a takeout: a dart stands out to at least two cameras.
            if(update.takeout || (!capture.before.empty() && still_seen <= 1))
            {
                capture.state = "waiting";
                capture.reason.clear();
            }
        }

        if(update.dart && capture.state == "waiting")
        {
            const auto& dart = *update.dart;
            capture.before = update.before;
            capture.camera_states = json::array();
            std::vector<geometry::DartView> views;
            for(std::size_t c = 0; c < dart.cameras.size() && c < ports_.size(); ++c)
            {
                capture.camera_states.push_back({{"camera", "usb-" + ports_[c]}, {"state", dart.cameras[c].state}});
                if(dart.cameras[c].observation && calibrations_[c])
                {
                    views.push_back({calibrations_[c], *dart.cameras[c].observation});
                }
            }
            std::optional<geometry::DartShape> shape;
            if(dart.location)
            {
                // locateDart counted the views of the cameras with an observation and a calibration, as built here.
                shape = geometry::measureDart(views, *dart.location);
            }
            if(!shape || shape->flight_mm <= 0.0)
            {
                capture.state = "failed";
                capture.reason = !dart.location ? dart.reason : "not_measured";
            }
            else
            {
                capture.shapes.push_back(*shape);
                capture.points_mm.push_back(dart.location->board_mm);
                capture.reason.clear();
                // The picture of each camera in which the dart covers the most pixels
                for(std::size_t c = 0; c < dart.cameras.size() && c < means.size() && c < ports_.size(); ++c)
                {
                    const auto& observation = dart.cameras[c].observation;
                    if(!observation || observation->cut || observation->area_px <= capture.crop_areas[c] || observation->mask.empty())
                    {
                        continue;
                    }
                    const cv::Rect box = (boundingBox(observation->mask) + cv::Size(2 * kCropMargin_px, 2 * kCropMargin_px) -
                                          cv::Point(kCropMargin_px, kCropMargin_px)) &
                                         cv::Rect(0, 0, means[c].cols, means[c].rows);
                    means[c](box).convertTo(capture.crops[c], CV_8UC3);
                    capture.crop_areas[c] = observation->area_px;
                }
                complete = static_cast<int>(capture.shapes.size()) >= kPlacements;
                capture.state = complete ? "measuring" : "placed";
            }
        }
    }
    if(complete)
    {
        detection_.intercept({});
        finish();
    }
    publishCapture();
    if(complete)
    {
        // The capture ends here, done or failed; the next one starts afresh.
        publishSets();
        std::lock_guard lock(mutex_);
        capture_.reset();
    }
}

void DartSets::finish ()
{
    std::lock_guard lock(mutex_);
    auto& capture = *capture_;
    std::vector<double> totals;
    for(const auto& shape : capture.shapes)
    {
        totals.push_back(shape.total_mm);
    }
    const double total = median(totals);
    std::vector<double> flight, barrel, diameter, kept_totals;
    Set set;
    set.id = newId();
    set.name = capture.name;
    set.created_utc = session::utcNow();
    for(std::size_t i = 0; i < capture.shapes.size(); ++i)
    {
        const auto& shape = capture.shapes[i];
        // The width along the axis, mm by mm, so that the split into point, barrel, shaft and flight can be checked
        std::vector<double> width;
        for(const double w : shape.width_mm)
        {
            width.push_back(std::round(w * 10.0) / 10.0);
        }
        set.placements.push_back({{"board_mm", {capture.points_mm[i].x, capture.points_mm[i].y}},
                                  {"dims", dimsJson(shape)},
                                  {"point_mm", shape.point_mm},
                                  {"width_mm", width}});
        if(std::abs(shape.total_mm - total) > kOutlier_mm)
        {
            continue;
        }
        kept_totals.push_back(shape.total_mm);
        flight.push_back(shape.flight_mm);
        barrel.push_back(shape.barrel_mm);
        diameter.push_back(shape.barrel_diameter_mm);
    }
    if(kept_totals.size() < 2)
    {
        capture.state = "failed";
        capture.reason = "placements_disagree";
        return;
    }
    set.dims = {
        {"total_mm", median(kept_totals)}, {"barrel_mm", median(barrel)}, {"barrel_diameter_mm", median(diameter)}, {"flight_mm", median(flight)}};
    std::error_code ignored;
    std::filesystem::create_directories(directory(), ignored);
    for(std::size_t c = 0; c < capture.crops.size(); ++c)
    {
        if(!capture.crops[c].empty() && cv::imwrite((directory() / (set.id + "-usb-" + ports_[c] + ".jpg")).string(), capture.crops[c]))
        {
            set.cameras.push_back("usb-" + ports_[c]);
        }
    }
    if(!save(set))
    {
        capture.state = "failed";
        capture.reason = "save_failed";
        return;
    }
    sets_.push_back(std::move(set));
    capture.state = "done";
}
}  // namespace dartpilot::cli
