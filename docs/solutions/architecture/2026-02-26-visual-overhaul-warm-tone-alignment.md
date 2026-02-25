---
tags: [design-system, color-palette, xcassets, warm-tone, app-icon, gradient, card-style, visual-identity]
category: architecture
date: 2026-02-26
severity: important
related_files:
  - DUNE/Resources/Assets.xcassets/Colors/
  - DUNE/Presentation/Shared/DesignSystem.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
related_solutions:
  - architecture/2026-02-21-wellness-section-split-patterns.md
---

# Solution: Visual Overhaul — App Icon 기반 Warm Tone 전환

## Problem

### Symptoms

- 앱 아이콘(다크 배경 + 앰버/골드 파도)과 앱 내부 UI(쿨 퍼플/시안/핑크)의 시각적 불일치
- 아이콘에서 받은 프리미엄 인상이 앱 내부에서 이어지지 않음
- 다크 모드에서 배경 그래디언트가 거의 보이지 않음 (opacity 0.03)

### Root Cause

초기 컬러 팔레트가 기능 구분 위주로 설계되어, 앱 아이콘의 warm amber/gold 톤과 괴리가 있었음. AccentColor(앰버)는 정의되어 있었으나 UI 전반에 활용되지 않고 있었음.

## Solution

Named Color asset(`.colorset`)을 단일 소스로 활용하여, colorset 값 변경만으로 `DS.Color.*` 토큰을 통한 전체 UI 자동 전파.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| 9개 `.colorset/Contents.json` | 쿨톤 → 워밍톤 RGB 값 | 아이콘 색상과 통일 |
| `SurfacePrimary.colorset` | 라벤더 → 웜 크림 (light), 블루틴트 제거 (dark) | 배경 온도감 조정 |
| `CardBackground.colorset` | 순백 → 아이보리 (light), 블루틴트 제거 (dark) | 카드 온도감 조정 |
| 3개 탭 View | 배경 gradient opacity 강화 (0.10~0.14) + AccentColor 레이어 추가 | 워밍 톤 가시성 확보 |
| `GlassCard.swift` | HeroCard: 골드 그래디언트 테두리 1pt / StandardCard: 다크모드 앰버 테두리+섀도 | 카드 프리미엄 느낌 |
| `DesignSystem.swift` | `DS.Color.warmGlow`, `DS.Gradient.tabBackgroundEnd` 토큰 추가 | 매직넘버 제거 + 확장용 |

### Key Code

```swift
// colorset 값 변경 → DS.Color 토큰 → 전체 UI 자동 전파
// MetricHRV: 보라(0.596, 0.388, 0.831) → 앰버(0.745, 0.588, 0.353)

// 배경 그래디언트 — 탭별 테마색 + AccentColor 워밍 레이어
LinearGradient(
    colors: [DS.Color.activity.opacity(0.10), Color.accentColor.opacity(0.06), .clear],
    startPoint: .top,
    endPoint: DS.Gradient.tabBackgroundEnd
)

// HeroCard — 골드 그래디언트 테두리
// Warm accent border — top-leading highlight fades to subtle bottom-trailing
.overlay(
    RoundedRectangle(cornerRadius: cornerRadius)
        .strokeBorder(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
)
```

### Color Mapping Reference

| 토큰 | Before (Cool) | After (Warm) |
|------|---------------|--------------|
| HRV | 보라 | 앰버/골드 |
| RHR | 핑크 | 코랄/살몬 |
| Sleep | 밝은 보라 | 딥 인디고 |
| Activity | 쿨 그린 | 워밍 에메랄드 |
| Steps | 시안 | 워밍 틸 |
| Vitals | 틸 | 소프트 앰버 |
| Fitness | 밝은 그린 | 워밍 그린 |

## Prevention

### Checklist Addition

- [ ] 새 colorset 추가 시 앱 아이콘의 warm amber/gold 톤과 조화되는지 확인
- [ ] 배경 gradient opacity는 다크 모드에서 0.06 이상 설정 (0.03 이하는 사실상 보이지 않음)
- [ ] 카드 테두리/섀도 값 변경 시 `GlassCard.swift` 한 곳만 수정하면 전체 반영 확인

### Rule Addition (if applicable)

향후 `.claude/rules/design-tokens.md`에 추가 고려:
- 반복되는 UnitPoint, opacity 값은 `DS.Gradient.*` 또는 `DS.Opacity.*` 토큰으로 추출
- colorset 값 변경 시 light/dark 모두 업데이트 필수

## Lessons Learned

1. **Named Color asset이 단일 소스 역할**: colorset JSON 값만 바꾸면 `DS.Color.*` → 모든 View 자동 전파. 코드 수정 없이 색상 조정 가능
2. **다크 모드 opacity는 보수적이면 안 보임**: 0.03은 사실상 투명. 최소 0.06~0.10 이상이어야 시각적 효과 있음
3. **v1(보수적) → v2(강화) 2단계 접근이 효과적**: 먼저 안전한 값으로 커밋, 실기기 확인 후 강도 조절. 한 번에 강하게 가면 롤백 범위가 넓어짐
4. **리뷰에서 unused token 지적 vs 향후 확장성**: `DS.Color.warmGlow`처럼 아직 사용 안 되지만 다음 작업(wave motif 등)에 쓸 토큰은 유지 판단 가능
