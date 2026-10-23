# Session and replay format

- **Format version:** 1
- **Status:** proposed (issue #8)

A **session** is one recording of all cameras, stored in one directory. The engine writes it while capturing (`dartpilot record`, #6), replays it offline (#9), and the Python tools read it (#10). Detection results and annotations live in the same directory, next to the frames they refer to, so every result can be traced back to its source frames (technical plan, section 8).

Sessions are never committed to the repository; see [LEGAL.md](../LEGAL.md#recordings-and-datasets).

## Directory layout

```text
<sessions root>/<session id>/
├── manifest.json            # cameras, settings, software version, calibration references
├── cameras/
│   └── <camera id>/
│       ├── frames.mjpg      # the camera's JPEG frames, concatenated as delivered
│       ├── frames.csv       # one line per frame: sequence, timestamps, position in frames.mjpg
│       └── clock.csv        # camera-clock samples for the PTS mapping (docs/adr/0005)
├── capture.csv              # periodic capture health per camera (#7)
├── throws.csv               # detected throws and their frame windows
├── results/
│   └── <run id>/
│       ├── run.json         # software version and configuration of this detection run
│       └── throws.jsonl     # one result record per throw
└── annotations/
    └── <annotation set>.jsonl   # ground truth (#14, #15)
```

- **Sessions root:** `~/.local/share/dartpilot/sessions/` by default, configurable. The repository's `data/` folder can be used during development; it is ignored by Git.
- **Session id:** start time in UTC plus a short random suffix, `20261023T201500Z-3f9a`. It is unique and sorts by time; the wall-clock time in it is informational only and never used for timing.
- **Camera id:** the USB port path of the camera, e.g. `usb-2.4.3.1.2`, the same key the calibration files use. The serial numbers of the reference cameras are identical (see [hardware.md](hardware.md)), so the port is the only stable identity.

## manifest.json

```json
{
  "format": "dartpilot-session",
  "version": 1,
  "session_id": "20261023T201500Z-3f9a",
  "created_utc": "2026-10-23T20:15:00Z",
  "software": { "version": "0.1.0", "commit": "12b196b" },
  "time_base": "CLOCK_MONOTONIC",
  "cameras": [
    {
      "id": "usb-2.4.3.1.2",
      "usb_port": "2.4.3.1.2",
      "device_path": "/dev/v4l/by-path/pci-0000:0e:00.4-usb-0:2.4.3.1.2:1.0-video-index0",
      "name": "USB Camera: USB Camera",
      "stream": { "pixel_format": "MJPG", "width": 1280, "height": 720, "fps": 30 },
      "controls": { "auto_exposure": 3, "exposure_dynamic_framerate": 0, "power_line_frequency": 1 },
      "metadata": true,
      "calibration": {
        "intrinsics": { "file": "intrinsics-usb-2.4.3.1.2.yml", "sha256": "…" },
        "extrinsics": null
      }
    }
  ],
  "notes": ""
}
```

- `controls` are the values read back from the camera after they were applied, not the requested ones.
- `calibration` references files in the calibration directory by name and SHA-256, so a later recalibration does not silently change an old session. A replay can be given another calibration explicitly.
- Fields are added only in a backwards-compatible way within a version (see [Versioning](#versioning)).

## Frames

`frames.mjpg` holds the JPEG frames exactly as the camera delivered them, concatenated without any container. Storing the camera's own MJPG avoids re-encoding: the recording is bit-identical to what the engine saw live, and it costs no CPU.

`frames.csv` indexes it, one line per frame, in the order the frames were dequeued:

| Column | Type | Meaning |
| ------ | ---- | ------- |
| `sequence` | uint32 | V4L2 sequence number; gaps are frames the driver lost |
| `exposure_ns` | int64 | best estimate of the start of exposure on `CLOCK_MONOTONIC` |
| `timestamp_source` | `pts` / `driver` | where `exposure_ns` comes from (ADR 0005) |
| `driver_ns` | int64 | driver buffer timestamp |
| `arrival_ns` | int64 | time the frame was dequeued |
| `pts` | uint32 or empty | raw UVC PTS in camera clock ticks |
| `offset` | uint64 | byte offset of the JPEG in `frames.mjpg` |
| `size` | uint32 | JPEG size in bytes |

```text
sequence,exposure_ns,timestamp_source,driver_ns,arrival_ns,pts,offset,size
1,182056465845123,driver,182056497865000,182056529891789,3200005,0,41213
```

Frames dropped by the capture ring buffer because the writer fell behind are missing from `frames.mjpg` but are counted in `capture.csv`; recording must not hide them (#6).

## Clock samples

`clock.csv` keeps the per-frame camera-clock samples that the PTS mapping was fitted on (ADR 0005), so a replay can recompute or improve the mapping:

| Column | Meaning |
| ------ | ------- |
| `sequence` | frame the sample belongs to |
| `camera_ticks` | mean SCR camera clock of the frame, uint32 |
| `host_ns` | mean host time of the same SCR samples |

## Capture health

`capture.csv` gets one line per camera every second (#7):

| Column | Meaning |
| ------ | ------- |
| `time_ns` | `CLOCK_MONOTONIC` when the line was written |
| `camera` | camera id |
| `frames`, `lost_frames`, `overflow_drops`, `pts_frames` | counters since the start |
| `effective_fps` | frame rate from the exposure times |
| `latency_ms` | arrival minus exposure of the latest frame |
| `queued` | frames waiting in the ring buffer |
| `brightness` | mean image brightness of the latest frame, 0–255 (ADR 0002) |

## Throws

A **throw** is one dart landing on the board. Its **event window** is the time span around it that detection looks at: baseline frames before the throw and the frames after the dart has settled.

`throws.csv`:

| Column | Meaning |
| ------ | ------- |
| `throw_id` | `<session id>/<n>`, n counting from 1 in the order of `event_ns` |
| `event_ns` | time of the throw event on `CLOCK_MONOTONIC` |
| `window_start_ns`, `window_end_ns` | event window |
| `source` | `live` (detected while recording), `replay:<run id>`, or `manual` |

The frames of a throw are all frames of all cameras whose `exposure_ns` lies in its window, so a throw needs no per-camera frame lists and stays valid when the clock mapping is refitted. A session may contain no throws at all, e.g. a calibration or timing recording.

## Detection results

Every detection run over a session gets its own directory `results/<run id>/`, so runs with different software or configuration can be compared on the same frames (technical plan, experiment 3).

`run.json`:

```json
{
  "run_id": "20261024T090000Z-baseline",
  "software": { "version": "0.3.0", "commit": "…" },
  "config": { "...": "the complete configuration of the run" },
  "config_sha256": "…",
  "calibration": { "usb-2.4.3.1.2": { "intrinsics_sha256": "…", "extrinsics_sha256": "…" } }
}
```

`throws.jsonl` holds one JSON object per line and throw. The fields that exist today are fixed; modules add their diagnostics under `diagnostics` as they are built:

```json
{
  "throw_id": "20261023T201500Z-3f9a/17",
  "accepted": true,
  "board_xy_mm": [12.4, 98.1],
  "position_covariance_mm2": [[0.6, 0.1], [0.1, 0.9]],
  "score": { "sector": 20, "ring": "triple", "points": 60, "boundary_distance_mm": 1.3 },
  "confidence": 0.93,
  "camera_measurements": [
    {
      "camera": "usb-2.4.3.1.2",
      "frames": { "baseline": [1203, 1204, 1205], "after": [1241, 1242] },
      "tip_candidates": [
        { "pixel_xy": [641.2, 377.8], "covariance_px2": [[0.8, 0.0], [0.0, 1.4]], "confidence": 0.88 }
      ],
      "selected_candidate": 0,
      "board_xy_mm": [12.1, 98.4],
      "reprojection_error_px": 0.6
    }
  ],
  "diagnostics": {},
  "processing_latency_ms": 41.7
}
```

- `board_xy_mm` uses the board coordinate convention of #11; `score` is the output of the deterministic scorer (#12), whose field names are authoritative.
- `frames` lists the `sequence` numbers of the frames each camera contributed, so a result points back to exact frames.
- A rejected throw has `"accepted": false`, keeps its measurements and diagnostics, and may leave `board_xy_mm` and `score` as `null`.
- `processing_latency_ms` is measured live; in a replay it is the processing time of the replay and is not compared between runs.

## Annotations

Ground truth lives in `annotations/<annotation set>.jsonl`, one line per throw, keyed by `throw_id`. Its fields (board point, tip pixel per camera, annotator, uncertainty, flags such as "near wire" or "occluded") are defined with the ground-truth method (#14) and the annotation tool (#15).

## Replay and determinism

- A replay reads the frames of all cameras merged in the order of `exposure_ns`; frames with equal `exposure_ns` are ordered by camera id. It does not depend on the order in which frames arrived.
- The same session, configuration and software version give byte-identical `throws.jsonl` files, apart from `processing_latency_ms` (#9 checks this in CI).
- The replay uses only the times stored in the session; it never reads the wall clock.

## Writing rules

- All files of a session are append-only while recording. A frame's JPEG is written to `frames.mjpg` before its line in `frames.csv`, so after a crash the last index line can be trusted and a truncated tail of `frames.mjpg` is ignored.
- `manifest.json` is written at the start and rewritten atomically (write to a temporary file, rename) when recording ends, with the final counters.
- Writing runs on its own thread and never blocks capture; when it falls behind, the capture ring buffer drops and counts frames (#6).

## Size

At the reference settings a frame is about 25–55 KB. Three cameras at 30 fps write roughly **3–5 MB/s, i.e. about 0.2–0.3 GB per minute or 11–18 GB per hour**. Recording #6 will replace this estimate with a measured value.

## Versioning

- `manifest.json` carries `format` and `version`. Readers refuse sessions with a higher major version than they know.
- Within a version, new optional fields and new CSV columns may be added at the end; readers ignore what they do not know.
- Renaming or removing a field, or changing its meaning, needs a new version and a note in this document.
