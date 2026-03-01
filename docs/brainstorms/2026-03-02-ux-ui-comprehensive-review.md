---
tags: [ux, ui, design, review, comprehensive, oura, whoop, apple-health]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: UX/UI 종합 재점검

## Problem Statement

DUNE 앱은 기능적으로 풍부하지만 **데이터 소비 중심** 설계로 인해 사용자 행동을 유도하지 못한다.
Oura/WHOOP/Apple Health와 비교했을 때 핵심 차이:

- **Actionability 부족**: 대시보드가 읽기 전용, "다음에 뭘 해야 하지?"에 답하지 않음
- **정보 계층 불명확**: 14개 메트릭이 동일한 시각적 무게로 나열됨
- **탭 간 완성도 불균형**: Activity(8개 섹션) vs Life(1개 리스트)
- **첫 사용자 경험 미비**: 빈 화면에서 행동 유도가 없음

## Benchmarks

| 앱 | 강점 | DUNE에 적용할 점 |
|----|------|----------------|
| **Oura** | Readiness → 1문장 설명 → 행동 제안, Sleep Score 직관적 | 스코어에 "왜?" + "그래서?" 추가 |
| **WHOOP** | Strain/Recovery 밸런스, "Log Workout" 1탭 접근 | 운동 시작 CTA를 hero 영역에 배치 |
| **Apple Health** | Summary 커스터마이징, Favorites, progressive disclosure | 메트릭 우선순위 + 개인화 |

---

## 발견 사항: 탭별 분석

### Tab 1: Today (Dashboard)

#### P1 — Critical

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| D1 | **Hero 스코어에 컨텍스트 없음** | "72" 숫자만 표시 | "Good recovery — HRV slightly below baseline" 1줄 narrative 추가 |
| D2 | **행동 유도 제로** | 전체가 읽기 전용 | Hero 하단에 "Start Workout" / "Log Weight" Quick Action 버튼 |
| D3 | **코칭 카드에 CTA 없음** | 텍스트만 있는 인사이트 카드 | "View Details" / "Got It" 액션 버튼 추가 |

#### P2 — Important

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| D4 | **코칭이 3가지 형태로 분산** | WeatherCard 내, TodayCoachingCard, InsightCardView | 단일 "Today's Focus" 섹션으로 통합 |
| D5 | **Stale 데이터 표현 모호** | opacity 0.6 + 선택적 freshness label | 명시적 "3일 전 측정" 레이블 항상 표시 |
| D6 | **Historical fallback이 조용함** | 오래된 체중 데이터를 현재처럼 표시 | "Last measured: Feb 27" 명시 |
| D7 | **iPad에서 공간 낭비** | 날씨 카드 full-width, 2열 고정 | 3열 또는 날씨+코칭 병렬 배치 |
| D8 | **Pinned Metrics가 시각적으로 구분 안됨** | 같은 카드 스타일, pin 아이콘만 차이 | 배경색 또는 위치로 구분 |

#### P3 — Minor

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| D9 | 빈 스파크라인이 대시만 표시 | 데이터 <2개일 때 점선 | "데이터 수집 중" 메시지 |
| D10 | 부분 에러 메시지가 불명확 | "2 of 6 sources failed" | 실패한 소스명 표시 |

---

### Tab 2: Activity (Train)

#### P1 — Critical

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| A1 | **"Start Workout" 버튼이 above-the-fold에 없음** | 툴바 "+" 아이콘만 존재 | Hero 카드 하단에 primary CTA 버튼 |
| A2 | **Suggested Workout이 4번째 섹션** | Muscle Map, Weekly Stats 아래에 위치 | Hero 바로 다음 (position 2)으로 이동 |
| A3 | **Readiness 스코어에 "왜?" 설명 없음** | "72" 숫자 + 3개 서브스코어 | "Limited by: Sleep debt" 또는 "HRV 15% below baseline" |

#### P2 — Important

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| A4 | **Muscle Map이 "뭘 피해야 하는지" 안 보여줌** | 색상 히트맵만 (탭해야 상세) | "Avoid: Chest (24h). Ready: Back, Shoulders" 요약 라인 |
| A5 | **Weekly Stats에 주간 목표 진행률 없음** | Volume, Calories, Duration만 표시 | "3/5 days completed this week" 추가 |
| A6 | **Training Load 차트가 해석 없음** | 숫자 + 변화율만 | "Moderate load — building safely" 텍스트 추가 |
| A7 | **Injury 경고가 Suggested Workout 아래** | Hero → Map → Stats → Injury | Hero 바로 다음으로 이동 |
| A8 | **Recent Workouts이 중복 정보** | Suggested + Recent에 같은 운동 표시 | "Today's Summary" (3 exercises, 45min, 280cal)로 대체 |

