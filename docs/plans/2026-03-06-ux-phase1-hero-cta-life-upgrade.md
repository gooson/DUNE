---
tags: [ux, hero-card, cta, life-tab, activity-tab, dashboard]
date: 2026-03-06
category: plan
status: approved
---

# Plan: Phase 1 UX — Hero CTA Buttons + Life Hero Upgrade

## Overview

Brainstorm `2026-03-06-ux-research-improvements.md`의 Phase 1 미구현 항목 중 **Hero CTA 버튼 추가** (P1-1)와 **Life 탭 Hero 업그레이드** (L4)를 구현합니다.

### 구현 범위

| ID | 항목 | 변경 내용 |
|----|------|----------|
| P1-1a | Activity Hero에 "Start Workout" CTA | `TrainingReadinessHeroCard` 하단에 primary 버튼 추가 |
| P1-1b | Today Hero에 Quick Action CTA | `ConditionHeroView` 하단에 context-aware CTA 추가 |
| L4 | Life Hero를 HeroCard 스타일로 업그레이드 | `StandardCard` → `HeroCard` + narrative message 추가 |

### 제외 항목 (별도 계획)

- P1-2: 코칭 통합 ("Today's Focus") — 아키텍처 변경이 크므로 별도 /plan 필요
- P1-3: VitalCard 변화율 표시 — 이미 구현됨 (arrow.up.right + change 값)
- P1-5: Stale 데이터 레이블 — 이미 구현됨 (freshnessLabel)

## Affected Files

| File | Change | ID |
|------|--------|----|
| `Presentation/Activity/Components/TrainingReadinessHeroCard.swift` | CTA 버튼 추가 | P1-1a |
| `Presentation/Activity/ActivityView.swift` | CTA action 연결 (showingExercisePicker) | P1-1a |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | Quick action CTA 추가 | P1-1b |
| `Presentation/Dashboard/DashboardView.swift` | CTA action 연결 | P1-1b |
| `Presentation/Life/LifeView.swift` | Hero를 HeroCard 스타일로 변경 + narrative | L4 |
| `Presentation/Life/LifeViewModel.swift` | heroNarrative computed property 추가 | L4 |
| `Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja | ALL |
| `DUNETests/LifeViewModelTests.swift` | heroNarrative 테스트 | L4 |

## Implementation Steps

### Step 1: Activity Hero CTA (P1-1a)

**TrainingReadinessHeroCard**에 "Start Workout" 버튼 추가:

```
┌─────────────────────────────┐
│ ○ 78  Ready to Train         │
│       "Ready — HRV stable"   │
│       [HRV ███ 82] [Sleep ██ 70] │
│                               │
│  [▶ Start Workout]            │ ← NEW: Primary CTA
└─────────────────────────────┘
```

구현:
- `TrainingReadinessHeroCard`에 `onStartWorkout: (() -> Void)?` closure 파라미터 추가
- HeroScoreCard 내부가 아닌, HeroCard content 하단에 독립 버튼 배치
- `readiness`가 nil (empty state)일 때는 CTA 없음
- ActivityView에서 closure로 `showingExercisePicker = true` 연결

### Step 2: Today Hero CTA (P1-1b)

**ConditionHeroView**에 context-aware Quick Action 추가:

```
┌─────────────────────────────┐
│ ○ 82  Good Condition          │
│       "Good — HRV stable"    │
│       [sparkline] 7d          │
│       Weekly Goal: 3/5        │
│                               │
│  [▶ Start Workout]            │ ← NEW: Context CTA
└─────────────────────────────┘
```

구현:
- `ConditionHeroView`에 `onQuickAction: (() -> Void)?` closure 파라미터 추가
- CTA 버튼 label: "Start Workout" (조건 무관하게 가장 높은 빈도 action)
- DashboardView에서 NavigationLink destination을 Activity 탭으로 연결하거나, 직접 exercise picker 열기

### Step 3: Life Hero 업그레이드 (L4)

**현재**: `StandardCard` 안에 "Today's Progress" + 숫자 + ring
**변경**: `HeroCard` 스타일 + completion narrative

```
현재:
┌─ StandardCard ───────────────┐
│  Today's Progress: 3/5  ○48% │
└──────────────────────────────┘

변경:
┌─ HeroCard (tintColor) ──────┐
│  ○ 60%  Life                  │
│  "3 of 5 habits done"        │
│  [▶ Add Habit] (empty only)   │
└──────────────────────────────┘
```

구현:
- `heroSection`에서 `StandardCard` → `HeroCard(tintColor: DS.Color.tabLife)` 변경
- `LifeViewModel`에 `heroNarrative: String` computed property 추가
  - 0/N: "Start your day — N habits waiting"
  - partial: "X of N habits done — keep going!"
  - all done: "All done! Great consistency today"
- `ProgressRingView` 재사용 (기존 Circle 대체)

### Step 4: Localization

새 문자열을 `Localizable.xcstrings`에 en/ko/ja 추가:
- "Start Workout"
- "Start your day — %lld habits waiting"
- "%lld of %lld habits done — keep going!"
- "All done! Great consistency today"

### Step 5: Unit Tests

- `LifeViewModelTests`: heroNarrative 로직 테스트 (0/N, partial, complete)

## Risks

- CTA 버튼이 HeroCard 높이를 늘려서 첫 화면 정보 밀도 감소 → 작은 버튼 스타일 사용 (`.buttonBorderShape(.capsule)` + `.font(.subheadline)`)
- ConditionHeroView가 NavigationLink 내부에 있어 버튼 중첩 가능 → `.buttonStyle(.plain)` 등으로 gesture 분리 필요
- Life HeroCard tintColor가 테마별로 다르게 보일 수 있음 → `DS.Color.tabLife` 사용으로 일관성 유지
