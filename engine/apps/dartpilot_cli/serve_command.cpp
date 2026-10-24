#include "serve_command.hpp"

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <thread>

#include "dartpilot/api/server.hpp"
#include "dartpilot/api/simulator.hpp"
#include "preview_sources.hpp"

namespace dartpilot::cli
{
namespace
{
std::atomic<bool> interrupted{false};

void onInterrupt (int) { interrupted = true; }

int usage ()
{
    std::fprintf(stderr,
                 "Usage: dartpilot serve --simulate [--cameras] [--listen ADDRESS] [--port N] [--seed N] [--interval MS]\n"
                 "  --simulate     darts, takeouts and camera states without cameras\n"
                 "  --cameras      previews and status from the real cameras; darts stay simulated\n"
                 "  --listen       address to listen on (default 127.0.0.1; 0.0.0.0 for the whole network)\n"
                 "  --port         default 8484\n");
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
        else if(arg == "--interval" && i + 1 < argc)
        {
            settings.dart_interval = std::chrono::milliseconds(std::atoi(argv[++i]));
        }
        else
        {
            return usage();
        }
    }
    if(!simulate)
    {
        // Live detection needs the detection pipeline (milestones 0.3 to 0.6); until then only the simulator serves.
        std::fprintf(stderr, "Live detection is not available yet; use --simulate.\n");
        return usage();
    }

    api::Hello hello;
    hello.mode = "simulate";
    api::Server server(port, host, hello);
    server.setPreviewScaler(scaleJpeg);
    CameraPreviews camera_previews(server);
    std::vector<std::string> simulated = {"sim-1", "sim-2", "sim-3"};
    SimulatedPreviews simulated_previews(server, simulated);
    if(cameras)
    {
        std::vector<api::CameraInfo> infos;
        for(const auto& device : camera_previews.start())
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
    }
    else
    {
        server.setCameras({{"sim-1", "Simulated camera 1", "ok"}, {"sim-2", "Simulated camera 2", "ok"}, {"sim-3", "Simulated camera 3", "ok"}});
        simulated_previews.start();
    }
    std::string error;
    if(!server.start(error))
    {
        std::fprintf(stderr, "%s %s:%d\n", error.c_str(), host.c_str(), port);
        return 1;
    }
    api::Simulator simulator(server, settings);
    server.onDetectionChanged([&simulator] (bool running) { simulator.setRunning(running); });
    simulator.start();
    std::printf("Engine API (simulated darts%s) on ws://%s:%d/ - Ctrl+C to stop\n", cameras ? ", real cameras" : "", host.c_str(), port);
    std::fflush(stdout);

    std::signal(SIGINT, onInterrupt);
    std::signal(SIGTERM, onInterrupt);
    while(!interrupted)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    simulator.stop();
    simulated_previews.stop();
    camera_previews.stop();
    server.stop();
    std::printf("%zu throws\n", server.throws().size());
    return 0;
}
}  // namespace dartpilot::cli
