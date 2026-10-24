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
- `detection`: `running`, `paused` or `unavailable` (e.g. not calibrated); see `engine_status`.
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

Sent to every client when the board state changes (#121). The engine compares each camera's image of the still board with the stored image of the empty board. It first aligns the stored image with the current one, including the slight zoom of a camera that warmed up since, and counts an object only if it still stands out when every pixel may be off by 2 px, so that the traces a warmer, softer image leaves along the wires do not count.

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
- `state`: `moving` (a camera's image moves), `settling` (still, waiting 1.5 s), `measuring` (averaging about a second), `measured` (done until something moves; an empty board that stays still is measured again every 20 s, so drift and light show over time), `stopped`.
- `findings`: most severe first, as in [setup-diagnosis.md](setup-diagnosis.md). `code` and `values` name the finding and its numbers, so a client can word it in its own language; `message` and `hint` are the English text. Codes: `lost_frames`, `few_still_moments`, `not_empty_at_start`, `no_refinement`, `board_not_found`, `calibration_off`, `drift`, `exposure_settling`, `light_changed`, `board_changed`, `no_darts`, `darts_located`, `darts_cut_lost`, `darts_cut`, `darts_not_seen`, `camera_disagrees`, `planes_agree`.
- `periods`: the measured still moments, per camera in the order of `cameras`; a dart period has `dart` (`none`, `cut`, `seen`) per camera and, if located, `board_mm`, `agreeing_cameras` and `worst_plane_mm`.

### engine_status

```json
{ "type": "engine_status", "detection": "paused", "message": "Calibration in progress" }
```

### result

The answer to every client request that has a `request_id`.

```json
{ "type": "result", "request_id": "7", "ok": false, "error": { "code": "unknown_throw", "message": "No throw 20261024T190000Z-7c1e/99" } }
```

Error codes: `bad_request`, `unknown_type`, `unknown_throw`, `unknown_camera`, `not_available`, `board_not_empty`, `not_still` (the image has not been still long enough to store the empty board), `save_failed`.

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

`dartpilot serve --simulate` implements the protocol with simulated darts, takeouts and camera states (`engine/api`), and the player app connects to it (`ui/lib/src/engine/`). Previews work for simulated cameras (drawn board with the darts of the visit) and, with `--simulate --cameras`, for the real cameras, which then also report their status. The simulator reports an empty board, occupied while darts are in it (`--occupied`: darts in the board at start, pulled out after the takeout delay); with `--cameras` the real cameras check the board: each camera's frames are averaged once its image has been still for a second and compared with its empty-board reference (`empty-usb-<port>.png` in the calibration directory). `start_diagnosis` runs the setup diagnosis on the real cameras with `--cameras`; without, the simulator answers with a fixed example. Not implemented yet: live detection (needs the detection pipeline), `--replay`, and storing corrections in a recorded session.

## Not in version 1

Authentication and encryption (use it in a trusted network only), discovery of engines in the network, several boards per engine, and engine-side game logic.
