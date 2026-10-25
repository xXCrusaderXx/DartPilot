# Session and replay format

- **Format version:** 1
- **Status:** accepted (issue #8); written by `dartpilot record` (#6)

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
│       ├── throws.jsonl     # one result record per throw
│       └── calibration_checks.jsonl   # calibration checks of the cameras (#49)
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
        "extrinsics": { "file": "extrinsics.yml", "sha256": "…" }
      }
    }
  ],
  "notes": ""
}
```

- `controls` are the values read back from the camera after they were applied, not the requested ones.
- `calibration` references files in the calibration directory by name and SHA-256, so a later recalibration does not silently change an old session. A replay can be given another calibration explicitly. `extrinsics` is the joint refinement of all cameras (#13); it is referenced only for cameras it covers, and is `null` otherwise.
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
  "board_point": { "x_mm": 12.4, "y_mm": 98.1, "covariance_mm2": { "xx": 0.6, "xy": 0.1, "yy": 0.9 } },
  "score": {
    "ring": "triple", "sector": 20, "multiplier": 3, "points": 60, "label": "T20",
    "boundary_distance_mm": 1.3, "ring_boundary_distance_mm": 1.3, "sector_boundary_distance_mm": 4.8,
    "board_geometry": "nominal"
  },
  "confidence": 0.93,
  "camera_measurements": [
    {
      "camera": "usb-2.4.3.1.2",
      "frames": { "baseline": [1203, 1204, 1205], "after": [1241, 1242] },
      "tip_candidates": [
        { "pixel_xy": [641.2, 377.8], "covariance_px2": [[0.8, 0.0], [0.0, 1.4]], "confidence": 0.88 }
      ],
      "selected_candidate": 0,
      "board_point": { "x_mm": 12.1, "y_mm": 98.4, "covariance_mm2": { "xx": 1.1, "xy": 0.2, "yy": 1.9 } },
      "reprojection_error_px": 0.6
    }
  ],
  "diagnostics": {},
  "processing_latency_ms": 41.7
}
```

