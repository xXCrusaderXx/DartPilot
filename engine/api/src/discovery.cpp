#include "dartpilot/api/discovery.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <chrono>
#include <cstring>
#include <map>

#include <nlohmann/json.hpp>

#include "dartpilot/api/protocol.hpp"

#ifdef DARTPILOT_HAVE_AVAHI
#include <avahi-client/client.h>
#include <avahi-client/publish.h>
#include <avahi-common/alternative.h>
#include <avahi-common/error.h>
#include <avahi-common/malloc.h>
#include <avahi-common/thread-watch.h>
#endif

namespace dartpilot::api
{
namespace
{
// One answer per asker and second: a search sends its request a few times, and nobody should make the engine flood
// another host with answers by faking the sender.
constexpr auto kAnswerInterval = std::chrono::seconds(1);
constexpr const char* kServiceType = "_dartpilot._tcp";
}  // namespace

std::string discoveryAnswer (const DiscoveryInfo& info)
{
    return nlohmann::json{{"type", "engine"},  {"name", info.name}, {"port", info.port},      {"protocol", kProtocol},
                          {"mode", info.mode}, {"id", info.id},     {"version", info.version}}
        .dump();
}

#ifdef DARTPILOT_HAVE_AVAHI
// The DNS-SD service, published through the Avahi daemon on its own thread
struct Discovery::Mdns
{
    AvahiThreadedPoll* poll = nullptr;
    AvahiClient* client = nullptr;
    AvahiEntryGroup* group = nullptr;
    DiscoveryInfo info;
    std::string name;

    void publish (AvahiClient* c)
    {
        if(!group)
        {
            group = avahi_entry_group_new(c, [] (AvahiEntryGroup*, AvahiEntryGroupState, void*) {}, this);
        }
        if(!group || !avahi_entry_group_is_empty(group))
        {
            return;
        }
        const std::string protocol = std::string("protocol=") + kProtocol, txt_name = "name=" + info.name, mode = "mode=" + info.mode,
                          id = "id=" + info.id, version = "version=" + info.version;
        AvahiStringList* txt = avahi_string_list_new(protocol.c_str(), txt_name.c_str(), mode.c_str(), id.c_str(), version.c_str(), nullptr);
        int result = avahi_entry_group_add_service_strlst(group, AVAHI_IF_UNSPEC, AVAHI_PROTO_INET, AvahiPublishFlags(0), name.c_str(), kServiceType,
                                                          nullptr, nullptr, static_cast<uint16_t>(info.port), txt);
        // Another engine of the same name in the network: take the next free variant ("name #2").
        if(result == AVAHI_ERR_COLLISION)
        {
            char* alternative = avahi_alternative_service_name(name.c_str());
            name = alternative;
            avahi_free(alternative);
            result = avahi_entry_group_add_service_strlst(group, AVAHI_IF_UNSPEC, AVAHI_PROTO_INET, AvahiPublishFlags(0), name.c_str(), kServiceType,
                                                          nullptr, nullptr, static_cast<uint16_t>(info.port), txt);
        }
        avahi_string_list_free(txt);
        if(result >= 0)
        {
            avahi_entry_group_commit(group);
        }
    }

    bool start ()
    {
        poll = avahi_threaded_poll_new();
        if(!poll)
        {
            return false;
        }
        int error = 0;
        client = avahi_client_new(
            avahi_threaded_poll_get(poll), AvahiClientFlags(0),
            [] (AvahiClient* c, AvahiClientState state, void* self)
            {
                if(state == AVAHI_CLIENT_S_RUNNING)
                {
                    static_cast<Mdns*>(self)->publish(c);
                }
            },
            this, &error);
        if(!client)
        {
            avahi_threaded_poll_free(poll);
            poll = nullptr;
            return false;
        }
        return avahi_threaded_poll_start(poll) == 0;
    }

    ~Mdns ()
    {
        if(poll)
        {
            avahi_threaded_poll_stop(poll);
        }
        if(client)
        {
            avahi_client_free(client);
        }
        if(poll)
        {
            avahi_threaded_poll_free(poll);
        }
    }
};
#else
struct Discovery::Mdns
{
    DiscoveryInfo info;
    std::string name;
    bool start () { return false; }
};
#endif

Discovery::Discovery (DiscoveryInfo info, int udp_port)
    : info_(std::move(info))
    , udp_port_(udp_port)
{
}

Discovery::~Discovery () { stop(); }

bool Discovery::start (std::string& error)
{
    stop();
    socket_ = ::socket(AF_INET, SOCK_DGRAM, 0);
    const int yes = 1;
    ::setsockopt(socket_, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_port = htons(static_cast<uint16_t>(udp_port_));
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    if(socket_ < 0 || ::bind(socket_, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0)
    {
        error = std::string("Cannot listen for discovery on UDP port ") + std::to_string(udp_port_) + ": " + std::strerror(errno);
        if(socket_ >= 0)
        {
            ::close(socket_);
            socket_ = -1;
        }
        return false;
    }
    stop_ = false;
    thread_ = std::thread([this] { answer(); });
    mdns_ = std::make_unique<Mdns>();
    mdns_->info = info_;
    mdns_->name = info_.name;
    if(!mdns_->start())
    {
        mdns_.reset();
    }
    return true;
}

void Discovery::stop ()
{
    mdns_.reset();
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
    if(socket_ >= 0)
    {
        ::close(socket_);
        socket_ = -1;
    }
}

bool Discovery::announcedByMdns () const { return mdns_ != nullptr; }

void Discovery::answer ()
{
    std::map<uint32_t, std::chrono::steady_clock::time_point> last_answer;
    std::array<char, 1024> buffer{};
    while(!stop_)
    {
        pollfd waiting{socket_, POLLIN, 0};
        if(::poll(&waiting, 1, 200) <= 0)
        {
            continue;
        }
        sockaddr_in sender{};
        socklen_t sender_size = sizeof(sender);
        const ssize_t size = ::recvfrom(socket_, buffer.data(), buffer.size(), 0, reinterpret_cast<sockaddr*>(&sender), &sender_size);
        if(size <= 0)
        {
            continue;
        }
        const auto request = nlohmann::json::parse(std::string(buffer.data(), static_cast<size_t>(size)), nullptr, false);
        // Any request of type discover gets an answer, also from an app of another protocol major: it names this
        // engine's protocol, so the app can tell the user it cannot use it.
        if(!request.is_object() || request.value("type", std::string()) != "discover")
        {
            continue;
        }
        const auto now = std::chrono::steady_clock::now();
        auto& last = last_answer[sender.sin_addr.s_addr];
        if(last.time_since_epoch().count() != 0 && now - last < kAnswerInterval)
        {
            continue;
        }
        last = now;
        const std::string reply = discoveryAnswer(info_);
        ::sendto(socket_, reply.data(), reply.size(), 0, reinterpret_cast<sockaddr*>(&sender), sender_size);
    }
}
}  // namespace dartpilot::api
