---
tags: [healthkit, deduplication, data-integrity, swiftdata, cloudkit, multi-source]
date: 2026-02-18
category: solution
status: implemented
---

# HealthKit 중복 운동 제거 (Deduplication)

## Problem

앱에서 ExerciseRecord를 SwiftData에 저장하고 동시에 HKWorkout을 HealthKit에 기록하면, HealthKit 쿼리 시 앱 자체가 만든 워크아웃이 다시 반환되어 UI에 중복 표시됨.

## Solution

**이중 전략 (Dual-strategy) 필터링**:

1. **Primary**: `healthKitWorkoutID` 매칭 — SwiftData ExerciseRecord에 저장된 HK UUID와 HealthKit WorkoutSummary.id를 비교. 일치하면 중복으로 판정하여 제거.

2. **Fallback**: `isFromThisApp` boolean — Data 레이어(WorkoutQueryService)에서 `HKWorkout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier`를 평가하여 boolean으로 변환. HealthKit write 실패로 `healthKitWorkoutID`가 설정되지 않은 경우를 커버.

**레이어 배치**:
- `isFromThisApp` 해소: Data 레이어 (`WorkoutQueryService.toSummary()`)
- ID 기반 필터: Presentation 레이어 (`WorkoutSummary+Dedup.swift` extension)
- `Bundle.main` 접근: Data 레이어에만 존재 (Domain/Presentation에 노출 안 함)

**빈 문자열 방어**:
- `healthKitWorkoutID`가 `""` (빈 문자열)인 경우 false-positive 매칭 방지를 위해 `!id.isEmpty` 검증 포함.

## Key Files

| File | Role |
|------|------|
| `Data/HealthKit/WorkoutQueryService.swift` | bundleID → `isFromThisApp` boolean 해소 |
| `Domain/Models/HealthMetric.swift` | `WorkoutSummary.isFromThisApp` 필드 |
| `Presentation/Shared/Extensions/WorkoutSummary+Dedup.swift` | 이중 전략 필터링 로직 |
| `Presentation/Exercise/ExerciseViewModel.swift` | invalidateCache()에서 dedup 적용 |

## Prevention

- 새 데이터 소스(Watch, 외부 앱) 추가 시 동일 패턴 재사용 가능
- `isFromThisApp`은 Data 레이어에서만 해소 — Domain 모델에 인프라 문자열 노출 금지
- 빈 문자열 ID 검증은 모든 compactMap 경로에 적용

## Related

- `docs/brainstorms/2026-02-18-healthkit-dedup-strategy.md` — 초기 전략 브레인스토밍
- `docs/plans/2026-02-18-healthkit-dedup.md` — 구현 계획
- `todos/012-pending-p1-watch-healthkit-dedup.md` — Watch 측 후속 작업
