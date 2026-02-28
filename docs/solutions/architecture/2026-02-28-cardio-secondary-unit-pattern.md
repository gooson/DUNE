---
tags: [cardio, exercise, unit-conversion, input-type, domain-model]
date: 2026-02-28
category: solution
status: implemented
---

# Per-Exercise Cardio Secondary Unit Pattern

## Problem

모든 유산소 운동이 동일한 "분 + km" 입력 형태를 사용하여 수영(meters), 계단(floors), 줄넘기(count), 엘립티컬(시간만) 등에 부적합한 단위가 표시됨.

## Solution

### Domain Model: `CardioSecondaryUnit`

`ExerciseDefinition`에 `cardioSecondaryUnit: CardioSecondaryUnit?` 필드를 추가하여 운동별로 보조 단위를 지정.

```swift
enum CardioSecondaryUnit: String, Codable, Sendable, CaseIterable {
    case km           // Running, Cycling — distance in km
    case meters       // Swimming, Rowing — distance in meters → stored as km
    case floors       // Stair Climber — stored in reps field
    case count        // Jump Rope — stored in reps field
    case timeOnly = "none"  // Elliptical — no secondary field
}
```

### Field Routing Strategy

| Unit | Input Field | Storage Field | Conversion |
|------|------------|---------------|------------|
| km | `distance` TextField | `WorkoutSet.distance` (km) | 1:1 |
| meters | `distance` TextField | `WorkoutSet.distance` (km) | ÷ 1000 |
| floors | `reps` TextField | `WorkoutSet.reps` (Int) | 1:1 |
| count | `reps` TextField | `WorkoutSet.reps` (Int) | 1:1 |
| timeOnly | (hidden) | nil | N/A |

### Key Design Decisions

1. **`reps` field reuse**: `WorkoutSet.reps`는 cardio에서 기존에 항상 nil. floors/count를 여기에 저장하면 CloudKit 스키마 변경 불필요
2. **Optional with nil default**: 기존 ExerciseDefinition/JSON과 100% 호환. `nil` → `.km` fallback
3. **rawValue `"none"` 보존**: Swift에서 `.timeOnly`로 rename했지만 Codable rawValue는 `"none"` 유지하여 CloudKit/JSON 호환
4. **stepperConfig는 validationRange에서 파생**: 단일 소스 원칙 — min/max 불일치 방지

### Validation Pattern

```swift
let unit = exercise.cardioSecondaryUnit ?? .km
if unit.usesDistanceField {
    // validate against unit.validationRange, convert via unit.toKm()
} else if unit.usesRepsField {
    // validate against unit.validationRange, store as Int in reps
}
// unit == .timeOnly → skip secondary validation
```

## Prevention

- 새 CardioSecondaryUnit case 추가 시: `validationRange`, `placeholder`, `stepperConfig`, `previousSuffix`, `keyboardType` 모두 구현 확인
- `stepperConfig`는 `validationRange`에서 자동 파생되므로 별도 수정 불필요
- `case timeOnly = "none"` rawValue는 CloudKit에 영구 저장됨 — 변경 금지 (Correction #164)
- Watch DTO (`WatchExerciseInfo`)에 새 필드 추가 시 양쪽 타겟 동기화 필수 (Correction #69)

## Files

| File | Role |
|------|------|
| `Domain/Models/CardioSecondaryUnit.swift` | Domain enum + conversion/validation |
| `Domain/Models/ExerciseDefinition.swift` | Optional field 선언 |
| `Data/Persistence/Models/CustomExercise.swift` | SwiftData rawValue 저장 |
| `Data/Resources/exercises.json` | 40개 유산소 운동 단위 지정 |
| `Presentation/Shared/Extensions/CardioSecondaryUnit+View.swift` | UI-only extensions |
| `Presentation/Exercise/WorkoutSessionViewModel.swift` | Validation + WorkoutSet 생성 |
| `Presentation/Exercise/Components/SetRowView.swift` | Unit-aware input fields |
