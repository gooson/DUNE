---
tags: [swift, validation, empty-string, race-condition, cloudkit, inverse-relationship, overflow, trimming, swiftdata]
category: general
date: 2026-02-17
severity: critical
related_files:
  - Dailve/Presentation/Exercise/WorkoutSessionViewModel.swift
  - Dailve/Presentation/Exercise/RestTimerViewModel.swift
  - Dailve/Domain/UseCases/CalorieEstimationService.swift
  - Dailve/Presentation/Shared/Extensions/WorkoutSet+Summary.swift
related_solutions:
  - 2026-02-17-cloudkit-optional-relationship.md
  - 2026-02-17-activity-tab-review-patterns.md
---

# Solution: 2차 리뷰 입력 검증 강화 및 레이스 컨디션 수정

## Problem

6관점 2차 리뷰에서 8건의 P1 이슈가 발견됨. 중복 제거 후 5건의 고유 문제로 정리.

### Symptoms

1. 빈 문자열 `""` → `Int("")` = nil이 validation을 bypass하여 nil 값이 WorkoutSet에 저장됨
2. `sets.filter(\.isCompleted)`가 body 내 3+회 반복 호출되어 불필요한 재계산 발생
3. `Int(set.duration) * 60`에서 극단적 값 입력 시 overflow 가능
4. `isSaving = true; defer { isSaving = false }`가 record 반환 전에 리셋되어 중복 저장 가능
5. CloudKit에서 inverse relationship이 명시적으로 설정되지 않아 orphan record 가능성

### Root Cause

- **빈 문자열**: Swift의 `Int("")`은 nil 반환 — `if !set.reps.isEmpty` 체크가 whitespace-only 문자열을 통과시킴
- **반복 filter**: SwiftUI body 평가 시 computed property가 매번 재계산됨
- **overflow**: `Int` 곱셈은 Swift에서 기본적으로 trap하지만 검증 범위 밖 값이 들어올 수 있음
- **isSaving**: `defer`는 함수 scope 종료 시 실행 — record 반환 후 caller가 insert하기 전에 리셋됨
- **inverse relationship**: SwiftData가 자동 처리하지만 CloudKit sync 시 타이밍 이슈 가능

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WorkoutSessionViewModel | `cachedCompletedSets` 캐싱 도입 | filter 3회→1회 |
| WorkoutSessionViewModel | `.trimmingCharacters(in: .whitespaces)` + `!trimmed.isEmpty` | 빈 문자열/공백 bypass 차단 |
| WorkoutSessionViewModel | `secs / 60 == mins` overflow guard | 곱셈 overflow 방지 |
| WorkoutSessionViewModel | `defer` 제거, record 반환 직전에 `isSaving = false` | race condition 수정 |
| WorkoutSessionViewModel | `workoutSet.exerciseRecord = record` | 명시적 inverse relationship |
| RestTimerViewModel | `try await Task.sleep` → `do/catch` | sleep 중단 시 안전 종료 |
| CalorieEstimationService | MET/weight/duration 도메인 범위 검증 | 비현실적 값 차단 |
| WorkoutSet+Summary | `formatSetSummary` 공통 함수 추출 | DRY 위반 해소 |

### Key Code

```swift
// 1. Empty string validation pattern
let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else {
    validationError = "Reps must be between 1 and \(maxReps)"
    return nil
}

// 2. Duration overflow guard
let durationSeconds: TimeInterval? = Int(trimmedDuration).flatMap { mins in
    let secs = mins * 60
    guard secs / 60 == mins else { return nil } // overflow check
    return TimeInterval(secs)
}

// 3. Explicit inverse relationship
workoutSet.exerciseRecord = record  // Before adding to array

// 4. isSaving without defer
isSaving = true
// ... create record ...
isSaving = false  // Reset just before return, not via defer
return record

// 5. Domain range validation
guard metValue > 0, metValue < 30,
      bodyWeightKg > 0, bodyWeightKg < 500,
      durationSeconds > 0, durationSeconds < 28800 else { return nil }
```

## Prevention

### Checklist Addition

- [ ] 문자열→숫자 변환 전 `trimmingCharacters` + `isEmpty` 체크 필수
- [ ] SwiftUI body 내 `.filter()` 호출 횟수 확인 — 2회 이상이면 캐싱
- [ ] `defer`로 상태 플래그 리셋 시 caller에게 반환된 후 타이밍 검토
- [ ] CloudKit 사용 시 inverse relationship 명시적 설정
- [ ] 도메인 서비스의 입력 범위를 물리적/의학적 한계로 제한

### Rule Addition

`.claude/rules/input-validation.md`에 다음 추가 필요:
- 문자열→숫자 변환 시 `.trimmingCharacters(in: .whitespaces)` 필수
- `defer`로 isSaving 리셋 금지 — 반환값이 있는 함수에서는 명시적 리셋

## Lessons Learned

1. **빈 문자열은 nil이 아니다**: `Int("")`은 Swift에서 nil을 반환하므로 optional binding이 실패하지만, validation 분기에서 "비어있으면 skip"하는 패턴이 이를 우회시킴. 항상 trim 후 isEmpty를 먼저 체크할 것.

2. **`defer`는 scope 종료 시 실행**: record를 반환하고 caller가 insert하기 전에 isSaving이 false로 돌아가면 중복 탭 방지가 무력화됨. 비동기 작업의 시작/종료 제어에 defer는 부적합.

3. **SwiftData inverse relationship은 "보통" 자동**: 그러나 CloudKit sync는 별도 경로를 사용하므로 명시적 설정이 안전. 방어적 프로그래밍 원칙 적용.

4. **도메인 서비스도 입력 검증이 필요**: caller의 검증을 신뢰하지 말 것. CalorieEstimationService처럼 독립적으로 사용될 수 있는 서비스는 자체 도메인 범위 검증 필수.

5. **6관점 리뷰는 2차까지 돌려야 함**: 1차 리뷰에서 수정한 코드에 새로운 이슈가 유입될 수 있음. 특히 validation 로직은 변경 시 regression 위험 높음.
