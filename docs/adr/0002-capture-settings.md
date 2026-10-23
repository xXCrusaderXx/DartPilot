# ADR 0002: Capture settings for the reference cameras

- **Status:** accepted – exposure revised after the measurements of 2026-10-23 (see [hardware.md](../hardware.md#exposure-and-gain)); values marked "to tune" follow from #3 and #44
- **Date:** 2026-10-23

## Context

The reference setup uses three identical UVC cameras (see [hardware.md](../hardware.md)). Calibration (#44) is only valid for fixed capture settings, synchronisation needs stable frame timing, and tip localisation needs sharp, consistently exposed images. Automatic exposure and white balance can change the image between throws and can change the frame rate.

Measurements showed that these cameras have **no usable manual exposure at 30 fps**: there is no gain control, and the automatic mode applies an internal gain of roughly 10× that is not available in manual mode. With the LED ring, the board reaches a brightness of about 130/255 in automatic mode and only about 14/255 at the longest manual exposure that keeps 30 fps (33 ms).

## Decision

| Setting | Value | Reason |
| ------- | ----- | ------ |
| Format | MJPG, 1280×720 | Only format with full resolution at 30 fps over USB 2.0 |
| Frame rate | 30 fps | Highest available |
| `auto_exposure` | 3 (aperture priority, i.e. automatic) | Only mode with usable brightness at 30 fps; the hidden gain is only applied here |
| `exposure_time_absolute` | not used in automatic mode | Manual exposure is an option only for setups with about 10× more light on the board than the reference LED ring |
| `exposure_dynamic_framerate` | 0 | It is on after every connect and lowers the rate to about 16.7 fps in room light; capture switches it off every time it opens a camera |
| `white_balance_automatic` | 0, `white_balance_temperature` to tune for the LED ring | Stable colours for the segment colour detection |
| `sharpness` | to tune (lowest value that keeps edges sharp) | In-camera sharpening shifts edges and may hurt sub-pixel accuracy |
| `power_line_frequency` | 50 Hz | Matches the mains frequency of the reference setup |
| Camera identity | USB port path (`/dev/v4l/by-path/`), verified against the image content | Serial numbers are identical on all cameras; `/dev/videoN` can change between boots |

The capture module applies these settings at start and refuses to start, or warns, when a camera does not accept them. Every recording stores the settings actually applied.

Because exposure is automatic, the pipeline must tolerate brightness changes:

- Baseline and post-throw frames are compared only after the exposure has settled (no brightness trend over the last frames).
- Difference masks use brightness-normalised frames (global gain/offset fitted on the unchanged board area).
- Every frame's mean brightness is logged, so replay and the benchmark can detect exposure jumps.

## Alternatives considered

- **YUYV at 1280×720:** no compression artefacts, but only 10 fps. Kept as a comparison in #3; reconsidered if MJPG artefacts measurably limit sub-pixel accuracy.
- **Lower resolution with YUYV at 30 fps (640×480):** halves the pixels per millimetre on the board, which already is only about 1–2 px/mm.
- **Manual exposure (original proposal):** constant images, but at 30 fps the board is nearly black (≤ 14/255) without gain. Usable only with much stronger lighting; kept as an option.
- **Vendor extension unit:** the cameras have an undocumented Realtek extension unit (GUID `1229a78c-47b4-4094-b0ce-db07386fb938`, two 8-byte selectors) that looks like a register/flash mailbox. It might reach the sensor gain, but writing to it risks bricking the camera and would only work for this chip; not used.

## Consequences

- Exposure time is not under our control, so motion blur of the incoming dart is not either. Detection uses frames of the resting dart, where blur does not matter.
- Brightness normalisation and the settle check become part of `event_detection` (#18) and of the replay format (per-frame brightness).
- White balance is set before focusing and before the intrinsic calibration (see the focus procedure in [hardware.md](../hardware.md)).
- Calibrations and recordings are keyed by USB port path; re-plugging cameras must be detected. Intrinsic calibrations are stored as `~/.local/share/dartpilot/calibration/intrinsics-usb-<port>.yml`.
- MJPG artefacts are a known error source that #3 measures.
