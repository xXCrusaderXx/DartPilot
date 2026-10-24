# Roadmap

This roadmap is a **living document**. Phases, features, and their order change as the project learns. New ideas are welcome at any time; see [Proposing changes](#proposing-changes).

Each phase is a GitHub [milestone](https://github.com/xXCrusaderXx/DartPilot/milestones) named `vX.Y.Z – Name`, and each feature is an issue in it. **When a milestone is closed, a release is created automatically** (see [Releases](#releases)).

The milestones follow section 10 of the [technical plan](docs/technical_plan.md#10-first-implementation-plan); its phase 1 is split into three milestones so that each one ends in a usable, measured step. Each milestone ends with a measured result, not only with features.

## Phases

| Release | Plan phase | Content | Result |
| ------- | ---------- | ------- | ------ |
| **[0.1.0 – Capture & timing](https://github.com/xXCrusaderXx/DartPilot/milestone/1)** | 1 Measurability | Documented camera hardware and capture settings. Capture backend and timestamp source chosen. One capture thread and bounded ring buffer per camera. Per-frame IDs, capture and arrival timestamps, drop detection. Session recording. Capture health statistics. Developer GUI for camera setup and live diagnostics ([ADR 0003](docs/adr/0003-developer-gui.md)). | Three cameras are recorded reliably, and their FPS, drops and latency are known. |
| **[0.2.0 – Replay & board model](https://github.com/xXCrusaderXx/DartPilot/milestone/2)** | 1 Measurability | Replay format and throw ID. Deterministic replay with a CI check. Python reader. Board coordinate and ground-truth convention. Deterministic scorer. Intrinsic calibration without a user-held target: a prior per camera model, refined per camera from the dartboard together with the extrinsics ([ADR 0006](docs/adr/0006-calibration-without-user-held-targets.md)), validated against a per-camera ChArUco reference. Extrinsic calibration from the dartboard itself: wire detection, measured board model, pose per camera, validated against held-out points, cross-camera consistency and reference pins. | Recorded sessions replay identically, anyone can calibrate their cameras at home with a documented error budget, and board points can be scored. |
| **[0.3.0 – Ground truth & baseline](https://github.com/xXCrusaderXx/DartPilot/milestone/3)** | 1 Measurability | Ground-truth method with measured uncertainty. Annotation tool. First benchmark dataset, split by session. Benchmark metrics and report. Baseline frame-differencing pipeline. Baseline report. | A reproducible baseline that describes the current state quantitatively. |
| **[0.4.0 – Synchronisation & geometry](https://github.com/xXCrusaderXx/DartPilot/milestone/4)** | 2 | Inter-camera offset and jitter. Timeline view. Single-camera projection error. Triangulation with reprojection and plane-distance checks. Temporal frame association. Detection of camera and board movement. Geometry path decision. | A well-founded decision on time association and the geometry path. |
| **[0.5.0 – Tip localisation](https://github.com/xXCrusaderXx/DartPilot/milestone/5)** | 3 | Candidate lists, shaft-axis estimation, confidence and pixel covariance. Annotated robustness cases. Ablation study. Optional learned detector. | Measurably better tip localisation, or a clearly documented remaining bottleneck. |
| **[0.6.0 – Fusion & scoring](https://github.com/xXCrusaderXx/DartPilot/milestone/6)** | 4 | Uncertainty-weighted robust fusion. Abstention threshold from the validation set. Regression tests for hard throws. Latency budget. Hold-out evaluation. | A verifiable engine with traceable quality indicators. |
| **[0.7.0 – Engine on every device](https://github.com/xXCrusaderXx/DartPilot/milestone/8)** | – | The engine inside the app on Android, Linux, Windows and Raspberry Pi, or remote in the network ([ADR 0008](docs/adr/0008-engine-deployment.md)). Android feasibility spike first. Capture backends libuvc (Android) and Media Foundation (Windows), portable data directory and camera identity, engine discovery (mDNS) and PIN pairing, CI for Android and Windows. | A player with only a phone and the cameras can play standalone, and any device can show the game of an engine elsewhere. |
| **[1.0.0 – Product integration](https://github.com/xXCrusaderXx/DartPilot/milestone/7)** | 5 | Engine API and event model. User interface in Flutter for Linux, Windows, web and Android ([ADR 0004](docs/adr/0004-user-interface.md)). Review of existing dart platforms. Published release benchmark and failure cases. Packaging and user documentation. | A modular open-source engine whose precision is backed by a repeatable benchmark. |

Every work item is an issue in its milestone, with a "Done when" criterion. Labels: `area/*` for the module, `experiment` for measurements with a documented result, `decision` for work that ends in an [ADR](docs/adr).

Phases after 1.0.0 are open. Ideas that don't belong to a phase yet are collected below.

## Open ideas

Unscheduled proposals, in no particular order. A maintainer moves an idea into a milestone once it is clear and someone works on it.

- Online multiplayer (after 1.0.0, on top of the engine API).
- Public benchmark dataset with a leaderboard of detection variants.
- Neural tip detector, if classical candidates turn out to be insufficient (phase 3 decides).

Add ideas through a [roadmap proposal](https://github.com/xXCrusaderXx/DartPilot/issues/new?template=roadmap_proposal.yml).

## Proposing changes

- **New feature or change to a phase:** open a [roadmap proposal](https://github.com/xXCrusaderXx/DartPilot/issues/new?template=roadmap_proposal.yml). Proposals are discussed in the issue. Accepted ones get a milestone, or land under [Open ideas](#open-ideas).
- This file is updated in the same PR that changes a milestone.

## Releases

- Work happens on feature branches that are merged into `dev`. At a release point, `dev` is merged into `main` by the maintainer.
- Closing a milestone `vX.Y.Z – Name` starts the `Milestone release` workflow. It checks that every issue in the milestone is closed, collects the closed issues and pull requests as release notes, and runs the `Release` workflow for version `X.Y.Z` on `main`.
- The `Release` workflow builds and tests the engine and publishes GitHub release `vX.Y.Z` with a source archive and `SHA256SUMS`. Binary packages follow once there is something to run.
- If a milestone is closed by mistake while issues are still open, no release is made. Reopen the milestone, finish the issues, and close it again.
- Bug-fix releases (`X.Y.Z+1`) use their own small milestone, or a manual run of the `Release` workflow.
