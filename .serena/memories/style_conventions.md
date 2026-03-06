# Style and conventions
- Documentation language: Korean. Keep code and technical terms in English.
- Documentation dates: `YYYY-MM-DD`. Filenames: kebab-case.
- Swift guidance comes from `.claude/rules/` and `code-style` skill.
- Design-system rules: prefer xcassets colors under `Colors/`; avoid inline RGB colors; keep semantic token naming.
- UI/title policy: tab names and navigation titles stay English.
- Testing: logic changes require Swift Testing coverage in `DUNETests/` or `DUNEWatchTests/`; UI-only body changes can be covered by UI tests.
- Process discipline: surgical scope, surface uncertainty, document reusable solutions in `docs/solutions/`.
