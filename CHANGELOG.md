# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-10-25

Ground truth and baseline: the first detection is measured against ground truth on a benchmark dataset, next to a frame-differencing baseline. Live detection, remote play and the app grew alongside.

### Added

- Ground truth (ADR 0011, #14):
  - reference corners for millimetres: 0.3 mm along a wire, about 1 mm across it (#205 follows up);
  - the player's corrections, confirmed fields and detection-test ratings for the field.
  - A guided reference measurement in the app, stored as a session the benchmark scores (#167, #170, #181).
- Benchmark (#17, #180):
  - one command scores a run against ground truth: errors, field accuracy, abstentions, and groups by ring and by flags (cut, occluded, near a wire, dart of the visit);
  - annotation sets from corrections, confirmed fields and detection-test ratings (#15, #115).
- The first dataset, split into development and test sessions (#16), and the baseline report (#19): the live detection placed 51 of 55 confirmed darts in the right field, abstained on 4, and put none in a wrong one. The frame-differencing baseline put 21 in a wrong field.
- Replay detects throws with the live tracker or the frame-differencing baseline (#18, #188). `serve --record` records games with their corrections and takeouts, and `serve --replay` plays a session through the engine API (#115, #184).
- Live detection:
  - a thrown dart reaches the app about 0.5 s after it lands, down from 2.8 s (#190, #192);
  - every detection value is in one documented registry, changeable while the engine runs, recorded with each throw and replayable (#194, #196);
  - a detection test in the setup GUI, with each camera's axis drawn into its image (#197);
  - a knocked camera is reported as moved, while a dart moving the board or its number ring no longer is (#168, #169, #173, #174, #177, #178, #200);
  - the next visit starts only when the darts of the last one are pulled (#128, #191).
- Dart sets (#120): the engine measures a player's darts from four placements, and the app keeps them per player (#201, #208).
- The real board as an image in the game, with its number plates (#166, #171, #175, #176).
- Remote play:
  - engines found in the home network by mDNS and UDP and shared by QR code (#109, #182, #183, #185);
  - pairing with a PIN or a stored token, protocol 1.1 (#110, #207, #209);
  - one game on several displays (#116, #187, #189).
- App:
  - statistics over games with a hit board, an end-of-game summary, and CSV and JSON export (#117, #210);
  - new cameras assigned once with their live images (#198).
- Android feasibility spike: three UVC cameras on a phone through libuvc, at 30 fps each (#104, #186).
- Engine, app and tools carry one version (#202).

### Fixed

- Thrown darts are detected without a person in view (#190).
- The board state is sent only when it changes (#211).
- The board check holds while a knocked camera sways (#178, #179).
- App layout and contrast fixes (#172, #204, #206, #212).

## [0.2.0] - 2026-10-25

Replay and board model: recorded sessions replay identically, the cameras are calibrated from the dartboard itself with a measured error budget, and board points are scored. The platform and app work done meanwhile ships with it.

### Added

- Calibration from the dartboard (ADR 0006, ADR 0009):
  - detection of the circles and radial wires, with sub-pixel transitions and the lens bend (#79, #87);
  - orientation by a tap into the 20, and a board plane per camera (#80);
  - joint refinement of all cameras, with held-out error and uncertainty in board mm (#85).
  - Validated: held-out wires 0.39 / 0.63 / 0.72 mm, cross-camera agreement on real darts 0.26–0.44 mm (#163).
- Intrinsic calibration with ChArUco as an option: held-out validation and model choice (#70), a warning on mismatching capture settings (#72), and a phone pattern (#73).
- Fixed white balance per camera, tuned to the user's light with `dartpilot white-balance` (#150).
- Sessions recorded to disk (#77), a capture health report (#78), and offline replay with calibration checks and a determinism test (#94). A Python reader is tested on a fixture shared with C++ (#96).
- Deterministic scorer from board point to sector and ring (#68), and the board coordinate and ground-truth convention (#67).
- Checks in the setup GUI:
  - calibration check (#92), pin check (#98) and guided validation (#101);
  - whether the board is empty, against a stored empty board (#122).
- Dart detection from several cameras:
  - the whole dart and its axis, with the tip along it (#100, #119);
  - it follows a drifting or warming camera (#136, #142).
- Setup diagnosis that tells the user what to fix: from a recording (#139) and live through the engine API (#144, #147, #148).
- Engine API over WebSocket (ADR 0007, #93, #95), with:
  - previews (#99) and board state (#123, #140);
  - the calibration wizard (#154) and engine discovery in the home network (#109, #138).
- Player app in Flutter (#86):
  - X01, Cricket and Around the Clock (#90, #91), bots (#162);
  - player profiles and statistics (#151, #156);
  - connection to the engine (#97), its own bundled engine or one in the network (#105, #143, #155), phones (#145);
  - setup diagnosis page (#146), calibration wizard (#160), navigation (#149), icon and colours (#141, #152).

### Fixed

- The board check no longer reports darts when a camera warmed up since the empty board was stored (#142).
- The calibration pages of the setup GUI keep the chosen camera, and drop a detection when the camera changes (#82, #83, #84).
- The app never starts itself as the engine (#153).

## [0.1.0] - 2026-10-25

Capture and timing: three cameras are recorded reliably, and their frame rate, drops and latency are known.

### Added

- Reference hardware and capture settings documented: MJPG 1280×720 at 30 fps, automatic exposure that never lowers the frame rate (ADR 0002, #51, #53, #62).
- Capture via V4L2 with UVC PTS timestamps (ADR 0005, #64, #65), with one capture thread and a bounded ring buffer per camera, frame IDs, and drop and latency statistics (#66).
- `dartpilot focus`, a live sharpness display for manual lenses (#54).
- Developer GUI `dartpilot_setup` for camera setup and calibration (ADR 0003, #57, #59).
- Session and replay format (#69).
- Project setup: technical plan, roadmap, contributor and legal documentation, GPL-3.0-or-later license.
- C++20 engine skeleton with one library per pipeline stage, a command-line app and GoogleTest tests.
- Python tools package for benchmark evaluation and annotation.
- CI (formatting, build and tests on Ubuntu and Arch, Python checks), DCO check, CodeQL, auto-merge, milestone releases (#60, #61, #63).
