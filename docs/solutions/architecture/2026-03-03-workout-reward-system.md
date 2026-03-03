---
tags: [workout, rewards, milestones, personal-records, notifications, badge, level, activity-tab]
category: architecture
date: 2026-03-03
severity: important
related_files:
  - DUNE/Domain/Models/WorkoutActivityType.swift
  - DUNE/Data/Persistence/PersonalRecordStore.swift
  - DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift
  - DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift
related_solutions:
  - docs/solutions/general/2026-02-24-activity-pr-cardio-healthkit-review-fixes.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
---

# Solution: Workout Reward System (Fixed Milestones + Representative Notification)

## Problem

기존 Activity PR 시스템은 PR 계산/표시는 가능했지만, 모든 운동 타입을 포괄하는 고정 구간 달성 체계와 배지/레벨 누적 히스토리가 부족했다.
또한 한 세션에서 여러 달성이 발생할 때 알림이 과다해질 가능성이 있어, 대표 이벤트 1건 정책이 필요했다.

### Symptoms

- 운동별 구간 달성 정책이 일관되지 않음
- 배지/레벨 보상 상태를 화면에서 확인하기 어려움
- PR 알림은 존재하지만 구간/레벨업 보상과 통합되지 않음

### Root Cause

- PR 저장소(`PersonalRecordStore`)가 PR 캐시 역할에 집중되어 있었고, 구간 진행/보상/히스토리 상태를 함께 관리하지 않았음
- 백그라운드 알림 평가가 PR 단일 이벤트만 대상으로 설계되어 있었음

## Solution

PR 저장소를 확장하여 고정 구간/보상 상태/히스토리를 통합 관리하고, 백그라운드 알림은 대표 이벤트 1건만 발송하도록 변경했다.
Activity 화면에서는 PR 현황에 레벨/배지를 결합하고, 달성 히스토리를 함께 노출했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/WorkoutActivityType.swift` | workout milestone metric/threshold/achievement 규칙 추가 | 모든 운동 타입에서 고정 구간 판정 지원 |
| `DUNE/Domain/Models/PersonalRecord.swift` | reward event/summary/outcome 모델 추가 | 배지/레벨/히스토리 데이터 구조 표준화 |
| `DUNE/Data/Persistence/PersonalRecordStore.swift` | reward 상태 저장, 대표 이벤트 선택, idempotency 처리 추가 | 중복 동기화 방지 + 알림 1건 정책 구현 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | PR 단일 알림 → reward 대표 이벤트 기반 알림으로 확장 | 운동 종료 후 구간/PR/레벨 보상 알림 통합 |
| `DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift` | `evaluateWorkoutReward` 추가 | 대표 이벤트 종류별 메시지 생성 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | reward summary/history 상태 로드 및 갱신 | PR 현황 + 달성 히스토리 UI 데이터 공급 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Achievement History 섹션 추가 | 히스토리 진입점 제공 |
| `DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift` | Level/Badge/Points 요약 행 추가 | PR 현황에서 보상 진행도 즉시 확인 |
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Reward Progress + Achievement History 렌더링 추가 | 상세 화면에서 달성 타임라인 제공 |

### Key Code

```swift
// PersonalRecordStore.swift
let rewardOutcome = PersonalRecordStore.shared.evaluateReward(
    for: summary,
    newPRTypes: newPRTypes
)
guard let representativeEvent = rewardOutcome.representativeEvent else { return nil }
```

```swift
// Representative priority: levelUp > badgeUnlocked > personalRecord > milestone
enum WorkoutRewardEventKind {
    var priority: Int { ... }
}
```

## Prevention

보상/알림 기능은 PR 단일 로직이 아니라 **구간 판정 + 누적 상태 + 대표 이벤트 정책**을 한 묶음으로 유지한다.

### Checklist Addition

- [ ] workout 종료 이벤트에서 다중 달성 시 대표 이벤트 1건만 선택되는지 확인
- [ ] reward 상태 저장 로직이 workoutID 기준으로 idempotent한지 확인
- [ ] Activity PR 요약과 상세 히스토리가 같은 데이터 소스를 사용하는지 확인
- [ ] 구간 정책 변경 시 단위 테스트(경계값/fallback metric)도 함께 갱신

### Rule Addition (if applicable)

새 rule 파일 추가는 하지 않았고, 기존 `testing-required.md`, `input-validation.md`, `swift-layer-boundaries.md` 준수 범위에서 처리했다.

## Lessons Learned

- PR 시스템 위에 보상 체계를 얹을 때는 이벤트 자체보다 **중복/우선순위/idempotency**가 사용자 경험에 더 큰 영향을 준다.
- "모든 운동" 요구는 단일 지표보다 metric fallback(distance/steps/duration) 구조로 설계해야 누락 없이 확장 가능하다.
