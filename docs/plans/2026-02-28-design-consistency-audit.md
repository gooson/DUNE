---
tags: [design-system, desert-palette, gradient, ring, text-color]
date: 2026-02-28
category: plan
status: draft
---

# Design Consistency Audit — Desert Palette 누락 수정

## Problem Statement

Desert Horizon 전면 개편 후 3가지 디자인 불일치 발견:

1. **`.white` 텍스트 전수 조사**: 일부 텍스트가 DS 토큰 대신 하드코딩된 `.white` 또는 기본 `.primary`(다크모드에서 흰색)를 사용
2. **Today 탭 링 숫자 그라데이션 불일치**: Today 탭 ConditionHeroView는 `warmGlow → warmGlow.opacity(0.7)` 사용, 다른 탭 HeroScoreCard는 `desertBronze → desertDusk` 사용
3. **Detail View 링 그라데이션 누락**: 각 탭 히어로 카드 상세에서 ProgressRingView에 `useWarmGradient: true` 누락 + 점수 텍스트에 desert gradient 미적용

## Analysis

### Issue 1: `.white` 사용처 분류

| 카테고리 | 파일 | 판정 |
|----------|------|------|
| **마스크** | WaveShape.swift (3건) | ✅ 유지 (opacity 제어용, 화면에 보이지 않음) |
| **공유 이미지** | WorkoutShareCard.swift (12건) | ✅ 유지 (어두운 배경 위 의도적 대비) |
| **컬러 배경 위 선택 상태** | ExercisePickerView (4건), CreateCustomExerciseView (2건), ExerciseHistoryView (1건) | ✅ 유지 (컬러 Capsule 위 대비 텍스트 — 표준 iOS 패턴) |
| **컬러 배지 텍스트** | PersonalRecordsSection (1건), PersonalRecordsDetailView (1건), ExerciseDetailSheet (1건), ConsistencyDetailView (1건), UserCategoryManagementView (1건) | ✅ 유지 (컬러 배경 위 소형 텍스트) |
| **컬러 버튼 텍스트** | CompoundWorkoutView (1건), CompoundWorkoutSetupView (1건), WorkoutCompletionSheet (1건), ShareImageSheet (1건) | ✅ 유지 (컬러 버튼 위 CTA 텍스트) |

**결론**: 현재 `.white` 사용은 모두 컬러 배경 위 대비 텍스트로, 올바른 패턴임. 수정 불필요.

**실제 문제**: Detail View의 점수 숫자가 `.foregroundStyle()` 미지정으로 `.primary` (다크모드 = 흰색)로 렌더링됨.

### Issue 2: Today 탭 링 숫자 그라데이션

| 위치 | 현재 | 목표 |
|------|------|------|
| ConditionHeroView (Today) | `warmGlow → warmGlow.opacity(0.7)` | `desertBronze → desertDusk` |
| HeroScoreCard (Wellness/Training) | `desertBronze → desertDusk` | (이미 올바름) |

### Issue 3: Detail View 링 + 텍스트

| 파일 | Ring `useWarmGradient` | 점수 텍스트 gradient |
|------|----------------------|---------------------|
| ConditionScoreDetailView | ❌ 누락 | ❌ `.primary` (기본값) |
| WellnessScoreDetailView | ❌ 누락 | ❌ `.primary` (기본값) |
| TrainingReadinessDetailView | ❌ 누락 | ❌ `.primary` (기본값) |

## Implementation Plan

### Step 1: ConditionHeroView — scoreGradient 통일

**File**: `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift`
- Line 25-28: `Layout.scoreGradient` 변경
  - Before: `[DS.Color.warmGlow, DS.Color.warmGlow.opacity(0.7)]`
  - After: `[DS.Color.desertBronze, DS.Color.desertDusk]`

### Step 2: Detail Views — Ring + 텍스트 그라데이션 추가

**ConditionScoreDetailView.swift**:
- Line 197-201: `ProgressRingView`에 `useWarmGradient: true` 추가
- Line 205: `Text("\(score.score)")` → `.foregroundStyle(scoreGradient)` 추가
- Line 209-212: "CONDITION" label → `.foregroundStyle(DS.Color.sandMuted)` (`.secondary` 대체)
- static scoreGradient 상수 추가

**WellnessScoreDetailView.swift**:
- Line 67-72: `ProgressRingView`에 `useWarmGradient: true` 추가
- Line 75: `Text("\(wellnessScore.score)")` → `.foregroundStyle(scoreGradient)` 추가
- Line 79-81: "WELLNESS" label → `.foregroundStyle(DS.Color.sandMuted)` (`.tertiary` 대체)
- static scoreGradient 상수 추가

**TrainingReadinessDetailView.swift**:
- Line 50-55: `ProgressRingView`에 `useWarmGradient: true` 추가
- Line 58: `Text("\(readiness.score)")` → `.foregroundStyle(scoreGradient)` 추가
- Line 63-64: "READINESS" label → `.foregroundStyle(DS.Color.sandMuted)` (`.tertiary` 대체)
- static scoreGradient 상수 추가

### Step 3: DS.Gradient에 detailScore 토큰 추가 (DRY)

Detail View 3곳에서 동일 gradient를 사용하므로 `DS.Gradient.detailScore`로 추출:
```swift
static let detailScore = LinearGradient(
    colors: [DS.Color.desertBronze, DS.Color.desertDusk],
    startPoint: .top,
    endPoint: .bottom
)
```

## Affected Files

| File | Change |
|------|--------|
| `DUNE/Presentation/Shared/DesignSystem.swift` | `DS.Gradient.detailScore` 추가 |
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift` | scoreGradient → desertBronze→desertDusk |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | ring warmGradient + score gradient + sandMuted label |
| `DUNE/Presentation/Wellness/WellnessScoreDetailView.swift` | ring warmGradient + score gradient + sandMuted label |
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | ring warmGradient + score gradient + sandMuted label |

## Risks

- ConditionHeroView gradient 변경으로 Today 탭 느낌이 달라질 수 있음 → HeroScoreCard와 동일해지므로 오히려 일관성 향상
- Detail view ring에 warm gradient 추가 시 ring color와 accent color 블렌딩 → ProgressRingView의 기존 동작(Correction #136)과 일치
