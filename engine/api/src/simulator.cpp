#include "dartpilot/api/simulator.hpp"

#include <array>
#include <cmath>
#include <ctime>
#include <random>
#include <string>

namespace dartpilot::api
{
namespace
{
std::int64_t monotonicNowNs ()
{
    timespec now{};
    ::clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<std::int64_t>(now.tv_sec) * 1'000'000'000 + now.tv_nsec;
}

// Targets a player aims at, as board points in the middle of T20, T19, D16, the bull and S20 (checked in ApiTest)
constexpr std::array<std::array<double, 2>, 5> kTargets = {{{0.0, 103.0}, {-31.83, -97.96}, {-134.30, -97.57}, {0.0, 0.0}, {0.0, 60.0}}};

const std::array<const char*, 3> kCameras = {"sim-1", "sim-2", "sim-3"};

void sleepInterruptibly (std::chrono::milliseconds duration, const std::atomic<bool>& stop)
{
    const auto end = std::chrono::steady_clock::now() + duration;
    while(!stop && std::chrono::steady_clock::now() < end)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
}
}  // namespace

Simulator::Simulator (Server& server, SimulatorSettings settings)
    : server_(server)
    , settings_(settings)
{
}

Simulator::~Simulator () { stop(); }

std::array<double, 2> Simulator::target (int index) { return kTargets[static_cast<std::size_t>(index / 3) % kTargets.size()]; }

Throw Simulator::makeDart (std::uint32_t seed, int index, const SimulatorSettings& settings)
{
    // Every dart has its own generator from (seed, index), so a dart does not depend on how many came before.
    std::seed_seq sequence{seed, static_cast<std::uint32_t>(index)};
    std::mt19937 random(sequence);
    std::uniform_real_distribution<double> unit(0.0, 1.0);
    const auto target = Simulator::target(index);
    // Box-Muller from the uniform generator, so the scatter is the same with every standard library
    const double radius = settings.scatter_mm * std::sqrt(-2.0 * std::log(1.0 - unit(random)));
    const double angle = 2.0 * 3.14159265358979323846 * unit(random);

    Throw dart;
    const bool abstain = unit(random) < settings.abstain_rate;
    const double sigma_mm = abstain ? 4.0 : 0.8 + 0.4 * unit(random);
    dart.board_point = BoardPoint{target[0] + radius * std::cos(angle), target[1] + radius * std::sin(angle),
                                  std::array<double, 3>{sigma_mm * sigma_mm, 0.0, sigma_mm * sigma_mm}};
    dart.accepted = !abstain;
    dart.confidence = abstain ? 0.35 + 0.2 * unit(random) : 0.85 + 0.14 * unit(random);
    if(abstain)
    {
        dart.reason = "tip occluded in two cameras (simulated)";
    }
    for(std::size_t c = 0; c < kCameras.size(); ++c)
    {
        const bool used = !abstain || c == 0;
        dart.cameras.push_back({kCameras[c], used, {}, used ? "" : "tip occluded"});
    }
    dart.processing_latency_ms = 30.0 + 20.0 * unit(random);
    return dart;
}

void Simulator::start ()
{
    stop();
    stop_ = false;
    thread_ = std::thread([this] { run(); });
}

void Simulator::stop ()
{
    stop_ = true;
    if(thread_.joinable())
    {
        thread_.join();
    }
}

void Simulator::run ()
{
    int index = 0;
    auto next_status = std::chrono::steady_clock::now();
    auto next_dart = std::chrono::steady_clock::now() + settings_.dart_interval;
    std::int64_t takeout_at_ns = 0;
    while(!stop_)
    {
        const auto now = std::chrono::steady_clock::now();
        if(now >= next_status)
        {
            for(const char* camera : kCameras)
            {
                server_.publishCameraStatus({camera, "ok", 30.0, 0, 0, 110.0});
            }
            next_status += std::chrono::seconds(1);
        }
        if(running_ && takeout_at_ns != 0 && monotonicNowNs() >= takeout_at_ns)
        {
            server_.publishTakeout(monotonicNowNs(), 3);
            takeout_at_ns = 0;
            next_dart = now + settings_.dart_interval;
        }
        if(running_ && takeout_at_ns == 0 && now >= next_dart)
        {
            Throw dart = makeDart(settings_.seed, index, settings_);
            dart.event_ns = monotonicNowNs();
            server_.publishThrow(dart);
            ++index;
            if(index % 3 == 0)
            {
                takeout_at_ns = monotonicNowNs() + std::chrono::nanoseconds(settings_.takeout_delay).count();
            }
            next_dart = now + settings_.dart_interval;
        }
        sleepInterruptibly(std::chrono::milliseconds(50), stop_);
    }
}
}  // namespace dartpilot::api
