#pragma once

#include <optional>
#include <string>
#include <vector>

#include "dartpilot/event_detection/event_detection.hpp"
#include "dartpilot/fusion/dart_tracker.hpp"

// Every value of the live detection path in one place (#195): when the board counts as still, how a dart is found per
// camera, when cameras agree on its point, when the board counts as occupied or empty, and the confidences sent with a
// throw. Each has a name, the pipeline stage it belongs to, a description, a unit, a default and a range, so that it can
// be changed while the engine runs, recorded with every result and replayed. docs/detection-params.md lists them.
namespace dartpilot::fusion
{
// Confidence sent with a throw, by the number of cameras that agree, and with an abstention (provisional, #48)
struct ConfidenceSettings
{
    double two_cameras = 0.8;
    double three_cameras = 0.95;
    double abstained = 0.3;
};

struct DetectionSettings
{
    event_detection::StillSettings still;
    TrackerSettings tracker;
    ConfidenceSettings confidence;
};

struct DetectionParam
{
    std::string name;
    // The pipeline stage: event_detection, tip_candidates, geometry or fusion
    std::string group;
    std::string description;
    std::string unit;
    double min = 0.0;
    double max = 0.0;
    // 1 or more for whole numbers
    double step = 0.0;
    double (*get)(const DetectionSettings&) = nullptr;
    void (*set)(DetectionSettings&, double) = nullptr;

    double defaultValue () const { return get(DetectionSettings{}); }
};

// In the order of the pipeline
const std::vector<DetectionParam>& detectionParams ();
const DetectionParam* findDetectionParam (const std::string& name);

// Sets one value; whole-number values are rounded. An error for an unknown name or a value out of range, which leaves
// the settings as they were.
std::optional<std::string> setDetectionParam (DetectionSettings& settings, const std::string& name, double value);

// The table of docs/detection-params.md
std::string detectionParamsMarkdown ();
}  // namespace dartpilot::fusion
