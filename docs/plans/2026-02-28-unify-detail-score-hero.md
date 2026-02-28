---
tags: [design-system, unification, hero-card, detail-view]
date: 2026-02-28
category: plan
status: draft
---

# Condition Score Detail Hero Card 디자인 통합

## Problem

Condition Score 상세 화면의 최상단 hero ring 카드가 다른 상세 화면(Wellness, Training Readiness)과 룩앤필이 다릅니다.

### 현재 상태 비교

| 속성 | Condition Detail | Wellness Detail | Readiness Detail |
|------|-----------------|-----------------|------------------|
| Ring size | 120/180 (iPhone/iPad) | 140/180 | 140/180 |
| Ring lineWidth | 12/16 | 16/18 | 16/18 |
| Score label | 없음 | "WELLNESS" (tracking) | "READINESS" (tracking) |
| Status icon | 없음 | 있음 | 있음 |
| Guide message | 별도 InsightSection | hero 내부 | hero 내부 |
| Sub-score badges | 없음 | 3개 (Sleep/Condition/Body) | 5개 (HRV/RHR/Sleep/Recovery/Trend) |
| Background | **없음** | .ultraThinMaterial | .ultraThinMaterial |
| Card container | 없음 | RoundedRectangle | RoundedRectangle |

추가로 ScoreContributorsView가 Condition에서는 카드 래핑 없이, Wellness에서는 StandardCard로 래핑되어 불일치합니다.

## Solution

### 1. `DetailScoreHero` 공유 컴포넌트 추출 (Correction #37: 3곳 중복)

Wellness/Readiness의 동일 패턴을 파라미터화된 단일 컴포넌트로 추출합니다.

```swift
struct DetailScoreHero: View {
    let score: Int
    let scoreLabel: String      // "CONDITION", "WELLNESS", "READINESS"
    let statusLabel: String
    let statusIcon: String
    let statusColor: Color
    let guideMessage: String
    var subScores: [SubScoreBadge] = []
    var badgeText: String? = nil

    struct SubScoreBadge: Identifiable {
        let id = UUID()
        let label: String
        let value: Int?
        let color: Color
    }
}
```

### 2. Condition Detail 업데이트

- `scoreHero` → `DetailScoreHero` 사용
- Ring 크기: 140/180, lineWidth: 16/18 (다른 화면과 동일)
- "CONDITION" 라벨 + status icon/label + guideMessage 포함
- `.ultraThinMaterial` 배경 적용
- ConditionInsightSection은 별도 유지 (상세 한국어 인사이트는 hero의 guideMessage보다 깊은 내용)
- ScoreContributorsView를 StandardCard로 래핑 (Wellness와 동일)

### 3. Wellness/Readiness Detail 리팩터링

기존 inline scoreHero + subScoreBadge → DetailScoreHero로 교체. 중복 코드 제거.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Presentation/Shared/Components/DetailScoreHero.swift` | **NEW** | 공유 hero 컴포넌트 |
| `Presentation/Dashboard/ConditionScoreDetailView.swift` | MODIFY | DetailScoreHero 사용 + Contributors StandardCard 래핑 |
| `Presentation/Wellness/WellnessScoreDetailView.swift` | MODIFY | DetailScoreHero 사용, inline hero/badge 제거 |
| `Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | MODIFY | DetailScoreHero 사용, inline hero/badge 제거 |

## Implementation Steps

1. `DetailScoreHero.swift` 생성 — Wellness/Readiness 패턴 기반
2. `ConditionScoreDetailView` 업데이트 — DetailScoreHero 적용 + Contributors 래핑
3. `WellnessScoreDetailView` 업데이트 — DetailScoreHero 적용, inline 코드 제거
4. `TrainingReadinessDetailView` 업데이트 — DetailScoreHero 적용, inline 코드 제거
5. 빌드 검증

## Risk

- **Low**: View-only 변경, Domain/Data 레이어 미접촉
- ConditionInsightSection 별도 유지로 기존 UX 보존
- 기능 변경 없음 (비주얼 통일만)
