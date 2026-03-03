---
tags: [ui-test, smoke-test, viewmodel-test, accessibilityidentifier, localization-safe, coverage]
category: testing
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Life/HabitFormSheet.swift
  - DUNE/Presentation/Injury/InjuryFormSheet.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/ActivitySmokeTests.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - DUNEUITests/Smoke/LifeSmokeTests.swift
  - DUNEUITests/Smoke/SettingsSmokeTests.swift
  - DUNEUITests/Smoke/WellnessSmokeTests.swift
  - DUNETests/SleepViewModelTests.swift
  - DUNETests/ConsistencyDetailViewModelTests.swift
  - DUNETests/ExerciseMixDetailViewModelTests.swift
  - DUNETests/ExerciseTypeDetailViewModelTests.swift
  - DUNETests/PersonalRecordsDetailViewModelTests.swift
  - DUNETests/TrainingReadinessDetailViewModelTests.swift
  - DUNETests/TrainingVolumeViewModelTests.swift
  - DUNETests/WeeklyStatsDetailViewModelTests.swift
  - DUNETests/AllDataViewModelTests.swift
related_solutions:
  - docs/solutions/testing/2026-03-02-nightly-full-ui-test-hardening.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
  - docs/solutions/testing/ui-test-infrastructure-design.md
---

# Solution: UI Test 최대 보강 + Locale-safe AXID 안정화

## Problem

기존 테스트는 탭별 smoke 검증 중심이어서 상세 화면군 ViewModel 공백이 남아 있었고, 일부 UI 절차 검증은 문자열 selector 의존으로 로케일/카피 변경에 취약했다.

### Symptoms

- Activity 상세 화면군 일부 ViewModel 테스트 파일이 누락됨
- 주요 폼 절차(열기/취소/유효성/전환) UI 회귀 검증 부족
- UI 테스트가 특정 문자열(예: `Weekly`, `Read All`, `Recovered`)에 의존

### Root Cause

- 초기 smoke 테스트가 "화면 렌더링 확인"에 초점을 두어 절차 단위 검증이 얕았음
- 새 UI 요소 추가 시 AXID를 선반영하지 않아 테스트가 label selector로 우회됨
- 상세 ViewModel 추가 시 테스트 동반 생성이 일부 누락됨

## Solution

누락 ViewModel 테스트를 일괄 추가하고, 탭별 smoke 테스트를 사용자 절차 중심으로 확장했다. 동시에 폼/허브 액션에 AXID를 추가하여 문자열 selector 의존을 제거했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/*ViewModelTests.swift` (9 files) | 신규 테스트 스위트 추가 | 누락된 상세 ViewModel 회귀 방어 |
| `DUNEUITests/Smoke/*.swift` | 절차 테스트(진입/취소/유효성/탐색) 추가 | 전 화면 절차 커버 확장 |
| `HabitFormSheet.swift` | save/cancel + frequency segment AXID 부여 | 폼 상호작용 selector 안정화 |
| `InjuryFormSheet.swift` | recovered toggle AXID 부여 | 문자열 toggle selector 제거 |
| `NotificationHubView.swift` | read-all 버튼 AXID 부여 | 허브 액션 selector 안정화 |
| `UITestHelpers.swift` | 신규 AXID 상수 추가 | 하드코딩 제거, 중앙 관리 |

### Key Code

```swift
// Example: locale-safe selector replacement
let weeklySegment = app.descendants(matching: .any)[AXID.habitFormFrequencyWeekly].firstMatch
XCTAssertTrue(weeklySegment.waitForExistence(timeout: 3))
weeklySegment.tap()
```

## Prevention

### Checklist Addition

- [ ] 새 UI 액션 버튼/토글/세그먼트 추가 시 AXID를 구현과 동시에 추가했는가?
- [ ] 새 상세 ViewModel 추가 시 대응 `DUNETests/{ViewModel}Tests.swift`를 함께 만들었는가?
- [ ] UI 테스트가 사용자 노출 문자열 대신 AXID selector를 우선 사용하는가?
- [ ] UI runtime이 불안정한 환경에서도 최소 `build-for-testing` 게이트를 유지하는가?

### Rule Addition (if applicable)

기존 testing/UI 인프라 규칙으로 충분하여 신규 rule 파일은 추가하지 않았다.

## Lessons Learned

- 커버리지 확장은 "파일 수"보다 "사용자 절차 단위 검증"이 회귀 탐지 효율이 높다.
- AXID 누락은 빠르게 문자열 selector 의존으로 이어지므로 UI 구현 시점에 선제 반영이 가장 저렴하다.
- 시뮬레이터 상태가 불안정할 때는 runtime 테스트만 고집하지 않고 build-for-testing을 병행해야 파이프라인 신뢰도를 유지할 수 있다.
