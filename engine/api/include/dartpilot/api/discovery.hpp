#pragma once

#include <atomic>
#include <memory>
#include <string>
#include <thread>

// How apps in the home network find an engine without an address (#109, ADR 0008): an mDNS/DNS-SD service
// `_dartpilot._tcp` where Avahi runs, and answers on UDP port 8485 for networks that block multicast between Wi-Fi and
// LAN. Both carry the same fields; nothing secret.
namespace dartpilot::api
{
inline constexpr int kDiscoveryPort = 8485;

struct DiscoveryInfo
{
    // Shown in the app, e.g. the host name
    std::string name;
    // The WebSocket port of the engine API
    int port = 8484;
    // live or simulate
    std::string mode;
    // Stable per engine, so an app lists an engine found both ways, or under two addresses, once
    std::string id;
    std::string version;
};

// The answer to a search request as JSON text: {"type":"engine","name","port","protocol","mode","id","version"}
std::string discoveryAnswer (const DiscoveryInfo& info);

class Discovery
{
   public:
    explicit Discovery (DiscoveryInfo info, int udp_port = kDiscoveryPort);
    ~Discovery ();
    Discovery (const Discovery&) = delete;
    Discovery& operator=(const Discovery&) = delete;

    // Starts answering and announcing; false with an error if the UDP port cannot be bound. mDNS is announced where
    // Avahi is available and silently skipped otherwise.
    bool start (std::string& error);
    void stop ();
    bool announcedByMdns () const;

   private:
    void answer ();

    DiscoveryInfo info_;
    int udp_port_;
    int socket_ = -1;
    std::thread thread_;
    std::atomic<bool> stop_{false};
    struct Mdns;
    std::unique_ptr<Mdns> mdns_;
};
}  // namespace dartpilot::api
