---
tags: [pre-commit, xcodebuild, incremental-build, build-for-testing, validation-time]
category: general
date: 2026-03-07
severity: important
related_files:
  - scripts/hooks/pre-commit.sh
  - scripts/build-target.sh
  - scripts/build-ios.sh
related_solutions:
  - docs/solutions/general/2026-02-23-activity-recent-workouts-style-and-ios-build-guard.md
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
---

# Solution: Pre-commit Build Fast Gate

## Problem

pre-commit 훅이 Swift/Xcode 관련 staged 변경마다 전체 앱 빌드를 강제하면서, 시작 전에 `.deriveddata` 와 `.xcodebuild` 를 삭제해 반복 커밋의 증분 빌드 이점을 완전히 잃고 있었다.

### Symptoms

- 작은 테스트 수정만 해도 pre-commit 에서 전체 `scripts/build-ios.sh --no-regen` 이 실행됐다.
- hook 시작 시 build artifact 를 지워 매번 cold build 가 발생했다.
- `DUNETests`, `DUNEWatchTests`, `DUNEUITests`, `DUNEWatchUITests` 전용 변경도 앱 전체 빌드 비용을 냈다.

### Root Cause

pre-commit 가 staged 변경의 영향 범위를 구분하지 않고 단일 full build 경로만 사용했다. 동시에 자동 cleanup 이 `.deriveddata` 를 삭제해 incremental compilation cache 를 매번 버리고 있었다.

## Solution

pre-commit 을 path-aware fast gate 로 바꾸고, test-only 변경은 스킴별 `build-for-testing` compile gate 로 축소했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/hooks/pre-commit.sh` | staged 파일 목록을 한 번 수집하고 full build vs targeted compile 로 분기 | 변경 영향에 맞는 최소 검증만 수행 |
| `scripts/hooks/pre-commit.sh` | `cleanup-artifacts.sh` 자동 호출 제거 | incremental build cache 보존 |
| `scripts/build-target.sh` | 스킴/플랫폼별 `build-for-testing` 공용 스크립트 추가 | test-only 변경을 빠르게 컴파일 검증 |
| `scripts/build-ios.sh` | `DAILVE_FAST_LOCAL_BUILD=1` 일 때 `ONLY_ACTIVE_ARCH=YES`, `COMPILER_INDEX_STORE_ENABLE=NO` 적용 | pre-commit 전용 local fast build 지원 |

### Key Code

```bash
# scripts/hooks/pre-commit.sh
if has_staged_match "^DUNETests/.*\\.(swift|plist)$"; then
    append_unique_target "DUNETests ios"
fi

DAILVE_FAST_LOCAL_BUILD=1 "$ROOT_DIR/scripts/build-target.sh" \
    --scheme "$scheme" \
    --platform "$platform" \
    --build-for-testing \
    --no-regen
```

## Prevention

pre-commit 검증은 "항상 전체 빌드"가 아니라 "빠른 결정에 필요한 최소 compile gate"를 우선해야 한다.

### Checklist Addition

- [ ] pre-commit 이 `.deriveddata` 를 자동 삭제하지 않는지 확인
- [ ] test-only 변경은 대응 스킴의 `build-for-testing` 으로 검증되는지 확인
- [ ] `DUNE/project.yml` 변경 시 regen 이 포함된 full build 로 승격되는지 확인

### Rule Addition (if applicable)

신규 rule 파일은 추가하지 않았다. 기존 build 단일 진입점 규칙은 유지하고, pre-commit 에서만 fast local build 옵션을 얹는 형태로 정리했다.

## Lessons Learned

validation time 은 build 자체보다 "어떤 변경에 어떤 게이트를 적용하는가"와 cache 를 보존하는가에 더 크게 좌우된다. pre-commit 은 전체 회귀를 대체하는 단계가 아니라, 커밋 직전 빠른 안전 신호를 주는 단계여야 한다.
