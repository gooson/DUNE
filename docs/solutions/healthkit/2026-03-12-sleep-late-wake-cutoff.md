---
tags: [healthkit, sleep, query-window, noon-anchor, late-wake, data-loss]
category: healthkit
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/HealthKit/SleepQueryService.swift
  - DUNETests/SleepQueryServiceTests.swift
  - docs/plans/2026-03-12-sleep-query-late-end-cutoff.md
related_solutions:
  - docs/solutions/general/2026-03-12-sleep-average-bedtime-card.md
  - docs/solutions/healthkit/2026-03-10-sleep-partial-watch-coverage-data-loss.md
---

# Solution: Preserve Late Wake Sleep Stages Beyond Noon Cutoff

## Problem

사용자 기준 실제 수면이 4시간 11분인데 앱에는 3시간 46분으로 표시됐다.

### Symptoms

- 늦게 일어난 날 수면 상세/대시보드/주간 수면 합계가 Apple Health보다 짧게 보였다.
- 차이는 정오 이후에 기록된 마지막 sleep stage 길이만큼 정확히 줄어드는 패턴을 보였다.

### Root Cause

`SleepQueryService.fetchSleepStages(for:)`가 수면 조회 범위를
`전날 12:00 ~ 당일 12:00`으로 고정하고 `strictStartDate` predicate를 사용했다.
그 결과 정오 이후에 **시작된** sleep stage는 같은 수면 세션의 연속 구간이어도 쿼리에서 제외됐다.

## Solution

기존 noon-anchor semantics는 유지하면서, query는 오후까지 넓게 가져오고
정오 이후 구간은 같은 수면 세션의 연속 구간일 때만 포함하도록 바꿨다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/HealthKit/SleepQueryService.swift` | query window helper 추가 및 upper bound 확장 | late wake stage를 source 단계에서 놓치지 않기 위해 |
| `DUNE/Data/HealthKit/SleepQueryService.swift` | `trimLateWakeContinuation` 추가 | 오후 낮잠까지 함께 집계되는 것을 막기 위해 |
| `DUNETests/SleepQueryServiceTests.swift` | noon 이후 연속 stage 포함 / 분리된 오후 nap 제외 테스트 추가 | 회귀 방지 |

### Key Code

```swift
let predicate = HKQuery.predicateForSamples(
    withStart: queryWindow.start,
    end: queryWindow.extendedEnd,
    options: .strictStartDate
)

let stages = deduplicateAndConvert(samples)
return Self.trimLateWakeContinuation(
    stages,
    primaryWindowEnd: queryWindow.primaryEnd
)
```

## Prevention

overnight metric은 query window와 display semantics를 따로 봐야 한다.
조회 범위를 넓히는 순간 낮잠/다중 세션 혼입 위험이 생기므로,
window 확장과 post-filter 기준을 항상 함께 설계해야 한다.

### Checklist Addition

- [ ] `strictStartDate` 기반 sleep query에서 cutoff 이후 stage가 잘리지 않는지 확인
- [ ] noon-anchor sleep query를 확장할 때는 late wake continuation과 afternoon nap 분리 기준을 함께 검증
- [ ] sleep total 회귀 테스트에 `정오 이후 종료` 사례를 포함

### Rule Addition (if applicable)

새 rule 추가까지는 필요 없다.
다만 sleep anchor/cutoff 이슈가 반복되면 `healthkit-patterns.md`에
overnight query window + continuation trimming 규칙으로 승격할 가치가 있다.

## Lessons Learned

1. `strictStartDate`는 경계 시각을 넘긴 stage를 통째로 누락시킬 수 있으므로 overnight metric에서 특히 위험하다.
2. query window를 단순히 늘리면 해결되는 것처럼 보여도, 같은 날 오후 nap이 같이 들어오는 부작용을 바로 만든다.
3. sleep 관련 로직은 dedup, anchor, display total이 모두 연결돼 있으므로 service 레벨에서 고쳐 downstream 전체를 같이 정합화하는 편이 안전하다.