#### P3 — Minor

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| A9 | iPad에서 Suggested Workout이 50% width | HStack 배치 | Full-width로 변경 |
| A10 | 첫 사용 시 6개 빈 섹션 동시 표시 | 각각 개별 empty state | "Get Started" 통합 온보딩 |

---

### Tab 3: Wellness

#### P1 — Critical

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| W1 | **14개 메트릭이 동일한 시각적 무게** | 2열 그리드, 모든 카드 동일 스타일 | 3단계 계층: Primary (HRV, Sleep) → Secondary (RHR, Weight) → Tertiary (나머지) |
| W2 | **Wellness Score 가이드 메시지가 기술적** | "가중치가 재정규화됩니다" | "Sleep이 낮아요 — 오늘 일찍 자보세요" 행동 제안 |

#### P2 — Important

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| W3 | **섹션 분류가 의미적으로 불명확** | Physical vs Active Indicators | Sleep / Cardiovascular / Body Composition / Recovery로 재분류 |
| W4 | **메트릭 개인화 불가** | 모든 메트릭 강제 표시 | 관심 메트릭 pin/hide 기능 (Dashboard처럼) |
| W5 | **Progressive onboarding 없음** | 전체 빈 화면 or 전체 표시 | "Sleep 데이터 수집 중 (2/7일)" 단계별 안내 |
| W6 | **Stale 카드가 공간 차지** | opacity 0.6으로 표시 | 7일+ stale → 접기 또는 하단 이동 |
| W7 | **HRV 접근 경로 2개, 컨텍스트 다름** | Hero → Wellness Detail vs Card → Metric Detail | 명확한 information architecture 정리 |

#### P3 — Minor

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| W8 | Sleep이 "Active Indicators"에 분류됨 | 코드상 active section | Sleep 독립 섹션으로 분리 |
| W9 | Detail view에 baseline 비교 시각화 없음 | 차트만 표시 | "Your average" 기준선 오버레이 |

---

### Tab 4: Life (Habits)

#### P1 — Critical

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| L1 | **다른 탭 대비 현저히 얕은 깊이** | Hero(ring) + flat list, 0개 detail page | Stats 섹션 추가: "This Week", "Best Streaks", "Completion Rate" |
| L2 | **Icon picker가 Form에 연결 안됨** | HabitIconPicker 컴포넌트 존재하나 HabitFormSheet에서 미사용 | Form에 아이콘 선택 섹션 통합 |
| L3 | **Empty state에 행동 유도 없음** | "No Habits Yet" 텍스트만 | "Create First Habit" 버튼 + 템플릿 제안 |

#### P2 — Important

| # | 문제 | 현재 | 개선안 |
|---|------|------|--------|
| L4 | **Hero가 HeroCard 아닌 StandardCard 사용** | 시각적으로 다른 탭 hero와 불일치 | HeroCard 또는 동등한 시각적 무게의 컴포넌트 사용 |
| L5 | **SectionGroup 미사용** | 습관 리스트가 flat | "Today's Progress" / "Weekly Overview" 섹션 그룹핑 |
| L6 | **습관 트렌드/히스토리 없음** | 현재 상태만 표시 | 7일 완료율 스파크라인, 월간 히트맵 |
| L7 | **selectedIconCategory 하드코딩** | `.health`로 고정, UI 변경 불가 | Form에서 카테고리 선택 가능하게 |

---

## 크로스탭 공통 문제

### CC1: Actionability Gap (전 탭 공통)

**현재**: 4개 탭 모두 **데이터 소비** 중심. 사용자가 "봤다 → 닫는다" 패턴.
**개선**: 각 탭에 1개의 Primary CTA:

| Tab | Primary CTA | 위치 |
|-----|------------|------|
| Today | "Log Weight" / "Start Workout" | Hero 하단 |
| Activity | "Start Workout" | Hero 하단 |
| Wellness | "Log Body Composition" | Hero 하단 |
| Life | "Check Today's Habits" | Hero 하단 |

### CC2: Score Narrative 부재 (Today, Activity, Wellness)

**현재**: 숫자 스코어만 표시. "72"가 좋은 건지 나쁜 건지 즉시 이해 불가.
**개선**: 모든 Hero Score에 1줄 narrative:
- "Excellent — best in 7 days"
- "Below average — HRV dropped 15%"
- "Improving — 3-day upward trend"

### CC3: Empty State 불일치

**현재**: 탭마다 다른 empty state 품질 (Dashboard: 액션 버튼 있음, Life: 없음)
**개선**: 통일된 EmptyStateView + 항상 CTA 버튼 포함

### CC4: 탭 깊이 불균형

