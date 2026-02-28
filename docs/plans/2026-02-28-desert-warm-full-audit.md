---
tags: [design-system, desert-warm, theme, performance, dark-mode]
date: 2026-02-28
category: plan
status: approved
---

# Plan: Desert Warm Theme Full Audit & Improvement

## Overview

4-agent review (UX, Architecture, Performance, Simplicity) 결과를 기반으로 Desert Warm 테마 전면 개선.

## Implementation Steps

### Step 1: DS Token Expansion (xcassets + DesignSystem.swift)
- `TextSecondary.colorset` 생성 (light: #8B7D6B, dark: #A0907E)
- `TextTertiary.colorset` 생성 (light: #6B5F52, dark: #7A6D61)
- `DS.Color.textSecondary`, `DS.Color.textTertiary` 추가
- `DS.Opacity.overlay` (0.20), `DS.Opacity.cardBorder` (0.25) 추가

### Step 2: Performance Fixes (P1)
- ProgressRingView: `Cache.warmGradientColors` static func → @State pre-compute
- WaveOverlayView: bottomFade LinearGradient mask → cached static

### Step 3: Performance Fixes (P2) — GlassCard Gradient Caching
- HeroCard, StandardCard, InlineCard: inline gradient → cached static let

### Step 4: Dead Code Removal
- `DS.Gradient.heroRingStart` / `heroRingEnd` → verify references, remove if unused
- `DS.Color.primaryTextStyle(active:fallback:)` → inline at 3 call sites

### Step 5: Theme Strengthening
- EmptyStateView: icon warmGlow tint, CTA button warm tint, wave height 60→100
- SettingsView: section header accent bar + icon warm tint
- SectionGroup: `.foregroundStyle(.secondary)` → `DS.Color.textSecondary`

### Step 6: System Color Bulk Replacement
- `.foregroundStyle(.secondary)` → `.foregroundStyle(DS.Color.textSecondary)` (268 occurrences, 95 files)
- `.foregroundStyle(.primary)` → 유지 (primary는 시스템 기본 흑/백이므로 대부분 적절)

### Step 7: Hardcoded Color Removal
- WorkoutShareCard: 5 RGB colors → DS tokens
- FatigueLevel+View: HSB colors → DS color cache

### Step 8: GlassCard Hardcoded Opacity → DS Tokens
- HeroCard: `0.08` → `DS.Opacity.light`
- StandardCard: `0.35`, `0.25` → `DS.Opacity.strong`, `DS.Opacity.cardBorder`
- InlineCard: `0.25` → `DS.Opacity.cardBorder`

### Step 9: Watch DS Sync
- Add textSecondary, textTertiary, overlay/cardBorder opacity to Watch DS

### Step 10: Build + Test
- `scripts/build-ios.sh`
- Unit test verification

## Affected Files

| File | Change |
|------|--------|
| Assets.xcassets/Colors/ | New: TextSecondary, TextTertiary colorsets |
| DesignSystem.swift | Token additions |
| DUNEWatch/DesignSystem.swift | Token sync |
| ProgressRingView.swift | P1 perf fix |
| WaveShape.swift | P1 perf fix |
| GlassCard.swift | P2 perf fix + opacity tokens |
| EmptyStateView.swift | Theme strengthen |
| SettingsView.swift | Theme strengthen |
| SectionGroup.swift | System color → DS token |
| 95 files | .secondary → DS.Color.textSecondary |
| WorkoutShareCard.swift | Hardcoded RGB removal |
| FatigueLevel+View.swift | Hardcoded HSB removal |

## Constraints
- Correction #120: light/dark 동일 색상은 universal만 유지
- Correction #136: 브랜드 컬러에 .accentColor 직접 사용 금지
- Correction #177: DS 색상 토큰은 xcassets 패턴 사용 필수
- 접근성: 텍스트 contrast ratio 4.5:1 이상 유지
