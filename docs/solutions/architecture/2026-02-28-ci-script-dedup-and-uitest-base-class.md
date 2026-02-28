---
tags: [ci, github-actions, xcodegen, bash, dry, uitest, xctest, base-class]
category: architecture
date: 2026-02-28
severity: important
related_files:
  - scripts/lib/regen-project.sh
  - scripts/build-ios.sh
  - scripts/test-unit.sh
  - scripts/test-ui.sh
  - .github/workflows/build-ios.yml
  - .github/workflows/test-unit.yml
  - .github/workflows/test-ui.yml
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - testing/2026-02-28-xcodegen-scheme-perpetual-diff.md
---

# Solution: CI 스크립트 xcodegen 중복 제거 + UI Test Base Class 추출

## Problem

### Symptoms

- 3개 CI 스크립트(build-ios.sh, test-unit.sh, test-ui.sh)에 xcodegen + pbxproj 후처리 로직이 복붙
- 3개 UI 테스트 파일에 동일한 `setUpWithError()` 패턴 복붙
- 스크립트 간 환경변수 네이밍 불일치 (`DAILVE_IOS_DESTINATION` vs `DAILVE_IOS_SIMULATOR`)
- workflow paths 필터가 `scripts/**` 전체를 감시 (불필요한 CI 실행)
- `continue-on-error: true`가 실제 UI 테스트 실패를 마스킹

### Root Cause

빠르게 CI를 추가하면서 기존 스크립트를 복사-붙여넣기로 생성. 리뷰 없이 머지하여 중복과 불일치 누적.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/lib/regen-project.sh` | xcodegen regen + pbxproj + xcscheme 후처리를 `regen_project()` 함수로 추출 | 단일 소스 유지 |
| `scripts/build-ios.sh` | `source lib/regen-project.sh` + `regen_project` 호출 | 중복 제거 |
| `scripts/test-unit.sh` | 동일 | 중복 제거 |
| `scripts/test-ui.sh` | 동일 | 중복 제거 |
| 3개 스크립트 | 환경변수를 `DUNE_SIM_NAME` / `DUNE_SIM_OS`로 통일 | 일관성 |
| 3개 workflow yml | paths를 `scripts/lib/**` + 해당 스크립트만 지정 | 정밀 트리거 |
| `test-ui.yml` | `continue-on-error: true` 제거, `if: always()` 유지 | 실패 가시성 |
| `UITestHelpers.swift` | `BaseUITestCase` 클래스 추가 | setUp 중복 제거 |
| 3개 UI 테스트 파일 | `XCTestCase` -> `BaseUITestCase` 상속 | setUp 제거 |
| `UITestHelpers.swift` | 도달 불가능한 "Don't Allow" 분기 제거 | Dead code |

### Key Code

```bash
# scripts/lib/regen-project.sh (sourced, not executed)
regen_project() {
    if [[ "$REGENERATE" -eq 1 || ! -d "$PROJECT_FILE" ]]; then
        xcodegen generate --spec "$PROJECT_SPEC"
        # pbxproj + xcscheme post-processing
    fi
}
```

```swift
// BaseUITestCase — shared setUp for all UI tests
@MainActor
class BaseUITestCase: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        addSystemPermissionMonitor()
        app.launch()
    }
}
```

## Prevention

### Checklist Addition

- [ ] 새 CI 스크립트 추가 시: xcodegen 로직은 `scripts/lib/regen-project.sh` 소싱
- [ ] 새 UI 테스트 파일 추가 시: `BaseUITestCase` 상속
- [ ] workflow paths 필터: 해당 스크립트만 명시 (`scripts/**` 전체 감시 금지)
- [ ] `continue-on-error: true`는 known flaky 스텝에만 사용, 주석으로 사유 명시

### Rule Addition (if applicable)

CLAUDE.md Correction Log 항목 추가 대상:
- CI 스크립트 xcodegen 로직은 `scripts/lib/regen-project.sh` 단일 소스
- workflow paths에 `scripts/**` 대신 개별 스크립트 경로 지정

## Lessons Learned

1. **CI 스크립트도 DRY 원칙 적용**: "동일 로직 3곳+ 즉시 추출" 규칙은 bash 스크립트에도 해당
2. **paths 필터는 정밀하게**: `scripts/**`는 빌드 스크립트 변경으로 UI 테스트를 트리거하는 등 의도치 않은 CI 실행 유발
3. **continue-on-error 남용 주의**: 임시 우회책이 영구 설정으로 굳어지면 실패를 놓침
4. **XCTestCase 상속으로 setUp 통합**: BaseClass 패턴이 3+ 테스트 파일에서 효과적
