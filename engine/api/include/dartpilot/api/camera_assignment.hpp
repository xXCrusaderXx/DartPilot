#pragma once

#include <filesystem>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

// Which camera is first, second, third, and what the user calls it (#198), kept by the engine so that every app sees
// the same assignment. Stored per camera id (the USB port) in a file next to the calibration; cameras that are not
// connected keep their entry.
namespace dartpilot::api
{
class CameraAssignment
{
   public:
    // store: the file; empty keeps the assignment in memory only. connected: the ids of the cameras now connected.
    CameraAssignment (std::filesystem::path store, std::vector<std::string> connected);

    // {type: "camera_assignment", cameras: [{id, order, label, connected}]}, connected cameras first, then by order
    nlohmann::json message () const;

    struct Error
    {
        std::string code;
        std::string message;
    };
    // cameras: [{id, order (1-based or null), label (or null)}]; listed cameras are replaced, others kept. Refused as a
    // whole for an unknown id (unknown_camera), or an order used twice or out of range (bad_request).
    std::optional<Error> set (const nlohmann::json& cameras);

   private:
    struct Entry
    {
        std::optional<int> order;
        std::optional<std::string> label;
    };
    void save () const;

    std::filesystem::path store_;
    std::vector<std::string> connected_;
    mutable std::mutex mutex_;
    std::map<std::string, Entry> entries_;
};
}  // namespace dartpilot::api
