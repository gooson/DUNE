---
tags: [healthkit, sleep, awake, consistency, all-data, testing]
category: healthkit
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/AllDataViewModel.swift
  - DUNE/Data/HealthKit/SleepQueryService.swift
  - DUNE/Domain/Models/HealthMetric.swift
  - DUNETests/AllDataViewModelTests.swift
  - DUNETests/EvaluateHealthInsightUseCaseTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-02-24-sleep-dedup-watch-detection.md
---

# Solution: Align AllData Sleep Duration With Existing Non-Awake Policy

## Problem

### Symptoms

- All Data 화면의 sleep 히스토리에서 `awake` 구간이 수면 시간으로 집계되어, 다른 수면 지표 경로와 값이 달라질 수 있었다.
- `AllDataViewModelTests`의 sleep 필터 테스트가 실패했다.

### Root Cause

`AllDataViewModel`의 sleep 경로가 `fetchSleepStages()` 결과를 그대로 합산했고, 앱의 표준 수면 정의(awake 제외)와 불일치했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | sleep 합산 시 `.awake` stage 필터 추가 | SleepSummary/MetricDetail/SleepQueryService 정책과 일관성 확보 |
| `DUNETests/EvaluateHealthInsightUseCaseTests.swift` | `"New Badge Unlocked"` 기대값을 `String(localized:)`로 변경 | 로케일 의존 테스트 실패 제거 및 CI 안정화 |

### Key Code

```swift
let total = stages
    .filter { $0.stage != .awake }
    .reduce(0.0) { $0 + $1.duration } / 60.0
```

## Prevention

### Checklist Addition

- [ ] Sleep duration 계산 경로에서 `awake` 포함/제외 정책이 기존 Domain 정의와 일치하는지 확인
- [ ] 사용자 대면 문자열을 검증하는 테스트는 하드코딩 영어 비교 대신 localized 기대값을 사용

### Rule Addition (if applicable)

기존 규칙/교정으로 커버됨:
- `docs/corrections-archive.md` #110 (Display/Score stage 분류 일관성)
- `docs/solutions/healthkit/2026-02-24-sleep-dedup-watch-detection.md`

## Lessons Learned

1. sleep 정책 차이는 작은 분기 1줄에서도 발생하므로, 계산 경로별 교차 검증이 필요하다.
2. 테스트 문자열은 로케일 영향으로 flaky해질 수 있으므로, 정책적으로 localized assertion을 사용해야 한다.
