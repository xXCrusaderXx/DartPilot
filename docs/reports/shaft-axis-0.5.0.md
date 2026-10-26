# Shaft axis, 0.5.0

How well each camera estimates the dart's axis, and what changes improve it (#27, technical plan 5.2). The location (`geometry::locateDart`) crosses the cameras' axis planes on the board, so the axis is what the point is made of: a camera whose axis plane passes a millimetre beside the entry point pulls the point that far. Measured on the [dataset](../dataset.md) of 2026-10-25 with the board refinement it was recorded with.

## How it is measured

Tracker replays now write each camera's axis plane met with the board, `axis_line` (`a x + b y = c_mm`, `geometry::axisBoardLine`). `python -m dartpilot_tools.candidate_recall` measures two things:

- **Axis error against ground truth:** the distance of the true point from each camera's line. The only truth with frames are the players' corrections.
- **Axis consistency without ground truth:** for every throw with axis lines from three or more cameras, how far each camera's line passes the point where the other cameras' lines cross. It uses every throw of every session, not only the annotated ones.

## The axis as it is

The axis was already a robust fit (#100, #119): `observeDart` takes the middles of the object's cross-sections, finds the straight line through most of them by trying every pair, and fits the line through those.

| Session | Throws with 3+ axes | Median | P90 | ≤ 1 mm | ≤ 2 mm |
| - | - | - | - | - | - |
| 91cb (development) | 32 | 0.58 mm | 10.2 mm | 0.71 | 0.81 |
| 5966, 0bef (development) | 18 | 0.9 – 8 mm | – | – | – |
| 9406 (test) | 20 | **0.74 mm** | **1.73 mm** | 0.73 | 0.90 |

5966 holds pins and darts put in by hand, so its objects are not all darts. Against the corrections (91cb, 24 camera views) the median axis error is 15 mm. All 17 corrections are darts the engine abstained on live, most of them cut by an image border, so that number describes the failures, not the typical axis.

**Where the tail comes from:** the large errors gather in a few throws (91cb: 33, 36, 39, 40, 42; 9406: 17). In their images, the new dart lies beside or across a dart already in the board, or was pushed against it, and one or two cameras cut the darts at the image border. The difference to the board before the throw then holds parts of two darts, and the middles of its cross-sections lie between them. The axis is wrong before any fit.

## What was tried

All variants were replayed on the four sessions with the same build and compared throw by throw.

| Variant | Effect | Decision |
| - | - | - |
| **Robust plane:** axis points far off the plane weighted down (Tukey), started from the plane most points agree with | points moved by at most 0.15 mm (91cb) and 0.09 mm (9406); consistency unchanged | dropped: no measurable gain |
| **End check with all tip candidates** (#26) instead of the two axis ends | would accept 4 of 16 abstentions, but 2 of them in the wrong field (S20 for T20, S16 for S8) | dropped: abstaining is right there |
| **Split cross-sections** at gaps wider than 1 px (`section_gap_px`) | 91cb: 6 instead of 11 abstentions, but one new dart in the wrong field (S1 for S20, 36 mm off) | not used |
| **Split cross-sections** at gaps wider than 3 px | 91cb: 7 instead of 11 abstentions, all new darts in the right field; 9406: 15 instead of 14 throws with three cameras, consistency P90 1.73 → 1.21 mm, no field changed; 0bef: one more three-camera throw | kept as an option, off by default |

The 3 px split is the most promising change, but two of the darts it newly accepts are 12 and 33 mm from their truth: the field was right because the big single is wide. With only 12 throws of millimetre truth, that risk cannot be judged, and fewer abstentions must not come from wrong points. `section_gap_px` therefore stays at 0. It is decided again on the robustness cases of #29.

## Conclusion

- The axis is accurate where one dart is seen clearly: on the test session 90 % of the camera axes pass within 2 mm of the point the others agree on.
- Its errors come from views that hold more than one dart or only part of one, not from noise along a clean axis. A better point fit does not help there; separating the darts does.
- Splitting cross-sections at gaps does that where the darts are a few pixels apart. Touching or overlapping darts need more, e.g. telling the new dart from the old ones by their appearance (#120).

## Reproducing

```sh
dartpilot replay <sessions>/<id> --pipeline tracker --run-id axis-027 --extrinsics <calibration>/extrinsics.yml
dartpilot replay <sessions>/<id> --pipeline tracker --run-id gap3-027 --params gap3.json --extrinsics <calibration>/extrinsics.yml   # {"section_gap_px": 3}
cd tools
DARTPILOT=<build>/engine/apps/dartpilot_cli/dartpilot python -m dartpilot_tools.candidate_recall <sessions>/<id> --run axis-027
```
