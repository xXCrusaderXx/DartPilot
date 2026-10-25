#include "dartpilot/api/pairing.hpp"

#include <algorithm>
#include <array>
#include <ctime>
#include <fstream>
#include <random>

#include <nlohmann/json.hpp>

#include "dartpilot/session/sha256.hpp"

namespace dartpilot::api
{
namespace
{
std::string utc (std::int64_t s)
{
    const std::time_t t = static_cast<std::time_t>(s);
    std::tm tm{};
    ::gmtime_r(&t, &tm);
    std::array<char, 32> text{};
    std::strftime(text.data(), text.size(), "%Y-%m-%dT%H:%M:%SZ", &tm);
    return text.data();
}

// Hex of random bytes from the operating system's generator
std::string randomHex (int bytes)
{
    static constexpr char kHex[] = "0123456789abcdef";
    std::random_device random;
    std::string out;
    for(int i = 0; i < bytes; ++i)
    {
        const auto byte = static_cast<unsigned>(random() & 0xff);
        out += kHex[byte >> 4];
        out += kHex[byte & 15];
    }
    return out;
}

std::string hashOf (const std::string& token)
{
    return session::sha256Hex(std::span(reinterpret_cast<const std::uint8_t*>(token.data()), token.size()));
}
}  // namespace

bool isLocalAddress (const std::string& address)
{
    return address == "127.0.0.1" || address == "::1" || address.starts_with("127.") || address == "::ffff:127.0.0.1" || address == "localhost";
}

Pairing::Pairing (std::filesystem::path store)
    : store_(std::move(store))
{
    if(store_.empty())
    {
        return;
    }
    std::ifstream in(store_);
    const auto stored = nlohmann::json::parse(in, nullptr, false);
    if(stored.is_discarded() || !stored.is_array())
    {
        return;
    }
    for(const auto& entry : stored)
    {
        clients_.push_back({{entry.value("id", std::string()), entry.value("client", std::string()), entry.value("created_utc", std::string()),
                             entry.value("last_seen_utc", std::string())},
                            entry.value("token_sha256", std::string())});
    }
}

void Pairing::save () const
{
    if(store_.empty())
    {
        return;
    }
    nlohmann::json stored = nlohmann::json::array();
    for(const auto& client : clients_)
    {
        stored.push_back({{"id", client.paired.id},
                          {"client", client.paired.client},
                          {"created_utc", client.paired.created_utc},
                          {"last_seen_utc", client.paired.last_seen_utc},
                          {"token_sha256", client.token_sha256}});
    }
    std::error_code ignored;
    std::filesystem::create_directories(store_.parent_path(), ignored);
    std::ofstream(store_) << stored.dump(2) << "\n";
    // Only the user may read it
    std::filesystem::permissions(store_, std::filesystem::perms::owner_read | std::filesystem::perms::owner_write, ignored);
}

void Pairing::newPin (std::int64_t now_s)
{
    std::random_device random;
    std::uniform_int_distribution<int> digit(0, 9);
    pin_.pin.clear();
    for(int i = 0; i < kPinDigits; ++i)
    {
        pin_.pin += static_cast<char>('0' + digit(random));
    }
    pin_.expires_s = now_s + kPinLifetime_s;
    if(on_new_pin_)
    {
        on_new_pin_(pin_);
    }
}

Pairing::Pin Pairing::pin (std::int64_t now_s)
{
    std::lock_guard lock(mutex_);
    if(pin_.pin.empty() || now_s >= pin_.expires_s)
    {
        newPin(now_s);
    }
    return pin_;
}

bool Pairing::limited (const std::string& address, std::int64_t now_s)
{
    auto& times = failures_[address];
    times.erase(std::remove_if(times.begin(), times.end(), [&] (std::int64_t t) { return now_s - t >= 60; }), times.end());
    return static_cast<int>(times.size()) >= kMaxFailuresPerMinute;
}

void Pairing::failed (const std::string& address, std::int64_t now_s) { failures_[address].push_back(now_s); }

Pairing::Result Pairing::pairWithPin (const std::string& pin, const std::string& client, const std::string& address, std::int64_t now_s)
{
    std::lock_guard lock(mutex_);
    if(limited(address, now_s))
    {
        return {std::nullopt, "too_many_attempts"};
    }
    if(pin_.pin.empty() || now_s >= pin_.expires_s)
    {
        // Shown in the log, so the user can read the current one there
        newPin(now_s);
    }
    if(pin != pin_.pin)
    {
        failed(address, now_s);
        return {std::nullopt, "wrong_pin"};
    }
    const std::string token = randomHex(32);
    clients_.push_back({{randomHex(4), client, utc(now_s), utc(now_s)}, hashOf(token)});
    save();
    // A PIN pairs one client only.
    newPin(now_s);
    return {token, ""};
}

Pairing::Result Pairing::pairWithToken (const std::string& token, const std::string& client, const std::string& address, std::int64_t now_s)
{
    std::lock_guard lock(mutex_);
    if(limited(address, now_s))
    {
        return {std::nullopt, "too_many_attempts"};
    }
    const std::string hash = hashOf(token);
    const auto it = std::find_if(clients_.begin(), clients_.end(), [&] (const Stored& s) { return s.token_sha256 == hash; });
    if(it == clients_.end())
    {
        failed(address, now_s);
        return {std::nullopt, "unknown_token"};
    }
    it->paired.last_seen_utc = utc(now_s);
    if(!client.empty())
    {
        it->paired.client = client;
    }
    save();
    return {token, ""};
}

std::vector<Pairing::Paired> Pairing::paired () const
{
    std::lock_guard lock(mutex_);
    std::vector<Paired> list;
    for(const auto& client : clients_)
    {
        list.push_back(client.paired);
    }
    return list;
}

bool Pairing::unpair (const std::string& id)
{
    std::lock_guard lock(mutex_);
    const auto it = std::find_if(clients_.begin(), clients_.end(), [&] (const Stored& s) { return s.paired.id == id; });
    if(it == clients_.end())
    {
        return false;
    }
    clients_.erase(it);
    save();
    return true;
}
}  // namespace dartpilot::api
