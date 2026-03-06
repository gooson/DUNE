---
tags: [healthkit, steps, notification, metric-detail, consistency]
category: general
date: 2026-03-06
severity: important
related_files:
  - DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailView.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNETests/BackgroundNotificationEvaluatorTests.swift
  - DUNETests/MetricDetailViewModelTests.swift
related_solutions:
  - docs/solutions/healthkit/healthkit-deduplication-best-practices.md
  - docs/solutions/healthkit/background-notification-system.md
---

# Solution: Steps 상세 헤더와 step goal 알림 총합 동기화

## Problem

Steps 상세 화면의 큰 숫자가 주간 차트/오늘 버킷과 다르게 보이고, step goal 알림도 별도 누적 로직을 사용해 사용자 체감 값과 어긋날 수 있었다.

### Symptoms

- Steps 상세 주간 화면에서 헤더 값이 차트의 오늘 값과 다름
- 오늘 알림(step goal) 문구의 걸음 수가 상세/차트와 일관되지 않음

### Root Cause

1. 상세 헤더는 기간 데이터가 아니라 진입 시점 `metric.value`를 그대로 표시했다.
2. background step goal 평가는 anchored query 신규 샘플 합계를 UserDefaults cache에 더하는 방식이라, 실제 “오늘 총합”과 표현 경로가 분리되어 있었다.

## Solution

상세 화면과 알림 모두 “현재 기간의 authoritative total”을 기준으로 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | Steps 카테고리에서 헤더 값을 ViewModel currentValue로 표시 | 진입 시점 카드 값 대신 실제 기간 데이터 반영 |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | steps 로드 후 period-aware currentValue 계산 추가 | week/month는 마지막 슬롯, day는 시간 버킷 합으로 일관화 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | `StepGoalResolver` 추출, cache 누적 제거, `fetchSteps(for:)` 기반 총합 재조회 | step goal 알림이 실제 오늘 총합을 사용하도록 보정 |
| `DUNETests/MetricDetailViewModelTests.swift` | steps 헤더 값 회귀 테스트 강화 | 진입 metric.value가 기간 데이터로 덮이는지 보호 |
| `DUNETests/BackgroundNotificationEvaluatorTests.swift` | step goal resolver 테스트 추가 | 샘플 합이 아니라 today total을 기준으로 판단하는지 보호 |

### Key Code

```swift
let total = try await stepsService.fetchSteps(for: now)
return EvaluateHealthInsightUseCase.evaluateStepGoal(todaySteps: total)
```

## Prevention

### Checklist Addition

- [ ] HealthKit 누적 지표(steps/calories/distance)는 UI/notification 모두 동일한 authoritative total query를 쓰는지 확인
- [ ] 상세 화면 헤더 값이 진입 파라미터에 고정되지 않고 현재 period data와 동기화되는지 확인

### Rule Addition (if applicable)

반복되면 HealthKit/notification rule로 승격할 가치가 있다. 현재는 solution doc으로 남긴다.

## Lessons Learned

동일 지표를 여러 경로에서 보여줄 때는 “표시용 숫자”를 재조합하지 말고, 최종 합계 쿼리 한 경로를 기준으로 맞추는 편이 안전하다.
