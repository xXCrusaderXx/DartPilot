#include "dartpilot/api/throw_log.hpp"

namespace dartpilot::api
{
ThrowLog::ThrowLog (std::string session_id)
    : session_id_(std::move(session_id))
{
}

std::string ThrowLog::nextId () { return session_id_ + "/" + std::to_string(next_++); }

Throw ThrowLog::record (Throw dart)
{
    std::lock_guard lock(mutex_);
    dart.throw_id = nextId();
    entries_[dart.throw_id] = Entry{dart, {}, {}, {}, {}};
    return dart;
}

std::optional<std::string> ThrowLog::correct (const std::string& throw_id, const BoardPoint& point, const std::string& client)
{
    std::lock_guard lock(mutex_);
    const auto it = entries_.find(throw_id);
    if(it == entries_.end())
    {
        return "unknown_throw";
    }
    it->second.correction = "corrected";
    it->second.corrected_point = point;
    it->second.client = client;
    return std::nullopt;
}

std::optional<std::string> ThrowLog::reject (const std::string& throw_id, const std::string& reason, const std::string& client)
{
    std::lock_guard lock(mutex_);
    const auto it = entries_.find(throw_id);
    if(it == entries_.end())
    {
        return "unknown_throw";
    }
    it->second.correction = "rejected";
    it->second.corrected_point.reset();
    it->second.client = client;
    it->second.reason = reason;
    return std::nullopt;
}

std::string ThrowLog::add (const BoardPoint& point, std::int64_t event_ns, const std::string& client)
{
    std::lock_guard lock(mutex_);
    Throw dart;
    dart.throw_id = nextId();
    dart.event_ns = event_ns;
    dart.board_point = point;
    entries_[dart.throw_id] = Entry{dart, "added", point, client, {}};
    return dart.throw_id;
}

std::optional<ThrowLog::Entry> ThrowLog::find (const std::string& throw_id) const
{
    std::lock_guard lock(mutex_);
    const auto it = entries_.find(throw_id);
    if(it == entries_.end())
    {
        return std::nullopt;
    }
    return it->second;
}

std::size_t ThrowLog::size () const
{
    std::lock_guard lock(mutex_);
    return entries_.size();
}
}  // namespace dartpilot::api
