---
tags: [pre-commit, xcodebuild, deriveddata, build-lock, sigkill, testing]
category: testing
date: 2026-03-07
status: implemented
severity: important
related_files:
  - scripts/build-ios.sh
  - scripts/test-unit.sh
  - scripts/test-ui.sh
  - scripts/test-watch-ui.sh
  - scripts/hooks/pre-commit.sh
  - scripts/hooks/cleanup-artifacts.sh
related_solutions:
  - docs/solutions/general/2026-02-23-activity-recent-workouts-style-and-ios-build-guard.md
  - docs/solutions/testing/2026-03-03-ios-build-destination-fallback-hardening.md
---

# Solution: Pre-commit Build Resource Hardening

## Problem

pre-commit iOS build check intermittently failed before any Swift compile error surfaced.

### Symptoms

- `scripts/hooks/pre-commit.sh` removed `.xcodebuild` and `.deriveddata` before every validation run.
- `scripts/build-ios.sh` sometimes ended with `Killed: 9` while `ios-build.log` stopped mid-`SwiftCompile` without any `error:`.
- When another Xcode build reused the same `.deriveddata`, `xcodebuild` failed immediately with:
  - `error: unable to attach DB ... build.db: database is locked`
- Failure summary was often opaque because `ios-build.log` contained NUL bytes and plain `grep` treated it as binary.

### Root Cause

- pre-commit forced a cold build on every Swift/Xcode commit by deleting `.deriveddata`, which increased memory pressure and made SIGKILL more likely during large Swift compile phases.
- build/test scripts shared the same `.deriveddata` root, so concurrent `xcodebuild` runs could contend on the same `build.db`.
- failure summary parsing assumed plain-text logs, but Xcode emitted binary-safe parseable output.

## Solution

Reduced unnecessary cold builds, isolated DerivedData per script, and made log summaries binary-safe.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/hooks/cleanup-artifacts.sh` | Added `--keep-deriveddata` option | Allow cleanup without forcing cold rebuilds |
| `scripts/hooks/pre-commit.sh` | Defaulted pre-commit cleanup to keep DerivedData, with `DAILVE_PRECOMMIT_CLEAN_DERIVEDDATA=1` opt-in for full clean | Preserve build cache on normal commit validation |
| `scripts/build-ios.sh` | Moved default DerivedData to `.deriveddata/build-ios`, added `DAILVE_XCODEBUILD_JOBS` override, added binary-safe `grep -a` summaries | Avoid cross-script lock contention and improve failure visibility |
| `scripts/test-unit.sh` | Moved default DerivedData to `.deriveddata/unit-tests`, added binary-safe `grep -a` summaries | Avoid lock contention with app build script |
| `scripts/test-ui.sh` | Moved default DerivedData to `.deriveddata/ui-tests`, added binary-safe `grep -a` summaries | Avoid lock contention with other test/build flows |
| `scripts/test-watch-ui.sh` | Moved default DerivedData to `.deriveddata/watch-ui-tests`, added binary-safe `grep -a` summaries | Avoid lock contention with other test/build flows |

### Key Code

```bash
# pre-commit: keep DerivedData unless full clean is explicitly requested
cleanup_args=()
if [ "${DAILVE_PRECOMMIT_CLEAN_DERIVEDDATA:-0}" != "1" ]; then
    cleanup_args+=(--keep-deriveddata)
fi
```

```bash
# build-ios: isolate cache from tests and make binary logs readable in summaries
DERIVED_DATA_DIR="${DAILVE_BUILD_DERIVED_DATA_DIR:-.deriveddata/build-ios}"
grep -a -n -E "BUILD (SUCCEEDED|FAILED)|error:" "$LOG_FILE"
```

## Verification

- `scripts/build-ios.sh --no-regen` -> `BUILD SUCCEEDED`
- `scripts/hooks/pre-commit.sh` on staged `DUNE/project.yml`, `DUNE/DUNE.xcodeproj/project.pbxproj`, `DUNEVision/App/DUNEVisionApp.swift` -> `Pre-commit checks passed.`
- During investigation, the old shared `.deriveddata` path reproduced `build.db` lock contention; the isolated build path removed that conflict.

## Prevention

### Checklist Addition

- [ ] pre-commit should not force full DerivedData cleanup unless reproducing a cache-related issue
- [ ] build/test scripts should not share the same `DerivedData` directory
- [ ] Xcode log summaries should use binary-safe parsing (`grep -a`) before assuming logs are plain text

## Lessons Learned

- For Xcode-heavy repositories, "clean every commit" is not automatically safer; it can make validation less reliable.
- Separate cache directories are a low-cost guard against accidental concurrent `xcodebuild` collisions.
- When `xcodebuild` dies without `error:` output, distinguish "compiler error" from "process/resource failure" first.
