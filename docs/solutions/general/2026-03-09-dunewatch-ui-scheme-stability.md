---
tags: [xcodegen, xcscheme, watchos, ui-test, post-processing, perpetual-diff]
category: general
date: 2026-03-09
severity: minor
related_files:
  - scripts/lib/regen-project.sh
  - scripts/lib/xcscheme-clean-filter.sh
  - DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme
related_solutions:
  - docs/solutions/general/2026-03-01-xcodegen-scheme-perpetual-diff.md
  - docs/solutions/general/2026-02-28-xcodegen-scheme-perpetual-diff.md
---

# Solution: DUNEWatchUITests scheme ordering drift

## Problem

`DUNEWatchUITests.xcscheme` kept changing after project regeneration even though the previous Xcode 26 compatibility patch was already in place.

### Symptoms

- `scripts/lib/regen-project.sh` regenerated `DUNEWatchUITests.xcscheme` with a diff every time.
- The diff only moved `MacroExpansion` and flipped the attribute order of the default `TestPlanReference`.
- Opening or saving the project in Xcode produced the opposite ordering, so the file could churn back and forth.

### Root Cause

The existing scheme normalization only patched missing attributes such as `version`, `runPostActionsOnFailure`, and `onlyGenerateCoverageForSpecifiedTargets`. For the watch UI test scheme, xcodegen still emitted a `TestAction` layout that did not match the Xcode-saved XML ordering:

1. xcodegen wrote `TestPlans` before `MacroExpansion`.
2. xcodegen wrote the default test plan attributes as `default` then `reference`.
3. Xcode rewrote the same scheme as `MacroExpansion` before `TestPlans` and `reference` before `default`.

Because the repo tracked the Xcode-style layout, every regeneration reintroduced the diff.

## Solution

Extend the existing post-processing so the watch UI test scheme is rewritten into the tracked canonical form immediately after regeneration, and apply the same rewrite in the git clean filter.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/lib/regen-project.sh` | Added a watch UI scheme-specific normalization step | Keep `regen_project` output aligned with Xcode's saved layout |
| `scripts/lib/xcscheme-clean-filter.sh` | Mirrored the same normalization during staging | Prevent staged content from drifting back to xcodegen ordering |

### Key Code

```bash
if grep -q 'BuildableName = "DUNEWatch.app"' "$scheme_file" \
    && grep -q 'BuildableName = "DUNEWatchUITests.xctest"' "$scheme_file"; then
    perl -0pi -e 's{(<TestAction\b[^>]*>\s*)(<TestPlans>.*?</TestPlans>\s*)(<MacroExpansion>.*?</MacroExpansion>\s*)}{$1$3$2}sg' "$scheme_file"
    perl -0pi -e 's{<TestPlanReference\s+default = "YES"\s+reference = "([^"]+)">}{<TestPlanReference\n            reference = "$1"\n            default = "YES">}sg' "$scheme_file"
fi
```

## Prevention

### Checklist Addition

- [ ] If a scheme still churns after the standard Xcode 26 attribute patch, compare the XML block ordering after `regen_project` versus an Xcode save.
- [ ] Keep watch UI scheme normalization in both regeneration and the clean filter so working tree and staged content converge.

### Rule Addition (if applicable)

No new rule was needed. The existing build pipeline rule remains correct: `xcodegen` must continue to flow through `scripts/lib/regen-project.sh`.

## Lessons Learned

- Scheme drift is not only about missing attributes; XML ordering can also be tool-version specific.
- When a generated file is committed, stabilization has to happen at both regeneration time and staging time.
- Narrow, marker-based normalization is safer than broad rewrites across every scheme file.
