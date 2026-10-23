# ADR 0005: Capture backend and timestamp source

- **Status:** accepted
- **Date:** 2026-10-23
- **Issue:** #3

## Context

Fusion and triangulation need to know when each camera exposed a frame (technical plan, sections 3.2 and 5.1). The three reference cameras run free, so the frames of different cameras have to be associated by time. Candidates for the frame time:

1. the V4L2 buffer timestamp of `uvcvideo`, flagged `TIMESTAMP_MONOTONIC | TSTAMP_SRC_SOE` (start of exposure),
2. the host time when the frame arrives in user space,
3. the camera's own UVC payload header timestamps: PTS (start of exposure on the camera's source clock, STC) and SCR (STC samples paired with USB frame numbers), available through the UVC metadata node (`video-index1`, format `UVCH`).

Capture can use OpenCV `VideoCapture` (V4L2 backend) or V4L2 directly.

## Measurements

All three cameras streaming MJPG 1280×720 at 30 fps at the same time, 300 frames each, probe [`tools/probes/uvc_timestamps.cpp`](../../tools/probes/uvc_timestamps.cpp), evaluation `python -m dartpilot_tools.probes.uvc_timestamps`:

| | Driver buffer timestamp | Arrival in user space | UVC PTS mapped to host clock |
| - | - | - | - |
| Frame interval | 32 or 36 ms, std 1.88 ms | 28–40 ms, std 1.9 ms | 33.328 ms, std < 0.001 ms |
| Relation | arrival − 32.0 ms (P95 32.04) | – | driver timestamp − PTS: median 1.2 ms, range −0.9 … +3.1 ms |

- The camera exposes on an exact 33.328 ms grid; only the USB delivery jitters on a 4 ms grid. The driver timestamp follows the delivery, not the exposure, although it is flagged as start of exposure.
- Every frame carries a PTS and SCR samples (header flags `0x8c`/`0x8d`). The STC runs at 15 MHz (measured 14.99994 MHz against the host clock, about 4 ppm off).
- No frame was lost in any stream, with or without the metadata node.
- OpenCV `VideoCapture` reports the driver timestamp (`CAP_PROP_POS_MSEC`, same 32/36 ms pattern) and gives no access to the sequence number or the metadata node.

## Decision

- **Capture uses V4L2 directly** (mmap streaming, `VIDIOC_DQBUF`), one thread per camera, streaming the video node and the metadata node (`/dev/v4l/by-path/…-video-index1`) together. OpenCV is used for decoding (MJPG) and image processing, not for capture.
- **The frame time is the UVC PTS mapped to `CLOCK_MONOTONIC`.** The mapping is a linear fit of SCR STC values against the host timestamps of the metadata blocks, over a sliding window, so clock drift is followed.
- Every frame record stores: sequence number, driver timestamp, arrival time, PTS (raw), mapped PTS, and the fit parameters in use. Missing PTS or a broken fit falls back to the driver timestamp and is flagged in the frame record.
- Drops are detected from gaps in the V4L2 `sequence`.
- Buffer count: 4 mmap buffers per camera; the ring buffer of #4 sits behind them.

## Alternatives considered

- **Driver buffer timestamp:** available everywhere without extra code, but it jitters by about ±2 ms against the real exposure, which matters for frame association across cameras.
- **Arrival time:** additionally contains scheduling latency of the host.
- **OpenCV `VideoCapture`:** simplest, but limited to the driver timestamp and without sequence numbers or metadata.

## Consequences

- `engine/capture` needs a small V4L2 streaming layer and a UVC metadata parser. Cameras without UVC metadata or without PTS/SCR work with the driver timestamp, with lower timing precision; the frame record says which source was used.
- The mapped PTS gives each camera a precise exposure time on a common clock, but not a common offset: the absolute offset between cameras is still measured with a shared visible event (#20).
- The comparison of MJPG and YUYV for sub-pixel accuracy, originally listed for #3 in [hardware.md](../hardware.md), needs a calibration target and is part of the calibration experiment (#46).
