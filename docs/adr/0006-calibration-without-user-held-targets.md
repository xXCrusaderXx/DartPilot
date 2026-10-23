# ADR 0006: Calibration without user-held targets

- **Status:** accepted
- **Date:** 2026-10-24
- **Issues:** #44, #45, #13, #47

## Context

The intrinsic calibration was planned as a guided capture of a ChArUco pattern on a tablet, a phone or a print (#44, #45). The setup GUI implements it, with held-out validation and model choice. A first real session showed the limits of that plan at home:

- With only a phone available, 11 views reached 48 % coverage, all in the image centre. The 10×7 pattern is too small on a phone screen, and close to the camera the image is soft.
- A coarser 8×4 phone pattern and a narrower margin made it detectable, but holding a phone still at the right distance in every part of the image remained fiddly. The maintainer's verdict: nobody will do this at home.
- Even the good centre result (0.22 px held-out) says little about the image edges, where the 100° lens distorts most and where the edge of the board lies.

At the same time, the dartboard is a precise calibration target that is always there: more than a hundred wire intersections of known geometry, straight radial wires and circular rings, spread over the image region that matters (#47). The extrinsic calibration already uses it (#13).

Cameras of the same model are similar but not identical:

| Parameter | Difference between units | Cause |
| - | - | - |
| Principal point | typically 10–30 px | sensor and lens are never exactly centred |
| Focal length | about 1–2 % | focus setting, turning the lens moves it |
| Distortion | small | mostly given by the lens design |

## Decision

Users do not hold a calibration target. The intrinsics of each camera come from two sources:

1. **A prior per camera model.** One careful ChArUco calibration of the model, with a flat print and many views over the whole image, done once by a maintainer or contributor and shipped in the repository with its uncertainty. Every camera of that model starts from it.
2. **Refinement per camera from the dartboard,** together with the extrinsics: wire intersections, radial wires and rings (#47) of the empty board, seen by all three cameras, against one shared board model (#13). Per camera the refinement estimates the pose, the focal length and the distortion starting from the prior, and the principal point with the prior as a soft constraint, because a single view of one plane observes it only weakly.

The result is judged in board millimetres (#48): the board region is where accuracy matters, and an error of the principal point is largely absorbed by the pose for points on the board plane. If the error budget is not met, the setup GUI points to the fallback: a per-camera ChArUco calibration with the existing intrinsic calibration page.

The ChArUco page stays, as the tool for model priors, for the method comparison (#46) and as that fallback, not as the normal user flow.

## Alternatives considered

- **Per-camera ChArUco calibration by every user** (the previous plan). Most accurate where the pattern was seen, but needs a tablet or a print and patience; too much to ask at home.
- **Model prior only, no refinement.** No user effort, but it ignores the principal point and focal length of the individual camera.
- **Board only, without a prior.** One plane in one pose per camera cannot determine focal length, principal point and distortion together reliably; the prior makes the problem well posed.

## Consequences

- #44 becomes: model priors, the refinement from the board, and the error budget in board mm. The per-camera ChArUco flow remains as fallback.
- #45 (guided capture) serves the model priors and the fallback; it is no longer part of the normal setup.
- #46 compares the board refinement against a per-camera ChArUco reference calibration, in board mm.
- #47 must deliver points over the whole board with a pixel uncertainty each, and #13 optimizes intrinsics and poses together.
- Model priors live in the repository per camera model, with the target, the number of views, the coverage and the held-out error they were made with. Until a print-based prior of the reference cameras exists, the maintainer's phone calibration of camera 1 (centre only) is a provisional starting value.
- The refinement needs the empty board in view of all cameras; that is the only user action.
