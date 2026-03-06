# What to do when a task is completed
- Regenerate/build through project scripts rather than ad-hoc Xcode commands.
- Prefer `scripts/build-ios.sh` for build verification.
- Run relevant unit tests with `scripts/test-unit.sh` and relevant UI tests when UI structure changes.
- Update documentation under `docs/` for plans, brainstorms, or solutions when the workflow calls for it.
- Keep changes consistent with mandatory `.claude/rules/*` guidance, especially testing/localization/layer boundaries.
