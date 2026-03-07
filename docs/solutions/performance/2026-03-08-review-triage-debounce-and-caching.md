---
tags: [debounce, healthkit-query, foreground, caching, computed-property, swiftui-state, review-finding]
date: 2026-03-08
category: solution
status: implemented
---

# Review Triage: Debounce 및 Computed Property 캐싱

## Problem

### 1. BedtimeWatchReminderScheduler 과도한 갱신

`refreshSchedule()`이 매 foreground 진입(`.active` scene phase)마다 호출됨. 매번 7개 병렬 HealthKit sleep 쿼리 + 평균 bedtime 계산 + notification 재등록을 수행. 사용자가 앱을 자주 열면 불필요한 HealthKit 쿼리 폭증.

### 2. TrainingVolume3DView computed property 반복 계산

`sortedMuscleVolumes`가 cached `@State`에서 computed property로 변경되어, body 내 다중 접근 시 매번 Dictionary grouping + sorting 반복.

## Solution

### Debounce (30분 간격)

```swift
// BedtimeWatchReminderScheduler.swift
private var lastRefreshDate: Date?

func refreshSchedule() async {
    if let last = lastRefreshDate, Date().timeIntervalSince(last) < 30 * 60 { return }
    lastRefreshDate = Date()
    // ... existing logic
}
```

30분은 foreground 빈도 대비 충분한 억제이면서, 취침 시간대 변동에도 빠르게 반영하는 균형점.

### Computed → @State 캐싱

```swift
// TrainingVolume3DView.swift
@State private var cachedMuscleVolumes: [(key: String, value: Double)] = ...

.onChange(of: sampleData.count) { _, _ in
    cachedMuscleVolumes = Self.computeMuscleVolumes(from: sampleData.filter(\.isPlottable))
}
```

`sampleData`가 `@State`로 weekRange 변경 시에만 바뀌므로, `onChange(of: count)`로 무효화.

## 부수 수정

- `onAlternativeSelected` → `onShowAlternativeDetails` 리네임 (detail sheet 표시 의미 반영)
- `CardioInactivityPolicyTests` XCTest → Swift Testing 전환 (프로젝트 컨벤션 통일)

## Prevention

1. **scene phase 콜백에서 비용 높은 작업**: 반드시 debounce/throttle 패턴 적용
2. **computed property → @State 전환 판단 기준**: body 내 2회 이상 접근 + 정렬/필터 포함이면 캐싱 검토
3. **콜백 네이밍**: 동작이 변경되면 콜백 이름도 동시 업데이트

## Lessons Learned

- HealthKit 쿼리는 foreground 진입마다 호출되는 경로에 놓으면 안 됨. singleton scheduler의 경우 `lastRefreshDate` 패턴이 간단하고 효과적
- 6시간 debounce는 취침 알림에 과도 → 30분이 적절 (도메인 맥락에 맞는 간격 선택 필요)
- visionOS Chart3D는 아직 sample data 기반이라 성능 이슈가 경미하지만, 실제 데이터로 전환 시 캐싱이 필수가 됨
