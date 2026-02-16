---
tags: [layer-boundary, domain, presentation, force-unwrap, nil-coalescing, deprecated-api, healthkit, formatting]
category: architecture
date: 2026-02-16
severity: important
related_files:
  - Dailve/Domain/Models/TimePeriod.swift
  - Dailve/Presentation/Shared/Extensions/TimePeriod+View.swift
  - Dailve/Data/HealthKit/WorkoutQueryService.swift
related_solutions: []
---

# Solution: 레이어 경계 강화 + Force-Unwrap 제거 + Deprecated API 교체

## Problem

### Symptoms

1. `TimePeriod`(Domain)에 `DateFormatter` 기반 한국어 포맷팅 — Presentation 관심사가 Domain에 혼입
2. `dateRange(offset:)`에 12개 force-unwrap(`!`) — `Calendar.date(byAdding:)` 실패 시 crash
3. `HKWorkout.totalEnergyBurned` / `.totalDistance` — iOS 18 deprecated warning 2개

### Root Cause

1. 초기 개발 시 TimePeriod에 편의상 포맷팅 추가 → 레이어 규칙 위반
2. `Calendar.date(byAdding:)` 실패 확률 극히 낮아 force-unwrap 사용 → 방어 코딩 원칙 위반
3. iOS 18 API 변경 미반영

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `TimePeriod.swift` | `rangeLabel`/`visibleRangeLabel` 제거, force-unwrap → `?? fallback` | Domain 정리 |
| `TimePeriod+View.swift` (NEW) | Presentation extension으로 포맷팅 이동, nil-coalescing 사용 | 레이어 분리 |
| `WorkoutQueryService.swift` | `totalEnergyBurned` → `statistics(for:).sumQuantity()`, `toSummary()` 헬퍼 | Deprecated 교체 + DRY |

### Key Code

```swift
// Force-unwrap → nil-coalescing
// Before:
baseStart = calendar.date(byAdding: .day, value: -6, to: startOfToday)!
// After:
baseStart = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday

// Deprecated API replacement
// Before:
calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
// After:
let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
    .sumQuantity()?.doubleValue(for: .kilocalorie())

// Layer separation pattern
// Domain (TimePeriod.swift): dateRange, strideComponent 등 계산만
// Presentation (TimePeriod+View.swift): rangeLabel, visibleRangeLabel 포맷팅
```

## Prevention

### Checklist Addition

- [ ] Domain 모델에 `DateFormatter`, locale-specific 문자열이 있으면 Presentation으로 이동
- [ ] `Calendar.date(byAdding:)` 호출에 `!` 사용 금지 → `?? fallback`
- [ ] Xcode deprecated warning은 발견 즉시 수정 (warning 0 정책)

### Rule Addition (if applicable)

기존 `swift-layer-boundaries.md`에 추가:
- "Domain 레이어에 `DateFormatter` 금지 — Presentation extension으로 분리"
- "Force-unwrap은 `fatalError` 수준의 확신이 있을 때만 사용"

## Lessons Learned

- `Calendar.date(byAdding:)` 결과에 `!` 쓰는 것은 "99.99% 안전"이지만, 방어 코딩 원칙상 `??` 사용이 코드 의도를 더 명확히 전달
- Deprecated API는 warning 단계에서 즉시 교체하면 나중에 breaking change 대응 비용 감소
- `toSummary()` 같은 매핑 헬퍼 추출은 deprecated 교체 시 변경 지점을 1곳으로 제한
