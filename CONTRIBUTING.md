# Contributing to DartPilot

Thanks for helping out! Please read [LEGAL.md](LEGAL.md) before you contribute. It says which material must not end up in this repository, in particular recordings of people.

The technical direction is described in the [technical plan](docs/technical_plan.md). What is planned next is in the [roadmap](ROADMAP.md). It is open for additions.

---

## DCO sign-off (required)

This project uses the [Developer Certificate of Origin](https://developercertificate.org/). By signing off, you certify that you have the right to submit your contribution under the project's license. There are two ways to do it:

**Per commit:** sign off each commit:

```sh
git commit -s -m "Your message"
```

**Per PR:** put one `Signed-off-by: Your Name <your@email>` line in the pull request description, or tick the sign-off box in the PR template. PRs are squash-merged, so that one sign-off covers the whole PR.

The `DCO` check enforces this. PRs opened from the repository owner's account are exempt: the owner certifies them as a standing decision. Use your real identity and a reachable email address. Never sign off for someone else.

## AI-assisted contributions

You may use AI coding tools. The rules:

- **You** are the author. You must review and understand every line, and be able to explain and maintain it in review.
- The DCO sign-off is yours to give. An AI tool must never add `Signed-off-by` for you. A `Co-Authored-By` trailer for the tool is fine.
- Say in the PR description that you used AI tools and for what (the PR template has a checkbox).
- Don't send unreviewed, bulk, or drive-by agent PRs. They will be closed.
- Agents working in this repository must follow [AGENTS.md](AGENTS.md).

## Licensing of contributions

By contributing, you agree that your code is licensed under the [GNU General Public License v3.0 or later](LICENSE). No separate CLA is needed. Datasets follow their own rules, see [Contributing data](#contributing-data).

---

## Ways to contribute

- **Code:** pick an issue from a [milestone](https://github.com/xXCrusaderXx/DartPilot/milestones) or propose something new with a [roadmap proposal](https://github.com/xXCrusaderXx/DartPilot/issues/new?template=roadmap_proposal.yml).
- **Recordings and annotations:** throws with ground truth are what the benchmark is built from. See [Contributing data](#contributing-data).
- **Hardware reports:** which cameras, resolutions and frame rates work, and how well their timestamps are synchronised.
- **Docs:** the technical plan, ADRs and build instructions.

### Changes to detection

DartPilot's claim is precision, so changes that affect the detection result (`event_detection`, `tip_candidates`, `geometry`, `fusion`) must show their effect:

- Run the benchmark on the same dataset before and after the change.
- Report in the PR at least the radial error (median and P95, in mm), segment and multiplier accuracy, false acceptance rate and abstention rate. Name the dataset and its version.
- Report hard groups separately when the change targets them (near wires, bull, double/triple rings, occluded tips; see section 7 of the [technical plan](docs/technical_plan.md#7-experiment-plan)).
- A change that improves the mean but worsens a hard group must say so.

Until the benchmark tooling exists (phase 1), describe how you measured the effect.

`scoring` must stay deterministic and free of image processing: board point in, score out.

### Contributing data

Recordings and annotations are valuable, but they are **not committed to this repository**. `data/` is ignored by Git; datasets are published separately and referenced by version.

- Only record the dartboard. No people, faces, or anything else that identifies a person may be visible in a frame, and no audio is recorded.
- You must have the right to share the recording. Name the license for the dataset (CC BY 4.0 is preferred).
- Describe the setup: camera models, resolution, FPS, exposure settings, camera positions, board model and how the ground truth was produced, including its uncertainty.
- Split by session, never by frame (see "Dataset split" in the technical plan). The hold-out test set is not used for tuning.

---

## Workflow

1. Open an issue first for larger changes, so the approach can be agreed on before you invest time.
2. Fork the repository and create a branch from `dev` (`feat/…`, `fix/…`, `docs/…`, `chore/…`).
3. Keep each PR focused on one topic. Use a [Conventional Commits](https://www.conventionalcommits.org/)-style PR title, for example `feat: per-frame capture timestamps from V4L2`. It becomes the message of the squash commit on `dev` and the changelog entry.
4. Open a pull request against `dev` and fill in the template.

### Branches

| Branch | Purpose |
| ------ | ------- |
| `main` | Released code only. Changes come exclusively from `dev`, merged by a maintainer at a release point. |
| `dev` | Integration branch and default branch. All development happens here, through feature and fix PRs. |
| `feat/…`, `fix/…`, `docs/…`, `chore/…` | One topic each, branched from `dev`, deleted after the merge. |

PRs into `dev` are **squash-merged**: each PR becomes one commit, and `dev` stays a straight line. `dev` → `main` is the only merge commit, made by a maintainer at a release point. The `Branch policy` check fails every PR into `main` whose source is not `dev`. After `dev` is merged into `main`, work simply continues on `dev`.

To bring a branch up to date, rebase it onto `dev` (`git rebase origin/dev`, or `gh pr update-branch --rebase`). Never merge `dev` into a feature branch.

### How a PR gets merged

A PR can only be merged when all required checks are green (`format`, `build (ubuntu)`, `build (arch)` including the tests, `python`, `DCO sign-off`; for PRs into `main` also `source is dev`). The branch does not need to be up to date with `dev`; if two PRs that pass on their own break `dev` together, the CI run on `dev` shows it and a small follow-up PR fixes it.

- **Contributors' PRs:** a maintainer reviews the change. When it is good, the maintainer merges it, or enables auto-merge so GitHub merges it as soon as the checks are green. Nothing from outside is merged without a maintainer looking at it.
- **Maintainers' own PRs into `dev`:** auto-merge is enabled automatically. Ticking the sign-off box in the PR description is the maintainer's one action; the PR merges once the checks are green.
- **Dependabot:** minor and patch updates of GitHub Actions merge automatically once CI is green. Major updates wait for a maintainer.

Auto-merge and CodeQL are switched on once the repository is public; until then they are skipped.

A PR with a merge conflict needs a rebase by its author.

Draft PRs are never merged; mark the PR "Ready for review" when you are done.

---

## Local CI gate

Run the same checks as CI before you push:

```sh
# Formatting of the lines you changed (.clang-format in the repository root)
git fetch origin && git clang-format --diff origin/dev

# Build and test the engine (the tests need no cameras)
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DDARTPILOT_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure

# Python tools
cd tools && ruff check . && ruff format --check . && pytest
```

Optional: `.githooks/pre-push` stops a push when a commit's author or committer email matches a pattern you set locally, so a work or private address never reaches GitHub by accident (Git GUIs often use their own identity). Enable it with `git config core.hooksPath .githooks` and `git config --add hooks.blockedEmail 'example\.com'`. The patterns stay in your local config.

Optional: `.githooks/post-merge` cleans up after every `git pull`: local branches whose PR was merged (remote branch gone) are deleted, together with their worktree if it has no changes. If you use worktrees, keep them under `.worktrees/` in the repository; that folder is ignored by Git. Enable it with `git config core.hooksPath .githooks` and `git config fetch.prune true`.

CI checks only the lines your PR changes. To fix them in place, run `git clang-format origin/dev`. Don't reformat code you didn't otherwise touch.

## Code style

- C++20, formatted with the repository's `.clang-format` (Allman braces, 4-space indent, 150 columns).
- Python 3.11+, formatted and linted with `ruff` (settings in `tools/pyproject.toml`).
- QML (developer GUI `engine/apps/dartpilot_setup`): 4-space indent, no `qmllint` warnings. Logic and image processing stay in C++; QML only arranges views and controls.
- **Code comments and log messages are written in English.**
- Each engine module is a library under `engine/<module>/` with its public headers in `include/dartpilot/<module>/`. Modules depend only on the modules before them in the pipeline; `scoring` depends on none of them.
- Results carry their units in the name (`board_xy_mm`, `latency_ms`). Board coordinates follow the convention defined in phase 1.
- Code that runs during replay must be deterministic: no wall-clock time, no unseeded randomness, no dependence on thread timing.
- Match the surrounding code: naming and comment density.
- Never commit build output, recordings, datasets, or binaries.

## Pull request checklist

- [ ] Signed off (`git commit -s`, or one `Signed-off-by` line in the PR description).
- [ ] `git clang-format --diff origin/dev` reports no changes.
- [ ] The project builds with `cmake --build build`, and `ctest --test-dir build` passes.
- [ ] `ruff check`, `ruff format --check` and `pytest` pass in `tools/` if you changed Python code.
- [ ] Changes to detection include before/after benchmark values (see [Changes to detection](#changes-to-detection)).
- [ ] No recordings, datasets, or binaries are committed (see [LEGAL.md](LEGAL.md)).
- [ ] The PR title describes the change (it becomes the changelog entry). Don't edit [CHANGELOG.md](CHANGELOG.md) in feature PRs.

## Releases

`CHANGELOG.md` is written by a maintainer once per release, from the titles of the merged PRs. Feature PRs don't edit it: with several PRs in flight it is the most frequent merge conflict.

Releases follow the [roadmap](ROADMAP.md): every phase is a milestone named `vX.Y.Z – Name`. At a release point, a PR `dev` → `main` is opened and the maintainer merges it (merge commit, never automatic). When the maintainer then closes the milestone, the `Milestone release` workflow checks that all its issues are closed and runs the `Release` workflow for `X.Y.Z` on `main`. That workflow builds and tests the engine and publishes GitHub release `vX.Y.Z` with a source archive and checksums, and with the milestone's issues and PRs as release notes. The version comes from the milestone title, so no version-bump commit is needed. Before closing a milestone, work through the [release checklist](https://github.com/xXCrusaderXx/DartPilot/issues/new?template=release.yml).

For a release outside a milestone, either run the `Release` workflow by hand with a version (without a version it is a dry run that builds and tests everything but publishes nothing), or set `DARTPILOT_VERSION` in `CMakeLists.txt` and push a matching tag `vX.Y.Z` on `main`. A version with a suffix (`0.2.0-rc.1`) is published as a pre-release.

## Conduct

All participation falls under the [Code of Conduct](CODE_OF_CONDUCT.md). Be respectful and constructive.
