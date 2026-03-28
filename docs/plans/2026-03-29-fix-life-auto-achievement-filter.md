---
tags: [life-tab, auto-achievement, bug-fix, healthkit-filter]
date: 2026-03-29
category: plan
status: draft
---

# Plan: 라이프탭 자동 운동 업적 필터 버그 수정

## Problem

라이프탭 자동 운동 업적이 단 1개도 기록되지 않음.

### Root Cause

`LifeAutoAchievementService.calculateProgresses` (line 158)에서:
```swift
let filtered = entries.filter { $0.hasHealthKitLink || $0.isFromHealthKit }
```

이 필터가 HealthKit에 연결되지 않은 **모든 수동 기록 운동**을 제외함.

- `isFromHealthKit`: HealthKit에서 가져온 기록에만 true (Apple Watch 등)
- `hasHealthKitLink`: `healthKitWorkoutID`가 설정된 경우에만 true

수동 기록 운동은 HealthKit write가 비동기로 실행되며, 권한 미부여/실패 시 두 필드 모두 false → 업적 0건.

### Impact

- 모든 수동 기록 운동이 업적 계산에서 제외됨
- HealthKit 권한 없는 사용자는 업적을 절대 달성할 수 없음
- HealthKit write 실패 시에도 동일 증상

## Solution

### Step 1: HealthKit 필터 제거

**파일**: `DUNE/Domain/UseCases/LifeAutoAchievementService.swift`

`calculateProgresses` 함수에서 HealthKit 필터 라인을 제거하고, 모든 entries를 dedup 후 사용.

변경 전:
```swift
let filtered = entries.filter { $0.hasHealthKitLink || $0.isFromHealthKit }
let workouts = deduplicated(entries: filtered)
```

변경 후:
```swift
let workouts = deduplicated(entries: entries)
```

Dedup은 `sourceWorkoutID`(HealthKit workout ID) 기반 1차, timestamp+type 기반 2차로 이미 정상 동작하므로 필터 제거 후에도 중복 집계되지 않음.

### Step 2: 불필요한 필드 정리

`LifeAutoWorkoutEntry`에서 `isFromHealthKit`과 `hasHealthKitLink` 필드는 필터에서만 사용됨. 필터 제거 후 사용처가 없으므로 삭제.

**파일**: `DUNE/Domain/UseCases/LifeAutoAchievementService.swift`
- `LifeAutoWorkoutEntry`에서 두 필드 삭제

**파일**: `DUNE/Presentation/Life/LifeViewModel.swift`
- `calculateAutoExerciseProgresses`에서 매핑 시 해당 필드 제거

### Step 3: 테스트 업데이트

**파일**: `DUNETests/LifeAutoAchievementServiceTests.swift`
- 기존 "HealthKit-linked entries only" 테스트 → "all entries count" 로 변경
- `makeEntry` 헬퍼에서 `isFromHealthKit`, `hasHealthKitLink` 파라미터 제거
- 새 테스트: 수동 기록(sourceWorkoutID nil)도 업적에 반영되는지 검증

**파일**: `DUNETests/LifeViewModelTests.swift`
- HealthKit 필드 관련 테스트 업데이트

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Domain/UseCases/LifeAutoAchievementService.swift` | 필터 제거 + 필드 삭제 |
| `DUNE/Presentation/Life/LifeViewModel.swift` | 매핑 시 필드 제거 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | 테스트 수정 |
| `DUNETests/LifeViewModelTests.swift` | 테스트 수정 (필요 시) |

## Test Strategy

1. 유닛 테스트: 수동 기록 운동이 업적에 반영되는지 검증
2. 유닛 테스트: 기존 dedup이 정상 동작하는지 회귀 검증
3. 빌드 검증: `scripts/build-ios.sh`

## Risk & Edge Cases

- **Dedup 정확성**: HealthKit 필터 제거 후 동일 운동이 중복 집계될 수 있음 → dedup 로직이 이미 timestamp+type fallback으로 처리하므로 안전
- **HealthKit 연동 운동 + 수동 기록 중복**: 같은 운동이 HealthKit에서도 오고 수동으로도 기록된 경우 → `sourceWorkoutID` 기반 dedup으로 처리됨
