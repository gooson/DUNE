---
tags: [cardio, exercise-input, ux, units, intervals]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: 유산소 운동 기록 방식 개선

## Problem Statement

현재 모든 유산소(cardio) 운동이 **동일한 입력 형태**(시간 min + 거리 km)를 사용하고 있어, 운동 특성에 맞지 않는 기록 방식이 강제됨.

**핵심 문제:**
1. **거리 단위 부적합**: 줄넘기에 "km", 스테어 클라이머에 "km", 수영에 "km" — 운동별 자연스러운 단위가 무시됨
2. **인터벌 세트 미지원**: 유산소 인터벌(400m × 8회, 1분 on/off 등)을 세트 단위로 기록할 UX가 부족

## Target Users

- 일반 유산소 사용자: 러닝/걷기/자전거 → 시간+거리 기록 (현재 방식 유지)
- 수영 사용자: 랩/미터 단위 기록 필요
- 실내 머신 사용자: 스테어 클라이머(층수), 줄넘기(횟수), 일립티컬(시간 only)
- 인터벌 훈련 사용자: 트랙 인터벌, 수영 인터벌, 로잉 인터벌 등

## Success Criteria

1. 각 유산소 운동이 자연스러운 보조 단위를 표시 (km/m/laps/floors/count/none)
2. 인터벌 세트를 세트 단위로 기록하고, 세트별 시간/거리를 입력 가능
3. 기존 데이터(WorkoutSet.distance: Double?)와 호환 — CloudKit 스키마 변경 없음
4. Pace/Intensity 계산이 새 단위에서도 정상 작동

## Current State Analysis

### 현재 구조

```
ExerciseInputType.durationDistance
  → SetRowView: TextField("min") + TextField("km")
  → WorkoutSet: duration(TimeInterval?) + distance(Double? — km)
  → WorkoutIntensityService: sessionPace = duration / distance
```

### 10개 기본 유산소 운동 (각 4개 변형 = 40개)

| 운동 | 현재 단위 | 적절한 단위 | 문제 |
|------|-----------|-------------|------|
| Running | min + km | min + km | OK |
| Walking | min + km | min + km | OK |
| Cycling | min + km | min + km | OK |
| Hiking | min + km | min + km | OK |
| Swimming | min + km | min + **m/laps** | km 비현실적 (50m 풀에서 0.05km?) |
| Rowing Machine | min + km | min + **m** | 로잉 업계는 미터 사용 |
| Stair Climber | min + km | min + **floors** | 거리 무의미, 층수가 표준 |
| Jump Rope | min + km | min + **count** | 거리 무의미, 횟수가 표준 |
| Elliptical | min + km | min + **none/cal** | 거리가 인위적, 시간만으로 충분 |
| Stationary Bike | min + km | min + km | OK (실내지만 가상거리 유의미) |

**문제 운동: 5/10 (Swimming, Rowing, Stair Climber, Jump Rope, Elliptical)**

### 인터벌 세트 현황

현재 유산소도 세트 추가 가능하지만:
- SetType이 strength 기반 (warmup/working/drop/failure)
- "세트 추가" UX가 무게 운동 맥락
- 인터벌 특화 기능 없음 (목표 거리/시간 설정, 랩 표시 등)

## Proposed Approach

### Phase 1: 운동별 보조 단위 도입 (MVP)

**새 enum 추가: `CardioSecondaryUnit`**

```swift
// Domain/Models/ExerciseCategory.swift
enum CardioSecondaryUnit: String, Codable, Sendable {
    case km           // Running, Walking, Cycling, Hiking, Stationary Bike
    case meters       // Swimming, Rowing Machine
    case laps         // Swimming (alternative)
    case floors       // Stair Climber
    case count        // Jump Rope
    case none         // Elliptical (시간만 기록)
}
```

**ExerciseDefinition 확장:**

```swift
struct ExerciseDefinition {
    // ... 기존 필드
    let cardioSecondaryUnit: CardioSecondaryUnit?  // nil = non-cardio
}
```

**exercises.json 변경:**

```json
{
    "id": "swimming",
    "inputType": "durationDistance",
    "cardioSecondaryUnit": "meters",
    ...
}
```

**SetRowView UI 변경:**

```swift
case .durationDistance:
    HStack {
        TextField("min", text: $editableSet.duration)

        if let unit = secondaryUnit {
            switch unit {
            case .km:     TextField("km", text: $editableSet.distance)
            case .meters: TextField("m", text: $editableSet.distance)
            case .laps:   TextField("laps", text: $editableSet.distance)
            case .floors: TextField("floors", text: $editableSet.distance)
            case .count:  TextField("count", text: $editableSet.distance)
            case .none:   EmptyView()  // 거리 입력 숨김
            }
        }
    }
```

**데이터 저장 — 내부 단위 통일 (km):**

```swift
// 사용자 입력 → 내부 저장 변환
func normalizeToKm(value: Double, unit: CardioSecondaryUnit) -> Double? {
    switch unit {
    case .km:     return value
    case .meters: return value / 1000.0
    case .laps:   return nil  // 거리 환산 불가 → distance 저장 안 함
    case .floors: return nil  // 거리 환산 불가 → distance 저장 안 함
    case .count:  return nil  // 거리 환산 불가 → distance 저장 안 함
    case .none:   return nil
    }
}
```

**비거리 단위(laps, floors, count) 저장:**
- `WorkoutSet.reps: Int?` 필드를 재활용 (현재 cardio에서 nil)
- laps=10 → `reps = 10`, floors=30 → `reps = 30`, count=500 → `reps = 500`
- CloudKit 스키마 변경 없음 (기존 optional 필드 활용)

### Phase 2: 인터벌 세트 UX 개선