- `board_point` uses the board coordinates and field names of [board-coordinates.md](board-coordinates.md) (#11): `x_mm`, `y_mm` and `covariance_mm2` with `xx`, `xy`, `yy`.
- `score` is **derived output** of this run: the deterministic scorer (#12) applied to `board_point`. Its fields are those of `scoring::Score` (`ring` as snake_case enum, `sector` 1–20 or 0 for the bulls and a miss, `multiplier` 0–3, `points`, `label` such as `T20`), and `board_geometry` names the board geometry it was scored with: `nominal` or the id of a measured board model (#47). `sector_boundary_distance_mm` is `null` where there are no radial wires (bulls, miss). When the scorer or the board geometry changes, the score is recomputed from `board_point`; it is never the primary result.
- `frames` lists the `sequence` numbers of the frames each camera contributed, so a result points back to exact frames.
- A rejected throw has `"accepted": false`, keeps its measurements and diagnostics, and may leave `board_point` and `score` as `null`.
- `processing_latency_ms` is measured live; a replay writes `null`, so its files stay byte-identical.
- Tip triangulation (#23, technical plan 5.3 B), in tracker replays: per camera, the visible end of the dart nearest to the entry point's image is its tip (`tip_candidates[0].pixel_xy`), that camera's ray met with the board plane is its own `board_point` (5.3 A, for the per-camera errors of #22), and `reprojection_error_px` is how far the triangulated tip lies from that pixel. `diagnostics.tip_triangulation` is the tip crossed in 3D from the cameras that agree on the entry point: `x_mm`, `y_mm`, `plane_distance_mm` (its distance from the playing surface; negative behind it) and `views`, or `null` with fewer than two tips.
- A replay's `diagnostics` hold `pipeline`, the throw's `event_ns`, `window_start_ns` and `window_end_ns`, `cameras_agreeing` and, if it abstained, `reason`; each camera measurement adds the camera's `state` (`seen`, `cut`, `not_seen`, `disagrees`, `not_calibrated`) and whether it was `used`.
- A run recorded live by `dartpilot serve --record` (`results/live/`) also holds the players' corrections, each as a line of its own after the throw: `{"throw_id": "…/17", "correction": {"action": "corrected", "board_point": {…}, "client": "app"}}`, with `rejected` (and `reason`) or `added` (a dart the engine missed, with `event_ns`) as other actions. `python -m dartpilot_tools.corrections <session>` turns them into the annotation set `corrections`: ground-truth candidates with about 3 mm uncertainty for the benchmark.

## Calibration checks

While replaying, every camera with a board refinement is checked against it (#49), at the start and then at a fixed interval of recorded time: ten frames are averaged, the board is detected and compared with where the refinement puts it, as on the setup GUI's calibration check page. `calibration_checks.jsonl` holds one line per check:

```json
{"camera": "usb-2.4.3.1.2", "exposure_ns": 182056465845123, "frames": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "board_found": true, "rms_mm": 0.4321, "rms_px": 0.5102, "worst_px": 1.2011, "shift_px": [0.0312, -0.1290], "edge_offset_mm": 0.52, "twenty_sector": 12}
```

- `exposure_ns` is the exposure time of the first frame of the check, `frames` the `sequence` numbers it averaged.
- `board_found` is `false` while darts or a hand cover the board; the measurements are then missing.
- `rms_mm` is the distance between the detected points and the refinement's points on the wire plane, `rms_px` and `worst_px` the same in the image, `shift_px` their mean displacement: a camera that moved shifts them all alike.
- `edge_offset_mm` is the light-dependent edge offset of the wire detection, measured again for this check; `twenty_sector` the image sector found to be the 20.

## Annotations

Ground truth lives in `annotations/<annotation set>.jsonl`, one line per throw, keyed by `throw_id`. It carries the board point (`x_mm`, `y_mm`, `covariance_mm2`, `source`, `frames`, see [board-coordinates.md](board-coordinates.md)) and **never a score**: benchmarks score the result and the ground truth with the same scorer and geometry.

How ground truth is made is decided in [ADR 0011](adr/0011-ground-truth.md). There is no separate annotation tool (#15): the sets come from what the reference run, play and the detection test already record.

| Set | Made by | Truth | Uncertainty |
| - | - | - | - |
| `reference_corners` | the guided reference run in the app (#167, #181), stored as a session without frames; while `serve --record` runs, also into the recording, each dart as a throw `<session>/ref<run>-<n>` in `results/live` and `throws.csv`, so a replay measures every camera against the targets (#22, #205) | darts pushed into known wire corners | 0.5 mm along the wire, 1.0 mm across it (1 σ) |
| `corrections` | `python -m dartpilot_tools.corrections <session>` from a run recorded with `serve --record` (#115) | the points players set when they corrected a dart or added a missed one; rejected darts with `"no_dart": true` | about 3 mm (a tap) |
| `confirmed` | the same command | darts the engine placed and the player left alone, at the engine's point, with `"field_only": true` | the field only |
| `ratings` | `python -m dartpilot_tools.detection_test <log>` from a detection test of the setup GUI (#197), stored as a session without frames with the run `detection-test` | darts rated right (`field_only`), moved to another field, given a point after an abstention, or added as missed; `"no_dart"` for false alarms | about 3 mm, or the field only |

A `field_only` truth counts for the field and the ring (segment and multiplier accuracy, abstention, false acceptance), never for millimetre errors. The benchmark takes several sets at once: `--annotations corrections,confirmed`.

Every entry carries `flags`, derived from the run that detected the throw and from the truth:

- `cut`: a camera saw the dart cut off by the image border;
- `occluded`: a camera did not see it, or its axis disagreed with the others (an earlier dart in the way);
- `near_wire`: the true point is within 2 mm of a ring or sector wire;
- `darts_in_board`: darts already in the board when it landed. From the takeouts a live run records (`{"takeout": {"event_ns", "darts_removed"}}` lines in its `throws.jsonl`), or from the dart's place in its round in the detection test; `null` for runs recorded before takeouts were logged.

A live run records the states of the cameras it did not use (`reason`); a used camera may have seen a cut dart without the run saying so, so `cut` is complete only for replays and detection tests. The benchmark reports its groups by these flags, including first, second and third dart.

## Replay and determinism

- A replay reads the frames of all cameras merged in the order of `exposure_ns`; frames with equal `exposure_ns` are ordered by camera id. It does not depend on the order in which frames arrived.
- The same session, configuration and software version give byte-identical `throws.jsonl` files, apart from `processing_latency_ms` (#9 checks this in CI).
- The replay uses only the times stored in the session; it never reads the wall clock.
- `dartpilot replay <session> [--pipeline tracker|baseline|none] [--run-id ID] [--extrinsics FILE] [--check-every SECONDS] [--no-checks] [--move-camera ID=DX,DY@SECONDS] [--turn-board DEG@SECONDS]` writes `results/<run id>/` (`replay` by default) and never overwrites an existing run. The board refinement is the one the manifest references, provided the file in the calibration directory still has the recorded SHA-256; `--extrinsics` names another one.
- Throw detection (#18) looks at the board at the still moments live detection waits for, found in the recorded times: every camera's latest frame is sampled every 100 ms, and once all cameras have been still for 1.5 s, ten frames per camera are averaged. The settings are part of `run.json`. Two pipelines compare these still images with the one before:
  - `tracker` (default) is the live detection (`fusion::DartTracker`): the dart's axis per camera, the cameras that agree, abstention otherwise. Without the stored empty-board images, which need not match an old recording, it checks the board for darts by its wires before it starts.
  - `baseline` is plain frame differencing, the method the others are measured against: the largest region that changed is the dart, its tip the point of that region furthest towards the board, projected onto the board per camera; the board points of all cameras that saw a change are averaged, and a dart seen by one camera only is an abstention. All darts are taken out when at most one camera still sees a change against the empty board.
- A detected throw takes the throw id of the session's throw (`throws.csv`) whose event window holds its event time, so live results, replays and annotations of one session refer to the same throws; a throw no recorded window holds gets `<session id>/unmatched-<n>`. A session without `throws.csv` gets one from its first replay that finds throws, with `source` `replay:<run id>`.

## Reading sessions

- C++: `session::openSession` and `session::FrameReader` (`engine/session`), `replay::replayOrder` (`engine/replay`).
- Python: `dartpilot_tools.session.load_session(directory)` gives the manifest, the frame index per camera (as pandas tables), `read_frame`, `capture.csv`, `throws.csv`, `replay_order()` and `annotations(name)`; `session.run(run_id)` reads `run.json`, `throws.jsonl` and `calibration_checks.jsonl` of a detection run.
- Both readers are tested on the same fixture session, `tests/fixtures/session-v1/`.

## Writing rules

- All files of a session are append-only while recording. A frame's JPEG is written to `frames.mjpg` before its line in `frames.csv`, so after a crash the last index line can be trusted and a truncated tail of `frames.mjpg` is ignored.
- `manifest.json` is written at the start and rewritten atomically (write to a temporary file, rename) when recording ends, with the final counters.
- Writing runs on its own thread and never blocks capture; when it falls behind, the capture ring buffer drops and counts frames (#6).

## Size

Measured with `dartpilot record` on the reference setup (#6, #7): a frame is about **35–66 KB** depending on the scene and light, so three cameras at 30 fps write about **3–6 MB/s, 200–360 MB per minute or 12–21 GB per hour**. The index and clock files add about 0.1 %. Check the free disk space before long recordings.

## Versioning

- `manifest.json` carries `format` and `version`. Readers refuse sessions with a higher major version than they know.
- Within a version, new optional fields and new CSV columns may be added at the end; readers ignore what they do not know.
- Renaming or removing a field, or changing its meaning, needs a new version and a note in this document.
