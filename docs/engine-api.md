# Engine API

- **Protocol version:** `dartpilot/1.0`
- **Status:** proposed ([ADR 0007](adr/0007-engine-api.md), issue #37)

The engine reports darts, takeouts and its state to clients over a WebSocket; clients can correct darts and watch the cameras. The engine knows no games: turns, game scores and statistics belong to the client.

## Connection

- `ws://<host>:8484/` by default. `dartpilot serve` listens on localhost; `--listen 0.0.0.0` makes it reachable from other devices in the network, `--port` changes the port.
- Text messages are UTF-8 JSON objects with a `type` field. Binary messages are camera previews (see [Previews](#previews)).
- Any number of clients may connect. Every event goes to every client; corrections made by one client are announced to all.
- Times (`*_ns`) are on the engine's `CLOCK_MONOTONIC`, the time base of the recorded sessions. Clients use them for ordering and differences, not as wall-clock time.
- Fields follow [board-coordinates.md](board-coordinates.md) and [replay-format.md](replay-format.md): a **board point** is `{ "x_mm", "y_mm", "covariance_mm2": { "xx", "xy", "yy" } }`, a **score** has the fields of the deterministic scorer (#12).

## Versioning

The engine's first message is `hello` with `"protocol": "dartpilot/1.0"`. Within major version 1, minor versions only add message types and fields; clients ignore unknown types and fields. A client that does not support the major version closes the connection.

## Engine → client

### hello

Sent once after the connection opens.

```json
{
  "type": "hello",
  "protocol": "dartpilot/1.0",
  "engine": { "version": "0.4.0", "commit": "0b299b1" },
  "mode": "live",
  "session_id": "20261024T190000Z-7c1e",
  "board_geometry": {
    "bull_radius_mm": 6.35, "outer_bull_radius_mm": 15.4,
    "triple_inner_radius_mm": 98.0, "triple_outer_radius_mm": 106.0,
    "double_inner_radius_mm": 162.0, "double_outer_radius_mm": 170.0,
    "wire_rotation_deg": 0.4,
    "source": "measured"
  },
  "cameras": [ { "id": "usb-2.4.3.1.2", "name": "USB Camera: USB Camera", "state": "ok" } ],
  "detection": "running",
  "board_state": { "state": "empty", "cameras": [ { "camera": "usb-2.4.3.1.2", "state": "empty", "image_point_px": null, "image_size_px": [ 1280, 720 ], "reason": "" } ], "reference": "stored" }
}
```

- `mode`: `live` (cameras), `replay` (a recorded session) or `simulate` (no cameras, generated darts).
- `session_id`: the session being recorded or replayed, if any, so client and recording can be matched.
- `board_geometry`: the boundaries the engine's scorer uses. `source` is `nominal` (tournament dimensions) or `measured` (derived from the calibration's board model, #13/#47). A client that scores or draws the board uses these values, so it agrees with the engine.
- `detection`: `running`, `paused` or `unavailable`; see `engine_status`. With `unavailable`, `detection_reason` says why: `not_calibrated` (no refinement of the cameras: the app sends the user to the calibration) or `no_empty_reference` (live detection waits for a still, empty board to compare darts with; it starts by itself once it sees one). `null` otherwise.
- `board_state`: whether the board is empty; see `board_state`.

### throw

A dart has landed and the engine has a result.

```json
{
  "type": "throw",
  "throw_id": "20261024T190000Z-7c1e/17",
  "event_ns": 1890125000000,
  "accepted": true,
  "board_point": { "x_mm": 12.4, "y_mm": 98.1, "covariance_mm2": { "xx": 0.6, "xy": 0.1, "yy": 0.9 } },
  "score": {
    "ring": "triple", "sector": 20, "multiplier": 3, "points": 60, "label": "T20",
    "boundary_distance_mm": 1.3, "ring_boundary_distance_mm": 1.3, "sector_boundary_distance_mm": 4.8
  },
  "confidence": 0.93,
  "cameras": [
    { "camera": "usb-2.4.3.1.2", "used": true, "frames": [1241, 1242] },
    { "camera": "usb-2.4.3.1.3", "used": false, "reason": "tip occluded" }
  ],
  "processing_latency_ms": 41.7
}
```

- `throw_id` is the throw ID of the recorded session (`<session id>/<n>`); without a recording the engine still numbers throws the same way.
- `accepted: false` means the engine **abstains**: it detected a dart but is not sure enough of its position. It then sends its best `board_point` and `score` if it has one (or `null`), and a `reason`. The client decides: ask the player, or offer the uncertain result for confirmation. It never treats an abstention as a miss.
- `score` is derived from `board_point` with `board_geometry`; a client can recompute it and must get the same result.
- A dart that bounced out or landed off the board is a `throw` with `board_point: null`, `score` of ring `miss` and a `reason`.

### throw_corrected

A client corrected, rejected or added a throw (see below). Sent to every client, including the one that made the change.

```json
{
  "type": "throw_corrected",
  "throw_id": "20261024T190000Z-7c1e/17",
  "action": "corrected",
  "board_point": { "x_mm": 15.0, "y_mm": 97.0, "covariance_mm2": null },
  "score": { "ring": "triple", "sector": 20, "multiplier": 3, "points": 60, "label": "T20", "boundary_distance_mm": 2.0, "ring_boundary_distance_mm": 2.0, "sector_boundary_distance_mm": 6.1 },
  "client": "player-app-tablet"
}
```

`action` is `corrected` (new board point), `rejected` (the throw did not happen, e.g. a false detection) or `added` (a dart the engine missed; `throw_id` is new).

### takeout

The darts were pulled out of the board. Clients use it to close the visit.

```json
{ "type": "takeout", "event_ns": 1897000000000, "darts_removed": 3 }
```

### camera_status

Sent when a camera's state changes and once per second while a client watches status (`subscribe_status`).

```json
{
  "type": "camera_status",
  "camera": "usb-2.4.3.1.2",
  "state": "ok",
  "effective_fps": 30.0,
  "lost_frames": 0,
  "overflow_drops": 0,
  "brightness": 112.5,
  "latency_ms": 31.3
}
```

`brightness` (mean image brightness 0–255) and `latency_ms` (arrival minus exposure of the latest frame) are `null` when unknown. `state` is `ok`, `degraded` (frames lost or the calibration check found a moved camera) or `lost` (no frames).

### board_state

Sent to every client when the board state changes (#121). The engine compares each camera's image of the still board with the stored image of the empty board. An object is reported once it has stayed for 4 s, so that a knocked, swaying camera does not raise the warning; an empty board is reported at once. It first aligns the stored image with the current one, including the slight zoom of a camera that warmed up since, and counts an object only if it still stands out when every pixel may be off by 2 px, so that the traces a warmer, softer image leaves along the wires do not count.

```json
{
  "type": "board_state",
  "state": "occupied",
  "cameras": [
    { "camera": "usb-2.4.3.1.2", "state": "occupied", "image_point_px": [ 702.5, 311.0 ], "image_size_px": [ 1280, 720 ], "reason": "object on the board" },
    { "camera": "usb-2.4.3.1.3", "state": "unknown", "image_point_px": null, "image_size_px": [ 1280, 720 ], "reason": "board is moving" }
  ],
  "reference": "stored"
}
```

- `state` per camera: `empty`, `occupied` or `unknown` (no reference, no calibration, or the image is not still). The overall `state` is `occupied` if any camera sees an object, `empty` if all cameras see an empty board, and `unknown` otherwise.
- `image_point_px`: where the object is in the camera's image of size `image_size_px` (e.g. 1280×720); a client scales it to mark the object in a preview. `null` when there is none.
- `reference`: `stored` or `missing`, whether the engine has an image of the empty board.

A client warns the player to pull out the darts when the board is occupied before a game starts, not during a visit, where darts in the board are normal.

### diagnosis

The state of the live setup diagnosis (#137), sent to every client after `start_diagnosis`, whenever the step or state changes or a still moment was measured, and once more after `stop_diagnosis`. A client that connects later gets the latest one after `hello`. The app shows it as a tool next to the calibration tools: the user follows `step`, and the findings tell what to fix.

```json
{
  "type": "diagnosis", "running": true, "step": "insert_dart", "state": "measured", "elapsed_s": 74.2,
  "cameras": [ "usb-2.4.3.1.2", "usb-2.4.3.1.3", "usb-2.4.3.1.4" ],
  "findings": [
    { "severity": "warning", "check": "drift", "camera": "usb-2.4.3.1.3", "code": "drift", "values": { "px": 0.62, "minutes": 1.6 },
      "message": "The image moved by 0.62 px within 1.6 min.", "hint": "Let the cameras run for about 10 minutes ..." }
  ],
  "periods": [ { "start_s": 41.3, "end_s": 42.4, "empty": true, "cameras": [ { "brightness": 112.4, "calibration_mm": 0.48, "shift_px": [ 0.02, -0.11 ] } ] } ]
}
```

- `step`, what the user should do next: `empty_board` (leave the board empty, hand out of view), `remove_darts` (the board was not empty at the start), `insert_dart` (put one dart in and take the hand away), `remove_dart` (pull it).
- `state`: `moving` (a camera's image moves), `settling` (still, waiting 1.5 s), `measuring` (averaging about a second), `measured` (done until something moves; a board that stays still is measured again every 20 s, so drift and light show over time, and a moment of the hand pulling a dart is followed by one of the board), `stopped`.
- `findings`: most severe first, as in [setup-diagnosis.md](setup-diagnosis.md). `code` and `values` name the finding and its numbers, so a client can word it in its own language; `message` and `hint` are the English text. Codes: `lost_frames`, `few_still_moments`, `not_empty_at_start`, `no_refinement`, `board_not_found`, `calibration_off`, `drift`, `exposure_settling`, `light_changed`, `board_changed`, `no_darts`, `darts_located`, `darts_cut_lost`, `darts_cut`, `darts_not_seen`, `camera_disagrees`, `planes_agree`.
- `periods`: the measured still moments (successive moments with an object, such as the dart and then the hand pulling it, count as one dart), per camera in the order of `cameras`; a dart period has `dart` (`none`, `cut`, `seen`) per camera and, if located, `board_mm`, `agreeing_cameras` and `worst_plane_mm`.

### Calibration

The calibration wizard of the app runs on the engine's cameras (`serve --cameras`); `serve --simulate` alone answers with fixed examples in the geometry of its simulated previews, so a client can be built without cameras. Cameras are named by their `id` from `hello` (`usb-<port>`); points are in pixels of the camera's full image, with `image_size_px` beside them. Results come as `code` plus numbers, so a client words them in its own language.

`calibration_status` is part of `hello` (`null` without cameras) and sent to every client when it changes:

```json
{ "type": "calibration_status", "refinement_stale": false, "extrinsics_created": "2026-10-24T17:41:00Z",
  "cameras": [ { "camera": "usb-2.4.3.1.2", "intrinsics": "valid", "board_plane_mm": 0.41, "refined": true, "white_balance_kelvin": 3000 } ] }
```

- `intrinsics`: `valid` (a lens calibration in the reference mode), `invalid` (one of another capture mode, `intrinsics_reason`: `other_capture_mode`) or `none`.
- `check`: the latest calibration check of the camera, `{state, mm, checked_at}` or `null` before the first one (see "Calibration check" below); a home screen warns from it when a camera moved.
- `board_plane_mm`: error of the measured board plane, `null` before the board was measured. `refined`: the camera is part of the stored refinement. `refinement_stale`: a board was measured or a lens calibrated after the refinement, so it should run again.

The steps, in the order of the wizard:

1. **White balance** (`tune_white_balance`). Board detection only works within a few hundred kelvin of the light's colour, so the engine fixes each camera's white balance (ADR 0002) and this step finds it for the user's light. It needs the empty, lit board; it waits until the cameras' exposure has settled (25 s after they started), then tries 2800 to 6400 K in steps of 200 K on all cameras, about 50 s, and stores the middle of the range in which the board was found. Events while it runs and at the end:

   ```json
   { "type": "white_balance", "state": "sweeping", "kelvin_now": 3400,
     "cameras": [ { "camera": "usb-2.4.3.1.2", "found_at": [ { "kelvin": 2800, "found": true } ], "chosen_kelvin": null } ] }
   ```

   `state`: `settling` (with `settle_s`), `sweeping`, `done`, `failed`. At the end each camera has `chosen_kelvin`, or `code`: `board_not_found_at_any`, in which case it keeps its previous value.
2. **Board measurement** (`detect_board` with `camera`). Averages ten frames and looks for the board; the event shows what was found, so the user can check it:

   ```json
   { "type": "board_detection", "camera": "usb-2.4.3.1.2", "ok": true, "code": "found", "image_size_px": [ 1280, 720 ],
     "ellipses": [ { "center_px": [ 652.1, 254.3 ], "axes_px": [ 31.2, 17.0 ], "angle_deg": 1.5 } ],
     "wires_px": [ [ 655.0, 238.1, 700.4, 12.9 ] ], "points_px": [ [ 660.2, 222.4 ] ] }
   ```

   `ellipses`: outer bull, centre of the treble, centre of the double ring; `axes_px` are the half axes. `wires_px`: the 20 radial wires from the bull outwards. `code`: `found` or `not_found` (darts in the board, poor light, or the white balance).
3. **Sector 20** (`set_sector_20` with `camera` and `point_px`, a point the user tapped in the sector 20). The colour pattern repeats every second sector, so the orientation has to come from the user. The engine fits and stores the board plane and answers with the numbers where it now sees them, so the user can check them:

   ```json
   { "type": "board_plane", "camera": "usb-2.4.3.1.2", "fit_mm": 0.41, "worst_mm": 0.93, "rms_px": 0.38, "lens_corrected": true,
     "sectors": [ { "sector": 20, "label_px": [ 640.0, 120.5 ] } ] }
   ```

   Errors: `no_detection` (detect the board first), `outside_board` (the point is not in a sector), `fit_failed`, `save_failed`.
4. **Refinement** (`refine_cameras`). Refines all cameras with a measured board together (#13) and stores the result:

   ```json
   { "type": "refinement", "state": "done", "board": { "outer_bull_mm": 15.9, "treble_centre_mm": 103.0 },
     "cameras": [ { "camera": "usb-2.4.3.1.2", "held_out_mm": 0.42, "quality": "good", "uncertainty_mm": 0.3, "focal_px": 1012.0,
                    "lens_from": "own", "advice": null } ] }
   ```

   `state`: `running`, `done`, `failed` (`code`: `no_board_planes`, `pose_failed`, `save_failed`). `quality` from the error on held-out wires: `good` up to 0.5 mm, `fair` up to 1 mm, else `poor`; `advice` then says what helps: `detect_again` (measure the board again in even light) or `lens_calibration` (the camera has no lens calibration of its own). `lens_from`: `own`, `model` (borrowed from a camera of the same model) or `board`.

**Calibration check** (`subscribe_calibration_check` / `unsubscribe_calibration_check`). Each camera's board is compared with its calibration, as the calibration check of the setup GUI (#92) does: the detected wire points against where the calibration puts them. In the background the engine does this every minute and puts the verdict into `calibration_status` (`cameras[].check`); while darts hide the board, the previous verdict stays. While a client is subscribed it checks every 2 s and sends the details per camera:

```json
{ "type": "calibration_check", "camera": "usb-2.4.3.1.3", "state": "moved", "mm": 4.2, "shift_px": [ 6.0, -3.0 ], "count": 60,
  "expected_px": [ [ 652.1, 254.3 ] ], "found_px": [ [ 658.0, 251.2 ] ], "image_size_px": [ 1280, 720 ] }
```

- `state`: `ok` (up to 1 mm), `off` (up to 2.5 mm: other light, or the camera moved a little), `moved` (more: calibrate the camera again and refine), `wrong_port` (another camera's calibration fits at least three times better and within 2.5 mm, named in `fits_camera`: the cameras were plugged into other ports), `no_board` (darts in the board, a hand, or no light), `not_calibrated`.
- `mm`: how far the wire points lie from the calibration on the board; `shift_px`: their mean displacement in the image, the same for all points when the camera moved. `expected_px` and `found_px` pair up for drawing.
- `--simulate` answers with one camera `moved`.

**Board image** (`get_board_image`, optional `size_px`, default 600, and `radius_mm`, default 250). The real board seen from the front, put together from the refined cameras: each pixel comes mostly from the camera that sees that part with the most pixels per millimetre, with soft transitions between cameras of matched brightness. Outside the number ring (222 mm) the surround is blurred and darkened. A client shows it instead of a drawn board and places hits by their board point: board point (x, y) mm lies at column `(x + radius_mm) / mm_per_px` and row `(radius_mm - y) / mm_per_px`. Taken from the current frames, so ask for it with the board empty, e.g. after a takeout.

```json
{ "type": "board_image", "image_size_px": [ 600, 600 ], "mm_per_px": 0.8333, "radius_mm": 250.0, "jpeg_base64": "/9j/4AAQ..." }
```

Fails with `not_calibrated` before the refinement; `not_available` with `--simulate` alone, where a client draws its board.

Long steps run one at a time; a request while one runs fails with `busy`. Events may arrive before the request's `result`.

### reference_run

The guided reference measurement (#14), started with `start_reference_run` and stopped with `stop_reference_run`, with `serve --cameras` (`--simulate` alone plays a fixed example run). The user pushes one dart by hand into one known position after the other: the centre of the bull, then corners where a radial wire meets a ring wire, with the point against both wires, so its centre lies 1.8 mm from each wire (about ±0.5 mm). The live detection locates it, and the distance from the target is the error of the whole chain from calibration to tip. While a run is active its darts are not sent as `throw`. Sent on every change, and the latest one after `hello`:

```json
{ "type": "reference_run", "running": true, "step": "insert_dart",
  "target": { "index": 1, "total": 10, "board_mm": [ 24.55, 166.40 ], "field": "D20", "wires": [ 20, 1 ], "hint_code": "corner",
              "label": "D20, corner of the 20/1 wire and the outer double wire" },
  "results": [ { "index": 0, "board_mm": [ 0.0, 0.0 ], "located_mm": [ 0.31, -0.22 ], "error_mm": 0.38, "cameras_used": 3 } ],
  "summary": { "located": 1, "abstained": 0, "median_error_mm": 0.38, "p90_error_mm": 0.38, "max_error_mm": 0.38 } }
```

- `step`: `empty_board` (waiting for a still empty board), `insert_dart`, `remove_dart`, and `done` once the last dart is pulled.
- `target`: the next position; `wires` are the sector numbers on either side of the corner's radial wire (empty for the bull centre), `field` the field the point sits in. `null` when done.
- `results`: per placed dart, `located_mm` and `error_mm`, or `null` with `reason` when the engine abstained.
- Errors of `start_reference_run`: `not_calibrated`.

### engine_status

```json
{ "type": "engine_status", "detection": "paused", "message": "Calibration in progress" }
```

### result

The answer to every client request that has a `request_id`.

```json
{ "type": "result", "request_id": "7", "ok": false, "error": { "code": "unknown_throw", "message": "No throw 20261024T190000Z-7c1e/99" } }
```

Error codes: `bad_request`, `unknown_type`, `unknown_throw`, `unknown_camera`, `not_available`, `board_not_empty`, `not_still` (the image has not been still long enough to store the empty board), `save_failed`, and those of the calibration steps (`busy`, `no_detection`, `outside_board`, `fit_failed`, `no_board_planes`).

## Client → engine

Every request carries a `request_id` chosen by the client and is answered with `result`.

| `type` | Fields | Effect |
| ------ | ------ | ------ |
| `hello` | `client`, `protocol` | Names the client for logs and corrections; optional |
| `correct_throw` | `throw_id`, `board_point` | Replaces the board point of a throw; broadcast as `throw_corrected` |
| `reject_throw` | `throw_id`, `reason` | Marks a throw as not having happened |
| `add_throw` | `board_point` | Adds a dart the engine missed |
| `pause_detection` / `resume_detection` | – | E.g. while the user calibrates or retrieves a dart that fell out |
| `subscribe_status` / `unsubscribe_status` | – | Periodic `camera_status` |
| `check_board` | – | Checks the board now; the answer comes as `board_state` |
| `store_empty_reference` | `force` (optional) | Stores the current images as the empty board; fails with `board_not_empty` while a camera sees an object, unless `force` is `true` (the user confirmed that the board is empty, e.g. when an outdated reference makes the check see an object) |
| `start_diagnosis` / `stop_diagnosis` | – | Starts the live setup diagnosis afresh, or stops it; its state comes as `diagnosis` |
| `tune_white_balance` | – | Finds each camera's white balance for the user's light; see "Calibration" |
| `detect_board` | `camera` | Measures the board of a camera; answered with `board_detection` |
| `set_sector_20` | `camera`, `point_px` | Orients and stores the board plane; answered with `board_plane` |
| `refine_cameras` | – | Refines all cameras together; answered with `refinement` |
| `start_reference_run` / `stop_reference_run` | – | The guided reference measurement; its state comes as `reference_run` |
| `subscribe_calibration_check` / `unsubscribe_calibration_check` | – | Detailed calibration checks every 2 s as `calibration_check` |
| `get_board_image` | `size_px`, `radius_mm` (optional) | The real board from the front; answered with `board_image` |
| `subscribe_preview` | `camera`, `max_fps`, `max_width` | Starts preview frames of a camera |
| `unsubscribe_preview` | `camera` | Stops them |

Corrections and additions are written into the recorded session (`results/<live run>/throws.jsonl`, with `"correction"` and the client name). They are labelled examples of hard cases for the benchmark (#29, #34).

```json
{ "type": "correct_throw", "request_id": "7", "throw_id": "20261024T190000Z-7c1e/17",
  "board_point": { "x_mm": 15.0, "y_mm": 97.0 } }
```

## Previews

Preview frames are binary messages:

| Bytes | Content |
| ----- | ------- |
| 0–3 | Length `n` of the header, unsigned 32-bit little-endian |
| 4 … 4+n−1 | Header, UTF-8 JSON: `{ "camera", "sequence", "exposure_ns", "width", "height" }` |
| 4+n … end | The JPEG |

The engine sends the camera's own JPEG when it fits `max_width`, otherwise a scaled copy, and drops frames rather than queueing them when a client is slow.

## Typical flow

1. The client connects and receives `hello`; it sets up its scorer and board drawing from `board_geometry`.
2. During a visit it receives `throw` for each dart and shows it at once; uncertain darts (`accepted: false`) are offered for confirmation or correction.
3. `takeout` ends the visit. If the client expected three darts and received fewer, it asks the player for the missing ones and sends them with `add_throw`.
4. The player corrects a wrong dart on the board; the client sends `correct_throw`, and every client updates on `throw_corrected`.

## Implementation status

`dartpilot serve --cameras` detects live darts (#121, #128, `fusion::DartTracker`). Whenever all cameras have been still for 1.5 s, it averages a second of frames and compares the board with its last still state:

- A new dart is located from the cameras whose axis planes meet (`locateDart`) and sent as `throw`. If the cameras do not agree it abstains: `accepted: false`, no `board_point`, and `reason` `cameras_disagree` or `seen_by_one_camera`, so the player confirms or corrects it. `cameras[].reason` gives each camera's part: `not_seen`, `cut` (by the image border), `disagrees`.
- When the board matches the empty board again after darts, it sends `takeout` with the number of darts that were in it, and the empty board, as it is now, becomes the reference for the next visit. A dart pulled and the next one put in without a still board in between are told apart by where the image is the empty board again.
- A camera whose whole image shifted since the last still moment was knocked or has loosened: its change is no dart. The engine sends `{ "type": "camera_moved", "camera": "usb-2.4.3.1.3", "shift_px": [ 12.0, -7.1 ] }`, takes the view as the new still state, and the next calibration check (within a minute, or at once on the subscribed page) tells whether the camera must be calibrated again.
- Detection waits for a still, empty board at the start (`detection: unavailable`, `no_empty_reference`), and is unavailable without a refinement (`not_calibrated`).

On the reference recordings, replayed through the tracker, all located darts were right: 9 of 10 type-1 darts located and 1 missed; 6 of 9 type-2 darts located and the others abstained, some of them twice when the hand was still in view. The engine sets no visit logic: the app decides how many darts a turn has.

`dartpilot serve --simulate` implements the protocol with simulated darts, takeouts and camera states (`engine/api`), and the player app connects to it (`ui/lib/src/engine/`). Previews work for simulated cameras (drawn board with the darts of the visit) and, with `--simulate --cameras`, for the real cameras, which then also report their status. The simulator reports an empty board, occupied while darts are in it (`--occupied`: darts in the board at start, pulled out after the takeout delay); with `--cameras` the real cameras check the board: each camera's frames are averaged once its image has been still for a second and compared with its empty-board reference (`empty-usb-<port>.png` in the calibration directory). `start_diagnosis` runs the setup diagnosis on the real cameras with `--cameras`; without, the simulator answers with a fixed example. Not implemented yet: `--replay`, and recording a live session with its corrections.

## Not in version 1

Authentication and encryption (use it in a trusted network only), discovery of engines in the network, several boards per engine, and engine-side game logic.
