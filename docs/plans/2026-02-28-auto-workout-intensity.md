---
tags: [workout, intensity, auto-scoring, domain-service]
date: 2026-02-28
category: plan
status: draft
---

# Plan: Auto Workout Intensity Scoring System

## Overview

운동 기록 완료 시 과거 퍼포먼스 대비 세션 강도를 자동 산출하는 시스템.
복합 신호(1RM%, 히스토리 percentile, RPE)를 가중 결합하여 5단계 라벨로 표시.

## Architecture

```
Domain/Models/WorkoutIntensity.swift          ← 5단계 enum + rawScore + detail
Domain/UseCases/WorkoutIntensityService.swift  ← 핵심 산출 로직
Data/Persistence/Models/ExerciseRecord.swift   ← autoIntensityRaw 필드 추가
Presentation/Exercise/WorkoutSessionView.swift ← 저장 시 산출 호출
Presentation/Exercise/Components/WorkoutCompletionSheet.swift ← 강도 표시
Presentation/Exercise/ExerciseHistoryViewModel.swift ← 트렌드 데이터
DUNETests/WorkoutIntensityServiceTests.swift   ← 단위 테스트
```

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Domain/Models/WorkoutIntensity.swift` | **CREATE** | 5단계 enum, rawScore, detail 모델 |
| `Domain/UseCases/WorkoutIntensityService.swift` | **CREATE** | 운동유형별 강도 산출 서비스 |
| `Data/Persistence/Models/ExerciseRecord.swift` | MODIFY | `autoIntensityRaw: Double?` 필드 추가 |
| `Presentation/Exercise/WorkoutSessionView.swift` | MODIFY | saveWorkout()에서 강도 산출 호출 |
| `Presentation/Exercise/Components/WorkoutCompletionSheet.swift` | MODIFY | 강도 라벨 표시 추가 |
| `Presentation/Exercise/ExerciseHistoryViewModel.swift` | MODIFY | SessionSummary에 intensity 추가 |
| `DUNETests/WorkoutIntensityServiceTests.swift` | **CREATE** | 테스트 (경계값, NaN, 유형별) |

## Implementation Steps

### Step 1: Domain Models (`WorkoutIntensity.swift`)

```swift
// Domain/Models/WorkoutIntensity.swift

enum WorkoutIntensityLevel: Int, CaseIterable, Sendable {
    case veryLight = 1  // 0.0 - 0.2
    case light = 2      // 0.2 - 0.4
    case moderate = 3   // 0.4 - 0.6
    case hard = 4       // 0.6 - 0.8
    case maxEffort = 5  // 0.8 - 1.0

    init(rawScore: Double) {
        // clamp 0-1, map to level
    }
}

struct WorkoutIntensityResult: Sendable {
    let level: WorkoutIntensityLevel
    let rawScore: Double          // 0.0 - 1.0
    let detail: WorkoutIntensityDetail
}

struct WorkoutIntensityDetail: Sendable {
    let primarySignal: Double?    // 1RM% or pace percentile
    let volumeSignal: Double?     // relative volume
    let rpeSignal: Double?        // normalized RPE
    let method: IntensityMethod   // which formula was used
}

enum IntensityMethod: String, Sendable {
    case oneRMBased        // 근력: 1RM 대비 %
    case repsPercentile    // 맨몸: reps 히스토리 percentile
    case pacePercentile    // 유산소: pace percentile
    case manualIntensity   // 유연성/HIIT: 기존 intensity 필드
    case rpeOnly           // fallback: RPE만
    case insufficientData  // 데이터 부족
}
```

### Step 2: Domain Service (`WorkoutIntensityService.swift`)

**Input structs** (OneRMEstimationService 패턴 따름):

```swift
struct IntensitySessionInput: Sendable {
    let date: Date
    let exerciseType: ExerciseInputType
    let sets: [IntensitySetInput]
    let rpe: Int?                      // 1-10 or nil
}

