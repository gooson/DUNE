---
tags: [ios, ci, xcodebuild, simulator, destination-fallback, xcodegen]
category: testing
date: 2026-03-03
severity: important
related_files:
  - scripts/build-ios.sh
  - DUNE/DUNE.xcodeproj/project.pbxproj
  - DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatch.xcscheme
  - DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchTests.xcscheme
  - DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatchUITests.xcscheme
related_solutions:
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/general/2026-03-01-xcodegen-scheme-perpetual-diff.md
---

# Solution: iOS Build Destination Fallback Hardening

## Problem

CI `Build iOS` job failed with exit code 70 because `scripts/build-ios.sh` required a fixed simulator destination (`name=iPhone 17, OS=26.2`). When runner images changed simulator inventory, `xcodebuild` failed before compilation.

### Symptoms

- GitHub Actions `build-ios` failed with:
  - `xcodebuild: error: Unable to find a device matching the provided destination specifier`
- Failure happened in destination resolution stage, not in app compile/link stages.

### Root Cause

- Build script used a hardcoded simulator name+OS pair without fallback.
- CI runner simulator availability is image-dependent and may not match fixed values.

## Solution

Added resilient destination resolution to `scripts/build-ios.sh` while preserving explicit env override.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/build-ios.sh` | Added `DAILVE_IOS_DESTINATION` override + `resolve_ios_destination()` fallback chain | Prevent destination mismatch failures across CI/local environments |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | Synced generated project entries for `HealthKitWorkoutDetailViewModelTests.swift` | Keep generated project graph consistent with existing test source |
| `DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatch*.xcscheme` | Synced Xcode 26.2 scheme metadata deltas from regen step | Keep xcodegen output stable and reproducible |

### Key Code

```bash
resolve_ios_destination() {
  # 1) exact name+runtime match
  # 2) any simulator in requested iOS runtime
  # 3) any available iOS simulator
  # 4) final fallback: generic/platform=iOS
}
```

## Verification

- `scripts/build-ios.sh` (with regen): `BUILD SUCCEEDED`
- `scripts/build-ios.sh --no-regen`: `BUILD SUCCEEDED`
- `scripts/test-unit.sh`: environment-limited failure on local CoreSimulator service (`Connection refused` / `simdiskimaged`) and not attributable to the script change.

## Prevention

### Checklist Addition

- [ ] CI script destination must support simulator fallback (exact -> runtime -> platform generic)
- [ ] Prefer `-j` JSON parsing over fragile text-grep runtime detection
- [ ] Keep explicit destination env override for incident response

### Rule Addition (if applicable)

No new global rule added. Existing `scripts/build-ios.sh` single-entry build policy remains valid; fallback behavior is now aligned with `scripts/test-unit.sh` hardening pattern.

## Lessons Learned

- Simulator inventory drift is a normal CI condition, not an exceptional case.
- Destination selection must be dynamic for runner resilience, while still allowing deterministic override for debugging.
- Regenerated `.xcodeproj`/scheme deltas should be treated as first-class artifacts and reviewed together with script changes.
