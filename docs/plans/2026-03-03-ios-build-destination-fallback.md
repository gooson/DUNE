---
topic: iOS build destination fallback hardening
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/general/2026-03-01-xcodegen-scheme-perpetual-diff.md
related_brainstorms: []
---

# Implementation Plan: iOS Build Destination Fallback Hardening

## Context

GitHub Actions build job (`macos-15`, Xcode 26.2) failed with exit code 70 because `scripts/build-ios.sh` used a fixed destination (`platform=iOS Simulator,name=iPhone 17,OS=26.2`) that was not always present on runner images. The script needs environment-resilient destination resolution while preserving reproducible local overrides.

## Requirements

### Functional

- `scripts/build-ios.sh` must keep supporting explicit destination override via env var.
- If requested simulator (`name + OS`) exists, use it unchanged.
- If requested simulator is missing, auto-fallback to an available simulator UDID in matching runtime.
- If matching runtime is missing, fallback to any available iOS simulator UDID.
- If simulator services/runtimes are unavailable, fallback to `generic/platform=iOS` to avoid immediate destination mismatch failure.

### Non-functional

- Maintain script readability and deterministic selection order.
- Avoid noisy simulator errors in normal logs.
- Keep compatibility with existing CI workflow (`.github/workflows/build-ios.yml`) without additional workflow changes.

## Approach

Adopt the same destination-fallback pattern already used in `scripts/test-unit.sh`, specialized for iOS build path. Add `resolve_ios_destination()` in `scripts/build-ios.sh` and compute destination only when `DAILVE_IOS_DESTINATION` is not explicitly provided.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Keep fixed `name+OS` destination | Simple | Fails whenever runner simulator matrix changes | Rejected |
| Force `generic/platform=iOS` only | Most robust to simulator list drift | Loses simulator-specific build parity; less representative | Rejected |
| Dynamic simulator resolution + generic fallback | Balances realism and robustness; aligns with existing script patterns | Slightly more script logic | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/build-ios.sh` | Modify | Add destination resolver, env override support, fallback chain |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | Sync (generated) | Include existing `HealthKitWorkoutDetailViewModelTests.swift` in project source graph |
| `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatch*.xcscheme` | Sync (generated) | Xcode 26.2 scheme metadata normalization from regen step |

## Implementation Steps

### Step 1: Destination resolution hardening in build script

- **Files**: `scripts/build-ios.sh`
- **Changes**:
  - Add `DAILVE_IOS_DESTINATION` override handling.
  - Add `resolve_ios_destination(sim_name, sim_os)`.
  - Resolve in this order: exact requested simulator -> matching iOS runtime UDID -> any iOS runtime UDID -> `generic/platform=iOS`.
  - Suppress `simctl` stderr for cleaner CI logs.
- **Verification**:
  - `scripts/build-ios.sh` succeeds in current dev environment.
  - Log shows resolved destination as UDID or generic fallback (not hard-fail on missing `name+OS`).

### Step 2: Regenerated project artifacts sync

- **Files**: `DUNE/DUNE.xcodeproj/project.pbxproj`, `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/*.xcscheme`
- **Changes**:
  - Keep xcodegen/regen-produced project state consistent with current source/test files.
- **Verification**:
  - `git diff --stat` contains only expected script + generated project deltas.
  - Build succeeds with regenerated project.

### Step 3: Quality checks and review gate

- **Files**: N/A (verification)
- **Changes**:
  - Run build/test checks relevant to changed CI scripts/project.
  - Perform 6-perspective review and resolve findings.
- **Verification**:
  - Build passes (`scripts/build-ios.sh`).
  - Unit tests pass or environment-limited failures are captured with impact.
  - P1 findings = 0 before ship.

## Edge Cases

| Case | Handling |
|------|----------|
| Requested simulator name exists but OS runtime missing | Fallback to matching runtime UDID or any iOS UDID |
| CoreSimulator service unavailable | Skip sim-specific resolution and use `generic/platform=iOS` |
| CI runner image updates simulator matrix | Dynamic lookup continues to work without script edits |
| User provides explicit destination env var | Respect override and skip auto-resolution |

## Testing Strategy

- Unit tests: No new runtime logic unit test (bash script change); validate via command execution paths.
- Integration tests:
  - `scripts/build-ios.sh`
  - `scripts/build-ios.sh --no-regen`
- Manual verification:
  - Confirm CI log no longer fails at destination matching when named simulator is unavailable.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `simctl -j` output parsing fails unexpectedly | Low | Medium | Keep generic fallback path and graceful `|| true` handling |
| Generated project files include unrelated noise | Medium | Medium | Review diffs and keep only deterministic regen outputs |
| Generic fallback still fails due watch runtime requirements in scheme graph | Medium | Medium | Prefer simulator UDID first; generic fallback only as last resort |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The fallback approach is already proven in `test-unit.sh`, and local execution confirmed build success with UDID-based resolution. Remaining variability is primarily environment-level simulator service availability.
