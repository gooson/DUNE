---
tags: [workout, intensity, validation, swiftui, set-input]
category: general
date: 2026-03-02
severity: important
related_files:
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift
  - DUNE/Presentation/Exercise/Components/SetRowView.swift
  - DUNE/Presentation/Exercise/CompoundWorkoutView.swift
  - DUNETests/WorkoutSessionViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-auto-workout-intensity-patterns.md
---

# Solution: Workout Manual Intensity Input for All Exercise Types

## Problem

세트 단위 수동 강도(`intensity`, 1-10) 입력 UI가 `durationIntensity` 타입에서만 노출되고 있었다.
사용자는 모든 운동 타입에서 강도를 입력할 수 있어야 하는데, 현재 구조상 타입별 분기 UI 때문에 접근 불가였다.

### Symptoms

- 단일 운동 세션에서 유연성(`durationIntensity`) 외 타입은 강도 입력 칸이 보이지 않음
- 컴파운드 세트 행에서도 강도 칸이 `durationIntensity`에만 노출됨

### Root Cause

- `WorkoutSessionView`와 `SetRowView`의 input type 분기에서 intensity 필드를 `durationIntensity` 케이스에만 배치
- `createValidatedRecord()`의 intensity 범위 검증도 동일하게 `durationIntensity` 조건으로 제한

## Solution

UI 노출 범위를 모든 input type으로 확장하고, intensity 검증을 공통 로직으로 통합했다.
또한 이전 세트 프리필 시 intensity를 복사하되, 범위 밖 값은 무시하도록 방어 로직을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutSessionView.swift` | 모든 입력 타입 UI에 `INTENSITY` stepper 추가 + 공통 helper 추출 | 단일 운동 플로우에서 전 타입 강도 입력 지원 |
| `SetRowView.swift` | `setsRepsWeight`, `setsReps`, `durationDistance`, `roundsBased`에 intensity 필드 추가 | 컴파운드 세트 행에서도 동일 기능 지원 |
| `CompoundWorkoutView.swift` | 컬럼 헤더에 `INT` 추가 | 입력 필드와 헤더 정합성 유지 |
| `WorkoutSessionViewModel.swift` | intensity 검증을 타입 무관 공통 처리 + previous set intensity 프리필(범위 검사 포함) | 저장 일관성 및 이상치 방어 |
| `WorkoutSessionViewModelTests.swift` | 강도 검증/저장/프리필 테스트 추가 | 회귀 방지 |

### Key Code

```swift
let trimmedIntensity = set.intensity.trimmingCharacters(in: .whitespaces)
if !trimmedIntensity.isEmpty {
    guard let val = Int(trimmedIntensity), val >= 1, val <= maxIntensity else {
        validationError = String(localized: "Intensity must be between 1 and \(maxIntensity)")
        return nil
    }
}
```

## Prevention

타입별 입력 분기를 추가/수정할 때 공통 필드(`intensity`)가 특정 케이스에만 묶이지 않도록 체크리스트를 추가한다.

### Checklist Addition

- [ ] `ExerciseInputType`별 UI 분기 변경 시 공통 필드(`intensity`, `memo` 등) 누락 여부 점검
- [ ] 타입별 조건 검증 로직에 공통 필드 검증이 중복/누락되지 않는지 확인
- [ ] previous set 프리필 시 값 범위 방어(`1...10`) 적용 여부 확인

### Rule Addition (if applicable)

새 규칙 파일 추가는 불필요. 기존 `input-validation.md`와 `testing-required.md` 범위 내에서 해결됨.

## Lessons Learned

`@Model` 필드가 공통이어도 SwiftUI 분기 UI에서 특정 타입에만 노출되면 기능이 사실상 제한된다.
공통 데이터 필드는 UI/검증/프리필 세 경로를 함께 점검해야 요구사항을 완전히 만족시킬 수 있다.
