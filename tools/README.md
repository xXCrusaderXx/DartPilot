# DartPilot tools

Python package `dartpilot_tools`: benchmark evaluation, ground truth and reports for recorded sessions. The tools read the engine's session and result files ([replay-format.md](../docs/replay-format.md)); they are never part of the detection path.

```sh
cd tools
python -m venv .venv && . .venv/bin/activate
pip install -e '.[dev]'
pytest
ruff check . && ruff format --check .
```

Python 3.11 or newer. Every tool runs as `python -m dartpilot_tools.<tool>`; `--help` shows its options, and the module's docstring describes its method.

## Tools

| Tool | What it does | More |
| ---- | ------------ | ---- |
| `capture_report` | Capture health of a recording: frame rate, losses, latency and timestamp quality per camera | [replay-format.md](../docs/replay-format.md) |
| `benchmark` | Scores a detection run against ground truth: radial error, field accuracy, abstentions, grouped by ring and flags; writes a report, CSV and plots | [benchmark.md](../docs/benchmark.md) |
| `compare` | Compares several detection runs on exactly the same throws | [benchmark.md](../docs/benchmark.md) |
| `corrections` | Turns the corrections and confirmed fields from a recorded game into annotation sets | [ADR 0011](../docs/adr/0011-ground-truth.md) |
| `detection_test` | Turns a detection test of the setup GUI into a small session the benchmark can score | [ADR 0011](../docs/adr/0011-ground-truth.md) |
| `projection_error` | How well each camera on its own puts a dart on the board, by region and viewing angle | [benchmark.md](../docs/benchmark.md) |
| `candidate_recall` | How often one of a camera's tip candidates lies at the true tip | [tip candidates report](../docs/reports/tip-candidates-0.5.0.md) |
| `timing` | How synchronous the cameras are: offsets, jitter and drift | [camera timing](../docs/benchmarks/camera-timing.md) |
| `timeline` | One timeline per throw: every camera's frames, losses and the frames the detection used | [benchmark.md](../docs/benchmark.md) |

## Modules

| Module | Content |
| ------ | ------- |
| `session` | Reader for recorded sessions and their results |
| `scoring` | Port of `engine/scoring`; must give the same result as the C++ scorer for every point (`tests/fixtures/scoring/cases.json`) |
| `annotation` | Ground-truth annotation flags (cut, occluded, near a wire, …) |
| `probes` | Evaluation of hardware measurement probes in [`probes/`](probes) |