```
Activity ████████████████████  (8+ sections, 10+ detail pages)
Dashboard ██████████████████   (5 sections, metrics, insights)
Wellness  ██████████████       (2 sections, limited detail)
Life      █████                (1 list, no detail pages)
```

**개선 방향**: Wellness와 Life에 depth 추가 (stats, trends, insights)

### CC5: iPad 최적화 미흡

**현재**: 모든 탭이 2열 고정. iPad에서 화면 낭비.
**개선**: Regular size class에서 3열 또는 master-detail 레이아웃

---

## 개선 제안: 우선순위별 로드맵

### Phase 1: Quick Wins (1-2일 작업, 큰 효과)

| ID | 작업 | 영향받는 파일 | 효과 |
|----|------|-------------|------|
| QW1 | Hero 스코어에 1줄 narrative 추가 | ConditionHeroView, TrainingReadinessHeroCard, WellnessHeroCard | 스코어 즉시 이해 가능 |
| QW2 | Activity: Suggested Workout을 position 2로 이동 | ActivityView.swift | 운동 시작 접근성 ↑ |
| QW3 | Activity: Injury warning을 hero 바로 아래로 이동 | ActivityView.swift | 안전 정보 가시성 ↑ |
| QW4 | Stale 데이터에 명시적 날짜 레이블 | VitalCard.swift | 데이터 신뢰도 ↑ |
| QW5 | Life: Empty state에 "Create Habit" 버튼 추가 | LifeView.swift | 첫 사용 경험 ↑ |

### Phase 2: Medium Effort (3-5일 작업)

| ID | 작업 | 영향받는 파일 | 효과 |
|----|------|-------------|------|
| ME1 | 각 탭 Hero에 Primary CTA 버튼 추가 | 4개 Hero 컴포넌트 | Actionability ↑↑ |
| ME2 | Wellness 메트릭 3단계 계층화 | WellnessView, VitalCard, WellnessViewModel | 인지 부하 ↓ |
| ME3 | Wellness 섹션 재분류 (Sleep/Cardio/Body/Recovery) | VitalCardData, WellnessView | 정보 구조 ↑ |
| ME4 | Dashboard 코칭 통합 ("Today's Focus" 단일 섹션) | DashboardView, 관련 컴포넌트 | 시각적 혼란 ↓ |
| ME5 | Life: Icon picker를 Form에 통합 | HabitFormSheet, LifeViewModel | Form 완성도 ↑ |
| ME6 | Activity: Muscle Map 요약 라인 추가 | MuscleRecoveryMapView | 스캔 가능성 ↑ |

### Phase 3: Major Effort (1-2주 작업)

| ID | 작업 | 영향받는 파일 | 효과 |
|----|------|-------------|------|
| MJ1 | Life 탭 depth 확장 (stats, trends, streaks detail) | 새 View + ViewModel 다수 | 탭 균형 ↑ |
| MJ2 | Wellness 메트릭 pin/hide 개인화 | WellnessView, 새 Store | 개인화 ↑ |
| MJ3 | Progressive onboarding 시스템 | 전 탭 empty state 리팩토링 | 첫 사용 경험 ↑↑ |
| MJ4 | iPad adaptive layout (3열, master-detail) | 전 탭 layout 수정 | iPad 경험 ↑ |
| MJ5 | Training Load 해석 엔진 | ActivityViewModel, 새 컴포넌트 | 인사이트 품질 ↑ |

---

## 와이어프레임 수준 개선안

### Today Tab — Before vs After

```
BEFORE:                          AFTER:
┌─────────────────────┐         ┌─────────────────────┐
│  ○ Condition: 72    │         │  ○ Condition: 72    │
│  ━━━━━ sparkline    │         │  "Good — HRV stable"│
│                     │         │  ━━━━━ sparkline    │
│                     │         │  [Start Workout] [Log]│
├─────────────────────┤         ├─────────────────────┤
│  ☁️ Weather Card    │         │  💡 Today's Focus   │
├─────────────────────┤         │  "Rest day advised —│
│  💡 Coaching Card   │         │   HRV trending down"│
├─────────────────────┤         │  [View Details]     │
│  💡 Insight Card    │         ├─────────────────────┤
├─────────────────────┤         │  ☁️ Weather + Tip   │
│  📌 Pinned Metrics  │         ├─────────────────────┤
│  [HRV] [RHR]       │         │  📌 Pinned Metrics  │
│  [Steps] [Sleep]    │         │  [HRV▲] [RHR●]     │
├─────────────────────┤         │  [Steps▼] [Sleep●]  │
│  Condition Metrics  │         ├─────────────────────┤
│  Activity Metrics   │         │  Condition | Activity│
│  Body Metrics       │         │  Body Metrics       │
└─────────────────────┘         └─────────────────────┘
```

### Activity Tab — Before vs After