struct IntensitySetInput: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    let manualIntensity: Int?          // 1-10 for durationIntensity type
    let setType: SetType
}
```

**산출 로직 (운동 유형별)**:

| ExerciseInputType | Primary Signal (60%) | Volume Signal (30%) | RPE (10%) |
|---|---|---|---|
| setsRepsWeight | avg(weight / est1RM) | sessionVolume / avgVolume | rpe/10 |
| setsReps | reps percentile in history | totalReps / avgTotalReps | rpe/10 |
| durationDistance | 1 - pacePercentile | duration / avgDuration | rpe/10 |
| durationIntensity | avgManualIntensity / 10 | duration / avgDuration | rpe/10 |
| roundsBased | rounds percentile | duration / avgDuration | rpe/10 |

**Fallback chain**: 1RM% → percentile → RPE → insufficientData(nil)

**Validation (Correction Log 준수)**:
- weight: 0-500, reps: 1-1000, distance: 0-500km, duration: 0-28800s (#22, #42, #79)
- 모든 나눗셈 결과 isFinite guard (#18)
- percentile 계산 시 분모 = 유효 데이터 count (#101)

### Step 3: ExerciseRecord Schema 변경

```swift
// ExerciseRecord.swift — 필드 추가
var autoIntensityRaw: Double?  // 0.0-1.0, nil = not computed
```

- init에 `autoIntensityRaw: Double? = nil` 파라미터 추가
- CloudKit Optional 호환 (Correction #32)

### Step 4: WorkoutSessionView 통합

`saveWorkout()` 수정:

```swift
private func saveWorkout() {
    // ... existing validation ...
    guard let record = viewModel.createValidatedRecord(weightUnit: weightUnit) else { return }

    // --- NEW: Auto intensity calculation ---
    let intensityResult = calculateAutoIntensity(for: record)
    record.autoIntensityRaw = intensityResult?.rawScore
    // --- END NEW ---

    modelContext.insert(record)
    // ... existing code ...
}

private func calculateAutoIntensity(for record: ExerciseRecord) -> WorkoutIntensityResult? {
    let service = WorkoutIntensityService()

    // Build current session input
    let currentInput = IntensitySessionInput(from: record, exerciseType: exercise.inputType)

    // Build history from @Query exerciseRecords (same exercise, last 30 days)
    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    let history: [IntensitySessionInput] = exerciseRecords
        .filter { $0.exerciseDefinitionID == exercise.id && $0.date >= thirtyDaysAgo }
        .sorted { $0.date < $1.date }  // oldest first (Correction #156)
        .compactMap { IntensitySessionInput(from: $0, exerciseType: exercise.inputType) }

    // Get 1RM if strength exercise
    var estimated1RM: Double? = nil
    if exercise.inputType == .setsRepsWeight {
        let oneRMSessions = history.map { session in
            OneRMSessionInput(date: session.date, sets: session.sets.map {
                OneRMSetInput(weight: $0.weight, reps: $0.reps)
            })
        }
        estimated1RM = OneRMEstimationService().analyze(sessions: oneRMSessions).currentBest
    }

    return service.calculateIntensity(
        current: currentInput,
        history: history,
        estimated1RM: estimated1RM
    )
}
```

### Step 5: WorkoutCompletionSheet UI

강도 라벨을 RPE 입력 위에 표시:

```swift
// WorkoutCompletionSheet — autoIntensity 추가
let autoIntensity: WorkoutIntensityResult?

// body 내 RPE 입력 위에:
if let intensity = autoIntensity {
    IntensityBadgeView(intensity: intensity)
        .padding(.horizontal, DS.Spacing.lg)
}
```

`IntensityBadgeView`: 라벨 + 색상 + rawScore bar를 보여주는 작은 컴포넌트.

### Step 6: ExerciseHistoryViewModel 트렌드

`SessionSummary`에 `autoIntensity: Double?` 추가하여 차트에서 강도 트렌드 표시 가능.

### Step 7: 단위 테스트

| 테스트 케이스 | 검증 항목 |
|---|---|
| 근력: 1RM 80% 세션 | rawScore ≈ 0.5-0.7 (moderate~hard) |
| 근력: 1RM 100% 세션 | rawScore ≈ 0.8-1.0 (hard~max) |
| 맨몸: 상위 90% reps | rawScore > 0.7 |
| 유산소: 평균 pace | rawScore ≈ 0.4-0.6 |
| 빈 히스토리 | nil 반환 |
| 1회 히스토리 | RPE fallback or nil |
| NaN/Infinite 입력 | nil 또는 안전 fallback |
| weight=0, reps=0 | 해당 세트 스킵 |
| RPE 결합 | RPE 포함 시 점수 조정 확인 |

## Risks

- **CloudKit 스키마 변경**: `autoIntensityRaw` 추가는 Optional이므로 안전 (Correction #32)
- **계산 비용**: 30일 히스토리 필터링은 @Query에서 이미 로드된 데이터. 추가 DB 쿼리 없음
- **1RM 부정확**: 초보자는 1RM 데이터 부족 → percentile fallback이 핵심

## Verification

1. 빌드 성공: `scripts/build-ios.sh`
2. 테스트 통과: `WorkoutIntensityServiceTests` 전체 green
3. 기능 확인: 근력/맨몸/유산소 각 1회 기록 → 완료 시트에 강도 표시
