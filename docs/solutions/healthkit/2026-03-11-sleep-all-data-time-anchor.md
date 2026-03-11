---
tags: [healthkit, sleep, all-data, timestamp, detail-view]
category: healthkit
date: 2026-03-11
severity: important
related_files:
  - DUNE/Presentation/Shared/Charts/ChartModels.swift
  - DUNE/Presentation/Shared/Detail/AllDataView.swift
  - DUNE/Presentation/Shared/Detail/AllDataViewModel.swift
  - DUNETests/AllDataViewModelTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-04-all-data-sleep-awake-alignment.md
  - docs/solutions/healthkit/2026-03-06-step-detail-header-notification-total-sync.md
---

# Solution: Preserve Sleep Day Grouping While Showing Real Session Time

## Problem

Sleep 상세의 "Show All Data" 목록에서 각 날짜 row의 시간이 모두 동일하게 보였다.

### Symptoms

- 여러 날짜의 sleep row 왼쪽 시간이 현재 시각과 같은 값으로 반복됐다.
- section header 날짜는 맞지만, row time이 실제 수면 시작 시각을 반영하지 못했다.

### Root Cause

`AllDataViewModel`의 sleep branch가 `fetchSleepStages(for:)` 조회용 날짜 앵커를 그대로 `ChartDataPoint.date`에 저장했다. 이 앵커는 `Date()`에서 day offset만 적용한 값이라, 페이지를 연 시각이 모든 row에 복제됐다.

## Solution

그룹용 날짜와 표시용 시각을 분리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Charts/ChartModels.swift` | `ChartDataPoint.displayDate` 추가 | 그룹 기준 날짜와 row 표시 시각을 분리하기 위해 |
| `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | sleep row는 `startOfDay` anchor + earliest non-awake `startDate`를 함께 저장 | 날짜 귀속은 유지하고 실제 수면 시작 시각을 표시하기 위해 |
| `DUNE/Presentation/Shared/Detail/AllDataView.swift` | row/accessibility가 `displayDate ?? date`를 사용하도록 변경 | UI와 VoiceOver가 동일한 실제 시각을 읽도록 맞추기 위해 |
| `DUNETests/AllDataViewModelTests.swift` | sleep data point가 date/displayDate를 분리하는 회귀 테스트 추가 | 동일 시각 반복 버그 재발 방지 |

### Key Code

```swift
let dayAnchor = calendar.startOfDay(for: referenceDate)
let displayDate = sleepStages.min(by: { $0.startDate < $1.startDate })?.startDate
return ChartDataPoint(date: dayAnchor, value: total, displayDate: displayDate)
```

## Prevention

### Checklist Addition

- [ ] All Data row가 query anchor time을 그대로 사용자 표시 시간으로 재사용하지 않는지 확인
- [ ] day grouping과 row display semantics가 다른 지표는 display model에서 별도 필드로 분리
- [ ] sleep처럼 overnight data는 section date와 row time의 기준이 같은지/다른지 명시적으로 결정

### Rule Addition (if applicable)

지금은 solution doc으로 충분하다. 같은 패턴이 다른 overnight metric에도 반복되면 detail/history rule로 승격할 가치가 있다.

## Lessons Learned

1. overnight metric은 “귀속 날짜”와 “대표 시각”이 다를 수 있으므로 하나의 `Date`로 동시에 표현하면 쉽게 왜곡된다.
2. generic detail list라도 category별 time semantics가 다르면 display model에서 의도를 분리하는 편이 안전하다.
