---
tags: [xcodegen, xcscheme, xcode-26, perpetual-diff, scheme-version, post-processing]
category: general
date: 2026-03-01
severity: minor
related_files:
  - scripts/lib/regen-project.sh
  - DUNE/DUNE.xcodeproj/xcshareddata/xcschemes/DUNEWatch.xcscheme
related_solutions: []
---

# Solution: xcodegen Scheme 파일 반복 변경 (Perpetual Diff)

## Problem

### Symptoms

- `DUNEWatch.xcscheme` 파일이 커밋 후에도 반복적으로 diff가 발생
- `version` 속성이 `"1.7"` → `"1.3"`으로 되돌아감
- `runPostActionsOnFailure = "NO"` 속성이 삭제됨
- `onlyGenerateCoverageForSpecifiedTargets = "NO"` 속성이 삭제됨

### Root Cause

xcodegen과 Xcode 26 사이의 scheme 포맷 불일치:

| 속성 | xcodegen 생성값 | Xcode 26 기대값 |
|------|-----------------|-----------------|
| `version` | `"1.3"` | `"1.7"` |
| `runPostActionsOnFailure` | 없음 | `"NO"` |
| `onlyGenerateCoverageForSpecifiedTargets` | 없음 | `"NO"` |

xcodegen을 실행하면 Xcode 26 이전 포맷의 scheme을 생성한다. Xcode 26에서 프로젝트를 열면 누락된 속성이 자동 추가되어 diff가 발생하고, xcodegen을 다시 실행하면 원래대로 되돌아가는 **무한 루프**가 발생한다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/lib/regen-project.sh` | xcodegen 실행 후 scheme 후처리 추가 | Xcode 26 포맷과 일치시킴 |

### Key Code

```bash
# regen-project.sh의 후처리 로직
for scheme_file in "$PROJECT_FILE"/xcshareddata/xcschemes/*.xcscheme; do
    [ -f "$scheme_file" ] || continue
    # version 1.3 → 1.7
    sed -i '' 's/version = "1.3"/version = "1.7"/' "$scheme_file"
    # runPostActionsOnFailure 추가
    if ! grep -q 'runPostActionsOnFailure' "$scheme_file"; then
        sed -i '' 's/buildImplicitDependencies = "YES">/buildImplicitDependencies = "YES"\
      runPostActionsOnFailure = "NO">/' "$scheme_file"
    fi
    # onlyGenerateCoverageForSpecifiedTargets 추가
    if ! grep -q 'onlyGenerateCoverageForSpecifiedTargets' "$scheme_file"; then
        sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES">/shouldUseLaunchSchemeArgsEnv = "YES"\
      onlyGenerateCoverageForSpecifiedTargets = "NO">/' "$scheme_file"
    fi
done
```

### 문제 재발 경로

다음 경우에 후처리가 누락되어 diff가 다시 발생할 수 있다:

1. **`xcodegen generate` 직접 실행** — 후처리 스크립트를 우회
2. **Xcode에서 scheme 수동 편집** — Xcode가 자체 포맷으로 덮어씀
3. **CI/CD에서 `regen-project.sh`를 거치지 않는 빌드 경로** 존재

## Prevention

### Checklist Addition

- [ ] xcodegen 실행은 반드시 `scripts/build-ios.sh` 또는 `regen-project.sh`를 통해 수행
- [ ] `xcodegen generate` 직접 실행 금지
- [ ] scheme diff 발생 시 `git checkout -- *.xcscheme`으로 되돌리고 `regen-project.sh` 재실행

### Rule Addition (if applicable)

Correction Log #121의 확장: "xcodegen 후 objectVersion/compatibilityVersion 후처리"에 scheme 후처리도 포함된 상태. 별도 규칙 추가 불필요 — 기존 프로세스 규칙(`빌드 검증은 scripts/build-ios.sh 단일 경로`)이 이미 커버.

## Lessons Learned

- xcodegen은 최신 Xcode 포맷을 즉시 따라가지 못한다. 새 Xcode 버전 업그레이드 시 scheme/pbxproj 후처리 로직 점검 필요
- 후처리가 있는 도구는 **단일 진입점**을 강제해야 우회 경로로 인한 회귀를 방지할 수 있다
- Perpetual diff의 근본 원인은 대부분 "두 도구가 같은 파일을 다른 포맷으로 쓰는 것"이다
