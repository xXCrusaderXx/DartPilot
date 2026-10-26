# Detection values

Every value that decides whether and where the engine finds a dart (#195). They are defined once, in `engine/fusion/src/detection_params.cpp` (`fusion::detectionParams()`), and this page is generated from there.

## Changing them

- **While the engine runs:** `get_detection_params` and `set_detection_params` (docs/engine-api.md, "detection_params"). A change applies from the next sample, is sent to every client, and is lost when the engine stops. `{"params": {"name": null}}` sets a value back to its default.
- **In the setup GUI:** the page "Detection test" of `dartpilot_setup` runs the same detection on the cameras (with `serve` stopped), with every value as a slider grouped by stage, reset, and named profiles in `calibration/detection-profiles/`. Each dart is rated there (right, wrong field, unsure, missed, no dart), counted per dart of the round, and logged with its revision in `detection-tests/<start>.jsonl`, next to the averaged images of every still moment.
- **Recorded:** `serve --record` writes `results/live/params.jsonl`: one line `{t_ns, revision, params}` at the start and after every change. Every throw names the `params_revision` it was made with (in the `throw` message and under `diagnostics` in `throws.jsonl`).
- **Replayed:** `dartpilot replay <session> --params <file> [--params-revision N] [--param NAME=VALUE]...`. The file can be a session's `params.jsonl` (the line of revision N, the last one without it), a `detection_params` message, or a plain JSON object of names and values. The run's `run.json` records every value it used under `config.params`.

A change to a default is a change to detection: report before/after benchmark values (CONTRIBUTING.md).

Not listed here: the calibration (board detection, refinement, intrinsics), which is measured once in the setup GUI, and the frame-differencing baseline of the replay, which stays fixed as the reference the detection is measured against.

## Values

Regenerate the table with `dartpilot detection-params`; `DetectionParams.DocumentedAsInTheRegistry` fails while it differs.

<!-- detection-params:begin -->
| Name | Stage | Default | Range | Unit | Meaning |
| - | - | - | - | - | - |
| `sample_ms` | event_detection | 33.3333 | 10–200 | ms | How often every camera's latest frame is looked at; 33 ms is every frame at 30 fps. |
| `motion_span_ms` | event_detection | 100 | 0–500 | ms | Each sample is also compared with the one this long before, so that a slowly moving hand still counts as motion. |
| `still_motion` | event_detection | 2.5 | 0.5–10 | grey | Mean brightness change of the whole image (at a quarter of its size) above which a camera moves; image noise gives about 1. |
| `local_change` | event_detection | 25 | 5–100 | grey | A pixel (at a quarter of the size) changed by more than this counts towards local_change_px. |
| `local_change_px` | event_detection | 30 | 1–500 | px | A camera also moves when this many pixels changed by more than local_change: a dart landing changes 100 to 700, noise at most 2. |
| `settle_samples` | event_detection | 6 | 1–60 |  | Samples in which every camera must be still before the board is measured: the flight must stop swinging. |
| `average_frames` | event_detection | 4 | 1–20 |  | Frames averaged per camera for one measurement of the board; more frames, less noise, more delay. |
| `retry_ms` | event_detection | 3000 | 500–10000 | ms | While the engine waits for an empty board, a still board is measured again this often. |
| `min_strong_pixels` | tip_candidates | 150 | 10–2000 | px | An object needs this many clearly changed pixels; a dart at the far side of the board still has several hundred. |
| `strong_sigmas` | tip_candidates | 8 | 2–20 | σ | A pixel is clearly changed above this many robust standard deviations of the difference image. |
| `weak_sigmas` | tip_candidates | 4 | 1–10 | σ | A weakly changed pixel connected to a clearly changed one belongs to the object above this many standard deviations. |
| `min_strong` | tip_candidates | 12 | 1–60 | grey | Floor of the clear-change threshold for very clean images. |
| `min_weak` | tip_candidates | 6 | 1–40 | grey | Floor of the weak-change threshold for very clean images. |
| `merge_distance_px` | tip_candidates | 20 | 0–80 | px | Parts of one dart this far apart are joined, e.g. across a shaft of the board's colour. |
| `min_merged_strong_pixels` | tip_candidates | 15 | 1–500 | px | A part is joined only with this many clearly changed pixels. |
| `merge_passes` | tip_candidates | 3 | 0–10 |  | How often parts are joined in turn. |
| `close_px` | tip_candidates | 9 | 1–31 | px | Closing bridges gaps up to about this size inside the object, such as between the edges of a plain barrel. |
| `bin_px` | tip_candidates | 2 | 0.5–8 | px | Width of the cross-sections along the object whose middles make up its axis. |
| `axis_tolerance_px` | tip_candidates | 1.5 | 0.5–5 | px | Middles within this distance of a line are on the axis. |
| `min_axis_span_px` | tip_candidates | 30 | 5–200 | px | The axis spans at least this length. |
| `min_axis_points` | tip_candidates | 8 | 2–50 |  | The axis needs at least this many middles. |
| `min_whole_dart_px` | tip_candidates | 100 | 20–400 | px | An object not cut off by the image border must be this long to be a dart (whole darts 146 px or more, board changes 90 px or less). |
| `band_px` | tip_candidates | 2 | 0.5–6 | px | Half width of the band in which an end of the dart is followed beyond its axis. |
| `max_reach_px` | tip_candidates | 120 | 10–300 | px | How far beyond the last axis point an end is followed: the thin point may be too faint for the object's outline. |
| `border_px` | tip_candidates | 5 | 0–50 | px | An end this close to the image border is not taken: the dart may go on beyond it. |
| `max_drift_px` | tip_candidates | 5 | 0–20 | px | The largest shift between image and board that is taken for a drifting camera and compensated. |
| `tiles_x` | tip_candidates | 8 | 2–16 |  | Tiles across in which a slight zoom or rotation of a drifting camera is measured. |
| `tiles_y` | tip_candidates | 5 | 2–16 |  | Tiles down for the same. |
| `min_tiles` | tip_candidates | 12 | 3–100 |  | With fewer measured tiles only the shift of the whole image is compensated. |
| `min_tile_response` | tip_candidates | 0.1 | 0–1 |  | A tile's correlation must reach this to be measured. |
| `min_tile_contrast` | tip_candidates | 5 | 0–40 | grey | Tiles plainer than this (standard deviation) are not measured. |
| `tile_outlier_px` | tip_candidates | 0.4 | 0.05–3 | px | A tile further than this off the fitted zoom and rotation (a dart in it) is dropped. |
| `max_linear` | tip_candidates | 0.01 | 0–0.1 |  | A larger zoom or rotation is not a drift; only the shift is compensated. |
| `min_linear_px` | tip_candidates | 0.3 | 0–3 | px | A zoom or rotation that moves no image corner by more than this only fits noise and is ignored. |
| `min_tone_pixels` | tip_candidates | 50 | 1–1000 | px | A grey level counts for the tone curve onto the board with this many pixels. |
| `min_tone_range` | tip_candidates | 60 | 10–200 | grey | The middle 96 % of the pixels must span this many levels for a tone curve, so a small dart cannot bend it. |
| `tone_outlier` | tip_candidates | 12 | 1–60 | grey | Levels further than this from the tone curve are dropped. |
| `view_cells` | tip_candidates | 8 | 2–32 |  | The image is split into cells × cells to tell a knocked camera, which changes everywhere, from a dart. |
| `view_changed_level` | tip_candidates | 25 | 5–100 | grey | A pixel changed by more than this counts for a changed cell. |
| `view_changed_cell_share` | tip_candidates | 0.002 | 0.0001–0.05 |  | A cell is changed with this share of changed pixels. |
| `view_max_cells_for_a_dart` | tip_candidates | 16 | 1–200 |  | More changed cells than this are a moved camera (a dart changed at most 10 of 64, a knocked camera 23 to 59). |
| `view_moved_camera_px` | tip_candidates | 3 | 0.5–20 | px | A shift of the whole image beyond this that explains the change is a moved camera. |
| `view_ignore_inside_mm` | tip_candidates | 230 | 0–400 | mm | Only the image outside this radius on the board tells a moved camera; a dart moving the board or its number ring does not. 0 compares the whole image. |
| `view_min_cell_region_share` | tip_candidates | 0.2 | 0–1 |  | Cells with less of the compared image than this share are left out. |
| `view_explained_share` | tip_candidates | 0.5 | 0.05–1 |  | The shift explains the change when at most this share of it is left after the shift. |
| `min_cut_axis_px` | geometry | 120 | 20–400 | px | A dart cut off by the image border must show this much axis to fix its direction. |
| `max_plane_distance_mm` | geometry | 1.5 | 0.2–10 | mm | The axis planes of agreeing cameras pass within this distance of their common point on the board. |
| `min_crossing_deg` | geometry | 15 | 1–60 | ° | Two cameras alone must see the dart at least at this angle to each other on the board. |
| `max_end_distance_px` | geometry | 12 | 1–60 | px | The point's image lies at most this far from a visible end of the dart. |
| `plane_sigma_mm` | geometry | 0.5 | 0.05–5 | mm | Uncertainty of one camera's axis plane on the board, for the covariance of the point. |
| `hidden_board_mm` | geometry | 2.5 | 0.5–10 | mm | Without a stored empty board: wires further than this from the calibration mean the board is partly hidden. |
| `edge_tolerance_px` | geometry | 2 | 0–10 | px | An object against the empty board must stand out even when every pixel may match within this distance. |
| `confirm_level` | geometry | 30 | 5–100 | grey | A pixel stands out from the empty board by more than this in some colour channel. |
| `board_check_radius_mm` | geometry | 175 | 0–300 | mm | Only pixels on the board within this radius make it occupied, not the number ring, the surround or a hand at the edge. 0 counts the whole image. |
| `min_confirmed_px` | geometry | 150 | 10–2000 | px | An object on the board needs this many pixels that stand out. |
| `takeout_max_cameras` | fusion | 1 | 0–3 |  | All darts are pulled when at most this many cameras still see something against the empty board. |
| `max_changes` | fusion | 3 | 1–6 |  | Changes looked at in one still moment: a dart pulled and another put in, and one more. |
| `pulled_reach_px` | fusion | 45 | 5–200 | px | How far around a pulled dart's axis the board is taken as it is now, to cover its flight. |
| `patch_px` | fusion | 2 | 0–10 | px | Half size of the patches along a change in which it is compared with the empty board. |
| `confidence_two_cameras` | fusion | 0.8 | 0–1 |  | Confidence of a dart located by two cameras. |
| `confidence_three_cameras` | fusion | 0.95 | 0–1 |  | Confidence of a dart located by three or more cameras. |
| `confidence_abstained` | fusion | 0.3 | 0–1 |  | Confidence sent with an abstention. |
| `uncertain_field_probability` | fusion | 0 | 0–1 |  | A located dart whose most likely field has less probability than this, from its covariance, is sent as uncertain with the fields it may be in, for the player to pick. 0 sends every located dart as accepted. |
<!-- detection-params:end -->
