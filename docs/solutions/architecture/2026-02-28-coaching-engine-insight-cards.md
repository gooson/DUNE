---
tags: [coaching, insight-cards, today-tab, priority-system, trend-analysis, dismiss-store]
category: architecture
date: 2026-02-28
severity: important
related_files:
  - DUNE/Domain/UseCases/CoachingEngine.swift
  - DUNE/Domain/Models/CoachingInsight.swift
  - DUNE/Domain/Models/TrendDirection.swift
  - DUNE/Domain/Services/TrendAnalysisService.swift
  - DUNE/Data/Persistence/InsightCardDismissStore.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Shared/Models/InsightCardData.swift
  - DUNE/Presentation/Dashboard/Components/TodayCoachingCard.swift
  - DUNE/Presentation/Dashboard/Components/InsightCardView.swift
  - DUNE/Presentation/Dashboard/Components/WorkoutRecommendationCard.swift
related_solutions: []
---

# Solution: CoachingEngine + Insight Cards for Today Tab

## Problem

### Symptoms

- Today 탭의 코칭 메시지가 5개의 정적 영어 패턴으로 제한됨
- 사용자 상태(HRV 트렌드, 수면 부족, 운동 빈도)에 따른 맞춤 조언 부재
- Today 탭에 실용적 정보(워크아웃 추천, 수면 인사이트 등)가 없음

### Root Cause

- 코칭 로직이 ConditionScore 숫자 기반 단순 분기로만 구성됨
- 트렌드 분석 서비스 부재 (HRV/수면 연속 방향성 감지 불가)
- 인사이트 카드 시스템(표시, 우선순위, 해제) 미구현

## Solution

3계층 Dashboard Architecture로 Today 탭을 재구성:

- **Layer 1**: Hero Score + Focus Coaching Message (최고 우선순위 인사이트)
- **Layer 2**: Dynamic Insight Cards (최대 3장, 우선순위순)
- **Layer 3**: Pinned Metrics Dashboard (기존)

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `CoachingEngine.swift` | 신규 — 9단계 우선순위 엔진 (P1-P9) | 40+ 한국어 템플릿, 5개 트리거 evaluator |
| `CoachingInsight.swift` | 신규 — InsightPriority, InsightCategory, CoachingInsight 모델 | Domain 계층 인사이트 표현 |
| `TrendDirection.swift` | 신규 — TrendDirection enum + TrendAnalysis struct | 연속 방향성 감지 결과 모델 |
| `TrendAnalysisService.swift` | 신규 — 3일+ 연속 방향 감지 | HRV/수면 트렌드 분석 |
| `InsightCardDismissStore.swift` | 신규 — @MainActor, 캐시, 일괄 접근, 자동 정리 | 일별 카드 해제 상태 관리 |
| `InsightCardData.swift` | 신규 — Presentation DTO | Domain CoachingInsight → SwiftUI 브릿지 |
| `DashboardViewModel.swift` | 수정 — buildCoachingInsights() 추가 | 코칭 엔진 통합, 인사이트 카드 생성 |
| `DashboardView.swift` | 수정 — insightCardsSection 추가 | 인사이트 카드 UI 렌더링 |
| `TodayCoachingCard.swift` | 수정 — CoachingInsight init 추가 | 카테고리별 아이콘/색상 |
| `InsightCardView.swift` | 신규 — 범용 인사이트 카드 UI | 해제 버튼 포함 |
| `WorkoutRecommendationCard.swift` | 신규 — 워크아웃 추천 카드 | 근육 태그, 운동 목록, CTA |

### Key Code

**Priority System (CoachingEngine)**:
```swift
// P1: Critical recovery warning (condition < 20 + falling HRV)
// P2: Recovery warning OR severe sleep deficit
// P3-P4: Training nudges, goal tracking
// P5-P6: Sleep insights (low/good)
// P7: Inactivity warning
// P8: Motivation (streak milestone, PR celebration)
// P9: Fallback (always produces output)
```

**InsightCardDismissStore Pattern**:
```swift
@MainActor
final class InsightCardDismissStore {
    // Cached dismissed IDs per date → avoid repeated UserDefaults reads
    private var cachedDismissedIDs: Set<String> = []
    private var cachedDate: String = ""

    // Batch access for ViewModel
    func dismissedIDs(on date: Date = Date()) -> Set<String>

    // Throttled cleanup (once per day)
    private func cleanupStaleEntriesIfNeeded()
}
```

**TrendAnalysis**:
```swift
// 3+ consecutive days same direction = trend detected
struct TrendAnalysis: Sendable {
    let direction: TrendDirection  // .rising, .falling, .stable
    let consecutiveDays: Int
    let changePercent: Double
    static let insufficient = TrendAnalysis(direction: .stable, consecutiveDays: 0, changePercent: 0)
}
```

## Prevention

### Checklist Addition

- [ ] 새 인사이트 카테고리 추가 시 `InsightCategory` enum + `TodayCoachingCard` icon switch + `InsightCardView` color switch 3곳 동시 수정
- [ ] `weeklyGoalDays=0` 시나리오 테스트 포함 (false positive 방지)
- [ ] `formatHoursMinutes` 등 시간 포맷 함수에 0-1440 범위 클램핑

### Rule Addition

- `InsightCardDismissStore`는 `@MainActor`로 격리. ViewModel과 동일 actor에서 접근
- UserDefaults 기반 일별 상태는 캐시 + 일괄 접근 패턴 사용
- 인사이트 카드 icon color switch가 2곳 이상 중복 시 `InsightCategory+View.swift` 추출 필요 (P3 TODO)

## Lessons Learned

1. **Priority 기반 엔진은 확장에 강함**: 새 트리거 추가 시 적절한 P-level에 삽입하면 기존 로직에 영향 없음
2. **@MainActor dismiss store가 @unchecked Sendable보다 안전**: ViewModel이 @MainActor이므로 같은 actor에서 접근 보장
3. **batch dismissedIDs()로 N회 → 1회 UserDefaults 읽기**: 카드 3장 × isDismissed() = 3회 읽기를 1회로 줄임
4. **weeklyGoalDays=0 guard 필수**: 목표 미설정 사용자에게 "목표 달성" 표시는 신뢰 하락
5. **volatilityRatio NaN 방어**: avgValue=0일 때 나눗셈 결과가 NaN → isFinite 체크 필수
