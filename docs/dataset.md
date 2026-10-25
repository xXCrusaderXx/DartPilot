# Benchmark dataset

The first dataset of recorded sessions with ground truth (#16), version **2026-10-25**. Every number in the [baseline report](reports/baseline-0.3.0.md) refers to it.

The sessions are recordings in the [replay format](replay-format.md), kept on the maintainer's computer under `~/.local/share/dartpilot/sessions/`. They are **not published yet**: together they are about 30 GB, and frames of a home stay out of the repository (LEGAL.md). An optional donation of annotated throws to an open benchmark is #133.

## Setup

All sessions are from the reference setup of ADR 0009: three identical UVC cameras at about 45 cm and 38–39° elevation (one at the left, two at the right), MJPG 1280×720 at 30 fps, LED ring, white balance 3000 K, steel-tip darts on a bristle board. The board refinement is `extrinsics.yml` of 2026-10-24 (sha256 `d23798d6…`), with the camera at USB port 2.4.3.1.4 recalibrated on 2026-10-25 07:37.

## Sessions

| Session | Content | Frames | Ground truth | Split |
| - | - | - | - | - |
| 20261024T162232Z-5966 | Pins and darts put in by hand, 10 darts, 2 min | 9,537 | none | development |
| 20261024T185432Z-0bef | Two dart types put in by hand, ring light, 9 darts, 3 min | 16,200 | none | development |
| 20261025T074057Z-4ebd | Reference run: 10 darts in known wire corners, no frames (the engine's located points only) | 0 | `reference_corners` (10 points) | test |
| 20261025T080221Z-91cb | A game of 501, thrown, 49 darts, 14 min | 73,331 | `corrections` (17 points) and 32 confirmed fields | development |
| 20261025T093140Z-9406 | Detection test, thrown, 25 darts, 2 h (mostly idle after 10:41), not finalized (engine killed) | 393,550 | `corrections` (2 points, 1 rejected) and the confirmed fields | test |

**Ground truth** follows ADR 0011:
- `reference_corners` are millimetre truth: 0.5 mm tangential, 1.0 mm radial (1 σ).
- `corrections` are the player's taps in the app, with 3 mm uncertainty.
- Confirmed fields are placed darts the player left alone: the field is right, the millimetres are unknown.

**Split by session.** Detection values were chosen on 91cb (#192, #196) and tried on 5966 and 0bef, so those three are **development** sessions; their results are optimistic. 9406 and the reference run 4ebd were not used for any choice and are the **test** sessions. A session is never split: frames of one session are too alike to keep test throws independent.

## Left out

- 20261024T215750Z-a98b, reference darts with frames: only the first of its ten targets was recorded (107 s).
- 20261024T235407Z-f5a3, hand detection: no motion at all.
- 20261025T074259Z-64ad and 20261025T075637Z-5030: the live detection never started (an outdated empty-board image, then motion not seen, fixed in #190); no throws.
- 20261025T093049Z-7773 (20 s) and 20261024T160909Z-f1fb (30 s): no throws.

## Reproducing

```sh
dartpilot replay <sessions>/<id> --pipeline tracker --run-id tracker-019 --extrinsics <calibration>/extrinsics.yml   # or --pipeline baseline
cd tools
python -m dartpilot_tools.corrections <sessions>/<id>          # annotation set "corrections"
python -m dartpilot_tools.benchmark <sessions>/<id> --run tracker-019 --annotations corrections --out <dir>
```

A new version of the dataset adds sessions and keeps the split of the old ones.
