#pragma once

#include <cstdint>
#include <filesystem>
#include <functional>
#include <map>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

// Pairing of clients with an engine that listens in the network (#110, docs/engine-api.md "Pairing"). A client pairs
// once with the engine's current PIN and gets a token; later it presents the token. The engine keeps only a SHA-256
// of each token, with the client's name and when it was last seen. Times are passed in, in seconds since the epoch,
// so that the rules can be tested without waiting.
namespace dartpilot::api
{
class Pairing
{
   public:
    static constexpr int kPinDigits = 6;
    // The PIN changes this often, and after every pairing
    static constexpr std::int64_t kPinLifetime_s = 600;
    // Wrong PINs or tokens one address may send per minute
    static constexpr int kMaxFailuresPerMinute = 5;

    // store: the file of paired clients; empty keeps them in memory only
    explicit Pairing (std::filesystem::path store);

    struct Pin
    {
        std::string pin;
        std::int64_t expires_s = 0;
    };
    Pin pin (std::int64_t now_s);
    // Called with every new PIN, e.g. to show it in the engine's log; set before the server starts
    void onNewPin (std::function<void(const Pin&)> handler) { on_new_pin_ = std::move(handler); }

    struct Paired
    {
        std::string id;
        std::string client;
        std::string created_utc;
        std::string last_seen_utc;
    };
    struct Result
    {
        // On success; the error code otherwise (wrong_pin, unknown_token, too_many_attempts)
        std::optional<std::string> token;
        std::string error;
    };
    Result pairWithPin (const std::string& pin, const std::string& client, const std::string& address, std::int64_t now_s);
    Result pairWithToken (const std::string& token, const std::string& client, const std::string& address, std::int64_t now_s);

    std::vector<Paired> paired () const;
    bool unpair (const std::string& id);

   private:
    struct Stored
    {
        Paired paired;
        std::string token_sha256;
    };
    bool limited (const std::string& address, std::int64_t now_s);
    void failed (const std::string& address, std::int64_t now_s);
    void newPin (std::int64_t now_s);
    void save () const;

    std::filesystem::path store_;
    mutable std::mutex mutex_;
    std::vector<Stored> clients_;
    Pin pin_;
    std::map<std::string, std::vector<std::int64_t>> failures_;
    std::function<void(const Pin&)> on_new_pin_;
};

// An address on this computer, which never needs pairing
bool isLocalAddress (const std::string& address);
}  // namespace dartpilot::api
