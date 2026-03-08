---
topic: DUNEWatchUITests xcscheme stability
date: 2026-03-09
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-01-xcodegen-scheme-perpetual-diff.md
  - docs/solutions/general/2026-02-28-xcodegen-scheme-perpetual-diff.md
related_brainstorms: []
---

# Implementation Plan: DUNEWatchUITests xcscheme stability

## Context

`DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme` keeps flipping after project regeneration. The current stabilization layer only adds missing Xcode 26 attributes, but it does not normalize the watch UI test scheme ordering that Xcode rewrites.

## Requirements

### Functional

- Keep `DUNEWatchUITests.xcscheme` stable after `regen_project`.
- Preserve the tracked Xcode-style ordering for the watch UI test scheme.
- Apply the same normalization in the git clean filter so staged output stays canonical.

### Non-functional

- Keep the normalization idempotent.
- Avoid touching unrelated schemes unless required.
- Verify with the repo-approved regeneration path rather than direct `xcodegen`.

## Approach

Extend the existing scheme post-processing to normalize the watch UI test scheme block ordering after regeneration. Mirror the same canonicalization in `scripts/lib/xcscheme-clean-filter.sh` so the working tree and staged content converge to one format.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Patch `project.yml` only | Keeps source of truth in one place | xcodegen still emits the unstable XML ordering | Rejected |
| Ignore the diff via git attributes | Hides the symptom in commits | Working tree still churns after regeneration | Rejected |
| Post-process the generated scheme | Works with current xcodegen output and Xcode format drift | Requires careful text normalization | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/lib/regen-project.sh` | code | Canonicalize the watch UI test scheme after regeneration |
| `scripts/lib/xcscheme-clean-filter.sh` | code | Apply the same canonicalization during staging |
| `docs/plans/2026-03-09-dunewatch-ui-scheme-stability.md` | docs | Record the implementation plan |
| `docs/solutions/general/2026-03-09-dunewatch-ui-scheme-stability.md` | docs | Record root cause and prevention after the fix |

## Implementation Steps

### Step 1: Capture the unstable delta

- **Files**: `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme`, `scripts/lib/regen-project.sh`
- **Changes**: Reproduce the diff through `regen_project`, then define the exact XML ordering that must be preserved.
- **Verification**: `git diff -- DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme`

### Step 2: Normalize regeneration output

- **Files**: `scripts/lib/regen-project.sh`
- **Changes**: Extend scheme normalization to rewrite the watch UI test scheme into the tracked canonical layout.
- **Verification**: rerun `regen_project`, then confirm the scheme no longer changes.

### Step 3: Align staged normalization

- **Files**: `scripts/lib/xcscheme-clean-filter.sh`
- **Changes**: Mirror the same canonicalization so staged content matches regeneration output.
- **Verification**: restage or re-clean the scheme file and confirm no new diff appears.

## Edge Cases

| Case | Handling |
|------|----------|
| Scheme already in canonical form | Normalization must be a no-op |
| Other schemes without watch UI markers | Leave untouched |
| xcodegen output changes again in a future Xcode version | Keep the normalization isolated and documented for future extension |

## Testing Strategy

- Unit tests: none; shell normalization is verified through deterministic file diffs.
- Integration tests: run `regen_project` through the repo script path and ensure `git diff` is empty for the watch UI scheme.
- Manual verification: inspect the resulting XML block ordering in the scheme file.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Regex-based rewrite catches unintended scheme content | Low | Medium | Gate the rewrite on watch UI scheme markers |
| Only regen path is fixed but staging still drifts | Medium | Medium | Update the clean filter in the same change |
| Future Xcode format adds more ordering changes | Medium | Low | Document the exact root cause and extension point |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The repro is deterministic and localized to the existing scheme post-processing layer.
