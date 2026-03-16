---
source: review/performance
priority: p2
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# BedtimeWatchReminderScheduler refreshSchedule debounce 추가

## Issue

`refreshSchedule()`이 매 foreground 진입(`.active` scene phase)마다 호출됨.
매번 7개 병렬 HealthKit sleep 쿼리 + 평균 bedtime 계산 + notification 재등록 수행.
사용자가 앱을 자주 열면 불필요한 HealthKit 쿼리 반복.

## Solution

last-refresh timestamp를 저장하고, 마지막 갱신 후 30분 이내면 skip.
30분은 foreground 빈도 대비 충분한 억제이면서, 취침 시간대 변동에도 빠르게 반영.

```swift
private var lastRefreshDate: Date?

func refreshSchedule() async {
    if let last = lastRefreshDate, Date().timeIntervalSince(last) < 30 * 60 { return }
    lastRefreshDate = Date()
    // ... existing logic
}
```

## Files

- `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
