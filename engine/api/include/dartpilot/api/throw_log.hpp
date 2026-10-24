#pragma once

#include <map>
#include <mutex>
#include <optional>
#include <string>

#include "dartpilot/api/protocol.hpp"

namespace dartpilot::api
{
// Throws of one engine run with their corrections. Throw IDs follow the session format, "<session id>/<n>".
class ThrowLog
{
   public:
    explicit ThrowLog (std::string session_id);

    // Assigns the next throw ID and stores the throw
    Throw record (Throw dart);

    // nullopt on success, otherwise the error code (unknown_throw)
    std::optional<std::string> correct (const std::string& throw_id, const BoardPoint& point, const std::string& client);
    std::optional<std::string> reject (const std::string& throw_id, const std::string& reason, const std::string& client);
    // Adds a dart the engine missed and returns its new throw ID
    std::string add (const BoardPoint& point, std::int64_t event_ns, const std::string& client);

    struct Entry
    {
        Throw dart;
        // Set when a client changed the throw: corrected, rejected or added
        std::string correction;
        std::optional<BoardPoint> corrected_point;
        std::string client;
        std::string reason;
    };
    std::optional<Entry> find (const std::string& throw_id) const;
    std::size_t size () const;

   private:
    std::string nextId ();

    std::string session_id_;
    int next_ = 1;
    std::map<std::string, Entry> entries_;
    mutable std::mutex mutex_;
};
}  // namespace dartpilot::api
