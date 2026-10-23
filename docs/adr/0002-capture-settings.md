# ADR 0002: Capture settings for the reference cameras

- **Status:** proposed – values marked "to tune" are set after the measurements in #3 and #44
- **Date:** 2026-10-23

## Context

The reference setup uses three identical UVC cameras (see [hardware.md](../hardware.md)). Calibration (#44) is only valid for fixed capture settings, synchronisation needs stable frame timing, and tip localisation needs sharp, consistently exposed images. Automatic exposure and white balance change the image between throws and can change the frame rate.

## Decision

| Setting | Value | Reason |
| ------- | ----- | ------ |
| Format | MJPG, 1280×720 | Only format with full resolution at 30 fps over USB 2.0 |
| Frame rate | 30 fps | Highest available |
| `auto_exposure` | 1 (manual) | Same exposure in every frame; no frame rate changes |
| `exposure_time_absolute` | to tune, as short as the LED ring allows (target ≤ 10 ms) | Short exposure reduces motion blur of the incoming dart |
| `exposure_dynamic_framerate` | 0 | Keep 30 fps regardless of light |
| `white_balance_automatic` | 0, `white_balance_temperature` to tune for the LED ring | Stable colours for the segment colour detection |
| `sharpness` | to tune (lowest value that keeps edges sharp) | In-camera sharpening shifts edges and may hurt sub-pixel accuracy |
| `power_line_frequency` | 50 Hz | Matches the mains frequency of the reference setup |
| Camera identity | USB port path, verified against the image content | Serial numbers are identical on all cameras |

The capture module applies these settings at start and refuses to start, or warns, when a camera does not accept them. Every recording stores the settings actually applied.

## Alternatives considered

- **YUYV at 1280×720:** no compression artefacts, but only 10 fps. Kept as a comparison in #3; reconsidered if MJPG artefacts measurably limit sub-pixel accuracy.
- **Lower resolution with YUYV at 30 fps (640×480):** halves the pixels per millimetre on the board, which already is only about 1–2 px/mm.
- **Automatic exposure:** simpler, but changes images between baseline and throw frames and breaks calibration and difference masks.

## Consequences

- The LED ring is part of the setup: without it, manual short exposures may be too dark, and there is no gain control.
- Calibrations and recordings are keyed by USB port path; re-plugging cameras must be detected.
- MJPG artefacts are a known error source that #3 measures.
