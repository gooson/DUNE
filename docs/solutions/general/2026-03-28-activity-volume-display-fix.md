---
tags: [activity, volume, snapshot, weekly-stats, dry, weight-reps, training-volume]
date: 2026-03-28
category: general
status: implemented
---

# Activity Tab Volume Display Bug Fix

## Problem

Activity 탭 전체에서 "Volume" 표시가 올바르게 나타나지 않음.

**근본 원인**: `ExerciseRecordSnapshot.totalWeight`가 세트별 무게의 단순 합(`sum(weight)`)으로 계산되고 있었음. 올바른 훈련 볼륨은 `sum(weight × reps)` (톤니지).

**예시**: 벤치프레스 3세트 × 60kg × 10회
- 잘못된 계산: 60 + 60 + 60 = **180** (세트 무게 합)
- 올바른 계산: 60×10 + 60×10 + 60×10 = **1,800** (훈련 볼륨)

동일한 잘못된 계산이 **3곳**에 복제되어 있었음:
1. `ActivityViewModel.buildExerciseRecordSnapshot`
2. `ExerciseRecord+Snapshot.snapshot(library:)`
3. `TrainingVolumeViewModel.makeExerciseSnapshot`

## Solution

### 1. `WorkoutSetVolumeProviding` 프로토콜 + `trainingVolume()` 공유 헬퍼 도입

`ExerciseRecord+Volume.swift`에 프로토콜 기반 공유 계산 추출:

```swift
extension Array where Element: WorkoutSetVolumeProviding {
    static var maxTrainingVolume: Double { 999_999 }

    func trainingVolume() -> Double? {
        let raw = reduce(0.0) { total, set in
            guard set.isVolumeCompleted else { return total }
            let w = set.volumeWeight
            let r = set.volumeReps
            guard w > 0, r > 0, w.isFinite else { return total }
            return total + w * r
        }
        let capped = Swift.min(raw, Self.maxTrainingVolume)
        return capped > 0 ? capped : nil
    }
}
```

### 2. 3곳의 스냅샷 빌더를 공유 헬퍼로 대체

```swift
// Before (3곳 각각):
let totalWeight = completedSets.compactMap(\.weight).reduce(0, +)

// After (3곳 모두):
let totalWeight = completedSets.trainingVolume()
```

### 3. `GenerateWorkoutReportUseCase` 이중 곱셈 수정

`totalWeight`가 이미 weight×reps이므로, intensity 계산에서 reps를 다시 곱하던 부분 제거.

### Changed Files

- `ExerciseRecord+Volume.swift` — `WorkoutSetVolumeProviding` 프로토콜 + `trainingVolume()` 추가
- `ActivityViewModel.swift` — `buildExerciseRecordSnapshot` 수정
- `ExerciseRecord+Snapshot.swift` — `snapshot(library:)` 수정
- `TrainingVolumeViewModel.swift` — `makeExerciseSnapshot` 수정
- `GenerateWorkoutReportUseCase.swift` — intensity 이중 곱셈 제거
- `ExerciseRecordSnapshot.swift` — 주석 업데이트
- `ExerciseRecordVolumeTests.swift` — 새 테스트 파일

## Prevention

1. **`totalWeight` 필드명 주의**: `ExerciseRecordSnapshot.totalWeight`는 이제 weight×reps (톤니지). 이름이 혼동될 수 있으므로 주석으로 명확히 기록.
2. **DRY 3곳 규칙 준수**: 동일 계산이 3곳 이상 반복되면 즉시 공유 헬퍼로 추출. 이번 버그는 3곳에 동일한 잘못된 계산이 복제되어 있어 발생.
3. **프로토콜 기반 테스트**: `WorkoutSetVolumeProviding` 프로토콜 덕분에 SwiftData 없이도 `StubSet`으로 볼륨 계산을 검증 가능.

## Lessons Learned

- `sum(weight)` vs `sum(weight × reps)`는 코드 리뷰에서 간과하기 쉬운 의미론적 차이. 필드명 `totalWeight`가 오해를 유발.
- 동일 스냅샷 빌더가 3곳에 있으면 cap 값도 불일치 발생 (`ExerciseRecord+Snapshot.swift`에는 cap이 없었음).
- `isFinite` 가드가 누락되면 HealthKit에서 잘못된 값이 흘러들어 `.infinity`가 전파될 수 있음.
