#include "dartpilot/api/camera_assignment.hpp"

#include <algorithm>
#include <fstream>
#include <set>
#include <tuple>

namespace dartpilot::api
{
namespace
{
// More cameras than this are not expected around one board
constexpr int kMaxOrder = 16;
}  // namespace

CameraAssignment::CameraAssignment (std::filesystem::path store, std::vector<std::string> connected)
    : store_(std::move(store))
    , connected_(std::move(connected))
{
    if(store_.empty())
    {
        return;
    }
    std::ifstream in(store_);
    const auto stored = nlohmann::json::parse(in, nullptr, false);
    if(stored.is_discarded() || !stored.is_object())
    {
        return;
    }
    const auto cameras = stored.value("cameras", nlohmann::json::object());
    for(const auto& [id, entry] : cameras.items())
    {
        Entry e;
        if(entry.contains("order") && entry["order"].is_number_integer())
        {
            e.order = entry["order"].get<int>();
        }
        if(entry.contains("label") && entry["label"].is_string())
        {
            e.label = entry["label"].get<std::string>();
        }
        entries_[id] = e;
    }
}

void CameraAssignment::save () const
{
    if(store_.empty())
    {
        return;
    }
    nlohmann::json cameras = nlohmann::json::object();
    for(const auto& [id, e] : entries_)
    {
        cameras[id] = {{"order", e.order ? nlohmann::json(*e.order) : nlohmann::json(nullptr)},
                       {"label", e.label ? nlohmann::json(*e.label) : nlohmann::json(nullptr)}};
    }
    std::error_code ignored;
    std::filesystem::create_directories(store_.parent_path(), ignored);
    std::ofstream(store_) << nlohmann::json{{"cameras", cameras}}.dump(2) << "\n";
}

nlohmann::json CameraAssignment::message () const
{
    std::lock_guard lock(mutex_);
    std::set<std::string> ids(connected_.begin(), connected_.end());
    for(const auto& [id, e] : entries_)
    {
        ids.insert(id);
    }
    std::vector<std::string> order(ids.begin(), ids.end());
    const auto connected = [&] (const std::string& id) { return std::find(connected_.begin(), connected_.end(), id) != connected_.end(); };
    const auto rank = [&] (const std::string& id)
    {
        const auto it = entries_.find(id);
        return it != entries_.end() && it->second.order ? *it->second.order : kMaxOrder + 1;
    };
    std::stable_sort(order.begin(), order.end(), [&] (const std::string& a, const std::string& b)
                     { return std::make_tuple(!connected(a), rank(a)) < std::make_tuple(!connected(b), rank(b)); });
    nlohmann::json cameras = nlohmann::json::array();
    for(const auto& id : order)
    {
        const auto it = entries_.find(id);
        const Entry e = it != entries_.end() ? it->second : Entry{};
        cameras.push_back({{"id", id},
                           {"order", e.order ? nlohmann::json(*e.order) : nlohmann::json(nullptr)},
                           {"label", e.label ? nlohmann::json(*e.label) : nlohmann::json(nullptr)},
                           {"connected", connected(id)}});
    }
    return {{"type", "camera_assignment"}, {"cameras", cameras}};
}

std::optional<CameraAssignment::Error> CameraAssignment::set (const nlohmann::json& cameras)
{
    if(!cameras.is_array())
    {
        return Error{"bad_request", "cameras must be a list"};
    }
    std::lock_guard lock(mutex_);
    auto entries = entries_;
    for(const auto& camera : cameras)
    {
        const std::string id = camera.value("id", std::string());
        const bool known = std::find(connected_.begin(), connected_.end(), id) != connected_.end() || entries_.count(id) != 0;
        if(!known)
        {
            return Error{"unknown_camera", "No camera " + id};
        }
        Entry e;
        if(camera.contains("order") && !camera["order"].is_null())
        {
            if(!camera["order"].is_number_integer() || camera["order"].get<int>() < 1 || camera["order"].get<int>() > kMaxOrder)
            {
                return Error{"bad_request", "order of " + id + " must be from 1 to " + std::to_string(kMaxOrder) + " or null"};
            }
            e.order = camera["order"].get<int>();
        }
        if(camera.contains("label") && !camera["label"].is_null())
        {
            if(!camera["label"].is_string())
            {
                return Error{"bad_request", "label of " + id + " must be text or null"};
            }
            e.label = camera["label"].get<std::string>();
        }
        entries[id] = e;
    }
    std::set<int> orders;
    for(const auto& [id, e] : entries)
    {
        if(e.order && !orders.insert(*e.order).second)
        {
            return Error{"bad_request", "order " + std::to_string(*e.order) + " is given to two cameras"};
        }
    }
    entries_ = entries;
    save();
    return std::nullopt;
}
}  // namespace dartpilot::api
