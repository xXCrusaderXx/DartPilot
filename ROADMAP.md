# Roadmap

This roadmap is a **living document**. Phases, features, and their order change as the project learns. New ideas are welcome at any time; see [Proposing changes](#proposing-changes).

Each phase is a GitHub [milestone](https://github.com/xXCrusaderXx/DartPilot/milestones) named `vX.Y.Z – Name`, and each feature is an issue in it. **When a milestone is closed, a release is created automatically** (see [Releases](#releases)).

The phases follow section 10 of the [technical plan](docs/technical_plan.md#10-first-implementation-plan). Each phase ends with a measured result, not only with features.

## Phases

| Release | Phase | Content | Result |
| ------- | ----- | ------- | ------ |
| **0.1.0** | Measurability | Capture of three cameras with frame IDs and timestamps. Logging of frame drops, effective FPS and queue latency. Replay format and throw ID. Board coordinate and ground-truth convention. Annotations for a first benchmark. Baseline metrics. | A reproducible baseline that describes the current state quantitatively. |
| **0.2.0** | Synchronisation & geometry | Measure time offset and jitter between cameras. Evaluate single-camera board projection. Triangulation on temporally associated measurements. Log reprojection error and board-plane distance. Errors broken down by camera, board region and difficulty. | A well-founded decision on time association and the geometry path. |
| **0.3.0** | Tip localisation | Candidate lists instead of a single point. Shaft-axis and end-point methods compared. Confidence and position covariance. Annotated robustness cases. Optional evaluation of a specialised detector. | Measurably better tip localisation, or a clearly documented remaining bottleneck. |
| **0.4.0** | Fusion & scoring | Discard temporally and geometrically incompatible candidates. Uncertainty-weighted robust fusion. Abstention threshold from the validation set. Scoring tested independently of the CV pipeline. Regression tests for known hard throws. | A verifiable engine with traceable quality indicators. |
| **1.0.0** | Product integration | Stable API and event model. Integration with a UI or an existing dart platform. Release benchmark and a published collection of failure cases. | A modular open-source engine whose precision is backed by a repeatable benchmark. |

Phases after 1.0.0 are open. Ideas that don't belong to a phase yet are collected below.

## Open ideas

Unscheduled proposals, in no particular order. A maintainer moves an idea into a milestone once it is clear and someone works on it.

- Own user interface (toolkit not decided, see [ADR 0001](docs/adr/0001-language-stack.md)).
- Online multiplayer.
- Integration with existing open-source dart platforms.
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
