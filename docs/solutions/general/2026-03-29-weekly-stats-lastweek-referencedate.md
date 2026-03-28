---
tags: [date-range, referenceDate, period-analysis, weekly-stats, activity, hardcoded-date]
date: 2026-03-29
category: general
status: implemented
---

# TrainingVolumeAnalysisService: Hardcoded Date() Breaks Historical Period Analysis

## Problem

WeeklyStatsDetailView에서 "지난 주" 선택 시 상단 요약 카드(볼륨, 소요 시간, 칼로리, 세션, 활동 일수)가 전부 빈 값으로 표시됨. 하단 차트에는 데이터가 정상 표시.

**증상**: 차트는 데이터를 보여주지만 요약 카드는 비어있음 (-100% 변화율 표시)

**근본 원인**: `TrainingVolumeAnalysisService.analyze()`가 내부에서 `let today = calendar.startOfDay(for: Date())`와 `let currentEnd = Date()`를 하드코딩. ViewModel이 지난 주 데이터(now-14 ~ now-7)를 필터링해서 전달해도, `analyze()`가 이번 주 범위(now-7 ~ now)로 재필터링하여 교집합이 공집합이 됨.

차트용 `buildHistoryDailyBreakdown()`은 명시적 `start`/`end` 파라미터를 받으므로 정상 동작 — 이 비대칭이 버그의 원인.

## Solution

### 변경 파일

| File | Change |
|------|--------|
| `TrainingVolumeAnalysisService.swift` | `referenceDate: Date = Date()` 파라미터 추가 |
| `WeeklyStatsDetailViewModel.swift` | pre-filtering 제거, `referenceDate: range.end` 전달 |
| `TrainingVolumeAnalysisServiceTests.swift` | referenceDate 테스트 2개 추가 |

### 핵심 코드

```swift
// Before: always uses "now"
static func analyze(..., period: VolumePeriod) -> PeriodComparison {
    let today = calendar.startOfDay(for: Date())  // ← hardcoded
    let currentEnd = Date()                        // ← hardcoded

// After: caller can shift the analysis window
static func analyze(..., period: VolumePeriod, referenceDate: Date = Date()) -> PeriodComparison {
    let today = calendar.startOfDay(for: referenceDate)
    let currentEnd = referenceDate
```

ViewModel에서:
```swift
// Before: manual pre-filtering that still got re-filtered inside analyze()
if period == .lastWeek {
    filteredWorkouts = workouts.filter { $0.date >= range.start && $0.date <= range.end }
}
let result = TrainingVolumeAnalysisService.analyze(workouts: filteredWorkouts, ...)

// After: pass referenceDate, let analyze() handle filtering
let result = TrainingVolumeAnalysisService.analyze(
    workouts: workouts, manualRecords: historySnapshots,
    period: period.volumePeriod, referenceDate: range.end
)
```

## Prevention

1. **분석 서비스가 내부에서 `Date()`를 하드코딩하면 과거 기간 분석이 불가능해짐** — 날짜 기준점은 항상 파라미터로 주입
2. **"데이터를 미리 필터링해서 넘기면 된다"는 해결책은 내부 재필터링이 있으면 깨짐** — 서비스 내부 필터링 로직을 확인할 것
3. **차트와 요약이 다른 API를 사용하면 불일치 발생** — Correction #213 패턴

## Lessons Learned

- 하나의 서비스에서 `buildHistoryDailyBreakdown()`은 explicit date params를 받고 `analyze()`는 hardcoded date를 쓰는 비대칭이 버그의 근본 원인. 같은 서비스 내 메서드들은 동일한 date 전략을 써야 함
- Default parameter(`referenceDate: Date = Date()`)는 기존 호출자를 깨뜨리지 않으면서 새 기능을 추가하는 안전한 패턴
