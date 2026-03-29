---
tags: [dashboard, today, phase2, hero, quick-actions, progress-ring, intelligence, recap]
date: 2026-03-29
category: plan
status: approved
---

# Today Tab Phase 2: Intermediate Enhancements

## Overview

Today 탭 Phase 1 (섹션 통합) 위에 5개 기능을 추가하여 대시보드를 개인화된 코칭 허브로 진화시킨다.

## Affected Files

| File | Change Type | Description |
|------|------------|-------------|
| `Domain/UseCases/CoachingEngine.swift` | Modify | 시간대별 적응형 메시지 생성 |
| `Domain/Models/CoachingInsight.swift` | Modify | `AdaptiveHeroMessage` 구조체 추가 |
| `Presentation/Dashboard/DashboardViewModel.swift` | Modify | 5개 기능 데이터 로딩 + 상태 관리 |
| `Presentation/Dashboard/DashboardView.swift` | Modify | 새 섹션 3개 배치 |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | Modify | 적응형 메시지 표시 |
| `Presentation/Dashboard/Components/QuickActionsRow.swift` | **New** | 빠른 동작 가로 스크롤 |
| `Presentation/Dashboard/Components/DailyProgressRingCard.swift` | **New** | 3대 미니 링 |
| `Presentation/Dashboard/Components/ExerciseIntelligenceCard.swift` | **New** | 추천 근거 카드 |
| `Presentation/Dashboard/Components/YesterdayRecapCard.swift` | **New** | 어제 한 줄 요약 |
| `Shared/Resources/Localizable.xcstrings` | Modify | en/ko/ja 번역 추가 |
| `DUNETests/AdaptiveHeroMessageTests.swift` | **New** | 시간대별 메시지 테스트 |
| `DUNETests/DailyProgressRingTests.swift` | **New** | 링 진행률 계산 테스트 |

## Implementation Steps

### Step 1: Adaptive Hero Message (Domain + Presentation)

**목표**: 시간대 + 컨디션 상태에 따라 히어로 메시지를 동적 생성

**Domain 변경**:
- `CoachingEngine`에 `generateAdaptiveHeroMessage(hour:conditionScore:sleepDebt:todayWorkoutDone:)` 메서드 추가
- 시간대 구간: 06-10 (아침), 10-14 (오전), 14-18 (오후), 18-22 (저녁), 22-06 (밤)
- 각 구간별 상태 조합으로 메시지 결정 (기존 `narrativeMessage` 패턴 활용)
- 반환 타입: `AdaptiveHeroMessage(icon: String, message: String)`
- `String(localized:)` 사용, en/ko/ja 번역

**Presentation 변경**:
- `DashboardViewModel`에 `adaptiveHeroMessage` stored property 추가
- `ConditionHeroView`의 narrative 영역에 적응형 메시지 표시 (기존 `narrativeMessage` 대체 시 fallback 유지)

**테스트**:
- `AdaptiveHeroMessageTests.swift`: 각 시간대별 × 상태별 메시지 생성 검증
- 경계값: 06시 정각, 22시 정각

### Step 2: Quick Actions Row (Presentation)

**목표**: Hero 아래 가로 스크롤 Quick Actions 4개

**구현**:
- `QuickActionsRow.swift` 새 파일
- 4개 고정 액션: 운동 시작, 수면 기록 (MetricDetail sleep), 체중 기록 (BodyCompositionFormSheet), 자세 촬영
- 각 액션: SF Symbol + 라벨 (pill shape button)
- `ScrollView(.horizontal, showsIndicators: false)` + `HStack(spacing: DS.Spacing.sm)`
- 탭 → 각 시트/뷰 열기 (callback 방식, DashboardView에서 `.sheet`/`.navigationDestination` 연결)
- 순서 정렬: 고정 순서 (MVP). Future: `QuickStartPopularityService` 활용

**DashboardView 배치**: Hero 직후, TodayBriefCard 이전

**접근성**: `"dashboard-quick-actions-{action}"` identifier

### Step 3: Daily Progress Ring Card (Domain + Presentation)

**목표**: 활동/수면/습관 3대 미니 링 표시

**Domain 데이터 수집** (DashboardViewModel에서 기존 데이터 재활용):
1. **활동 링**: `sortedMetrics.first { $0.category == .steps }?.value` / 10000 (기본 목표). 이미 `todaySteps`로 로딩됨
2. **수면 링**: `sortedMetrics.first { $0.category == .sleep }?.value` / 480 (8시간 목표 = 480분). 이미 sleep metric 로딩됨
3. **습관 링**: `LifeViewModel` 데이터와 같은 소스. `HabitLog` count 기반 계산이 필요하므로 `DashboardViewModel`에 습관 완료율 로딩 추가 (SwiftData `@Query`는 View에서만 가능 → `modelContext`에서 직접 fetch)

**주의**: 습관 데이터는 View에서 `@Query`로 가져오거나, ViewModel에 `habitCompletionRate: Double` 프로퍼티를 두고 View에서 `@Query` 결과를 전달하는 패턴 사용. Layer boundary 준수: ViewModel은 SwiftData import 금지.

