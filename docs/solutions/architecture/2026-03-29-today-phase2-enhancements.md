---
tags: [dashboard, today, phase2, adaptive-hero, quick-actions, progress-ring, intelligence-card, recap]
date: 2026-03-29
category: architecture
status: implemented
---

# Today Tab Phase 2: Intermediate Enhancements

## Problem

Today 탭 Phase 1에서 섹션 통합(13→9)이 완료되었지만, 대시보드가 여전히 정적 지표 나열에 머물러 시간대별 맥락 제공, 빠른 액션 진입, 추천 근거 투명화가 부족.

## Solution

5개 기능을 추가하여 코칭 허브로 진화:

### 1. Adaptive Hero Message
- `CoachingEngine.generateAdaptiveHeroMessage(hour:conditionScore:sleepDebtMinutes:todayWorkoutDone:)`
- 5개 시간대 구간 (morning/midday/afternoon/evening/night) × 상태 조합
- 기존 `narrativeMessage` fallback 유지
- `ConditionHeroView`에 `adaptiveMessage: AdaptiveHeroMessage?` 파라미터 추가

### 2. Quick Actions Row
- `QuickActionsRow.swift`: 가로 스크롤 capsule 버튼 4개
- 액션: Log Weight → MetricDetail, Sleep → MetricDetail, Briefing → Sheet, Ask AI → Sheet
- 탭 전환이 필요한 액션(운동 시작 등)은 Dashboard 범위 외이므로 제외

### 3. Daily Progress Ring Card
- `DailyProgressRingCard.swift`: ProgressRingView 기반 미니 링 (48pt, lineWidth 6)
- Steps(10K 목표), Sleep(8h 목표) 2링 + 습관 링(nil → 향후 확장)
- **중요**: 값은 ViewModel에서 pre-compute (`todayStepsValue`, `todaySleepMinutes`)

### 4. Exercise Intelligence Card
- `ExerciseIntelligenceCard.swift`: 기존 `WorkoutSuggestion` 데이터 재활용
- 추천 근거(reasoning) + 컨디션/수면 기반 부가 설명
- CTA 버튼 (현재는 noop — 탭 전환 필요)

### 5. Yesterday Recap Card
- `YesterdayRecapCard.swift`: 06-12시에만 표시
- 어제 운동 요약 + 수면 시간 + 컨디션 delta
- `shouldShowYesterdayRecap`은 stored property로 `buildYesterdayRecap()`에서 pre-compute

## Key Decisions

1. **ViewModel pre-computation**: `sortedMetrics.first(where:)` 같은 O(N) 탐색을 body에서 반복하지 않도록 `todayStepsValue`, `todaySleepMinutes`, `shouldShowYesterdayRecap` 등을 stored property로 유지
2. **습관 링 미구현**: HabitLog @Query를 DashboardView에 추가하면 SwiftData 의존성이 증가. 향후 LifeViewModel 데이터 공유 구조 설계 시 추가
3. **Quick Actions 범위**: Dashboard 내에서 열 수 있는 sheet/navigation만 포함. 탭 전환이 필요한 "운동 시작"은 제외 (Correction #226: TabView 바깥 NavigationStack 금지)
4. **sleep debt threshold**: `weeklyDeficit`은 7일 누적값이므로 per-night 60분이 아니라 weekly 120분(2시간)을 threshold로 사용

## Prevention

- Dashboard body에서 `sortedMetrics.first(where:)` 새로 호출하지 말 것 — ViewModel stored property 사용
- 시간 기반 표시/숨김 로직은 `buildX()` 메서드에서 pre-compute
- 새 카드 추가 시 `sectionVisibilityHash`에 관련 프로퍼티 포함
- `navigationDestination(item:)` 추가 시 동일 타입 기존 destination 확인 → 하나로 통합
