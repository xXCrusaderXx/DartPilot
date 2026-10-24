# Setup diagnosis

Every user should be able to set DartPilot up well and find and fix problems without a developer (#137). The setup diagnosis analyses a short test and lists what is wrong, each finding with a severity and a hint. It runs live on the cameras, as a tool the app offers next to the calibration tools, or on a test recording from the command line.

## Live

With `dartpilot serve --cameras`, a client sends `start_diagnosis` and receives `diagnosis` messages ([engine-api.md](engine-api.md)): the step the user should take next, whether the cameras are still, and the findings so far, updated with every still moment. It waits for an empty board before it starts, so darts left in the board are not taken as the reference, and it measures an empty board that stays still again every 20 s, so that a camera that drifts while warming up or a change of light shows without a recording.

## From a recording

```sh
dartpilot record --seconds 120 --notes "setup test"
dartpilot analyse ~/.local/share/dartpilot/sessions/<session id>
```

## The test

1. Start the cameras and wait about 30 s, so their automatic exposure has settled.
2. Keep the board empty for 5 s, hand out of view.
3. Put a dart into the board, take the hand away and wait 5 s; pull it, wait with the empty board; repeat at 8 to 10 places, also the bull and near the double ring. One dart at a time.

The guided validation page of the setup GUI (#101) records the same sequence.

## Checks

| Check | What it looks at | Typical hint |
| - | - | - |
| `capture` | frames lost per camera | another USB port or a powered hub |
| `still` | moments in which no camera's image moves | hold still, check for vibrations |
| `board` | the first image has hidden wires (not empty); changes of the empty board between darts | start empty; fibres pushed out by darts are harmless |
| `calibration` | each empty board against the camera's calibration (#92) | calibrate again and refine all cameras |
| `drift` | how far each camera's image moved between the empty boards | let the cameras warm up about 10 minutes, tighten the mount |
| `light` | brightness of the empty board over the test | wait for the exposure after starting, use the ring light |
| `darts` | each dart: which cameras saw it, cut it at the image border, located it | tilt a camera that cuts darts and cannot help locating them |
| `consistency` | how far the axis planes of the cameras that located a dart are apart | refine all cameras again |

Each empty board between darts becomes the reference for the next dart, as after a takeout in a game.

## Report

`dartpilot analyse` writes `results/diagnosis/diagnosis.json` (machine-readable, for the GUI) and `diagnosis.md` into the session and prints the Markdown. Findings are sorted most severe first: `problem`, `warning`, `info`. The thresholds are provisional until the error budget is set (#48).

On the recordings of the reference setup, the diagnosis found what was found by hand while developing the dart detection: camera 2 (usb-2.4.3.1.3) drifting by 0.6 px within the first minutes after starting and 1.2 mm off its calibration, the automatic exposure settling for about 25 s after starting, fibres pushed out of the board, and darts whose flight left the image without costing their location.
