---
tags: [life-tab, auto-achievement, healthkit, filter, bug-fix]
date: 2026-03-29
category: general
status: implemented
related_files:
  - DUNE/Domain/UseCases/LifeAutoAchievementService.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNETests/LifeAutoAchievementServiceTests.swift
  - DUNETests/LifeViewModelTests.swift
---

# Solution: 라이프탭 자동 운동 업적 HealthKit 필터 버그

## Problem

라이프탭 자동 운동 업적이 단 1개도 기록되지 않음.

### Symptoms

- 수동 기록한 운동이 주간 업적(5회/7회, 근력 3회 등)에 전혀 반영되지 않음
- 모든 업적 progress가 0/N으로 표시

### Root Cause

`LifeAutoAchievementService.calculateProgresses`에서 HealthKit 연동 필터가 모든 수동 기록을 배제:

```swift
let filtered = entries.filter { $0.hasHealthKitLink || $0.isFromHealthKit }
```

- `isFromHealthKit`: HealthKit에서 가져온 기록에만 true (Apple Watch 등 외부 소스)
- `hasHealthKitLink`: `healthKitWorkoutID`가 설정된 경우에만 true

앱 내 수동 기록 운동은 HealthKit write가 비동기이고, 권한 미부여/실패 시 두 필드 모두 false → 필터에서 모두 제외됨.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `LifeAutoAchievementService.swift` | HealthKit 필터 라인 제거, `isFromHealthKit`/`hasHealthKitLink` 필드 삭제 | 모든 ExerciseRecord를 업적 계산에 포함 |
| `LifeViewModel.swift` | 매핑 시 삭제된 필드 제거 | 컴파일 일관성 |
| `LifeAutoAchievementServiceTests.swift` | 테스트 업데이트 + 수동 기록 검증 테스트 2개 추가 | 수정 검증 + 회귀 방지 |
| `LifeViewModelTests.swift` | HealthKit 의존 제거 | 수동 기록만으로도 동작 확인 |

### Key Code

변경 전:
```swift
let filtered = entries.filter { $0.hasHealthKitLink || $0.isFromHealthKit }
let workouts = deduplicated(entries: filtered)
```

변경 후:
```swift
let workouts = deduplicated(entries: entries)
```

기존 dedup 로직이 `sourceWorkoutID` 기반 1차 + timestamp+type 기반 2차로 중복을 방지하므로, 필터 제거 후에도 중복 집계되지 않음.

## Prevention

### Checklist

- [ ] 도메인 계산 서비스에 외부 시스템(HealthKit 등) 연동 상태를 필터 조건으로 사용하지 않았는가
- [ ] 비동기 write의 성공/실패에 따라 핵심 기능이 동작하지 않는 경우가 없는가
- [ ] 권한 미부여 상태에서도 앱 내 기록이 정상 동작하는지 확인했는가

### Rule Candidate

외부 시스템 연동 상태를 핵심 도메인 계산의 필터 조건으로 사용하지 않음. 필터가 필요하면 별도 표시용 계산으로 분리.

## Lessons Learned

- HealthKit write는 비동기이며 실패할 수 있으므로, HealthKit 연동 상태를 핵심 비즈니스 로직의 게이트 조건으로 사용하면 안 됨
- 테스트에서 `isFromHealthKit: true`, `hasHealthKitLink: true` 기본값을 사용하면 실제 사용 패턴(수동 기록)을 놓칠 수 있음
- "외부 시스템 연결 필요 → 기능 동작"이 아닌 "앱 내 데이터 존재 → 기능 동작"이 올바른 의존 방향
