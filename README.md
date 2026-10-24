# DartPilot

[![CI](https://github.com/xXCrusaderXx/DartPilot/actions/workflows/ci.yml/badge.svg)](https://github.com/xXCrusaderXx/DartPilot/actions/workflows/ci.yml)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](LICENSE)

An open-source **automatic dart scoring engine for three USB cameras**. Its goal is a more precise impact position than existing camera-based systems, backed by a reproducible millimetre benchmark instead of claims.

DartPilot treats scoring as a measurement problem: every throw yields a board point in millimetres with its uncertainty and diagnostics, and the engine may abstain instead of forcing a wrong score. The full reasoning is in the [technical plan](docs/technical_plan.md).

> **Status: early development.** The repository contains the project structure; the engine modules are still empty. Work starts with [phase 1 – Measurability](ROADMAP.md).

> DartPilot is an independent project. It is not affiliated with any manufacturer of dartboards or dart scoring systems. See [LEGAL.md](LEGAL.md).

## How it works

```text
3 USB cameras ─► capture (timestamps, frame IDs, ring buffers)
              ─► event_detection (throw window, difference masks)
              ─► tip_candidates (tip candidates per camera, with covariance)
              ─► geometry (board projection / triangulation)
              ─► fusion (temporal association, robust estimate, abstention)
              ─► scoring (board point in mm ─► sector and ring)
              ─► score + confidence + diagnostics
```

Detection, geometry and scoring are separate modules. Every result can be traced back to its source frames, and every recorded throw can be replayed with identical results.

The core metrics are the radial position error in mm (median, P95), segment and multiplier accuracy, and false acceptance and abstention rates, which are always reported together. See [section 6 of the technical plan](docs/technical_plan.md#6-metrics-and-preliminary-targets).

## Repository layout

| Path | Content |
| ---- | ------- |
| [`engine/`](engine) | C++20 engine: one library per module, plus `apps/dartpilot_cli` and the developer GUI `apps/dartpilot_setup` (Qt 6, optional) |
| [`tests/`](tests) | C++ tests (GoogleTest, run with `ctest`) |
| [`ui/`](ui) | Flutter player app (Linux, Windows, web, Android), see [ADR 0004](docs/adr/0004-user-interface.md) |
| [`tools/`](tools) | Python tools for benchmark evaluation and annotation |
| [`docs/`](docs) | [Technical plan](docs/technical_plan.md), [reference hardware](docs/hardware.md), [session format](docs/replay-format.md), [engine API](docs/engine-api.md) and [architecture decisions](docs/adr) |
| `data/` | Local recordings and datasets; never committed |

## Building from source

Requirements: CMake 3.20 or newer, a C++20 compiler and OpenCV 4 or 5. GoogleTest is downloaded automatically when the tests are enabled.

```sh
# Arch Linux
sudo pacman -S --needed base-devel cmake ninja opencv
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

### Checking and recording the cameras

```sh
./build/engine/apps/dartpilot_cli/dartpilot capture-check 30     # frame rate, losses and timestamp quality
./build/engine/apps/dartpilot_cli/dartpilot record --seconds 60  # session in ~/.local/share/dartpilot/sessions
python -m dartpilot_tools.capture_report ~/.local/share/dartpilot/sessions/<session>   # capture health of a recording
```

A recording of three cameras takes about 200–360 MB per minute, depending on the scene; the format is described in [docs/replay-format.md](docs/replay-format.md). Recordings stay on your computer and are never committed (see [LEGAL.md](LEGAL.md)).

### Python tools

```sh
cd tools
python -m venv .venv && . .venv/bin/activate
pip install -e '.[dev]'
pytest
```

### Player app

The Flutter app in [`ui/`](ui) needs the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.47 or newer). Until the engine API exists, darts are entered on the screen.

```sh
cd ui
flutter run -d linux
flutter test
```

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first. Development happens on `dev`; `main` only receives merges from `dev` at release points. Every commit needs a DCO sign-off (`git commit -s`). Pull requests go against `dev` and are checked by CI; a maintainer reviews and merges them. Changes to detection report their effect on the benchmark.

- Security problems: [SECURITY.md](SECURITY.md)
- Code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Legal notes, recordings and datasets: [LEGAL.md](LEGAL.md)
- Plans and milestones: [ROADMAP.md](ROADMAP.md)

## License

DartPilot is licensed under the [GNU General Public License v3.0 or later](LICENSE). Datasets and recordings may have their own licenses (see [LEGAL.md](LEGAL.md)).
