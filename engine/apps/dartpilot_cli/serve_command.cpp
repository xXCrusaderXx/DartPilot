#include "serve_command.hpp"

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <string>
#include <thread>

#include "board_watch.hpp"
#include "calibration_service.hpp"
#include "dartpilot/api/server.hpp"
#include "dartpilot/api/simulator.hpp"
#include "live_detection.hpp"
#include "live_diagnosis.hpp"
#include "paths.hpp"
#include "preview_sources.hpp"
#include "reference_run.hpp"

namespace dartpilot::cli
{
namespace
{
std::atomic<bool> interrupted{false};

void onInterrupt (int) { interrupted = true; }

int usage ()
{
    std::fprintf(stderr,
                 "Usage: dartpilot serve --cameras [--listen ADDRESS] [--port N]\n"
                 "       dartpilot serve --simulate [--cameras] [--listen ADDRESS] [--port N] [--seed N] [--interval MS] [--occupied]\n"
                 "  --cameras      the real cameras: previews, status, board check, diagnosis, calibration, and live darts\n"
                 "  --simulate     simulated darts and takeouts; without --cameras also simulated cameras\n"
                 "  --listen       address to listen on (default 127.0.0.1; 0.0.0.0 for the whole network)\n"
                 "  --port         default 8484\n"
                 "  --occupied     darts are in the board at start (board check warning)\n");
    return 2;
}
}  // namespace

int runServe (int argc, char* argv[])
{
    bool simulate = false;
    bool cameras = false;
    std::string host = "127.0.0.1";
    int port = 8484;
    api::SimulatorSettings settings;
    for(int i = 0; i < argc; ++i)
    {
        const std::string arg = argv[i];
        if(arg == "--simulate")
        {
            simulate = true;
        }
        else if(arg == "--cameras")
        {
            cameras = true;
        }
        else if(arg == "--listen" && i + 1 < argc)
        {
            host = argv[++i];
        }
        else if(arg == "--port" && i + 1 < argc)
        {
            port = std::atoi(argv[++i]);
        }
        else if(arg == "--seed" && i + 1 < argc)
        {
            settings.seed = static_cast<std::uint32_t>(std::strtoul(argv[++i], nullptr, 10));
        }
        else if(arg == "--occupied")
        {
            settings.occupied_at_start = true;
        }
        else if(arg == "--interval" && i + 1 < argc)
        {
            settings.dart_interval = std::chrono::milliseconds(std::atoi(argv[++i]));
        }
        else
        {
            return usage();
        }
    }
    if(!simulate && !cameras)
    {
        std::fprintf(stderr, "Live darts need the cameras: --cameras, or --simulate without them.\n");
        return usage();
    }

    api::Hello hello;
    hello.mode = simulate ? "simulate" : "live";
    api::Server server(port, host, hello);
    server.setPreviewScaler(scaleJpeg);
    CameraPreviews camera_previews(server);
    std::vector<std::string> simulated = {"sim-1", "sim-2", "sim-3"};
    SimulatedPreviews simulated_previews(server, simulated);
    std::unique_ptr<BoardWatch> board_watch;
    std::unique_ptr<LiveDiagnosis> live_diagnosis;
    std::unique_ptr<CalibrationService> calibration;
    std::unique_ptr<LiveDetection> live_detection;
    std::unique_ptr<ReferenceRun> reference_run;
    if(cameras)
    {
        std::vector<api::CameraInfo> infos;
        const auto cameras_started = std::chrono::steady_clock::now();
        const auto devices = camera_previews.start();
        for(const auto& device : devices)
        {
            infos.push_back({"usb-" + device.usb_port, device.name, "ok"});
        }
        if(infos.empty())
        {
            std::fprintf(stderr, "No camera could be started.\n");
            return 1;
        }
        server.setCameras(infos);
        settings.camera_status = false;
        settings.board_state = false;
        settings.diagnosis = false;
        board_watch = std::make_unique<BoardWatch>(server, camera_previews, devices, dataHome() / "calibration");
        live_diagnosis = std::make_unique<LiveDiagnosis>(server, camera_previews, devices, dataHome() / "calibration", cameras_started);
        calibration = std::make_unique<CalibrationService>(server, camera_previews, devices, dataHome() / "calibration", cameras_started);
        if(!simulate)
        {
            live_detection = std::make_unique<LiveDetection>(server, camera_previews, devices, dataHome() / "calibration");
            reference_run = std::make_unique<ReferenceRun>(server, *live_detection, dataHome() / "calibration", dataHome() / "sessions");
            // Until the first still empty board, darts cannot be told from the board.
            const auto unavailable = live_detection->unavailableReason();
            server.publishEngineStatus("unavailable", unavailable.value_or("no_empty_reference"));
        }
    }
    else
    {
        server.setCameras({{"sim-1", "Simulated camera 1", "ok"}, {"sim-2", "Simulated camera 2", "ok"}, {"sim-3", "Simulated camera 3", "ok"}});
        simulated_previews.start();
        // An example reference run in the nominal board, for building the client's page without cameras
        server.onCalibrationRequest("start_reference_run",
                                    [&server] (const api::CalibrationRequest&) -> std::optional<api::Server::CalibrationError>
                                    {
                                        for(const auto& message : exampleReferenceRun())
                                        {
                                            server.publishState(message);
                                        }
                                        return std::nullopt;
                                    });
    }
    std::string error;
    if(!server.start(error))
    {
        std::fprintf(stderr, "%s %s:%d\n", error.c_str(), host.c_str(), port);
        return 1;
    }
    if(board_watch)
    {
        board_watch->start();
    }
    api::Simulator simulator(server, settings);
    if(live_detection)
    {
        server.onDetectionChanged([&live_detection] (bool running) { live_detection->setRunning(running); });
        live_detection->start();
        std::printf("Engine API (live darts%s) on ws://%s:%d/ - Ctrl+C to stop\n",
                    live_detection->unavailableReason() ? ", not calibrated: no detection" : "", host.c_str(), port);
    }
    else
    {
        server.onDetectionChanged([&simulator] (bool running) { simulator.setRunning(running); });
        simulator.start();
        std::printf("Engine API (simulated darts%s) on ws://%s:%d/ - Ctrl+C to stop\n", cameras ? ", real cameras" : "", host.c_str(), port);
    }
    std::fflush(stdout);

    std::signal(SIGINT, onInterrupt);
    std::signal(SIGTERM, onInterrupt);
    while(!interrupted)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    simulator.stop();
    reference_run.reset();
    live_detection.reset();
    calibration.reset();
    live_diagnosis.reset();
    board_watch.reset();
    simulated_previews.stop();
    camera_previews.stop();
    server.stop();
    std::printf("%zu throws\n", server.throws().size());
    return 0;
}
}  // namespace dartpilot::cli
