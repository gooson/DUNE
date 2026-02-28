---
tags: [cardio, exercise-input, ux, units, intervals]
date: 2026-02-28
category: plan
status: draft
---

# Plan: 유산소 운동 기록 방식 개선

**Brainstorm**: `docs/brainstorms/2026-02-28-improve-cardio-logging.md`
**Fidelity**: F2 (명확한 범위, 여러 파일)

## Summary

5개 유산소 운동(Swimming, Rowing, Stair Climber, Jump Rope, Elliptical)의 보조 단위를 운동 특성에 맞게 변경하고, 인터벌 세트 타입(interval/rest)을 추가한다.

## Affected Files

| # | 파일 | 변경 유형 | 설명 |
|---|------|-----------|------|
| 1 | `Domain/Models/ExerciseCategory.swift` | 추가 | `CardioSecondaryUnit` enum, `SetType` 확장 |
| 2 | `Domain/Models/ExerciseDefinition.swift` | 수정 | `cardioSecondaryUnit` 필드 추가 |
| 3 | `Data/Persistence/Models/CustomExercise.swift` | 수정 | `cardioSecondaryUnitRaw` 필드 추가, `toDefinition()` 반영 |
| 4 | `Data/Resources/exercises.json` | 수정 | 40개 cardio에 `cardioSecondaryUnit` 지정 |
| 5 | `Presentation/Exercise/Components/SetRowView.swift` | 수정 | 단위별 placeholder 분기 |
| 6 | `Presentation/Exercise/WorkoutSessionView.swift` | 수정 | `durationDistanceInput()` 단위별 label/stepper 분기 |
| 7 | `Presentation/Exercise/WorkoutSessionViewModel.swift` | 수정 | 단위별 validation, meters→km 변환, reps 재활용 |
| 8 | `Presentation/Exercise/CompoundWorkoutView.swift` | 수정 | 컬럼 헤더 "KM" → 단위별 표시 |
| 9 | `Presentation/Exercise/Components/CreateCustomExerciseView.swift` | 수정 | cardio 선택 시 보조 단위 Picker 추가 |
| 10 | `Domain/UseCases/WorkoutIntensityService.swift` | 수정 | distance 없는 cardio(floors/count/none) RPE fallback |
| 11 | `DUNETests/WorkoutSessionViewModelTests.swift` | 추가 | 새 단위 validation 테스트 |
| 12 | `DUNETests/CardioSecondaryUnitTests.swift` | 생성 | CardioSecondaryUnit 변환 로직 테스트 |

## Implementation Steps

### Step 1: Domain 모델 확장

**파일**: `Domain/Models/ExerciseCategory.swift`

`CardioSecondaryUnit` enum 추가:

```swift
enum CardioSecondaryUnit: String, Codable, Sendable, CaseIterable {
    case km           // Running, Walking, Cycling, Hiking, Stationary Bike
    case meters       // Swimming, Rowing Machine
    case floors       // Stair Climber
    case count        // Jump Rope
    case none         // Elliptical (시간만 기록)
}
```

`SetType`에 interval/rest 추가:

```swift
enum SetType: String, Codable, Sendable {
    case warmup
    case working
    case drop
    case failure
    case interval  // 인터벌 활성 구간
    case rest      // 인터벌 휴식 구간
}
```

**CardioSecondaryUnit 도메인 로직**:

```swift
extension CardioSecondaryUnit {
    /// 사용자 입력값을 내부 저장 단위(km)로 변환
    func toKm(_ value: Double) -> Double? {
        switch self {
        case .km: return value
        case .meters: return value / 1000.0
        case .floors, .count, .none: return nil  // 거리 환산 불가
        }
    }

    /// 사용자 입력을 WorkoutSet.reps에 저장할지 여부
    var usesRepsField: Bool {
        switch self {
        case .floors, .count: return true
        case .km, .meters, .none: return false
        }
    }

    /// 거리(distance) 필드를 사용하는지 여부
    var usesDistanceField: Bool {
        switch self {
        case .km, .meters: return true
        case .floors, .count, .none: return false
        }
    }

    /// UI placeholder 텍스트
    var placeholder: String {
        switch self {
        case .km: return "km"
        case .meters: return "m"
        case .floors: return "floors"
        case .count: return "count"
        case .none: return ""
        }
    }

    /// 키보드 타입
    var keyboardType: UIKeyboardType {
        switch self {
        case .km: return .decimalPad
        case .meters, .floors, .count: return .numberPad
        case .none: return .default
        }
    }

    /// stepper 증감 범위
    var stepperConfig: (step: Double, min: Double, max: Double)? {
        switch self {
        case .km: return (0.1, 0, 500)
        case .meters: return (50, 0, 50_000)
        case .floors: return (1, 0, 500)
        case .count: return (10, 0, 10_000)
        case .none: return nil
        }
    }

    /// validation 범위
    var validationRange: ClosedRange<Double>? {
        switch self {
        case .km: return 0.1...500
        case .meters: return 1...50_000
        case .floors: return 1...500
        case .count: return 1...10_000
        case .none: return nil
        }
    }
}
```

