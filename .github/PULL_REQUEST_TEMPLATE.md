## Summary

<!-- What does this change and why? Link the issue it closes, e.g. "Closes #12". PRs go against `dev`; only `dev` is merged into `main`. -->

## Testing

<!-- How did you test it? Distro, compiler, OpenCV version, cameras (model, resolution, FPS) if relevant. -->

## Benchmark

<!-- Required for changes to event_detection, tip_candidates, geometry or fusion. Dataset and version, before → after:
radial error median / P95 (mm), segment accuracy, multiplier accuracy, false acceptance rate, abstention rate.
Delete this section if the change does not affect detection results. -->

## Checklist

- [ ] Signed off: every commit (`git commit -s`), or I add a `Signed-off-by: Name <email>` line to this description. See [CONTRIBUTING.md](../CONTRIBUTING.md).
- [ ] `git clang-format --diff origin/dev` reports no changes.
- [ ] The project builds locally, and `ctest` passes.
- [ ] `ruff check`, `ruff format --check` and `pytest` pass in `tools/` (if Python changed).
- [ ] Changes to detection include before/after benchmark values above.
- [ ] No recordings, datasets, or binaries are included (see [LEGAL.md](../LEGAL.md)).
- [ ] If AI tools were used: I reviewed every change myself, and I describe their use here. See [AGENTS.md](../AGENTS.md).
- [ ] The title describes the change; `CHANGELOG.md` is not edited (it is written at release time).
