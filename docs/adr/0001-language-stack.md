# ADR 0001: Language stack

- **Status:** accepted
- **Date:** 2026-10-23
- **Amended by:** [ADR 0003](0003-developer-gui.md) (developer GUI) and [ADR 0004](0004-user-interface.md) (user interface)

## Context

DartPilot needs a detection engine that captures three USB cameras with per-frame timestamps, runs the candidate, geometry and fusion pipeline, and replays recorded throws deterministically (see the [technical plan](../technical_plan.md)). It also needs tooling to annotate throws, compute benchmark metrics and plot error distributions. A user interface and online multiplayer come later and must attach through a stable interface.

The maintainer works mainly in C++ and OpenCV.

## Decision

- **Engine: C++20, CMake, OpenCV.** All modules (`capture`, `event_detection`, `tip_candidates`, `geometry`, `fusion`, `scoring`, `replay`) live under `engine/`.
- **Tools: Python** (NumPy, pandas, Matplotlib) under `tools/` for benchmark evaluation, annotation helpers and plots. The tools read the engine's replay and result files; they never sit in the detection path.
- **UI: not decided** at the time; decided in [ADR 0004](0004-user-interface.md) (Flutter). It talks to the engine through an API (for example JSON over WebSocket) so the choice (Flutter or another toolkit) does not affect the engine.

## Alternatives considered

- **Rust.** Memory safety and good tooling, but OpenCV is only available through generated bindings (`opencv-rust`) with a less convenient API. The project's risk is algorithmic precision, not memory safety, so the switch would add learning effort without improving the core metric.
- **Python only.** Fastest for experiments, but less suited for low-latency multi-camera capture with tight control over buffers and timestamps.
- **C++ only, including the benchmark.** Possible, but plotting and ad-hoc data analysis are much faster in Python.

## Consequences

- CI builds and tests the C++ engine (CMake, ctest) and checks the Python tools (ruff, pytest).
- Direct V4L2 access is available for kernel capture timestamps where OpenCV's `VideoCapture` does not expose them.
- Data exchanged between engine and tools needs a documented file format; it is defined together with the replay format in phase 1.
