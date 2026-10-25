# Benchmark

One command computes the core metrics of a detection run against ground truth (#17, technical plan section 6.1):

```sh
cd tools
python -m dartpilot_tools.benchmark ~/.local/share/dartpilot/sessions/<session>... --run <run id> --annotations <set> --out <dir>
```

A run of the live detection and one of the baseline (#18) over a recorded session come from the replay:

```sh
dartpilot replay ~/.local/share/dartpilot/sessions/<session> --pipeline tracker --run-id tracker
dartpilot replay ~/.local/share/dartpilot/sessions/<session> --pipeline baseline --run-id baseline
```

The sessions of the benchmark, their ground truth and their split are in [dataset.md](dataset.md); the results of 0.3.0 in [reports/baseline-0.3.0.md](reports/baseline-0.3.0.md).

It pairs each throw of `results/<run id>/throws.jsonl` with its ground truth in `annotations/<set>.jsonl` (see [replay-format.md](replay-format.md)), in one or more sessions. It writes four files into `<dir>`:

- `report.md` for people;
- `summary.json`, machine-readable, for comparing runs and PRs;
- `throws.csv`, one row per throw;
- `error_histogram.png` and `error_components.png`.

## Metrics

| Metric | Meaning |
| - | - |
| Abstention rate | Throws the engine did not accept, of all throws with ground truth |
| Segment accuracy | Accepted throws whose result scores the same field as the truth (e.g. `T20`) |
| Multiplier accuracy | The same for the ring only: single, double, triple or bull |
| False acceptance rate | Accepted throws that score differently from the truth, of all throws; the error that costs a game |
| Error | Distance between result and truth in mm: median, P90, P95, maximum |
| Radial / tangential | The error split along the radius through the true point (outwards positive) and across it (counter-clockwise positive); a mean far from zero is a bias, e.g. of the board model or the tip |
| Latency | `processing_latency_ms`, P50 and P95 |
| Frame drop rate | Lost and dropped frames of the recording, from its capture health |

Groups: throws near a ring or sector boundary (closer than 2 mm), the bulls, doubles and triples. Per camera: the error of each camera's own board point, where the run records one.

Ground truth can come from an annotation, from the reference measurement (`reference_corners`, #14), or from the corrections players made in a recorded game (`python -m dartpilot_tools.corrections <session>` writes `corrections`; about 3 mm uncertainty, so good for finding wrong scores rather than for millimetre errors).

Ground truth and results are scored with `dartpilot_tools.scoring`, a port of `engine/scoring`. Both are tested against the same points in `tests/fixtures/scoring/cases.json`, so a change to one scorer fails the other's test until both agree.

## Timeline of a throw

To see when each camera delivered which frame around a throw, and which frames a run measured with (#21):

```sh
cd tools
python -m dartpilot_tools.timeline ~/.local/share/dartpilot/sessions/<session> --run <run id> [--throw <throw id>]... [--out <dir>]
```

It writes one PNG per throw, into `results/<run id>/timeline/` by default, every throw of `throws.csv` without `--throw`. The top panel shows the whole event window: a row per camera with every frame at its exposure time, frames lost in between (red ×), the frames the run took the board from before the dart (blue) and with the dart (orange), the event time, and how the run saw the dart in that camera (`seen`, `cut`, …, ✓ when its measurement counted). The bottom panel is ±150 ms around the event: there the cameras' offsets against each other show, and each frame's delivery to the host from exposure to arrival.

## Projection error per camera

How well each camera on its own puts a dart on the board (#22): every camera's own board point, its tip pixel's ray on the board plane, against the ground truth.

```sh
cd tools
python -m dartpilot_tools.projection_error ~/.local/share/dartpilot/sessions/<session>... --run <run id> --annotations <set> [--calibration <dir>] --out <dir>
```

It writes `report.md` (per camera: count, median, P95 and maximum error, mean radial and tangential error as a bias; and the median error by region of the true point), `cameras.csv` (one row per throw and camera), `error_maps.png` (a board per camera, each true point coloured by its error, with the error as an enlarged arrow) and `error_angle.png` (error over the viewing angle to the board normal). The viewing angle comes from the camera poses of the board refinement, `extrinsics.yml` in the calibration directory (by default `~/.local/share/dartpilot/calibration`). It needs a run whose `camera_measurements` carry each camera's `board_point`. With `--annotations fused` it compares each camera with the run's own fused point instead: how far a camera lies from the cameras' agreement, a consistency check until ground truth with frames exists, not an accuracy.

## Comparing runs

To compare variants of the detection or geometry on exactly the same throws (#25):

```sh
cd tools
python -m dartpilot_tools.compare ~/.local/share/dartpilot/sessions/<session>... --run <name>=<run id> --run <name>=<run id>... --annotations <set> --out <dir>
```

Only throws with ground truth that every run has a result for count, so a variant that abstains more is not compared on easier throws. It writes `comparison.md` with median and P95 error, segment and multiplier accuracy, false acceptance and abstention per run, `comparison.csv`, and `comparison_error.png` with the error of each run's accepted throws.