**인터벌 운동에서 세트 = 인터벌 랩**

현재 `*-intervals` 변형 12개:
- running-intervals, swimming-intervals, cycling-intervals 등

**인터벌 UX 개선 포인트:**

1. **세트 라벨**: "Set 1" → "Lap 1" / "Interval 1"
2. **SetType 확장**: 기존 warmup/working/drop/failure + `interval` / `rest`
3. **목표 표시**: 인터벌 운동에 목표값 pre-fill (예: 400m 목표)
4. **요약 표시**: 세트 완료 후 평균 페이스, 총 거리, best/worst lap 표시

**인터벌 SetType 확장:**

```swift
enum SetType: String, Codable, Sendable {
    case warmup
    case working
    case drop
    case failure
    case interval   // 새로 추가: 인터벌 활성 구간
    case rest       // 새로 추가: 인터벌 휴식 구간 (기록용)
}
```

**인터벌 입력 플로우:**

```
[인터벌 설정]
  목표 거리/시간: 400m (또는 1:00)
  반복 횟수: 8

[자동 생성된 세트]
  Interval 1: 400m  [시간 입력] ✓
  Interval 2: 400m  [시간 입력] ✓
  ...
  Interval 8: 400m  [시간 입력] □
```

## Constraints

### 기술적 제약
- **CloudKit 스키마**: WorkoutSet 필드 추가 금지 (기존 optional 필드 재활용)
- **Watch 동기화**: WatchExerciseInfo에 새 필드 반영 필요 (#69)
- **HealthKit**: 거리는 항상 미터 단위 → km 변환 로직 유지
- **기존 데이터 호환**: distance=nil인 기존 유산소 기록이 깨지지 않아야 함

### 시간/리소스 제약
- Phase 1 (단위 개선): 중간 복잡도, 여러 파일 변경
- Phase 2 (인터벌 UX): 높은 복잡도, 새 UI 컴포넌트 필요

## Edge Cases

1. **수영 laps → 거리 변환**: 풀 길이(25m/50m)를 알아야 함 → 사용자 설정 또는 HealthKit에서 가져오기
2. **laps/floors/count에서 페이스 계산**: distance 없으면 pace 계산 불가 → RPE fallback 또는 count-rate(횟수/분) 기반 intensity
3. **커스텀 유산소 운동**: `CreateCustomExerciseView`에서 `cardioSecondaryUnit` 선택 UI 추가 필요
4. **기존 데이터 마이그레이션**: 이미 입력된 swimming distance(km 단위)를 meters로 재해석하면 안 됨 → 새 기록부터 적용
5. **인터벌 도중 목표 변경**: 8 × 400m 설정 후 중간에 200m로 바꾸는 경우
6. **혼합 인터벌**: 400m-200m-400m 같은 비균일 인터벌

## Scope

### MVP (Must-have)
- [ ] `CardioSecondaryUnit` enum 추가
- [ ] `ExerciseDefinition`에 `cardioSecondaryUnit` 필드 추가
- [ ] `exercises.json`에 10개 기본 운동 + 30개 변형에 단위 지정
- [ ] `SetRowView` — 운동별 보조 단위 placeholder/keyboard 변경
- [ ] 비거리 단위(laps/floors/count)는 `WorkoutSet.reps` 재활용
- [ ] `WorkoutSessionViewModel` — 단위별 validation 범위 조정
- [ ] 기존 데이터 호환성 보장 (migration 불필요)
- [ ] 인터벌 세트 기본 지원 (세트 라벨 "Interval N", 요약 표시)

### Nice-to-have (Future)
- [ ] 수영 풀 길이 설정 (laps → meters 자동 변환)
- [ ] 인터벌 템플릿 (목표 거리/시간 pre-fill, 자동 세트 생성)
- [ ] SetType.interval / .rest 추가
- [ ] 인터벌 요약 (평균 페이스, best/worst lap)
- [ ] 하이브리드 운동 InputType (무게 + 거리: farmer's walk, sled push)
- [ ] 페이스 계산 — count-rate 기반 (jump rope: count/min)

## Affected Files (예상)

| 파일 | 변경 내용 |
|------|-----------|
| `Domain/Models/ExerciseCategory.swift` | `CardioSecondaryUnit` enum 추가 |
| `Domain/Models/ExerciseDefinition.swift` | `cardioSecondaryUnit` 필드 추가 |
| `Data/Resources/exercises.json` | 40개 cardio에 `cardioSecondaryUnit` 지정 |
| `Presentation/Exercise/Components/SetRowView.swift` | 단위별 placeholder/keyboard 분기 |
| `Presentation/Exercise/WorkoutSessionViewModel.swift` | 단위별 validation, reps 재활용 로직 |
| `Presentation/Exercise/Components/CreateCustomExerciseView.swift` | 커스텀 운동 단위 선택 UI |
| `Domain/UseCases/WorkoutIntensityService.swift` | 비거리 운동 intensity fallback |
| `DUNETests/WorkoutSessionViewModelTests.swift` | 새 단위 validation 테스트 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | Watch UI 동기화 |

## Open Questions

1. 수영 기본 단위를 `meters`와 `laps` 중 어느 것으로 할 것인가? (laps면 풀 길이 설정 필요)
2. Elliptical의 보조 입력을 완전히 숨길 것인가, 아니면 "strides" 같은 대안 단위를 제공할 것인가?
3. 인터벌 세트의 rest 구간도 기록할 것인가? (on/off 패턴)
4. `WorkoutSet.reps`를 laps/floors/count로 재활용할 때 기존 strength 세트와의 의미 충돌은 없는가?

## Next Steps

- [ ] `/plan improve-cardio-logging` 으로 구현 계획 생성
