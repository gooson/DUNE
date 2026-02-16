---
tags: [dry, duplication, highlight-builder, shared-utility, isDistanceBased, workout-summary, domain-model]
category: architecture
date: 2026-02-16
severity: critical
related_files:
  - Dailve/Presentation/Shared/HighlightBuilder.swift
  - Dailve/Domain/Models/HealthMetric.swift
  - Dailve/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - Dailve/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - Dailve/Presentation/Dashboard/DashboardViewModel.swift
related_solutions: []
---

# Solution: 중복 코드 추출 패턴 (HighlightBuilder + WorkoutSummary)

## Problem

### Symptoms

- `buildHighlights()` — MetricDetailViewModel과 ConditionScoreDetailViewModel에 거의 동일한 35줄 로직 중복
- `isDistanceBased` / `workoutIcon()` — DashboardViewModel, MetricDetailViewModel, ExerciseListSection 3곳에 동일 로직

### Root Cause

기능 개발 시 "일단 동작하게" 만들고 추출을 미룸. ViewModel마다 독립 구현하면서 자연 발생한 중복.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HighlightBuilder.swift` (NEW) | `buildHighlights(from:)`, `computeTrend(from:)` static 메서드 | Presentation 공통 유틸 |
| `MetricDetailViewModel.swift` | `buildHighlights()` → `HighlightBuilder.buildHighlights(from:)` 1줄 | 중복 제거 |
| `ConditionScoreDetailViewModel.swift` | 동일, `highLabel`/`lowLabel` 커스텀 | 중복 제거 + 유연성 |
| `HealthMetric.swift` | `WorkoutSummary.isDistanceBasedType(_:)`, `.iconName(for:)` 추가 | Domain 단일 소스 |
| `DashboardViewModel.swift` | 50줄 `isDistanceBased()`/`workoutIcon()` 제거 → `WorkoutSummary` 사용 | 중복 제거 |

### Key Code

```swift
// Pattern: Shared utility with customization via parameters
enum HighlightBuilder {
    static func buildHighlights(
        from data: [ChartDataPoint],
        highLabel: String = "Highest",
        lowLabel: String = "Lowest"
    ) -> [Highlight] { ... }
}

// Pattern: Domain model에 static helper
struct WorkoutSummary {
    static func isDistanceBasedType(_ type: String) -> Bool { ... }
    static func iconName(for type: String) -> String { ... }
}
```

### 추출 판단 기준

| 조건 | 위치 |
|------|------|
| 2개+ ViewModel에서 동일 로직 | `Presentation/Shared/` utility |
| 도메인 모델의 속성/분류 로직 | Domain model의 static method |
| UI 포맷팅 로직 | `Presentation/Shared/Extensions/{Type}+View.swift` |

## Prevention

### Checklist Addition

- [ ] 새 ViewModel 추가 시 기존 VM의 `buildHighlights`, `computeTrend` 등 유사 메서드 검색
- [ ] 워크아웃 타입 분류/아이콘 로직은 `WorkoutSummary`에 추가

### Rule Addition (if applicable)

`.claude/rules/`에 추가 고려:
- "2곳 이상 동일 로직 → shared utility 추출" 규칙 (correction log #9와 유사)

## Lessons Learned

- 중복 코드는 div/0 같은 버그가 한 곳만 수정되고 다른 곳은 누락되는 위험을 만듦
- `HighlightBuilder`처럼 enum + static 메서드는 인스턴스 생성 없이 사용 가능해서 유틸에 적합
- `WorkoutSummary`에 static helper를 두면 Domain 레이어 규칙도 지키면서 단일 소스 확보
