#pragma once

#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <thread>

#include "dartpilot/api/server.hpp"

namespace dartpilot::api
{
struct SimulatorSettings
{
    // Fixed seed, so a simulated session is the same every time
    std::uint32_t seed = 1;
    std::chrono::milliseconds dart_interval{2500};
    std::chrono::milliseconds takeout_delay{3000};
    // Scatter of a dart around its target, standard deviation per axis
    double scatter_mm = 12.0;
    // Share of darts the engine abstains on
    double abstain_rate = 0.1;
    // Off when real cameras report their own status (`serve --simulate --cameras`)
    bool camera_status = true;
    // Simulated board check (#121): occupied while darts are in the board; off with real cameras
    bool board_state = true;
    // Darts are already in the board at start; they are pulled out after takeout_delay
    bool occupied_at_start = false;
};

// Plays darts into the server without cameras (`dartpilot serve --simulate`): three darts aimed at a target per
// visit, then a takeout, and the status of three simulated cameras every second.
class Simulator
{
   public:
    Simulator (Server& server, SimulatorSettings settings = {});
    ~Simulator ();

    void start ();
    void stop ();
    void setRunning (bool running) { running_ = running; }

    // One dart as the simulator would produce it, for tests: the target point plus scatter
    static Throw makeDart (std::uint32_t seed, int index, const SimulatorSettings& settings);
    // Board point the simulator aims at for the visit of dart `index`
    static std::array<double, 2> target (int index);
    // Board state of the simulated cameras
    static BoardStateInfo boardState (bool occupied);

   private:
    void run ();
    void publishBoard (bool occupied);

    Server& server_;
    SimulatorSettings settings_;
    std::thread thread_;
    std::atomic<bool> stop_{false};
    std::atomic<bool> running_{true};
    std::atomic<bool> occupied_{false};
};
}  // namespace dartpilot::api
