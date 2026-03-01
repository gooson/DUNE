---
tags: [ux, ui, hero-card, narrative, stale-data, empty-state, quick-wins]
date: 2026-03-02
category: plan
status: approved
---

# Plan: Phase 1 UX Quick Wins (QW1, QW3, QW4, QW5)

## Overview

brainstorm `2026-03-02-ux-ui-comprehensive-review.md`의 Phase 1 Quick Wins 중 4개 항목 구현.

## Affected Files

| File | Change | QW |
|------|--------|----|
| `Domain/Models/ConditionScore.swift` | `narrativeMessage` computed property 추가 | QW1 |
| `Domain/Models/TrainingReadiness.swift` | `narrativeMessage` computed property 추가 | QW1 |
| `Domain/Models/WellnessScore.swift` | `narrativeMessage` computed property 추가 | QW1 |
| `Presentation/Dashboard/Components/ConditionHeroView.swift` | guideMessage → narrativeMessage | QW1 |
| `Presentation/Activity/Components/TrainingReadinessHeroCard.swift` | guideMessage → narrativeMessage | QW1 |
| `Presentation/Wellness/Components/WellnessHeroCard.swift` | guideMessage → narrativeMessage | QW1 |
| `Presentation/Activity/ActivityView.swift` | Injury warning 위치 확인 (이미 position 2) | QW3 |
| `Presentation/Wellness/Components/VitalCard.swift` | stale 표시 개선 | QW4 |
| `Presentation/Life/LifeView.swift` | empty state에 CTA 추가 | QW5 |
| `Resources/Localizable.xcstrings` | 새 문자열 en/ko/ja | ALL |

## Implementation Steps

### Step 1: QW1 — Hero Narrative Messages

**Domain 모델에 narrativeMessage 추가** (기존 guideMessage는 유지, 새 프로퍼티 추가)

#### ConditionScore
- `detail` 프로퍼티의 `todayHRV`, `baselineHRV`, `rhrPenalty`, `zScore` 활용
- 패턴: "{상태} — {원인 1줄}"
- 예: "Good — HRV stable, RHR slightly elevated"

#### TrainingReadiness
- `components`의 4개 서브스코어 중 가장 낮은 것 식별
- 패턴: "{상태} — {제한 요인}"
- 예: "Ready to train — sleep was excellent"
- 예: "Light day advised — limited by sleep quality"

#### WellnessScore
- 3개 서브스코어(sleep, condition, body) 중 가장 낮은 것 식별
- 패턴: "{상태} — {제한 요인 or 긍정 메시지}"
- 예: "Good — sleep is your strongest factor"

#### View 연결
- 각 HeroView에서 `guideMessage` → `narrativeMessage`로 교체

### Step 2: QW3 — Injury Warning Position

리서치 결과 injury warning은 이미 hero 바로 다음 (position 2)에 위치함.
추가 작업 없음 — brainstorm 시점의 분석이 최신 코드와 다름.

### Step 3: QW4 — Stale Data Labels

VitalCard에서:
1. `freshnessLabel`을 항상 표시 (isStale 조건 제거)
2. opacity 0.6 제거 → 대신 freshnessLabel 스타일로 시각적 구분
3. fresh 데이터: "Today" 레이블 (subtle)
4. stale 데이터: "3d ago" 레이블 (secondary color, 강조)

### Step 4: QW5 — Life Empty State CTA

EmptyStateView가 이미 `actionTitle` + `action` 파라미터 지원.
- `actionTitle: "Add Habit"` 추가
- action에서 `viewModel.resetForm()` + `isShowingAddSheet = true`

### Step 5: Localization

새 문자열을 Localizable.xcstrings에 en/ko/ja 추가.

## Test Strategy

- QW1: ConditionScore/TrainingReadiness/WellnessScore의 narrativeMessage 유닛 테스트
- QW4: VitalCard freshness 표시 로직 테스트 (Date+Validation)
- QW5: 기능 단순하여 테스트 면제

## Risks

- QW1 narrative 문자열이 길어질 경우 HeroScoreCard 레이아웃 영향 → fixedSize로 이미 처리됨
- QW4 freshnessLabel 항상 표시 시 "Today" 레이블이 시각적 노이즈 → 조건부 스타일링
