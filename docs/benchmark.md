# Benchmark

One command computes the core metrics of a detection run against ground truth (#17, technical plan section 6.1):

```sh
cd tools
python -m dartpilot_tools.benchmark ~/.local/share/dartpilot/sessions/<session>... --run <run id> --annotations <set> --out <dir>
```

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

Ground truth and results are scored with `dartpilot_tools.scoring`, a port of `engine/scoring`. Both are tested against the same points in `tests/fixtures/scoring/cases.json`, so a change to one scorer fails the other's test until both agree.
