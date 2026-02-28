---
tags: [xcodegen, xcscheme, xcode-26, build-script, post-processing, perpetual-diff]
category: general
date: 2026-02-28
severity: minor
related_files: [scripts/build-ios.sh]
related_solutions: [testing/2026-02-16-xcodegen-test-infrastructure]
---

# Solution: xcodegen 스킴 Xcode 26 호환 후처리

## Problem

### Symptoms

- `DUNEWatch.xcscheme`이 빌드 방법에 따라 diff 발생
- xcodegen 실행 후와 Xcode로 열었을 때 스킴 파일 내용이 달라짐
- `version`, `runPostActionsOnFailure`, `onlyGenerateCoverageForSpecifiedTargets` 속성이 왕복 변경

### Root Cause

xcodegen이 생성하는 xcscheme와 Xcode 26이 기대하는 xcscheme 사이에 3가지 차이:

1. **`version`**: xcodegen(구버전)이 `"1.3"` 생성 → Xcode 26이 `"1.7"`로 업그레이드
2. **`runPostActionsOnFailure`**: xcodegen(구버전)이 미포함 → Xcode 26이 `BuildAction`에 추가
3. **`onlyGenerateCoverageForSpecifiedTargets`**: xcodegen(구버전)이 미포함 → Xcode 26이 `TestAction`에 추가

xcodegen 2.44.1은 이 속성들을 이미 포함하지만, 다른 버전/환경에서는 누락될 수 있음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/build-ios.sh` | xcscheme 후처리 추가 | xcodegen 버전 무관하게 Xcode 26 호환 보장 |

### Key Code

```bash
# Post-process xcschemes: xcodegen generates version 1.3 without some attributes
# that Xcode 26 adds on open, causing perpetual diffs.
for SCHEME_FILE in "$PROJECT_FILE"/xcshareddata/xcschemes/*.xcscheme; do
    [ -f "$SCHEME_FILE" ] || continue
    sed -i '' 's/version = "1.3"/version = "1.7"/' "$SCHEME_FILE"
    if ! grep -q 'runPostActionsOnFailure' "$SCHEME_FILE"; then
        sed -i '' 's/buildImplicitDependencies = "YES">/buildImplicitDependencies = "YES"\
      runPostActionsOnFailure = "NO">/' "$SCHEME_FILE"
    fi
    if ! grep -q 'onlyGenerateCoverageForSpecifiedTargets' "$SCHEME_FILE"; then
        sed -i '' 's/shouldUseLaunchSchemeArgsEnv = "YES">/shouldUseLaunchSchemeArgsEnv = "YES"\
      onlyGenerateCoverageForSpecifiedTargets = "NO">/' "$SCHEME_FILE"
    fi
done
```

### 패턴 설명

- `grep -q`로 속성 존재 여부를 먼저 확인 → 이미 있으면 no-op (멱등성)
- `shouldUseLaunchSchemeArgsEnv = "YES">`는 TestAction에서만 `>`로 끝남 (ProfileAction에서는 뒤에 속성이 더 있음) → false positive 없음
- `buildImplicitDependencies = "YES">`도 BuildAction에서만 해당 패턴 → 안전

## Prevention

### Checklist Addition

- [ ] xcodegen 버전 업그레이드 시 후처리 no-op 확인 (이미 속성 포함하면 grep 체크에서 스킵)
- [ ] Xcode 메이저 버전 업그레이드 시 새로 추가되는 scheme 속성 확인

### Rule Addition (if applicable)

기존 Correction #121의 패턴 확장: `xcodegen 후 objectVersion/compatibilityVersion 후처리`에 xcscheme 후처리도 포함됨.

## Lessons Learned

- xcodegen이 생성하는 XML과 Xcode가 기대하는 XML 사이에 버전별 차이가 존재한다
- 후처리는 멱등(idempotent)해야 한다: 이미 올바른 상태이면 아무것도 변경하지 않아야 함
- `build-ios.sh` 단일 경로 원칙(Correction #95-96)이 이런 후처리를 한 곳에서 관리하게 해준다
