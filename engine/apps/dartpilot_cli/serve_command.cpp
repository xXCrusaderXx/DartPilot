#include "serve_command.hpp"

#include <array>
#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <memory>
#include <string>
#include <thread>

#include <unistd.h>

#include "board_watch.hpp"
#include "calibration_service.hpp"
#include "dart_sets.hpp"
#include "dartpilot/api/discovery.hpp"
#include "dartpilot/api/server.hpp"
#include "dartpilot/api/simulator.hpp"
#include "dartpilot/version.hpp"
#include "live_detection.hpp"
#include "live_diagnosis.hpp"
#include "paths.hpp"
#include "preview_sources.hpp"
#include "reference_run.hpp"
#include "session_recording.hpp"

namespace dartpilot::cli
{
namespace
{
std::atomic<bool> interrupted{false};

void onInterrupt (int) { interrupted = true; }

int usage ()
{
    std::fprintf(stderr,
                 "Usage: dartpilot serve --cameras [--record] [--listen ADDRESS] [--port N]\n"
                 "       dartpilot serve --replay SESSION [--listen ADDRESS] [--port N]\n"
                 "       dartpilot serve --simulate [--cameras] [--listen ADDRESS] [--port N] [--seed N] [--interval MS] [--occupied]\n"
                 "  --cameras      the real cameras: previews, status, board check, diagnosis, calibration, and live darts\n"
                 "  --record       record the game as a session, with the throws and the players' corrections\n"
                 "  --replay       play a recorded session in real time as if its cameras were connected\n"
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
    bool record = false;
    std::filesystem::path replay;
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
        else if(arg == "--record")
        {
            record = true;
        }
        else if(arg == "--replay" && i + 1 < argc)
        {
            replay = argv[++i];
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
    if(!replay.empty() && (cameras || record))
    {
        std::fprintf(stderr, "--replay plays a recorded session instead of the cameras; it cannot be combined with --cameras or --record.\n");
        return usage();
    }
    if(record && !cameras)
    {
        std::fprintf(stderr, "--record records the cameras: use it with --cameras.\n");
        return usage();
    }
    if(!simulate && !cameras && replay.empty())
    {
        std::fprintf(stderr, "Live darts need the cameras: --cameras, a recorded session with --replay, or --simulate without them.\n");
        return usage();
    }
    std::optional<session::RecordedSession> recorded;
    std::string error;

    api::Hello hello;
    hello.mode = simulate ? "simulate" : replay.empty() ? "live" : "replay";
    hello.engine_id = engineId();
    if(!replay.empty())
    {
        recorded = session::openSession(replay, error);
        if(!recorded)
        {
            std::fprintf(stderr, "%s\n", error.c_str());
            return 1;
        }
        hello.session_id = recorded->session_id;
    }
    if(record)
    {
        hello.session_id = session::newSessionId();
    }
    api::Server server(port, host, hello);
    // In the network, other computers must pair with the PIN first (#110); on this computer only, nobody else can connect.
    const bool networked = host != "127.0.0.1" && host != "localhost" && host != "::1";
    std::shared_ptr<api::Pairing> pairing;
    if(networked)
    {
        pairing = std::make_shared<api::Pairing>(dataHome() / "paired-clients.json");
        pairing->onNewPin(
            [] (const api::Pairing::Pin& pin)
            {
                std::printf("Pairing PIN for other devices: %s (changes after each pairing and every %lld min)\n", pin.pin.c_str(),
                            static_cast<long long>(api::Pairing::kPinLifetime_s / 60));
                std::fflush(stdout);
            });
        server.requirePairing(pairing);
        pairing->pin(static_cast<std::int64_t>(std::time(nullptr)));
    }
    server.setPreviewScaler(scaleJpeg);
    CameraPreviews camera_previews(server);
    std::vector<std::string> simulated = {"sim-1", "sim-2", "sim-3"};
    SimulatedPreviews simulated_previews(server, simulated);
    std::unique_ptr<BoardWatch> board_watch;
    std::unique_ptr<LiveDiagnosis> live_diagnosis;
    std::unique_ptr<CalibrationService> calibration;
    std::unique_ptr<LiveDetection> live_detection;
    std::unique_ptr<DartSets> dart_sets;
    std::unique_ptr<ReferenceRun> reference_run;
    std::unique_ptr<SessionPlayback> playback;
    std::unique_ptr<SessionRecording> recording;
    if(cameras || recorded)
    {
        std::vector<api::CameraInfo> infos;
        const auto cameras_started = std::chrono::steady_clock::now();
        std::vector<capture::CameraDevice> devices;
        if(recorded)
        {
            playback = std::make_unique<SessionPlayback>(server, std::move(*recorded));
            devices = playback->devices();
        }
        else
        {
            devices = camera_previews.start();
        }
        const FrameFeed& feed = playback ? static_cast<const FrameFeed&>(*playback) : camera_previews;
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
        if(record)
        {
            recording = SessionRecording::start(dataHome() / "sessions", hello.session_id, devices, camera_previews, error);
            if(!recording)
            {
                std::fprintf(stderr, "Cannot record: %s\n", error.c_str());
                return 1;
            }
            server.onLogged([&recording] (const nlohmann::json& record_line) { recording->log(record_line); });
            std::printf("Recording into %s\n", recording->directory().c_str());
        }
        settings.camera_status = false;
        settings.board_state = false;
        settings.diagnosis = false;
        board_watch = std::make_unique<BoardWatch>(server, feed, devices, dataHome() / "calibration", !playback);
        live_diagnosis = std::make_unique<LiveDiagnosis>(server, feed, devices, dataHome() / "calibration", cameras_started);
        calibration = std::make_unique<CalibrationService>(server, feed, devices, dataHome() / "calibration", cameras_started);
        if(!simulate)
        {
            live_detection = std::make_unique<LiveDetection>(server, feed, devices, dataHome() / "calibration", !playback);
            reference_run = std::make_unique<ReferenceRun>(server, *live_detection, dataHome() / "calibration", dataHome() / "sessions");
            dart_sets = std::make_unique<DartSets>(server, *live_detection, devices, dataHome() / "calibration");
            if(recording)
            {
                // Every value in effect, from the start and after each change, so that a replay can use the same ones
                const auto params_path = recording->directory() / "results" / "live" / "params.jsonl";
                const auto write = [params_path] (const nlohmann::json& message)
                {
                    std::ofstream(params_path, std::ios::app)
                        << nlohmann::json{{"t_ns", capture::monotonicNowNs()}, {"revision", message["revision"]}, {"params", message["params"]}}
                               .dump()
                        << "\n";
                };
                write(live_detection->paramsMessage());
                live_detection->onParamsChanged(write);
            }
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
    if(!server.start(error))
    {
        std::fprintf(stderr, "%s %s:%d\n", error.c_str(), host.c_str(), port);
        return 1;
    }
    if(board_watch)
    {
        board_watch->start();
    }
    // Announced only when apps elsewhere in the network can reach the engine at all
    std::unique_ptr<api::Discovery> discovery;
    if(host != "127.0.0.1" && host != "localhost" && host != "::1")
    {
        std::array<char, 256> name{};
        ::gethostname(name.data(), name.size() - 1);
        discovery =
            std::make_unique<api::Discovery>(api::DiscoveryInfo{name.data(), port, hello.mode, hello.engine_id, std::string(dartpilot::kVersion)});
        if(!discovery->start(error))
        {
            std::fprintf(stderr, "%s; apps can still connect by address.\n", error.c_str());
            discovery.reset();
        }
        else
        {
            std::printf("Announced in the network as %s%s\n", name.data(), discovery->announcedByMdns() ? " (mDNS and UDP)" : " (UDP)");
        }
    }
    if(playback)
    {
        playback->start();
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
    bool told_finished = false;
    while(!interrupted)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        if(playback && playback->finished() && !told_finished)
        {
            std::printf("The recorded session has been played; the engine keeps serving its last frames.\n");
            std::fflush(stdout);
            told_finished = true;
        }
    }
    simulator.stop();
    dart_sets.reset();
    reference_run.reset();
    live_detection.reset();
    calibration.reset();
    live_diagnosis.reset();
    board_watch.reset();
    server.onLogged({});
    recording.reset();
    playback.reset();
    simulated_previews.stop();
    camera_previews.stop();
    discovery.reset();
    server.stop();
    std::printf("%zu throws\n", server.throws().size());
    return 0;
}
}  // namespace dartpilot::cli
