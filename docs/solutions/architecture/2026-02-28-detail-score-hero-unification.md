---
tags: [design-system, shared-component, detail-view, hero-card, swiftui]
date: 2026-02-28
category: solution
status: implemented
---

# Detail Score Hero 디자인 통합

## Problem

3개 score detail 화면(Condition, Wellness, Training Readiness)의 최상단 hero ring card가 각각 다른 스타일로 구현되어 있었습니다:

- Condition: 배경 없음, 작은 링(120pt), score label 없음, status icon 없음
- Wellness/Readiness: `.ultraThinMaterial` 배경, 140pt 링, score label + status icon + guide message

ScoreContributorsView도 Condition에서는 카드 래핑 없이, Wellness에서는 StandardCard로 래핑되어 불일치.

## Solution

### 1. `DetailScoreHero` 공유 컴포넌트 추출

**위치**: `Presentation/Shared/Components/DetailScoreHero.swift`

파라미터화된 단일 컴포넌트로 3개 화면의 hero 패턴을 통합:
- `score`, `scoreLabel`, `statusLabel`, `statusIcon`, `statusColor`, `guideMessage`
- `subScores: [SubScoreBadge]` (optional, Condition은 빈 배열)
- `badgeText: String?` (optional, Readiness의 "Calibrating" 용)

### 2. SubScoreBadge identity

`UUID()` 대신 `label` 기반 identity 사용 (`ForEach(subScores, id: \.label)`).
매 렌더마다 UUID 생성 방지 + ForEach diffing 안정화. (Correction #87, #175 적용)

### 3. ScoreContributorsView 일관성

Condition detail에서도 `StandardCard { ScoreContributorsView(...) }` 래핑 적용.

## Key Decisions

1. **ConditionInsightSection 별도 유지**: hero의 `guideMessage`는 짧은 영문 메시지. InsightSection은 상세 한국어 해석+가이드로 별도 가치가 있음
2. **Condition hero에서 날짜 제거**: 다른 hero에 없는 정보이므로 패턴 통일을 위해 제거
3. **접근성 레이블**: `scoreLabel.capitalized` 사용하여 VoiceOver에서 "Condition score 78, Good" 형태로 읽힘

## Prevention

- 새 score detail 화면 추가 시 반드시 `DetailScoreHero` 사용
- 공유 컴포넌트에 `UUID()` identity 사용 금지 — content-derived identity 원칙
