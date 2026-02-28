---
tags: [today-tab, coaching, insights, phase-1]
date: 2026-02-28
category: plan
status: approved
---

# Plan: 투데이탭 코칭 강화 Phase 1

## Summary

투데이탭의 코칭 메시지를 5개 → 40개+ 템플릿으로 다양화하고,
운동 추천/수면 인사이트/근육 회복 상태를 동적 Insight Card로 표시한다.

## Implementation Steps

### Step 1: Domain Models (신규 파일 3개)

**1-A. `TrendDirection.swift`** → `Domain/Models/`
- `enum TrendDirection: Sendable { case rising, falling, stable, volatile, insufficient }`
- `struct TrendAnalysis: Sendable` — metric, direction, consecutiveDays, changePercent

**1-B. `CoachingInsight.swift`** → `Domain/Models/`
- `enum InsightPriority: Int, Comparable` (P1=1 ~ P9=9)
- `enum InsightCategory` (recovery, training, sleep, motivation, recap)
- `struct CoachingInsight: Sendable, Identifiable` — id, priority, category, title, message, iconName, actionHint?

**1-C. `WorkoutRecommendation.swift`** → `Domain/Models/`
- `enum RecommendedIntensity` (rest, low, moderate, high, peak)
- `struct WorkoutRecommendation: Sendable` — intensity, targetMuscles, avoidMuscles, suggestedExercises, reasoning

### Step 2: Domain Services (신규 파일 2개)

**2-A. `TrendAnalysisService.swift`** → `Domain/Services/`
- `func analyzeTrend(values: [(date: Date, value: Double)], windowDays: Int) -> TrendDirection`
- 3일 연속 방향 일치 → rising/falling, 그 외 stable/volatile
- guards: empty input → .insufficient, < 3 values → .insufficient

**2-B. `CoachingEngine.swift`** → `Domain/UseCases/`
- Input: ConditionScore?, [CompoundFatigueScore], SleepScore?, WorkoutStreak, TrendAnalysis(hrv), TrendAnalysis(sleep), recentExerciseRecords
- Output: (focusMessage: CoachingInsight, insightCards: [CoachingInsight])
- 우선순위 P1→P9 순서로 평가, 첫 매칭이 focusMessage
- 나머지 매칭 중 상위 3개가 insightCards
- 40개+ 템플릿을 내부 배열로 정의 (한국어)

### Step 3: Presentation Models (신규 파일 2개)

**3-A. `InsightCardData.swift`** → `Presentation/Shared/Models/`
- `struct InsightCardData: Identifiable, Hashable, Sendable`
- Properties: id, category, title, message, iconName, iconColor, actionType?, priority, isDismissed

**3-B. `InsightCardDismissStore.swift`** → `Data/Persistence/`
- UserDefaults 기반, 날짜별 dismiss 상태
- `func isDismissed(cardID: String, on date: Date) -> Bool`
- `func dismiss(cardID: String, on date: Date)`
- 자동 cleanup: 3일 이전 entries 삭제

### Step 4: Presentation Views (신규 파일 2개 + 기존 수정 3개)

**4-A. `InsightCardView.swift`** → `Presentation/Dashboard/Components/` (신규)
- 범용 인사이트 카드 뷰 (InlineCard 래퍼 사용)
- dismiss 스와이프 지원
- icon + title + message + optional action button

**4-B. `WorkoutRecommendationCard.swift`** → `Presentation/Dashboard/Components/` (신규)
- 운동 추천 전용 카드
- 강도 표시 (dots), 부위 태그, 추천 운동명
- "운동 시작하기" 액션

**4-C. `DashboardViewModel.swift`** 수정
- 새 프로퍼티: `insightCards: [InsightCardData]`, `focusMessage: CoachingInsight?`
- `loadData()` 마지막에 CoachingEngine 호출
- TrendAnalysisService로 HRV/수면 트렌드 계산
- 기존 `buildCoachingMessage()` → CoachingEngine으로 대체

**4-D. `DashboardView.swift`** 수정
- Hero 아래, 메트릭 위에 InsightCard 섹션 삽입
- ForEach(insightCards) { InsightCardView(data:) }
- dismiss 핸들링

**4-E. `TodayCoachingCard.swift`** 수정
- `CoachingInsight` 기반으로 확장 (아이콘, 트렌드 뱃지)

### Step 5: Tests (신규 파일 2개)

**5-A. `TrendAnalysisServiceTests.swift`**
- rising/falling/stable/insufficient 케이스
- 경계값 (정확히 3일, empty 입력)

**5-B. `CoachingEngineTests.swift`**
- 우선순위 P1이 P9보다 먼저 선택되는지
- 각 시그널(warning, sleep debt, fatigue high 등) 매칭
- 데이터 없음 → 기본 메시지 fallback

## Affected Files

| 파일 | Action | 변경 내용 |
|------|--------|----------|
| Domain/Models/TrendDirection.swift | NEW | 트렌드 모델 |
| Domain/Models/CoachingInsight.swift | NEW | 코칭 인사이트 모델 |
| Domain/Models/WorkoutRecommendation.swift | NEW | 운동 추천 모델 |
| Domain/Services/TrendAnalysisService.swift | NEW | 트렌드 분석 |
| Domain/UseCases/CoachingEngine.swift | NEW | 코칭 엔진 (40+ 템플릿) |
| Presentation/Shared/Models/InsightCardData.swift | NEW | 카드 DTO |
| Data/Persistence/InsightCardDismissStore.swift | NEW | dismiss 저장 |
| Presentation/Dashboard/Components/InsightCardView.swift | NEW | 범용 인사이트 카드 |
| Presentation/Dashboard/Components/WorkoutRecommendationCard.swift | NEW | 운동 추천 카드 |
| Presentation/Dashboard/DashboardViewModel.swift | MODIFY | 코칭 엔진 통합 |
| Presentation/Dashboard/DashboardView.swift | MODIFY | 인사이트 섹션 추가 |
| Presentation/Dashboard/Components/TodayCoachingCard.swift | MODIFY | CoachingInsight 기반 |
| DUNETests/TrendAnalysisServiceTests.swift | NEW | 트렌드 테스트 |
| DUNETests/CoachingEngineTests.swift | NEW | 코칭 엔진 테스트 |
| Dailve/project.yml | MODIFY | 신규 파일 등록 (자동) |
