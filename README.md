# DartPilot

[![CI](https://github.com/xXCrusaderXx/DartPilot/actions/workflows/ci.yml/badge.svg)](https://github.com/xXCrusaderXx/DartPilot/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/xXCrusaderXx/DartPilot)](https://github.com/xXCrusaderXx/DartPilot/releases)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

An open-source **automatic dart scoring system for a steel-tip board and three USB cameras**: a detection engine, a setup tool and a player app.

## Goal

Camera-based dart scoring exists, but how precise it is can rarely be checked. DartPilot aims for a more precise impact position than existing systems and backs every claim with a reproducible benchmark in millimetres.

It treats scoring as a measurement problem:

- Every dart becomes a **board point in millimetres** with its uncertainty and diagnostics, not just a score.
- The engine **may abstain** when it is unsure, instead of forcing a wrong score. Abstentions and false scores are always reported together.
- Every result is **traceable** to the camera frames it came from, and every recorded throw **replays with identical results**.
- It runs on **cheap, generic hardware**: three UVC webcams, calibrated from the dartboard itself, without a calibration target in the player's hand.

The full reasoning is in the [technical plan](docs/technical_plan.md); the way there is in the [roadmap](ROADMAP.md).

> DartPilot is an independent project. It is not affiliated with any manufacturer of dartboards or dart scoring systems. See [LEGAL.md](LEGAL.md).

## Status

**Early development, but playable.** The latest release is [v0.4.0](https://github.com/xXCrusaderXx/DartPilot/releases/latest); work continues on [0.5.0 – Tip localisation](https://github.com/xXCrusaderXx/DartPilot/milestone/5).

- **Live detection runs:** a thrown dart reaches the app about 0.5 s after it lands. On the first [benchmark dataset](docs/dataset.md) it placed 51 of 55 darts in the right field, abstained on 4 and put none in a wrong field ([baseline report](docs/reports/baseline-0.3.0.md)). The dataset is small and comes from one board; these numbers describe the current state, not a promise.
- **Calibration from the board** is validated with its error budget ([ADR 0009](docs/adr/0009-board-calibration-validated.md)).
- **Camera timing** is measured: constant offsets, no drift, timestamps true to about 1 ms ([camera timing](docs/benchmarks/camera-timing.md)).
- The engine runs on **Linux**. Android and Windows are planned ([0.8.0](ROADMAP.md#platform-and-app)).

## What is in the box

| Part | What it does |
| ---- | ------------ |
| **Engine** (`dartpilot`) | Captures the three cameras, detects darts and takeouts, and reports them to clients over a WebSocket ([engine API](docs/engine-api.md)). Records sessions and replays them for evaluation. C++20 with OpenCV. |
| **Setup tool** (`dartpilot_setup`) | Developer GUI for camera setup: assigning the cameras, focus, exposure and white balance, calibration and its validation, and a live detection test ([ADR 0003](docs/adr/0003-developer-gui.md)). Qt 6, optional. |
| **Player app** ([`ui/`](ui)) | Flutter app for Linux, Windows, web and Android ([ADR 0004](docs/adr/0004-user-interface.md)). Games: X01, Cricket (also cut-throat), Around the Clock, Shanghai, Bob's 27, Halve-It and Killer, against other players or bots. Training: grouping, doubles practice and a checkout trainer, each dart measured in mm against its target. Statistics with CSV and JSON export, a score caller, corrections of detected darts, live camera images, a setup diagnosis, and manual input when no engine is connected. |
| **Remote displays** | Phones and tablets find the engine in the home network, pair with a PIN and show the same game ([ADR 0008](docs/adr/0008-engine-deployment.md), [ADR 0010](docs/adr/0010-shared-game-state.md)). |
| **Tools** ([`tools/`](tools)) | Python package for the benchmark, annotation and reports. It reads engine output and is never part of detection. |

## How it works

```text
3 USB cameras ─► capture (timestamps, frame IDs, ring buffers)
              ─► event_detection (throw window, difference masks)
              ─► tip_candidates (tip candidates per camera, with covariance)
              ─► geometry (board projection / triangulation)
              ─► fusion (temporal association, robust estimate, abstention)
              ─► scoring (board point in mm ─► sector and ring)
              ─► score + confidence + diagnostics ─► engine API ─► apps
```

Detection, geometry and scoring are separate modules. The engine knows no games: turns, rules and statistics live in the app.

The core metrics are the radial position error in mm (median, P95), segment and multiplier accuracy, and false acceptance and abstention rates, which are always reported together. See [section 6 of the technical plan](docs/technical_plan.md#6-metrics-and-preliminary-targets) and [the benchmark](docs/benchmark.md).

## Getting started

### Play

Download the app for Linux, Android, Windows or the browser from the [latest release](https://github.com/xXCrusaderXx/DartPilot/releases/latest). The Linux AppImage includes the camera engine. Every game can also be played without cameras, by entering the darts by hand. The [player guide](docs/user-guide.md) ([Deutsch](docs/user-guide.de.md)) explains installing, the first start, the games, training, statistics, the score caller and using a phone as a second display; [setting up the cameras](docs/setup-guide.md) ([Deutsch](docs/setup-guide.de.md)) covers mounting and calibrating them.

### Try it without cameras

The engine can simulate darts, so the app can be tried without any hardware:

```sh
./build/engine/apps/dartpilot_cli/dartpilot serve --simulate
cd ui && flutter run -d linux        # then press Connect on the home screen
```

### Play with cameras

1. **Hardware:** a steel-tip board, three USB cameras around it about 120° apart, each seeing the whole board from about 35–45° above, and even light. The reference setup is in [hardware.md](docs/hardware.md); reports on other cameras are welcome.
2. **Build** the engine and the setup tool (see [Building from source](#building-from-source)).
3. **Set up the cameras** in `./build/engine/apps/dartpilot_setup/dartpilot_setup`: assign them, set focus and white balance, and calibrate from the board ([calibration](docs/calibration.md)). The [setup diagnosis](docs/setup-diagnosis.md) in the app lists what is still wrong.
4. **Start the engine:** `dartpilot serve --cameras`. Add `--listen 0.0.0.0` so phones and tablets in the network can connect, and `--record` to record the game for evaluation.
5. **Play** in the app. On Linux the app can also start the engine itself.

### Command-line tool

| Command | Purpose |
| ------- | ------- |
| `dartpilot serve --cameras` | Live detection for the apps; `--simulate` without cameras, `--replay <session>` from a recording |
| `dartpilot capture-check [seconds]` | Frame rate, losses and timestamp quality of the cameras |
| `dartpilot record --seconds N` | Record a session to `~/.local/share/dartpilot/sessions` |
| `dartpilot replay <session>` | Detect throws offline from a recording |
| `dartpilot white-balance`, `focus --camera <device>` | Camera settings |
| `dartpilot detection-params` | All detection values with their documentation ([detection values](docs/detection-params.md)) |
| `dartpilot pattern`, `dart-sheet` | Calibration pattern and the sheet for measuring a dart |

The pages linked in the [documentation index](docs/README.md) describe the options of each command.

## Building from source

Requirements: CMake 3.20 or newer, a C++20 compiler and OpenCV 4 or 5. The setup tool also needs Qt 6.5 or newer with Qt Quick; without Qt it is skipped. GoogleTest is downloaded automatically when the tests are enabled.

```sh
# Arch Linux (qt6-declarative only for the setup tool)
sudo pacman -S --needed base-devel cmake ninja opencv qt6-declarative
# Debian / Ubuntu
sudo apt install build-essential cmake ninja-build libopencv-dev
# Fedora
sudo dnf install gcc-c++ cmake ninja-build opencv-devel

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/engine/apps/dartpilot_cli/dartpilot --version
```

### Tests

```sh
cmake -B build -G Ninja -DDARTPILOT_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

The tests need no cameras and no internet connection (apart from the first GoogleTest download).

### Recordings

```sh
./build/engine/apps/dartpilot_cli/dartpilot record --seconds 60
python -m dartpilot_tools.capture_report ~/.local/share/dartpilot/sessions/<session>
```

A recording of three cameras takes about 200–360 MB per minute, depending on the scene; the format is described in [docs/replay-format.md](docs/replay-format.md). Recordings stay on your computer and are never committed (see [LEGAL.md](LEGAL.md)).

### Python tools

```sh
cd tools
python -m venv .venv && . .venv/bin/activate
pip install -e '.[dev]'
pytest
```

See [tools/README.md](tools/README.md) for what each tool does.

### Player app

The Flutter app in [`ui/`](ui) needs the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.47 or newer). See [ui/README.md](ui/README.md).

```sh
cd ui
flutter run -d linux
flutter test
```

## Repository layout

| Path | Content |
| ---- | ------- |
| [`engine/`](engine) | C++20 engine: one library per module, plus `apps/dartpilot_cli` and the setup tool `apps/dartpilot_setup` |
| [`tests/`](tests) | C++ tests (GoogleTest, run with `ctest`) |
| [`ui/`](ui) | Flutter player app |
| [`tools/`](tools) | Python tools for benchmark evaluation and annotation |
| [`docs/`](docs) | Technical plan, formats, measurements, reports and [architecture decisions](docs/adr); start at the [documentation index](docs/README.md) |
| `data/` | Local recordings and datasets; never committed |

## Contributing

Contributions are welcome: code, measurements, hardware reports and ideas. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Development happens on `dev`; `main` only receives merges from `dev` at release points. Every commit needs a DCO sign-off (`git commit -s`). Pull requests go against `dev` and are checked by CI; a maintainer reviews and merges them. Changes to detection report their effect on the benchmark.

- Ideas for the roadmap: [roadmap proposal](https://github.com/xXCrusaderXx/DartPilot/issues/new?template=roadmap_proposal.yml)
- Security problems: [SECURITY.md](SECURITY.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Legal notes, recordings and datasets: [LEGAL.md](LEGAL.md)
- AI coding agents: [AGENTS.md](AGENTS.md)

## License

DartPilot is licensed under the [GNU General Public License v3.0 or later](LICENSE). Datasets and recordings may have their own licenses (see [LEGAL.md](LEGAL.md)).
