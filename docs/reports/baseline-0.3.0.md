# Baseline report, 0.3.0

How well the first detection works, measured on the [dataset](../dataset.md) of 2026-10-25 against its ground truth ([ADR 0011](../adr/0011-ground-truth.md)) (#19). Two pipelines, both replayed from the recordings with the same board refinement (#18):

- **baseline**: plain frame differencing. The largest changed region is the dart, and its tip is the point of that region furthest towards the board. The board points of all cameras that saw a change are averaged. This is the reference that later work is measured against.
- **tracker**: the live detection of `dartpilot serve` (`fusion::DartTracker`). It finds the dart's axis per camera, locates the point from the cameras whose axes agree, and abstains otherwise. Replayed with the values of #192 (settle 6 frames, average 4).

## Results

### Test session 9406 (detection test, 25 thrown darts; not used for any choice)

| | Baseline | Tracker |
| - | - | - |
| Confirmed fields (23): same field | 12 | **22** |
| other field | 11 | **0** |
| abstained | 0 | 1 |
| Corrected darts (2): located | 2, 8.6 mm median error | 1, 14.6 mm error |
| abstained | 0 | 1 |
| Takeouts | 8 | 8 |

### Development session 91cb (a game of 501, 49 thrown darts; values were chosen on it)

| | Baseline | Tracker |
| - | - | - |
| Confirmed fields (32): same field | 22 | **29** |
| other field | 10 | **0** |
| abstained | 0 | 3 |
| Corrected or missed darts (17): located | 11, 18.1 mm median error, 9 of 11 in the right field | 3, 6.2 mm median error, 2 of 3 in the right field |
| abstained or not found | 6 | 14 |
| Events matching no thrown dart | 5 | 3 |
| Takeouts | 15 | 15 |

### Reference run 4ebd (10 darts in known wire corners; test)

Only the tracker, live, since the run stores located points and no frames:
- 9 of 10 located, all in the right field;
- error median 1.33 mm, P90 1.59 mm, max 1.64 mm;
- tangential median 0.29 mm;
- radial within the ±1 mm uncertainty of the method (ADR 0011).

## What it says

- **The tracker does not put darts in a wrong field when it is sure.** Of 55 confirmed darts it placed 51 in the same field and abstained on 4. The baseline put 21 of them, about two in five, in another field.
- **The baseline never abstains.** That is its main fault: a camera that sees only the flight, a flight that moved when the next dart landed, or a dart cut off by the image border all go into the average.
- **The tracker abstains too often on hard darts.** In the game, the live run abstained on 13 of the 17 darts the player had to correct and missed the other 4, mostly darts near the 20 whose flights two cameras see cut off by the image border, and on 2nd and 3rd darts where an earlier dart is in the way of camera .4. These are the targets for 0.5.0 (tip localisation) and 0.6.0 (fusion, uncertain throws confirmed by the player, #126).
- **Millimetres are known only from the reference run.** The corrected darts are the hard cases with a 3 mm tap uncertainty: their errors (6–15 mm) describe failures, not precision. The precision target of 1.5 mm can only be checked with reference corners, and those are limited by the method's radial uncertainty of about 1 mm.
- **Latency** (live, #192): 0.4–0.5 s from a dart landing to the throw, of which about 0.1 s is processing.

## Not covered

- One board, one dart type thrown, one light. The two dart types and the ring light of 0bef have no ground truth.
- Bounce-outs (#199), darts pulled during a still moment, hands at the board.
- Darts the engine missed entirely: only those the player added are counted.

## Reproducing

See [dataset.md](../dataset.md). The runs are `baseline-019` and `tracker-019` in each session; their `run.json` records the values used.