**주의**: `placeholder`, `keyboardType` → Foundation 내 타입만 사용. UIKeyboardType은 `import UIKit` 필요하므로 Presentation extension으로 분리.

→ **수정**: `placeholder`는 String(OK), `keyboardType`/`stepperConfig`는 `Presentation/Shared/Extensions/CardioSecondaryUnit+View.swift`에 배치.

**Verification**: 빌드 성공. 기존 코드에 영향 없음.

### Step 2: ExerciseDefinition + CustomExercise 확장

**파일**: `Domain/Models/ExerciseDefinition.swift`, `Data/Persistence/Models/CustomExercise.swift`

**ExerciseDefinition**:
- `let cardioSecondaryUnit: CardioSecondaryUnit?` 추가 (default nil)
- init에 파라미터 추가 (기본값 nil → 기존 호출 사이트 변경 불필요)
- Codable 자동 합성이므로 JSON에 없으면 nil 디코딩 (기존 호환)

**CustomExercise**:
- `var cardioSecondaryUnitRaw: String?` 추가
- computed property `var cardioSecondaryUnit: CardioSecondaryUnit?`
- `toDefinition()`에 `cardioSecondaryUnit:` 전달
- init에 파라미터 추가

**Verification**: 빌드 성공. 기존 CustomExercise 데이터 호환 (새 필드는 optional).

### Step 3: exercises.json 업데이트

**파일**: `Data/Resources/exercises.json`

40개 cardio 운동에 `cardioSecondaryUnit` 필드 추가:

| 운동 그룹 (×4 변형) | cardioSecondaryUnit |
|---------------------|---------------------|
| running, running-intervals/endurance/recovery | `"km"` |
| walking, walking-* | `"km"` |
| cycling, cycling-* | `"km"` |
| hiking, hiking-* | `"km"` |
| stationary-bike, stationary-bike-* | `"km"` |
| swimming, swimming-* | `"meters"` |
| rowing-machine, rowing-machine-* | `"meters"` |
| stair-climber, stair-climber-* | `"floors"` |
| jump-rope, jump-rope-* | `"count"` |
| elliptical, elliptical-* | `"none"` |

**Verification**: JSON 디코딩 테스트 통과. 기존 non-cardio 운동은 필드 없음 → nil 디코딩.

### Step 4: Presentation Extension (CardioSecondaryUnit+View)

**파일**: `Presentation/Shared/Extensions/CardioSecondaryUnit+View.swift` (신규)