```
BEFORE:                          AFTER:
┌─────────────────────┐         ┌─────────────────────┐
│  ○ Readiness: 72    │         │  ○ Readiness: 72    │
│  HRV | Sleep | Load │         │  "Ready — Sleep was │
│                     │         │   great, HRV normal"│
├─────────────────────┤         │  [START WORKOUT]    │
│  🏋️ Muscle Map      │         ├─────────────────────┤
│  (full body heatmap)│         │  ⚠️ Injury: Shoulder│
├─────────────────────┤         ├─────────────────────┤
│  📊 Weekly Stats    │         │  💪 Suggested Today │
├─────────────────────┤         │  Bench Press, Squat │
│  ⚠️ Injury Warning  │         │  Avoid: Chest (24h) │
├─────────────────────┤         ├─────────────────────┤
│  💪 Suggested Today │         │  🏋️ Muscle Recovery │
│                     │         │  (map + summary)    │
├─────────────────────┤         ├─────────────────────┤
│  📈 Training Volume │         │  📊 This Week 3/5   │
│  ... (more scroll)  │         │  📈 Training Volume │
└─────────────────────┘         └─────────────────────┘
```

### Wellness Tab — Before vs After

```
BEFORE:                          AFTER:
┌─────────────────────┐         ┌─────────────────────┐
│  ○ Wellness: 78     │         │  ○ Wellness: 78     │
│  Sleep|Condition|Body│         │  "Sleep lagging —   │
│                     │         │   try sleeping early"│
├─────────────────────┤         │  [Log Body Comp]    │
│  Physical Metrics   │         ├─────────────────────┤
│  [Weight] [BMI]     │         │  🌙 Sleep           │
│  [BodyFat] [Lean]   │         │  [Score: 82] ━━━━━  │
├─────────────────────┤         ├─────────────────────┤
│  Active Indicators  │         │  ❤️ Cardiovascular   │
│  [HRV] [RHR]       │         │  [HRV▲] [RHR●]     │
│  [HR] [SpO2]       │         ├─────────────────────┤
│  [RespRate] [VO2]  │         │  🏋️ Body Composition│
│  [HRRecov] [Temp]  │         │  [Weight] [BodyFat] │
│                     │         ├─────────────────────┤
│                     │         │  More ▾             │
│                     │         │  (SpO2, Temp, etc.) │
└─────────────────────┘         └─────────────────────┘
```

### Life Tab — Before vs After

```
BEFORE:                          AFTER:
┌─────────────────────┐         ┌─────────────────────┐
│  Today 3/5          │         │  ○ Today 3/5        │
│  ○ (simple ring)    │         │  "Great progress!   │
│                     │         │   2 more to go"     │
├─────────────────────┤         │  🔥 5-day streak    │
│  □ Meditation  ✓    │         ├─────────────────────┤
│  □ Water 6/8  ━━━   │         │  📋 Today's Habits  │
│  □ Reading    ✓     │         │  □ Meditation  ✓    │
│  □ Stretching       │         │  □ Water 6/8  ━━━   │
│  □ Journal          │         │  □ Reading    ✓     │
│                     │         │  □ Stretching       │
│                     │         ├─────────────────────┤
│                     │         │  📊 This Week       │
│                     │         │  Mon●Tue●Wed○Thu○Fri│
│                     │         │  Completion: 60%    │
│                     │         ├─────────────────────┤
│  (empty space)      │         │  🏆 Best Streaks    │
│                     │         │  Meditation: 12 days│
└─────────────────────┘         └─────────────────────┘
```

---

## Open Questions

1. **메트릭 개인화 범위**: Wellness 메트릭 pin/hide를 Dashboard에도 확장할지?
2. **코칭 엔진 깊이**: "Today's Focus" 통합 시 기존 3가지 코칭 소스를 어떻게 우선순위화?
3. **Life 탭 목표**: 습관 트래킹의 최종 비전 — 단순 체크리스트 vs 건강 지표와 연계된 라이프스타일 관리?
4. **iPad 전략**: 3열 그리드 vs master-detail split vs 현재 유지?
5. **Progressive onboarding**: 데이터 수집 기간(7일)의 UX — 빈 화면을 어떻게 채울지?

## Scope

### MVP (Must-have for initial release)
- Phase 1 전체 (Quick Wins)
- Phase 2에서 ME1 (Hero CTA), ME2 (Wellness 계층화)

### Nice-to-have (Post-release)
- Phase 2 나머지
- Phase 3 전체

## Next Steps

- [ ] 사용자 피드백 후 우선순위 확정
- [ ] Phase 1 항목별 `/plan` 생성
- [ ] 변경 범위 큰 항목 (Life 탭 확장, iPad layout)은 별도 brainstorm
