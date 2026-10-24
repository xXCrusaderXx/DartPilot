# ADR 0009: Board-based calibration, validated

- **Status:** accepted
- **Date:** 2026-10-25
- **Issues:** #48, #13, #44, #47

## Context

ADR 0006 made the dartboard itself the calibration target. Each camera's pose, focal length and distortion are refined from the wire intersections of the empty board, jointly for all cameras and against one measured board model (#13, #47). The lens prior comes from a ChArUco calibration of the camera or of another camera of the same model. #48 asked whether this is accurate enough, measured in board millimetres, and for the method to be decided here.

## Measurements

All values are from the reference setup (three identical UVC cameras at about 45 cm, LED ring, white balance fixed at 3000 K, #150). The refinement is from 2026-10-24T21:44:17Z.

**Held-out wires.** The wires are split into four groups. Each group is held out once, and its intersections are predicted by the refinement of the other three. The wires are an absolute reference: the board's own geometry, which scoring is relative to.

| Camera | Lens prior | Held-out error | Fit error | Parameter uncertainty (1 σ, scoring area) |
| - | - | - | - | - |
| usb-2.4.3.1.2 | own ChArUco calibration | 0.39 mm | 0.36 mm | 0.12 mm |
| usb-2.4.3.1.3 | same model | 0.63 mm | 0.57 mm | 0.20 mm |
| usb-2.4.3.1.4 | same model | 0.72 mm | 0.67 mm | 0.22 mm |

**Board detection on recordings (#47).** Board found in 1 s averages of three recordings, with 60 wire intersections per camera:

| Recording | usb-2.4.3.1.2 | usb-2.4.3.1.3 | usb-2.4.3.1.4 |
| - | - | - | - |
| empty board, 30 s | 30 / 30 | 30 / 30 | 30 / 30 |
| darts put in and pulled, type 1 | 102 / 106 | 89 / 106 | 101 / 106 |
| darts put in and pulled, type 2 | 175 / 180 | 175 / 180 | 171 / 180 |

- The misses are moments when darts or a hand cover the board.
- Largest deviation of a detected wire from its fitted line, median: 0.7, 0.9–1.0 and 0.9–1.0 px.
- A fresh detection against the stored calibration: 0.6, 1.2–1.3 and 0.8–0.9 px RMS.

**Cross-camera consistency.** For a dart seen by three cameras, each camera's axis plane passes within some distance of the located point. The median of the largest of these distances:

| Data | Darts | Median agreement |
| - | - | - |
| live setup diagnosis, 2026-10-24 evening | 14 | 0.29 mm |
| recording, type-1 darts | 10 | 0.26 mm |
| recording, type-2 darts | 9 | 0.44 mm |

**Pins clicked by hand (#98).** The spread between cameras was 0.7–2.7 mm, median 2.3 mm. Clicking the same pin again moved it by about 1 mm per camera, so this method measures the click more than the calibration. It is kept as a quick plausibility check for users.

## Decision

- The board-based refinement of ADR 0006 is the calibration method. A ChArUco lens calibration per camera is optional: it lowered the held-out error from about 0.65 to 0.39 mm on the reference setup and is recommended when a camera stays at "fair".
- Error budget of the calibration, provisional for scoring:
  - **good** below 0.5 mm held-out;
  - **fair** below 1.0 mm;
  - otherwise **poor**, with a hint to measure the board again or calibrate the lens.
  
  The calibration check (#92) and the setup diagnosis (#137) use the same scale.
- The absolute position of a dart's tip, as opposed to the wires, is not a calibration question. It belongs to the ground truth of the tip localisation (#14) and is measured there, with a guided reference measurement in the app.

## Consequences

- #13, #44, #47 and #48 are done for 0.2.0. #45 and #46, the guided ChArUco capture and the method comparison, moved to 1.0.0.
- The calibration contributes about 0.4–0.7 mm (held-out, per camera) to a dart's error, and less after fusion of several cameras. Tip localisation and fusion (0.5.0, 0.6.0) are measured against this floor.
- Not measured, and left open: the sensitivity to the assumed wire height and to the viewing angle (#48 tasks). The held-out wires include their effect at the reference setup's angles.
