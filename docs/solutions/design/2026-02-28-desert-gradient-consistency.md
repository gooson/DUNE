---
tags: [design-system, desert-palette, gradient, ring, detail-view, consistency]
date: 2026-02-28
category: solution
status: implemented
---

# Desert Gradient Consistency — Detail View 링 + 점수 텍스트

## Problem

Desert Horizon 전면 개편 후 3가지 디자인 불일치 발견:

1. **Today 탭 링 숫자**: `warmGlow → warmGlow(0.7)` (다른 탭은 `desertBronze → desertDusk`)
2. **Detail View 링**: `useWarmGradient` 미적용 → 단색 링 렌더링
3. **Detail View 점수 텍스트**: `.primary` 기본값 → 다크모드에서 순백색으로 렌더링

## Root Cause

초기 구현 시점의 차이:
- `HeroScoreCard` (Wellness/Training 탭)는 Desert Horizon 개편 시 함께 업데이트됨
- `ConditionHeroView` (Today 탭)는 별도 파일이라 gradient 통일이 누락됨
- Detail View 3개는 개편 범위에서 제외되었음

## Solution

### 1. DS.Gradient.detailScore 토큰 추가
```swift
static let detailScore = LinearGradient(
    colors: [DS.Color.desertBronze, DS.Color.desertDusk],
    startPoint: .top,
    endPoint: .bottom
)
```

### 2. ConditionHeroView scoreGradient 통일
`warmGlow → warmGlow(0.7)` → `desertBronze → desertDusk`로 변경하여 HeroScoreCard와 동일 패턴.

### 3. Detail View 3곳 동일 수정
- `ProgressRingView`에 `useWarmGradient: true` 추가
- 점수 숫자에 `.foregroundStyle(DS.Gradient.detailScore)` 추가
- 라벨에 `.foregroundStyle(DS.Color.sandMuted)` 추가

## Prevention

### 체크리스트: 새 Score Detail View 추가 시
1. `ProgressRingView`에 `useWarmGradient: true` 설정 확인
2. 점수 숫자에 `DS.Gradient.detailScore` 적용 확인
3. 부제 라벨에 `DS.Color.sandMuted` 적용 확인
4. 탭 Hero View와 Detail View의 gradient가 동일한지 비교 확인

### `.white` 텍스트 사용 가이드
| 용도 | 올바른 사용 |
|------|------------|
| 마스크 gradient | `.white` (opacity 제어) |
| 컬러 버튼/뱃지 위 텍스트 | `.white` (대비 목적) |
| 선택 상태 (컬러 Capsule 위) | `.white` |
| 점수 숫자 | `DS.Gradient.detailScore` 또는 `DS.Gradient.heroText` |
| 부제/라벨 | `DS.Color.sandMuted` |
| 일반 텍스트 | `.primary` / `.secondary` / `.tertiary` |

## Affected Files

- `DesignSystem.swift` — `DS.Gradient.detailScore` 추가
- `ConditionHeroView.swift` — scoreGradient 통일
- `ConditionScoreDetailView.swift` — ring + text gradient
- `WellnessScoreDetailView.swift` — ring + text gradient
- `TrainingReadinessDetailView.swift` — ring + text gradient
