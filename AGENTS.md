# Rules for AI coding agents

These rules apply to every AI agent (Claude Code, Codex, Copilot, Cursor, …) that works in this repository. A task brief or issue that states its own rule for its work takes precedence over this file. Human contributors follow [CONTRIBUTING.md](CONTRIBUTING.md); everything there applies to agents too.

## Responsibility

- An agent works on behalf of a human contributor. That human reviews every change, understands it, and answers for it in the PR.
- **Never add a `Signed-off-by` line yourself, and never tick the sign-off box.** The DCO sign-off is a legal statement only the human can make. A `Co-Authored-By` trailer for the agent is welcome.
- Do not open, approve, merge, or close pull requests, push to `main` or `dev`, merge `dev` into `main`, create tags or releases, or change repository settings unless the human explicitly asks for that specific action.
- Never bypass checks: no `--no-verify`, no disabling CI jobs, no weakening `.github/workflows/` or the DCO check to make a PR pass.
- Disclose agent use in the PR description (the template has a checkbox).

## Legal limits

Read [LEGAL.md](LEGAL.md). In particular, never add:

- recordings, frames, or datasets to the repository (`data/` stays untracked), and never any image that shows a person,
- code copied from sources whose license is not compatible with GPL-3.0-or-later, or whose origin you cannot name,
- logos or brand assets of dartboard or scoring-system makers.

## Architecture

The design is in [docs/technical_plan.md](docs/technical_plan.md); decisions are recorded in [docs/adr/](docs/adr). Read both before changing the pipeline.

- `engine/<module>/`: one C++ library per pipeline stage, public headers in `include/dartpilot/<module>/`, namespace `dartpilot::<module>`.
  - `capture`: camera threads, per-frame timestamps and IDs, bounded ring buffers, drop counters.
  - `event_detection`: throw event, time window, baseline and difference masks.
  - `tip_candidates`: several tip candidates per camera, each with confidence and a 2×2 covariance.
  - `geometry`: board plane, ray–plane projection, triangulation, reprojection error.
  - `fusion`: temporal association, robust estimation, abstention.
  - `scoring`: deterministic board point (mm) → sector and ring. No image processing, no dependency on other modules.
  - `replay`: offline evaluation of recorded throws.
- `engine/apps/dartpilot_cli/`: command-line entry point.
- `tests/`: GoogleTest tests, registered with ctest.
- `tools/`: Python package `dartpilot_tools` (benchmark, annotation). It reads engine output files and is never part of the detection path.
- [ROADMAP.md](ROADMAP.md): phases and milestones. Each closed milestone becomes a release. Work on a roadmap item references its issue, and a change to a phase updates ROADMAP.md in the same PR.

Principles that every change keeps:

- Detection, geometry and scoring stay separate. Results are board points in mm with uncertainty and diagnostics, not only scores.
- Every result is traceable to its source frame IDs and candidates.
- Replay is deterministic: the same input and configuration give identical results. No wall-clock time, unseeded randomness, or thread-timing dependence in replayed code.
- The engine may abstain. Never force a score to make a metric look better.
- A change to detection reports before/after benchmark values (see CONTRIBUTING.md, "Changes to detection"). Do not claim a precision gain you did not measure.

## Code

- C++20, `.clang-format` style (Allman braces, 4-space indent, 150 columns). Format only the lines you change: `git clang-format origin/dev`.
- Python 3.11+, `ruff` for linting and formatting.
- Comments and log messages are written in English. A comment states intent the code cannot show; do not narrate history or the change you just made.
- Units are part of names (`_mm`, `_px`, `_ms`, `_ns`).
- Match the surrounding code: naming, structure, and comment density. Do not reformat or refactor code unrelated to the task.

## Build and verify

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DDARTPILOT_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build --output-on-failure
git clang-format --diff origin/dev
(cd tools && ruff check . && ruff format --check . && pytest)
```

A change is done only when it builds and the tests pass. Say so in the PR if you could not test a code path with real cameras.

## Working in a shared checkout

- Changes you did not make belong to the human or another agent. Do not commit, revert, stash, or unstage them. Check `git diff --cached --name-only` before you commit.
- Do not commit build output (`build/`), virtual environments, or anything under `data/`.
- Branch from `dev` and open PRs against `dev` (merge commit, no squash). `main` only receives `dev` at release points, merged by the human.
- Never switch branches in the main checkout; it stays on `dev`. Work on a branch in your own worktree (`git worktree add <dir> -b <branch> origin/dev`).
- Don't edit `CHANGELOG.md` in feature PRs; it is written once per release. Put the change in the PR title instead.
- Clean up after every merge: remove your worktree and local branch (`git worktree remove <dir>`, `git branch -D <branch>`) and run `git fetch --prune`. The `Clean up merged branches` workflow deletes the remote branch.