**Presentation**:
- `DailyProgressRingCard.swift` 새 파일
- `HStack(spacing: DS.Spacing.lg)` 내 3개 미니 링
- 각 링: `ProgressRingView(progress:ringColor:lineWidth:size:)` (size: 48, lineWidth: 6)
- 링 아래: 아이콘 + 수치 텍스트
- 링 색상: 활동=DS.Color.activityCardio, 수면=DS.Color.sleepPrimary(또는 적절한 토큰), 습관=DS.Color.habitPrimary
- `InlineCard` 래퍼로 통일

**DashboardView 배치**: QuickActionsRow 아래, TodayBriefCard 이전

### Step 4: Exercise Intelligence Card (Presentation)

**목표**: 운동 추천 근거를 투명하게 표시

**데이터 소스**: 기존 `DashboardViewModel.workoutSuggestion: WorkoutSuggestion?`
- `reasoning`: 이미 존재 (한 줄 요약)
- `focusMuscles`: 이미 존재
- `exercises`: 이미 존재

**추가 데이터** (DashboardViewModel 확장):
- 근육 피로 상태 (fatigue level) → `CoachingInput`에 이미 `fatigueStates` 존재하지만 빈 배열. `FatigueCalculationService`에서 로딩 필요
- 미사용 일수 → `WorkoutRecommendationService`가 내부적으로 사용. `WorkoutSuggestion`에 `reasoningDetails: [ReasoningDetail]` 추가하여 구조화된 근거 제공

**구현**:
- `ExerciseIntelligenceCard.swift` 새 파일
- Header: "오늘의 추천" + 타겟 아이콘
- 추천 운동 이름 + 강도 + 예상 시간
- 근거 목록 (불릿 포인트, 최대 4개):
  - 근육 피로도 (어제 X 운동)
  - 미사용 근육 N일
  - 컨디션 점수 → 적정 강도
  - 수면 시간 → 회복 상태
- CTA: "이 운동 시작" 버튼 → Activity 탭 운동 시작으로 라우팅
- `InlineCard` 래퍼

**DashboardView 배치**: RecoverySleepCard 이후, SmartInsightsSection 이전 (Zone B)

### Step 5: Yesterday Recap Card (Presentation)

**목표**: 오전(6-12시)에만 어제 운동/수면/컨디션 변화 한 줄 요약

**데이터 수집** (DashboardViewModel):
- 어제 운동: `ExerciseRecord`에서 어제 날짜 필터 (SwiftData → View에서 `@Query` + ViewModel 전달)
- 어제 수면: 이미 `sleepDeficitAnalysis`에 일별 수면 데이터 포함
- 컨디션 변화: `recentScores`에서 어제 → 오늘 delta

**구현**:
- `YesterdayRecapCard.swift` 새 파일
- 한 줄 요약: "🏋️ {운동 타입} {시간}분 · 🛏️ {수면 시간} 수면"
- 둘째 줄: "컨디션 {어제} → {오늘} ({delta})"
- 오전 6-12시에만 표시: `DashboardViewModel`에 `shouldShowYesterdayRecap: Bool` computed property
- 운동 없으면 "쉬는 날" 표시
- `InlineCard` 래퍼

**DashboardView 배치**: Hero 직후, QuickActionsRow 이전 (오전에만)

### Step 6: Localization

모든 새 문자열을 `Localizable.xcstrings`에 en/ko/ja 3개 언어 동시 등록.

### Step 7: Unit Tests

- `AdaptiveHeroMessageTests.swift`: 시간대 × 상태 행렬
- `DailyProgressRingTests.swift`: 진행률 계산 (0, 경계, 초과)

## Final Section Order

| Zone | # | Component | New? |
|------|---|-----------|------|
| A | 0 | Condition Hero (+ adaptive message) | Modified |
| A | 1 | Yesterday Recap Card (06-12시만) | **NEW** |
| A | 2 | Quick Actions Row | **NEW** |
| A | 3 | Daily Progress Ring Card | **NEW** |
| A | 4 | Today's Brief | Existing |
| B | 5 | Recovery & Sleep | Existing |
| B | 6 | Exercise Intelligence Card | **NEW** |
| B | 7 | Smart Insights | Existing |
| B | 8 | Health Q&A | Existing |
| C | 9+ | Pinned/Condition/Activity/Body | Existing |

## Test Strategy

1. **Unit Tests**: AdaptiveHeroMessage 시간대별 로직, DailyProgressRing 계산
2. **Build Verification**: `scripts/build-ios.sh`
3. **UI Tests**: 새 카드 존재 확인 + 접근성 식별자

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 습관 데이터 없을 때 링 표시 | 습관 0개면 링 숨김 (2링만 표시) |
| 어제 운동 없을 때 Recap | "쉬는 날" 메시지 |
| 컨디션 점수 없을 때 Hero 메시지 | 기존 `narrativeMessage` fallback |
| WorkoutSuggestion nil일 때 Intelligence Card | 카드 자체 숨김 |
| 밤 시간대(22-06) Quick Actions | 운동 시작 버튼 유지 (사용자 자율) |
| 스크롤 길이 증가 | 조건부 표시로 최소화 (Recap=오전만, Intelligence=추천 있을 때만) |
