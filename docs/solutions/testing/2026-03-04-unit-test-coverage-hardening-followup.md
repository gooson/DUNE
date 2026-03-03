---
tags: [testing, watchconnectivity, localization, swift-testing, regression]
category: testing
date: 2026-03-04
severity: important
related_files:
  - DUNETests/DomainModelCoverageTests.swift
  - DUNETests/WatchWorkoutUpdateValidationTests.swift
  - DUNETests/ParsedWatchIncomingMessageTests.swift
  - DUNETests/DashboardViewModelTests.swift
  - DUNETests/HealthMetricTests.swift
  - DUNETests/ExerciseViewModelTests.swift
  - DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift
related_solutions:
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/testing/2026-03-02-locale-safe-validation-format-tests.md
  - docs/solutions/testing/2026-03-01-date-sensitive-test-boundary.md
---

# Solution: Unit Test Coverage Hardening + Locale-Safe Gate Recovery

## Problem

도메인/WatchConnectivity 경계에 테스트 공백이 남아 있었고, 전체 iOS 유닛 게이트는 로케일 고정 기대값으로 인해 반복 실패했다.

### Symptoms

- `WatchWorkoutUpdate` 검증 분기(`rpe`, `restDuration`, HR 경계) 커버리지 부족
- `ParsedWatchIncomingMessage`의 `requestWorkoutTemplateSync` 플래그 미검증
- 전체 유닛 테스트에서 다국어 환경 기준 문자열 mismatch 발생
- `TemplateWorkoutViewModel`에서 모든 운동 skip 시 `isAllDone == false` 회귀

### Root Cause

- 모델/DTO 레벨 테스트는 광범위했지만 일부 신규 경계값 분기 케이스가 누락됨
- 테스트 assertion이 영어 고정 문자열을 직접 비교하고 있었음
- skip 후 다음 인덱스 탐색이 `skipped` 상태를 다시 `inProgress`로 되돌리는 로직을 포함함

## Solution

테스트 커버리지를 모델/검증/파서 단위로 보강하고, 로케일 독립 assertion으로 정리했다.  
동시에 skip 탐색 로직을 `pending`만 대상으로 제한해 상태 회귀를 제거했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/DomainModelCoverageTests.swift` | 신규 suite 추가 | Domain/Watch 모델의 ID/Comparable/Codable/Hashable 규칙 보강 |
| `DUNETests/WatchWorkoutUpdateValidationTests.swift` | 경계 테스트 추가 | `rpe`, duration/rest, HR 범위 필터 분기 커버 |
| `DUNETests/ParsedWatchIncomingMessageTests.swift` | 플래그 테스트 추가 | `requestWorkoutTemplateSync` 파싱 보장 |
| `DUNETests/DashboardViewModelTests.swift` | locale-safe assertion 적용 | 다국어 환경에서 walking card title/unit 안정화 |
| `DUNETests/HealthMetricTests.swift` | 로케일 의존 문자열 비교 제거 | `formattedValue`, relative/freshness label 안정화 |
| `DUNETests/ExerciseViewModelTests.swift` | duration assertion 완화 | locale별 단위 텍스트 차이 제거 |
| `DUNE/Presentation/Exercise/TemplateWorkoutViewModel.swift` | 탐색 로직 수정 | skip 완료 후 상태가 되돌아가던 회귀 제거 |

### Key Code

```swift
private func findNextPendingIndex(after index: Int) -> Int? {
    for i in (index + 1)..<config.exercises.count {
        if exerciseStatuses[i] == .pending { return i }
    }
    for i in 0..<index {
        if exerciseStatuses[i] == .pending { return i }
    }
    return nil
}
```

## Prevention

### Checklist Addition

- [ ] 사용자 노출 텍스트 테스트는 영어 하드코딩 대신 locale-safe 비교를 사용한다.
- [ ] Watch 입력 검증 로직 변경 시 경계값(최소/최대/초과/미만) 케이스를 함께 추가한다.
- [ ] 상태 전이 로직(`pending/inProgress/completed/skipped`)은 “종료 조건” 테스트를 항상 포함한다.

### Rule Addition (if applicable)

기존 `2026-03-02-locale-safe-validation-format-tests` 패턴을 재사용했으므로 새 rule 추가는 보류한다.

## Lessons Learned

테스트 커버리지는 파일 수보다 “분기의 종료 조건”을 얼마나 명확히 고정하는지가 중요하다.  
특히 다국어 앱에서는 assertion을 문자열 literal이 아니라 로직/포맷 함수 기준으로 검증해야 CI 안정성이 유지된다.
