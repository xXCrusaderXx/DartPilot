#pragma once

#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>

namespace dartpilot::capture
{
// Bounded queue between a capture thread and its consumer. When it is full, the oldest element is dropped and
// counted, so a slow consumer never builds up latency.
template <typename T>
class RingBuffer
{
   public:
    explicit RingBuffer (std::size_t capacity)
        : capacity_(capacity == 0 ? 1 : capacity)
    {
    }

    // Returns true if the oldest element had to be dropped to make room.
    bool push (T value)
    {
        bool dropped = false;
        {
            std::lock_guard lock(mutex_);
            if(items_.size() == capacity_)
            {
                items_.pop_front();
                ++dropped_;
                dropped = true;
            }
            items_.push_back(std::move(value));
        }
        ready_.notify_one();
        return dropped;
    }

    std::optional<T> tryPop ()
    {
        std::lock_guard lock(mutex_);
        return popLocked();
    }

    // Waits up to the timeout for an element.
    std::optional<T> pop (std::chrono::milliseconds timeout)
    {
        std::unique_lock lock(mutex_);
        ready_.wait_for(lock, timeout, [this] { return !items_.empty(); });
        return popLocked();
    }

    std::size_t size () const
    {
        std::lock_guard lock(mutex_);
        return items_.size();
    }

    std::size_t capacity () const { return capacity_; }

    // Elements dropped because the buffer was full
    std::uint64_t dropped () const
    {
        std::lock_guard lock(mutex_);
        return dropped_;
    }

   private:
    std::optional<T> popLocked ()
    {
        if(items_.empty())
        {
            return std::nullopt;
        }
        T value = std::move(items_.front());
        items_.pop_front();
        return value;
    }

    const std::size_t capacity_;
    mutable std::mutex mutex_;
    std::condition_variable ready_;
    std::deque<T> items_;
    std::uint64_t dropped_ = 0;
};
}  // namespace dartpilot::capture
