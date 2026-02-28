---
tags: [design-system, color-palette, xcassets, desert-horizon, watch-sync]
date: 2026-02-28
category: solution
status: implemented
---

# Desert Horizon Full Palette Redesign

## Problem

앱 전체의 색상이 "기본 iOS" 느낌이었고, Today 탭의 Desert Horizon 링과 시각적으로 분리되어 있었음. Metric/Score/HR Zone 색상이 각각 독립적인 팔레트를 사용하여 앱 전체의 디자인 정체성이 불일치.

## Solution

### Strategy: xcassets-First Propagation

색상 토큰 아키텍처를 활용하여 **xcassets RGB 값만 변경**하면 `DS.Color.*` 토큰을 참조하는 98+ 파일에 자동 전파. 코드 변경 최소화.

### 변경 범위

| 카테고리 | 파일 수 | 방식 |
|---------|--------|------|
| Metric Colors (9) | 18 (iOS+Watch) | xcassets RGB 교체 |
| Score Colors (5) | 10 (iOS+Watch) | xcassets RGB 교체 + 4 redundant 삭제 |
| HR Zone Colors (5) | 5 (iOS only) | xcassets RGB 교체 |
| DS Gradient tokens | 2 (iOS+Watch) | heroText, sectionAccent 추가 |
| UI 컴포넌트 | 5 | VitalCard, MetricSummaryHeader, SectionGroup, EmptyStateView, AreaLineChartView |

### Desert Horizon Palette 원칙

1. **Warm earth tones**: 사막의 금색, 구리색, 테라코타
2. **Temperature progression**: 새벽(차가운 파란) → 한낮(금색) → 석양(붉은) 순서
3. **Score = HR Zone 매핑**: 동일 5단계 온도 그라데이션 공유
4. **Dark mode**: 약간 밝고 채도 높은 variant (사막 밤하늘 대비)

### 주요 기술 결정

1. **Score 통합**: WellnessScore 4개 colorset 삭제 → 공유 Score 5개 사용. `WellnessScore+View.swift`에서 `scoreExcellent/Good/Fair/Warning` 참조로 변경
2. **SurfacePrimary dark mode**: `(0.043,0.043,0.059)` → `(0.060,0.050,0.040)` 따뜻한 갈색 시프트
3. **heroText gradient**: `DS.Gradient.heroText` (DesertBronze→WarmGlow) — VitalCard, MetricSummaryHeader 값 텍스트에 적용
4. **sectionAccent bar**: SectionGroup 헤더에 2×14pt 그라데이션 바 추가 — `DS.Opacity.strong`/`.border` 토큰 사용

## Review Findings & Fixes

### P1 — Canvas draw 클로저 Gradient 할당

WaveRefreshIndicator에서 60fps Canvas draw에 `Gradient` + `Color.opacity()` 4개 인스턴스 생성 → flat color stroke로 복원.

**교훈**: Canvas draw 클로저는 SwiftUI diffing 보호 없음. 모든 allocation은 per-frame. Correction #82 확장.

### P1 — Dead DS Token

`chartAreaFade`, `hintBlend`, `chartGrid`, `cardOverlay` 4개 토큰이 소비자 없이 추가됨. 즉시 삭제.

**교훈**: DS 토큰은 소비자와 동시에 추가. 소비자 없는 토큰은 Correction #145 위반.

### P2 — Computed var areaGradient

`AreaLineChartView`의 `private var areaGradient`가 ForEach 내 매 데이터 포인트마다 `LinearGradient` 재생성. `tintColor`이 `let`이므로 init에서 stored `let`으로 promotion.

**교훈**: Chart ForEach 내 `.foregroundStyle()` → per-data-point 실행. Correction #105/#165 적용 범위 확인.

## Prevention

1. **DS 토큰 추가 시 소비자 코드와 동시 커밋** — dead token 방지
2. **Canvas draw 클로저 내 Color/Gradient allocation 금지** — per-frame 비용
3. **Watch DS 동기화 체크리스트** — iOS DS 변경 시 Watch DS에 미러링 여부 확인
4. **DS.Opacity magic number 금지** — gradient 정의 시 기존 토큰 참조 필수
5. **xcassets-First 전략** — 색상 변경은 colorset RGB 교체 우선, 코드 변경 최소화
