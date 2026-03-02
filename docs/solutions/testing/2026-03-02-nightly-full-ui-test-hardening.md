---
tags: [ui-test, ci, nightly, regression, accessibility]
date: 2026-03-02
category: solution
status: implemented
---

# Solution: Nightly Full UI Test 자동화 + Selector 안정성 강화

## Problem

- UI 테스트가 PR 머지 시점에만 실행되어, 일일 회귀 감시가 부족했다.
- 일부 smoke 테스트가 화면 텍스트에 의존해 copy/localization 변경 시 취약했다.
- teardown의 `Thread.sleep()`가 테스트 시간을 불필요하게 늘리고 안정성을 저하시켰다.

## Solution

### 1. Nightly Full UI Test Workflow 추가

- 파일: `.github/workflows/test-ui-nightly.yml`
- 매일 `04:00 KST`(= `19:00 UTC`) 스케줄 실행
- 수동 실행(`workflow_dispatch`) 지원
- 실패/성공과 무관하게 nightly 로그 artifact 업로드
- manual 성격의 `HealthKitPermissionUITests`는 nightly에서도 명시적으로 skip

### 2. UI Test Runner 스크립트 확장

- 파일: `scripts/test-ui.sh`
- 옵션 추가:
  - `--only-testing <target>` (복수 가능)
  - `--test-plan <name>`
- 기본 동작은 기존과 동일하게 `-only-testing DUNEUITests`
- `-parallel-testing-enabled NO`로 UI test 병렬 실행 비활성화 (flaky 완화)

### 3. AXID 기반 테스트로 전환

- 앱 코드에 접근성 식별자 추가:
  - `wellness-menu-body-record`
  - `wellness-menu-injury`
  - `picker-cancel-button`
  - `picker-root-list`
  - `settings-row-resttime`
  - `settings-section-appearance`
  - `settings-row-icloud-sync`
  - `settings-row-location-access`
  - `settings-row-version`

- UI 테스트 코드 변경:
  - Activity/Wellness/Settings smoke tests에서 문자열 기반 selector를 AXID 기반으로 전환
  - `guard ... else { return }` 형태를 assertion 중심으로 변경해 false pass 방지

### 4. sleep 기반 대기 제거

- 파일:
  - `DUNEUITests/Helpers/UITestBaseCase.swift`
  - `DUNEUITests/Launch/LaunchScreenTests.swift`
- `Thread.sleep()` 제거 후 `app.wait(for: .notRunning, timeout:)` 사용

## Prevention

- 새 UI 요소에 대한 테스트 추가 시 우선 AXID를 부여하고 테스트에서 문자열 selector 사용을 지양한다.
- 자동 회귀 범위는 nightly workflow를 기준으로 유지하고, manual 성격 테스트는 gating한다.
- UI 테스트 runner의 실행 모드(only-testing/test-plan)는 스크립트 옵션으로 통일한다.

## Files

| File | Change |
|------|--------|
| `.github/workflows/test-ui-nightly.yml` | nightly full UI test 자동 실행 workflow 추가 |
| `scripts/test-ui.sh` | only-testing/test-plan 옵션 추가, 병렬 테스트 비활성화 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | picker AXID 추가 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | menu action AXID 추가 |
| `DUNE/Presentation/Settings/SettingsView.swift` | settings rows/section AXID 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | 신규 AXID 상수 추가 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | picker open/dismiss 검증 강화 |
| `DUNEUITests/Smoke/WellnessSmokeTests.swift` | menu/form 검증 AXID 전환 + assertion 강화 |
| `DUNEUITests/Smoke/LifeSmokeTests.swift` | cancel/assertion 강화 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | settings 검증 AXID 전환 |
| `DUNEUITests/Helpers/UITestBaseCase.swift` | sleep 제거 |
| `DUNEUITests/Launch/LaunchScreenTests.swift` | sleep 제거 |
