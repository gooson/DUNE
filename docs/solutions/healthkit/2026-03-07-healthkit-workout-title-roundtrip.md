---
tags: [healthkit, workout, title, metadata, watch, strength]
category: healthkit
date: 2026-03-07
severity: important
related_files:
  - DUNE/Data/HealthKit/WorkoutActivityType+HealthKit.swift
  - DUNE/Data/HealthKit/WorkoutWriteService.swift
  - DUNEWatch/Managers/WatchWorkoutWriter.swift
  - DUNE/Data/HealthKit/WorkoutQueryService.swift
  - DUNE/Presentation/Shared/Models/ExerciseListItem.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-04-watch-individual-workout-recording.md
---

# Solution: HealthKit 운동명 Round-Trip 복구

## Problem

근력 운동이 개별 `HKWorkout`으로 저장되더라도 앱에서는 모든 운동이 `"Weight Training"` / `"웨이트 트레이닝"`으로만 보였다.

### Symptoms

- Watch strength template workout이 Health 앱에는 개별 항목으로 생기지만 앱 리스트/상세에서는 전부 generic strength 이름으로 표시됨
- CloudKit으로 `ExerciseRecord`가 아직 안 내려온 시점에는 개별 운동명이 완전히 사라진 것처럼 보임
- 사용자는 기록 실패와 HealthKit sync 실패를 구분할 수 없게 됨

### Root Cause

문제는 저장과 조회 양쪽에 걸쳐 있었다.

1. iPhone `WorkoutWriteService`와 Watch `WatchWorkoutWriter`가 HealthKit에 운동명을 metadata로 저장하지 않았다.
2. `WorkoutQueryService`와 `BackgroundNotificationEvaluator`가 HealthKit에서 제목을 읽을 때 `activityType.typeName`만 사용했다.
3. UI(`ExerciseListItem`, `HealthKitWorkoutDetailView`)도 HealthKit workout의 stored title보다 `activityType.displayName`을 우선했다.

즉, 개별 `ExerciseRecord` 저장 경로는 존재했지만, HealthKit-only fallback 경로가 제목을 일반화해서 보여주고 있었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/WorkoutActivityType+HealthKit.swift` | `HealthKitWorkoutTitle` helper 추가 | metadata key/read/write fallback 단일 소스화 |
| `DUNE/Data/HealthKit/WorkoutWriteService.swift` | iPhone HKWorkout metadata에 운동명 기록 | HealthKit-only 조회 시 제목 보존 |
| `DUNEWatch/Managers/WatchWorkoutWriter.swift` | Watch 개별 HKWorkout metadata에 운동명 기록 | Watch strength workout 제목 보존 |
| `DUNE/Data/HealthKit/WorkoutQueryService.swift` | `WorkoutSummary.type`를 metadata 우선으로 구성 | 조회 시 generic title 덮어쓰기 제거 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | background summary도 동일 helper 사용 | foreground/background title 일관성 유지 |
| `DUNE/Presentation/Shared/Models/ExerciseListItem.swift` | HealthKit row가 stored/custom title 우선 표시 | 리스트에서 `"웨이트 트레이닝"` 뭉개짐 방지 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | 상세 화면 제목과 편집 기본값 교정 | 상세 진입 후에도 generic fallback 방지 |
| `DUNE/Presentation/Shared/WorkoutHealthKitWriter.swift` | iPhone 수동 기록은 localized exercise name 우선 저장 | 사용자에게 보이는 운동명과 HK metadata 정렬 |
| `DUNETests/WorkoutWriteServiceTests.swift` | metadata helper 회귀 테스트 추가 | title round-trip fallback 보장 |
| `DUNETests/ExerciseViewModelTests.swift` | HealthKit row title 우선순위 테스트 추가 | UI 회귀 방지 |

### Key Code

```swift
enum HealthKitWorkoutTitle {
    static let metadataKey = "com.dune.workout.exerciseName"

    static func metadata(exerciseName: String) -> [String: Any] {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        return [metadataKey: String(trimmed.prefix(100))]
    }

    static func resolveTitle(
        metadata: [String: Any]?,
        activityType: WorkoutActivityType
    ) -> String {
        guard let metadata,
              let rawTitle = metadata[metadataKey] as? String else {
            return activityType.typeName
        }
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? activityType.typeName : trimmed
    }
}
```

## Prevention

### Checklist Addition

- [ ] 개별 운동명이 중요한 HKWorkout은 `HKWorkoutActivityType`만 믿지 말고 custom metadata round-trip 여부를 함께 확인한다
- [ ] Watch/iPhone writer 수정 시 `WorkoutQueryService` title resolution까지 세트로 검증한다
- [ ] HealthKit-only fallback 화면(리스트/상세)에서 generic activity label이 다시 우선되지 않는지 테스트한다

### Rule Addition (if applicable)

이번에는 별도 rule 파일 추가 없이 solution doc으로 패턴을 남긴다. 다음에 같은 실수가 반복되면 `.claude/rules/healthkit-patterns.md`로 승격한다.

## Lessons Learned

1. `HKWorkoutActivityType`는 활동 분류 정보일 뿐, 개별 운동명 보존 수단이 아니다.
2. Watch 개별 기록을 고쳐도 `title metadata -> query -> UI` round-trip이 빠지면 사용자는 여전히 기록 실패로 인식한다.
3. HealthKit fallback UI가 존재하는 기능은 SwiftData/CloudKit 동기화 지연을 항상 전제로 설계해야 한다.
