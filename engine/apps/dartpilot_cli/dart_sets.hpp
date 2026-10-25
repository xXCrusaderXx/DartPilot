#pragma once

#include <filesystem>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

#include "dartpilot/api/server.hpp"
#include "dartpilot/capture/v4l2_device.hpp"
#include "dartpilot/geometry/dart_shape.hpp"
#include "live_detection.hpp"

// The player's darts (#120): a dart set is measured by putting one of its darts into the board at a few places, and
// stored with its dimensions and a picture of the dart from every camera in calibration/dart-sets. The app names the
// set that the player at the board throws; detection does not use it yet (the profile is an optional refinement and
// first has to show its benefit on recordings).
namespace dartpilot::cli
{
class DartSets
{
   public:
    DartSets (api::Server& server, LiveDetection& detection, const std::vector<capture::CameraDevice>& devices,
              const std::filesystem::path& calibration_directory);
    ~DartSets ();

    // Placements a new set needs
    static constexpr int kPlacements = 4;

   private:
    struct Set
    {
        std::string id;
        std::string name;
        std::string created_utc;
        // Dimensions by where they come from: measured in the board, from a photo on the measuring sheet, entered by
        // the user. The set's dimensions take each value from the first of entered, photo, measured that has it.
        nlohmann::json measured = nlohmann::json::object();
        nlohmann::json photo = nlohmann::json::object();
        nlohmann::json entered = nlohmann::json::object();
        // One per placement: board point and the dimensions measured there
        nlohmann::json placements = nlohmann::json::array();
        std::vector<std::string> cameras;
    };

    struct Capture
    {
        std::string name;
        std::string state;
        std::string reason;
        nlohmann::json camera_states = nlohmann::json::array();
        std::vector<geometry::DartShape> shapes;
        std::vector<cv::Point2f> points_mm;
        // The clearest picture of the dart per camera so far, and how much of the dart it shows
        std::vector<cv::Mat> crops;
        std::vector<int> crop_areas;
        // The board at the last still moment before the dart was put in: once it looks like that again, the dart was
        // pulled. Waiting for the tracker's takeout instead would hang on a trace the dart left, or on an outdated
        // empty board.
        std::vector<cv::Mat> before;
    };

    std::optional<api::Server::CalibrationError> start (const std::string& name);
    // A set from entered dimensions only, without measuring
    std::optional<api::Server::CalibrationError> create (const std::string& name, const nlohmann::json& dims);
    // Enters or corrects dimensions (null removes an entered value, so the measured one counts again)
    std::optional<api::Server::CalibrationError> update (const std::string& id, const nlohmann::json& dims);
    // Measures the set's dart on a photo of the dart sheet (geometry::measureDartPhoto) into its photo dimensions
    std::optional<api::Server::CalibrationError> measurePhoto (const std::string& id, const std::string& jpeg_base64);
    void cancel ();
    // On the detection thread
    void onUpdate (const fusion::TrackerUpdate& update, const std::vector<cv::Mat>& means);
    void finish ();
    void load ();
    bool save (const Set& set) const;
    nlohmann::json setJson (const Set& set) const;
    void publishSets ();
    void publishCapture ();
    std::filesystem::path directory () const { return calibration_directory_ / "dart-sets"; }

    api::Server& server_;
    LiveDetection& detection_;
    std::vector<std::string> ports_;
    std::filesystem::path calibration_directory_;
    std::optional<geometry::StoredExtrinsics> extrinsics_;
    // The calibration of each camera, in the order of the tracker's cameras; null without one
    std::vector<const geometry::RefinedCamera*> calibrations_;

    mutable std::mutex mutex_;
    std::vector<Set> sets_;
    std::optional<std::string> active_;
    std::optional<Capture> capture_;
};
}  // namespace dartpilot::cli