UI 전용 프로퍼티 분리 (Correction #1 — Domain에 SwiftUI import 금지):

```swift
import SwiftUI

extension CardioSecondaryUnit {
    var keyboardType: UIKeyboardType {
        switch self {
        case .km: return .decimalPad
        case .meters, .floors, .count: return .numberPad
        case .none: return .default
        }
    }

    var stepperConfig: (label: String, step: Double, min: Double, max: Double)? {
        switch self {
        case .km:     return ("KM", 0.1, 0, 100)
        case .meters: return ("M", 50, 0, 50_000)
        case .floors: return ("FLOORS", 1, 0, 500)
        case .count:  return ("COUNT", 10, 0, 10_000)
        case .none:   return nil
        }
    }
}
```

**SetType 인터벌 확장 (SetType+View에 추가)**:

```swift
extension SetType {
    var displayName: String {
        switch self {
        // ... 기존 case
        case .interval: "Int"
        case .rest: "Rest"
        }
    }

    var tintColor: Color {
        switch self {
        // ... 기존 case
        case .interval: DS.Color.activity
        case .rest: .secondary
        }
    }
}
```

**Verification**: 빌드 성공.

### Step 5: SetRowView 단위별 분기

**파일**: `Presentation/Exercise/Components/SetRowView.swift`

**변경 사항**:
1. `let cardioUnit: CardioSecondaryUnit?` 프로퍼티 추가
2. `previousLabel` — `durationDistance` case에서 단위별 suffix ("k" → "m"/"fl"/"×" 등)
3. `inputFields` — `durationDistance` case에서:
   - `cardioUnit == .none` → duration 필드만 표시
   - `cardioUnit?.usesRepsField` → `editableSet.reps` 바인딩 + 정수 키보드
   - `cardioUnit?.usesDistanceField` → `editableSet.distance` 바인딩 + 단위별 placeholder

```swift
case .durationDistance:
    HStack(spacing: DS.Spacing.xs) {
        TextField("min", text: $editableSet.duration)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 60)

        if let unit = cardioUnit, unit != .none {
            if unit.usesDistanceField {
                TextField(unit.placeholder, text: $editableSet.distance)
                    .keyboardType(unit.keyboardType)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 70)
            } else if unit.usesRepsField {
                TextField(unit.placeholder, text: $editableSet.reps)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 70)
            }
        }
    }
```

**Verification**: 각 단위별 UI 확인. Elliptical은 시간만 표시.

### Step 6: WorkoutSessionView 단위별 stepper

**파일**: `Presentation/Exercise/WorkoutSessionView.swift`

**변경 사항**: `durationDistanceInput(set:)` 메서드에서:

1. `viewModel.exercise.cardioSecondaryUnit` 참조
2. `.none` → duration stepper만 표시
3. `.km` → 현재와 동일 (KM stepper)
4. `.meters` → "M" 라벨, step 50, max 50000
5. `.floors` / `.count` → 정수 stepper, `set.reps` 바인딩

```swift
private func durationDistanceInput(set: Binding<EditableSet>) -> some View {
    let unit = viewModel.exercise.cardioSecondaryUnit ?? .km
    return VStack(spacing: DS.Spacing.lg) {
        // Duration stepper (항상 표시)
        stepperField(label: "MINUTES", value: set.duration, ...)

        // 보조 단위 stepper (unit != .none일 때만)
        if let config = unit.stepperConfig {
            Divider().padding(.horizontal, DS.Spacing.xl)
            if unit.usesDistanceField {
                stepperField(label: config.label, value: set.distance, ...)
            } else if unit.usesRepsField {
                stepperField(label: config.label, value: set.reps, ...)
            }
        }
    }
}
```

**Verification**: 각 단위별 stepper 동작 확인.

### Step 7: WorkoutSessionViewModel validation + 저장 변환

**파일**: `Presentation/Exercise/WorkoutSessionViewModel.swift`

**변경 사항**:

1. **Validation** (`createValidatedRecord` 내 `durationDistance` 블록):

```swift
if exercise.inputType == .durationDistance {
    let unit = exercise.cardioSecondaryUnit ?? .km
    if unit.usesDistanceField {
        // km, meters → distance 필드 validation
        let trimmed = set.distance.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let range = unit.validationRange {
            guard let dist = Double(trimmed), range.contains(dist) else {
                validationError = "\(unit.placeholder) must be between \(Int(range.lowerBound)) and \(Int(range.upperBound))"
                return nil
            }
        }
    } else if unit.usesRepsField {
        // floors, count → reps 필드 validation
        let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let range = unit.validationRange {
            guard let val = Int(trimmed), Double(val) >= range.lowerBound, Double(val) <= range.upperBound else {
                validationError = "\(unit.placeholder) must be between \(Int(range.lowerBound)) and \(Int(range.upperBound))"
                return nil
            }
        }
    }
    // unit == .none → 보조 필드 validation 스킵
}
```

2. **WorkoutSet 생성** (distance 변환):

```swift
// 기존: distance: trimmedDistance.isEmpty ? nil : Double(trimmedDistance)
// 변경:
let unit = exercise.cardioSecondaryUnit ?? .km
let distanceKm: Double?
if unit.usesDistanceField {
    distanceKm = Double(trimmedDistance).flatMap { unit.toKm($0) }
} else {
    distanceKm = nil
}

let repsValue: Int?
if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps || exercise.inputType == .roundsBased {
    repsValue = trimmedReps.isEmpty ? nil : Int(trimmedReps)
} else if unit.usesRepsField {
    // cardio: floors/count → reps 필드 재활용
    repsValue = trimmedReps.isEmpty ? nil : Int(trimmedReps)
} else {
    repsValue = nil
}

let workoutSet = WorkoutSet(
    ...
    reps: repsValue,
    distance: distanceKm,
    ...
)
```

**Verification**: meters 입력 → km 저장, floors/count 입력 → reps 저장, 기존 km 동작 유지.

### Step 8: CompoundWorkoutView 헤더 분기

**파일**: `Presentation/Exercise/CompoundWorkoutView.swift`

**변경**: `durationDistance` 헤더에서 "KM" → 단위별 표시.

```swift
case .durationDistance:
    let unit = exercise.cardioSecondaryUnit ?? .km
    HStack(spacing: DS.Spacing.xs) {
        Text("MIN").frame(maxWidth: 60)
        if unit != .none {
            Text(unit.placeholder.uppercased()).frame(maxWidth: 70)
        }
    }
```

**Verification**: CompoundWorkout 헤더 표시 확인.

### Step 9: CreateCustomExerciseView 보조 단위 Picker

**파일**: `Presentation/Exercise/Components/CreateCustomExerciseView.swift`

**변경**: cardio 카테고리 선택 시 `CardioSecondaryUnit` Picker 표시.

```swift
@State private var selectedCardioUnit: CardioSecondaryUnit = .km

// Category onChange에 추가:
case .cardio:
    selectedInputType = .durationDistance
    selectedCardioUnit = .km

// Input Type 섹션 아래에 조건부 추가:
if selectedInputType == .durationDistance {
    Section("Distance Unit") {
        Picker("Unit", selection: $selectedCardioUnit) {
            Text("Kilometers").tag(CardioSecondaryUnit.km)
            Text("Meters").tag(CardioSecondaryUnit.meters)
            Text("Floors").tag(CardioSecondaryUnit.floors)
            Text("Count").tag(CardioSecondaryUnit.count)
            Text("None (time only)").tag(CardioSecondaryUnit.none)
        }
    }
}

// createExercise()에서 CustomExercise init에 전달:
let custom = CustomExercise(
    ...,
    cardioSecondaryUnit: selectedInputType == .durationDistance ? selectedCardioUnit : nil
)
```

**Verification**: 커스텀 유산소 운동 생성 시 단위 선택 가능.

### Step 10: WorkoutIntensityService — distance 없는 cardio fallback

**파일**: `Domain/UseCases/WorkoutIntensityService.swift`

**변경**: `cardioIntensity()` 내 `sessionPace` 계산이 distance=nil이면 nil 반환 → 이미 RPE fallback으로 처리됨. 추가 변경 불필요.

확인 사항:
- `sessionPace(from:)` → distance 합산이 0이면 nil 반환 → `rpeFallback()` 호출 ✓
- floors/count 운동은 distance가 nil → 자동으로 RPE fallback ✓
- meters 운동은 distance가 km로 변환 저장 → pace 계산 정상 작동 ✓

**Verification**: 기존 intensity 테스트 통과. 추가 테스트에서 floors/count fallback 확인.

### Step 11: 유닛 테스트 작성

**파일**: `DUNETests/CardioSecondaryUnitTests.swift` (신규)

테스트 케이스:
- `toKm()`: km passthrough, meters 변환 (1500m → 1.5km), floors/count/none → nil
- `usesRepsField` / `usesDistanceField` 정확성
- `validationRange` 경계값

**파일**: `DUNETests/WorkoutSessionViewModelTests.swift` (추가)

테스트 케이스:
- meters 단위 validation (swimming): 1-50000m 범위 통과/거부
- floors 단위 validation (stair climber): 1-500 범위 통과/거부
- count 단위 validation (jump rope): 1-10000 범위 통과/거부
- none 단위 (elliptical): distance 입력 없이 통과
- meters → km 저장 변환: 1500m 입력 → distance 1.5 저장
- floors → reps 저장: floors=30 입력 → reps=30, distance=nil
- 기존 km 테스트 변경 없음

**Verification**: 전체 테스트 스위트 통과.

### Step 12: SetType interval/rest — Presentation 반영

**변경 범위가 최소한인 곳만**:
1. `SetType+View.swift`에 `displayName`, `tintColor` 추가 (Step 4에서 처리)
2. `SetRowView`의 setType indicator에서 `.interval` / `.rest` 표시

기존 working 세트로 기록하는 플로우는 유지. `*-intervals` 변형 운동 선택 시 기본 SetType을 `.interval`로 설정하는 것은 Future scope.

**Verification**: 빌드 성공. interval/rest SetType이 UI에서 표시 가능.

## Correction Log 체크리스트

구현 전 확인할 기존 교정 사항:

- [x] #1: Domain에 SwiftUI import 금지 → CardioSecondaryUnit의 UI 프로퍼티는 Presentation extension
- [x] #3: 사용자 입력 범위 검증 → 단위별 validationRange 적용
- [x] #32: CloudKit @Relationship Optional → 새 필드 없음 (기존 필드 재활용)
- [x] #36: rawValue UI 표시 금지 → placeholder computed property 사용
- [x] #37: 3곳 이상 중복 즉시 추출 → 단위 분기 로직을 CardioSecondaryUnit extension에 집중
- [x] #42: Domain 서비스도 자체 입력 범위 검증 → validationRange는 Domain에
- [x] #93: 분류 switch에 default 금지 → CardioSecondaryUnit switch exhaustive
- [x] #164: Codable struct rawValue 필드 WARNING → CardioSecondaryUnit rawValue 변경 주의

## Risks & Mitigations

| 위험 | 영향 | 완화 |
|------|------|------|
| 기존 cardio 데이터 깨짐 | 높음 | cardioSecondaryUnit 미지정 → .km fallback으로 기존 동작 유지 |
| CustomExercise 스키마 변경 | 중간 | optional String 필드 추가 → CloudKit 호환 |
| intensity 계산 오류 | 중간 | distance=nil → 이미 RPE fallback 경로 존재 |
| Watch 동기화 불일치 | 낮음 | Watch는 inputType 기반으로 카테고리만 표시 → 변경 불필요 |
