# Roadmap

This roadmap is a **living document**. Phases, features, and their order change as the project learns. New ideas are welcome at any time; see [Proposing changes](#proposing-changes).

Work runs in **two tracks**:

- **Detection** – the versioned milestones `vX.Y.Z – Name`. They follow section 10 of the [technical plan](docs/technical_plan.md#10-first-implementation-plan) (its phase 1 is split into 0.1 to 0.3) and are the critical path: each ends with a measured result, and **closing one creates a release** (see [Releases](#releases)).
- **Platform and app** – milestones without a version, worked on in parallel. What is finished there ships with the next release.

Every work item is an issue in its [milestone](https://github.com/xXCrusaderXx/DartPilot/milestones) with a "Done when" criterion. Labels: `prio/high` (next up), `prio/medium`, `prio/low`; `status/blocked` with the reason in the issue; `area/*` for the module, `experiment` for measurements with a documented result, `decision` for work that ends in an [ADR](docs/adr).

## Detection track

| Release | Plan phase | Content | Result |
| ------- | ---------- | ------- | ------ |
| **[0.1.0 – Capture & timing](https://github.com/xXCrusaderXx/DartPilot/milestone/1)** | 1 Measurability | Documented camera hardware and capture settings. Capture backend and timestamp source chosen. One capture thread and bounded ring buffer per camera. Per-frame IDs, capture and arrival timestamps, drop detection. Session recording. Capture health statistics. Developer GUI for camera setup and live diagnostics ([ADR 0003](docs/adr/0003-developer-gui.md)). | Three cameras are recorded reliably, and their FPS, drops and latency are known. |
| **[0.2.0 – Replay & board model](https://github.com/xXCrusaderXx/DartPilot/milestone/2)** | 1 Measurability | Replay format and throw ID. Deterministic replay with a CI check. Python reader. Board coordinate and ground-truth convention. Deterministic scorer. Intrinsic calibration without a user-held target: a prior per camera model, refined per camera from the dartboard together with the extrinsics ([ADR 0006](docs/adr/0006-calibration-without-user-held-targets.md)), validated against a per-camera ChArUco reference. Extrinsic calibration from the dartboard itself: wire detection, measured board model, pose per camera, validated against held-out points, cross-camera consistency and reference pins. | Recorded sessions replay identically, anyone can calibrate their cameras at home with a documented error budget, and board points can be scored. |
| **[0.3.0 – Ground truth & baseline](https://github.com/xXCrusaderXx/DartPilot/milestone/3)** | 1 Measurability | Ground-truth method with measured uncertainty. Annotation tool. First benchmark dataset, split by session. Benchmark metrics and report. Baseline frame-differencing pipeline. Baseline report. | A reproducible baseline that describes the current state quantitatively. |
| **[0.4.0 – Synchronisation & geometry](https://github.com/xXCrusaderXx/DartPilot/milestone/4)** | 2 | Inter-camera offset and jitter. Timeline view. Single-camera projection error. Triangulation with reprojection and plane-distance checks. Temporal frame association. Detection of camera and board movement. Geometry path decision. | A well-founded decision on time association and the geometry path. |
| **[0.5.0 – Tip localisation](https://github.com/xXCrusaderXx/DartPilot/milestone/5)** | 3 | Candidate lists, shaft-axis estimation, confidence and pixel covariance. Annotated robustness cases. Ablation study. Optional learned detector. Optional dart profile: the player's darts measured as a reference; detection must work without it. | Measurably better tip localisation, or a clearly documented remaining bottleneck. |
| **[0.6.0 – Fusion & scoring](https://github.com/xXCrusaderXx/DartPilot/milestone/6)** | 4 | Uncertainty-weighted robust fusion. Abstention threshold from the validation set. Regression tests for hard throws. Latency budget. Hold-out evaluation. | A verifiable engine with traceable quality indicators. |
| **[1.0.0 – Product integration](https://github.com/xXCrusaderXx/DartPilot/milestone/7)** | 5 | Engine API and event model. User interface in Flutter for Linux, Windows, web and Android ([ADR 0004](docs/adr/0004-user-interface.md)). Review of existing dart platforms. Published release benchmark and failure cases. Packaging and user documentation. | A modular open-source engine whose precision is backed by a repeatable benchmark. |


## Platform and app track

| Milestone | Content | Result |
| --------- | ------- | ------ |
| **[Platform: remote play and engine choice](https://github.com/xXCrusaderXx/DartPilot/milestone/8)** | Engine discovery in the home network with mDNS and a UDP broadcast fallback [#109](https://github.com/xXCrusaderXx/DartPilot/issues/109). The app starts its own engine on Linux or connects to one in the network [#105](https://github.com/xXCrusaderXx/DartPilot/issues/105). Phone as a remote display [#114](https://github.com/xXCrusaderXx/DartPilot/issues/114). PIN pairing for network engines [#110](https://github.com/xXCrusaderXx/DartPilot/issues/110). Portable data directory and camera identity [#112](https://github.com/xXCrusaderXx/DartPilot/issues/112). Raspberry Pi as engine host [#108](https://github.com/xXCrusaderXx/DartPilot/issues/108). ([ADR 0008](docs/adr/0008-engine-deployment.md)) | Any device in the home network finds the engine and shows the game; the Linux app plays without a terminal. |
| **[Platform: engine on Android and Windows](https://github.com/xXCrusaderXx/DartPilot/milestone/9)** | Android feasibility spike with three UVC cameras [#104](https://github.com/xXCrusaderXx/DartPilot/issues/104), Android engine library with libuvc [#106](https://github.com/xXCrusaderXx/DartPilot/issues/106), Windows with Media Foundation [#107](https://github.com/xXCrusaderXx/DartPilot/issues/107), CI for both [#111](https://github.com/xXCrusaderXx/DartPilot/issues/111). | A player with only a phone and the cameras plays standalone; Windows works like Linux. |
| **[App: games and players](https://github.com/xXCrusaderXx/DartPilot/milestone/10)** | One game on several displays [#116](https://github.com/xXCrusaderXx/DartPilot/issues/116), player profiles and statistics [#117](https://github.com/xXCrusaderXx/DartPilot/issues/117), lobbies and friends with pairing by QR code, token or short code [#124](https://github.com/xXCrusaderXx/DartPilot/issues/124), more game modes [#118](https://github.com/xXCrusaderXx/DartPilot/issues/118). | The app is a complete dart companion beyond detection. |

The player app already has X01, Cricket, Around the Clock and free throwing, manual input, the engine connection with corrections, and live camera previews ([ADR 0004](docs/adr/0004-user-interface.md), [ADR 0007](docs/adr/0007-engine-api.md)).

## Priorities and order

The order in which work is picked up, highest first. Issue labels carry the same priorities.

1. **Finish calibration (0.2.0):** extrinsic calibration from the dartboard [#13](https://github.com/xXCrusaderXx/DartPilot/issues/13), wire detection and board model [#47](https://github.com/xXCrusaderXx/DartPilot/issues/47), its validation [#48](https://github.com/xXCrusaderXx/DartPilot/issues/48). Set the focus of the reference cameras [#52](https://github.com/xXCrusaderXx/DartPilot/issues/52), which closes 0.1.0 and allows release v0.1.0.
2. **Remote play** – in parallel, it needs no detection: engine discovery [#109](https://github.com/xXCrusaderXx/DartPilot/issues/109), phone as a remote display [#114](https://github.com/xXCrusaderXx/DartPilot/issues/114), engine choice in the app [#105](https://github.com/xXCrusaderXx/DartPilot/issues/105).
3. **Ground truth and baseline (0.3.0):** ground-truth method [#14](https://github.com/xXCrusaderXx/DartPilot/issues/14), annotation tool [#15](https://github.com/xXCrusaderXx/DartPilot/issues/15), benchmark metrics [#17](https://github.com/xXCrusaderXx/DartPilot/issues/17); then the dataset [#16](https://github.com/xXCrusaderXx/DartPilot/issues/16), the baseline pipeline [#18](https://github.com/xXCrusaderXx/DartPilot/issues/18) and its report [#19](https://github.com/xXCrusaderXx/DartPilot/issues/19); corrections from play as labelled data and replay through the API [#115](https://github.com/xXCrusaderXx/DartPilot/issues/115).
4. **Platform groundwork:** PIN pairing [#110](https://github.com/xXCrusaderXx/DartPilot/issues/110), portable data directory and camera identity [#112](https://github.com/xXCrusaderXx/DartPilot/issues/112), Raspberry Pi host [#108](https://github.com/xXCrusaderXx/DartPilot/issues/108).
5. **Android:** feasibility spike [#104](https://github.com/xXCrusaderXx/DartPilot/issues/104) – *blocked until a USB-C OTG adapter and a powered USB-C hub are available* – then the Android engine [#106](https://github.com/xXCrusaderXx/DartPilot/issues/106).
6. **Synchronisation and geometry (0.4.0):** inter-camera timing [#20](https://github.com/xXCrusaderXx/DartPilot/issues/20) can start any time; the rest needs the 0.3.0 dataset.
7. **App:** one game on several displays [#116](https://github.com/xXCrusaderXx/DartPilot/issues/116), profiles and statistics [#117](https://github.com/xXCrusaderXx/DartPilot/issues/117), then lobbies and friends [#124](https://github.com/xXCrusaderXx/DartPilot/issues/124): identity and pairing first; how players connect over the internet is decided in its own ADR before online play is built.
8. **Tip localisation (0.5.0)** – including the optional dart profile [#120](https://github.com/xXCrusaderXx/DartPilot/issues/120) after generic detection is checked against a second dart type – **fusion (0.6.0)**, then **1.0.0**; Windows [#107](https://github.com/xXCrusaderXx/DartPilot/issues/107), CI for Android and Windows [#111](https://github.com/xXCrusaderXx/DartPilot/issues/111) and more game modes [#118](https://github.com/xXCrusaderXx/DartPilot/issues/118) when there is room.

Phases after 1.0.0 are open. Ideas that don't belong to a phase yet are collected below.

## Open ideas

Unscheduled proposals, in no particular order. A maintainer moves an idea into a milestone once it is clear and someone works on it.

- Online multiplayer (after 1.0.0): apps of different households play together, each with its own engine.
- iOS app as a remote display (iOS cannot run the engine with USB cameras, ADR 0008).
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
- Milestones without a version (platform and app track) create no release when they are closed.
