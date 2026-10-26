# Tip candidates, 0.5.0

Several tip candidates per camera instead of one point (#26, technical plan 5.2), and how often one of them lies at the true tip: the candidate recall. Measured on the [dataset](../dataset.md) of 2026-10-25 with the board refinement it was recorded with (sha256 `d23798d6…`).

## What changed

Per camera, `tip_candidates::tipCandidates` turns the observation of a dart into candidates from three generators, one at each end of the dart and none within 5 px of the image border:

- **axis_end**: an end of the axis as `observeDart` refines it (the two points the tracker used before),
- **contour_end**: the object's outermost pixel along its axis,
- **skeleton_end**: an end of the object's skeleton (thinning of Zhang and Suen), the end furthest along the axis.

Tracker replays list them in `tip_candidates` with their `source`, after the selected tip. The location does not use them yet: replays of 91cb and 9406 give the same points as before on every throw. Recall is measured with `python -m dartpilot_tools.candidate_recall`, which projects the true point into each camera with the engine's own model (`dartpilot project`).

## Recall

The only ground truth with frames are the players' corrections (ADR 0011: taps in the app, about 3 mm, 1 σ). One millimetre spans 1.2 to 1.7 px in these cameras, so 10 px are about 6 to 8 mm.

### Development session 91cb (10 corrected throws with views, 30 camera views)

| Candidates | ≤ 2 px | ≤ 5 px | ≤ 10 px | ≤ 20 px |
| - | - | - | - | - |
| selected tip | 0.03 | 0.03 | 0.13 | 0.17 |
| axis ends | 0.03 | 0.03 | 0.23 | 0.30 |
| contour ends | 0.03 | 0.07 | 0.30 | 0.47 |
| skeleton ends | 0.00 | 0.07 | 0.30 | 0.53 |
| all candidates | 0.07 | 0.10 | **0.37** | **0.57** |

### Test session 9406 (2 corrected throws, 6 camera views)

| Candidates | ≤ 2 px | ≤ 5 px | ≤ 10 px | ≤ 20 px |
| - | - | - | - | - |
| selected tip | 0.00 | 0.00 | 0.00 | 0.00 |
| axis ends | 0.00 | 0.00 | 0.00 | 0.17 |
| contour ends | 0.00 | 0.33 | 0.50 | 0.83 |
| skeleton ends | 0.00 | 0.33 | 0.50 | 0.83 |
| all candidates | 0.00 | 0.33 | **0.50** | **1.00** |

## What the numbers say

- **The corrected throws are the hardest ones.** All 17 corrections of 91cb are darts the engine abstained on live, and most of them were cut by an image border. The recall above is the recall on failures, not on typical throws.
- **The new generators find the tip where the axis ends do not.** On these throws, all candidates together lie within 10 px of the truth almost three times as often as the selected tip, and within 20 px in more than half of the views. The contour and skeleton ends reach further along a fading point than the refined axis end.
- **The location does not depend on the tip.** `locateDart` crosses the cameras' axis planes on the board, and uses the ends only to check that the point lies at a visible end (within 12 px). So better candidates help where that check rejects a good point, and better axes help everywhere; the second is #27.
- **The validation set is too small.** 12 throws with millimetre truth and frames give a first number, not a reliable one. Annotated robustness cases (#29) are needed: a reference run with frames, darts at known places near wires, in the bull and the rings, and with occluded tips.

## Reproducing

```sh
dartpilot replay <sessions>/<id> --pipeline tracker --run-id cand-026 --extrinsics <calibration>/extrinsics.yml
cd tools
DARTPILOT=<build>/engine/apps/dartpilot_cli/dartpilot python -m dartpilot_tools.candidate_recall <sessions>/<id> --run cand-026
```
