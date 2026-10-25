# Temporal association of the cameras

How much it matters which frames of the cameras are taken together (#24, technical plan 5.1 experiment 1), measured on the game 20261025T080221Z-91cb (49 darts) with the live detection replayed.

## How frames are associated

- **Replay** orders the frames of all cameras by their exposure time, the mapped UVC PTS (ADR 0005), not by when they arrived. [camera-timing.md](camera-timing.md) measured these times to be true within about 1 ms between the cameras. So the replay already associates frames by measured capture time.
- **Live detection** looks at each camera's latest delivered frame at every sample. All cameras deliver about 32 ms after exposure, so this is the same association up to the delivery jitter of a few ms.
- **The detection measures the board only when it is still**: after 200 ms without motion, it averages 4 frames per camera (#192). Between two cameras, the frames of such a moment are at most half a frame apart (the free-running phase, up to 17 ms).

## Experiment

The replay can shift one camera's frames in time (`dartpilot replay --camera-offset usb-2.4.3.1.3=MS`), which makes the association wrong on purpose by that much. The game was replayed with camera .3 shifted by 0 to 250 ms. Every located point was compared with the one the unshifted replay found for the same dart.

| Shift of camera .3 | Darts located in both | Point moved: median | P90 | Max | Darts whose field or abstention changed |
| - | - | - | - | - | - |
| 17 ms (half a frame) | 35 | 0.04 mm | 0.44 mm | 1.22 mm | 1 of 47 |
| 33 ms (one frame) | 35 | 0.11 mm | 0.45 mm | 1.22 mm | 1 |
| 67 ms | 34 | 0.23 mm | 0.79 mm | 1.35 mm | 2 |
| 100 ms | 33 | 0.19 mm | 0.75 mm | 1.22 mm | 3 |
| 167 ms | 35 | 0.22 mm | 0.98 mm | 1.42 mm | 3 |
| 250 ms | 32 | 0.24 mm | 0.82 mm | 87.7 mm | 6 |

No confirmed dart moved into a wrong field at any shift. The changed decisions are abstentions that came or went: with 29 to 30 of the 32 confirmed fields right at every shift up to 167 ms, they are the size of the run-to-run differences of #192.

## What it means

- **For the current detection, the association does not limit the precision.** A wrong association of half a frame, the most the free-running cameras can produce, moves the points by 0.04 mm (median). Even a full frame moves them by 0.1 mm, against a precision target of 1.5 mm. The reason is the still moment: the board does not change within it.
- **It starts to matter at about a quarter of a second.** Then a shifted camera averages frames of a different state of the board (a dart just pulled or put in), as the 88 mm outlier at 250 ms shows. That is longer than the settle time of 200 ms. The settle time therefore also bounds how wrong the association may be.
- **Measuring during motion would change this**: the dart in flight, a bounce-out (#199), the hand at the board. There, frames half a frame apart see the dart about 10 mm apart in flight. Pairing frames by the measured exposure times, as the replay does, would then be needed, and the timestamps are good enough for it.
- **Hardware sync is not needed** for still-moment detection. That is input for the geometry decision (#25).
