# Documentation

Where to find what. New readers start with the [technical plan](technical_plan.md); the [roadmap](../ROADMAP.md) shows where the project stands.

## Plan and decisions

- [Technical plan](technical_plan.md): why DartPilot is built the way it is, its metrics and targets.
- [Architecture decisions](adr): one ADR per decision, numbered in order.

| ADR | Decision |
| --- | -------- |
| [0001](adr/0001-language-stack.md) | Language stack |
| [0002](adr/0002-capture-settings.md) | Capture settings for the reference cameras |
| [0003](adr/0003-developer-gui.md) | Developer GUI |
| [0004](adr/0004-user-interface.md) | User interface |
| [0005](adr/0005-capture-backend-and-timestamps.md) | Capture backend and timestamp source |
| [0006](adr/0006-calibration-without-user-held-targets.md) | Calibration without user-held targets |
| [0007](adr/0007-engine-api.md) | Engine API |
| [0008](adr/0008-engine-deployment.md) | Engine deployment: in the app and remote |
| [0009](adr/0009-board-calibration-validated.md) | Board-based calibration, validated |
| [0010](adr/0010-shared-game-state.md) | One game on several displays |
| [0011](adr/0011-ground-truth.md) | Ground truth from reference corners and from the player's corrections |
| [0012](adr/0012-remote-play.md) | Remote play: peer to peer, the leading player hosts |

## Setting up

- [Reference hardware](hardware.md): board, cameras and mounting the measurements were made with.
- [Calibration](calibration.md): intrinsics and the board pose of each camera, and the calibration patterns.
- [Setup diagnosis](setup-diagnosis.md): finding and fixing setup problems without a developer.
- [Android](android.md): whether a phone can run the cameras.

## Formats and interfaces

- [Engine API](engine-api.md): the WebSocket protocol between engine and apps.
- [Session and replay format](replay-format.md): how recordings and detection results are stored.
- [Board coordinates](board-coordinates.md): the coordinate system every result uses.
- [Detection values](detection-params.md): every value that decides whether and where a dart is found (generated).
- [Online play – concept](online-play.md): playing over the internet.

## Measuring

- [Benchmark](benchmark.md): the metrics and the commands that compute them.
- [Benchmark dataset](dataset.md): the recorded sessions with ground truth.
- Measurements: [camera timing](benchmarks/camera-timing.md) ([data](benchmarks/camera-timing-data.md)), [temporal association](benchmarks/temporal-association.md).
- Reports: [baseline 0.3.0](reports/baseline-0.3.0.md), [tip candidates 0.5.0](reports/tip-candidates-0.5.0.md), [shaft axis 0.5.0](reports/shaft-axis-0.5.0.md), [candidate confidence 0.5.0](reports/candidate-confidence-0.5.0.md).
