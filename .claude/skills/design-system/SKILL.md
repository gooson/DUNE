---
name: design-system
description: "UI/UX 디자인 시스템 가이드. 컬러, 타이포그래피, 간격, 컴포넌트 패턴. 디자인 관련 작업 시 자동으로 참조됩니다."
---

# DUNE Design System

> Source of truth: `DUNE/Presentation/Shared/DesignSystem.swift` (`enum DS`)
> Named colors: `DUNE/Resources/Assets.xcassets/Colors/`

## Colors

All colors are Named Colors in the asset catalog, referenced via `DS.Color.*`.

### Brand

| Token | Usage | Dark sRGB |
|-------|-------|-----------|
| `AccentColor` | Primary brand, tint, warm glow | (201, 149, 107) amber |
| `warmGlow` | Alias for `Color.accentColor` | — |

### Score Levels (5)

| Token | Usage |
|-------|-------|
| `scoreExcellent` | Condition/Wellness 90+ |
| `scoreGood` | 70–89 |
| `scoreFair` | 50–69 |
| `scoreTired` | 30–49 |
| `scoreWarning` | 0–29 |

### Metric Categories (9)

| Token | Category | Warm tone |
|-------|----------|-----------|
| `hrv` | HRV | amber-gold |
| `rhr` | Resting HR | coral |
| `heartRate` | Heart Rate | warm red |
| `sleep` | Sleep | deep indigo |
| `activity` | Activity | warm emerald |
| `steps` | Steps | warm teal |
| `body` | Body Comp | gold |
| `vitals` | Vitals | soft amber |
| `fitness` | Fitness | warm green |

### Surface

| Token | Light | Dark |
|-------|-------|------|
| `surfacePrimary` | warm cream (250,248,243) | near-black (11,11,15) |
| `cardBackground` | ivory (253,251,247) | — |

### Feedback

| Token | Usage |
|-------|-------|
| `positive` | Improvements, gains |
| `negative` | Declines, losses |
| `caution` | Warnings, errors |

## Typography

All Dynamic Type compatible (scales automatically).

| Token | Font | Weight | Usage |
|-------|------|--------|-------|
| `DS.Typography.heroScore` | Rounded `.largeTitle` | Bold | Detail view score |
| `DS.Typography.cardScore` | Rounded `.title` | Bold | Hero card score |
| `DS.Typography.sectionTitle` | `.title3` | Semibold | Section headers |

## Spacing (4pt Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 2pt | Tight inner gaps |
| `xs` | 4pt | Icon-label gaps |
| `sm` | 8pt | Compact padding |
| `md` | 12pt | Standard padding |
| `lg` | 16pt | Card padding (compact) |
| `xl` | 20pt | Card padding (regular) |
| `xxl` | 24pt | Section spacing |
| `xxxl` | 32pt | Large section gaps |

## Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 8pt | InlineCard (compact) |
| `md` | 12pt | StandardCard (compact), InlineCard (regular) |
| `lg` | 16pt | StandardCard (regular) |
| `xl` | 20pt | HeroCard (compact) |
| `xxl` | 24pt | HeroCard (regular) |

## Gradient Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `tabBackgroundEnd` | UnitPoint(0.5, 0.6) | Tab background fade-out |
| `waveAmplitude` | 0.03 | Wave height (fraction of rect) |
| `waveFrequency` | 2.0 | Wave periods across width |
| `waveVerticalOffset` | 0.7 | Wave vertical center (fraction) |
| `heroRingStart` | UnitPoint(0, 0) | Hero ring gradient start |
| `heroRingEnd` | UnitPoint(1, 1) | Hero ring gradient end |

## Animation

| Token | Type | Duration | Usage |
|-------|------|----------|-------|
| `snappy` | Spring | 0.25s, bounce 0.05 | Toggles, small changes |
| `standard` | Spring | 0.35s, bounce 0.1 | Cards, transitions |
| `emphasize` | Spring | 0.6s, bounce 0.15 | Hero, large movements |
| `slow` | Spring | 1.0s, bounce 0.1 | Score ring fill |
| `numeric` | EaseOut | 0.6s | Score counter animation |
| `waveDrift` | Linear | 6s, repeat forever | Background wave drift |

## Component Patterns

### Cards (GlassCard.swift)

4 levels of visual hierarchy using material backgrounds:

| Card | Material | Border | Shadow | Radius |
|------|----------|--------|--------|--------|
| `HeroCard` | `.ultraThinMaterial` | Accent gradient stroke (0.30→0.06), 1pt | None | xl/xxl |
| `StandardCard` | `.thinMaterial` | Accent 0.15 (dark only), 0.5pt | Warm/black, r10 y2 | md/lg |
| `InlineCard` | `.ultraThinMaterial` | None | None | sm/md |
| `SectionGroup` | `.thinMaterial` | None | None | md/lg |

HeroCard accepts `tintColor` — applies `tintColor.opacity(0.08).gradient` overlay.

### Progress Ring (ProgressRingView.swift)

- Background track: `ringColor.opacity(0.15)`, round cap
- Progress arc: `AngularGradient` from `ringColor.opacity(0.6)` to `ringColor`
- `useWarmGradient: true` switches to amber-gold angular gradient
- Animate in with `DS.Animation.slow`, update with `DS.Animation.emphasize`
- Respects `accessibilityReduceMotion`

### Wave Motif (WaveShape.swift)

- SwiftUI `Shape` — sine wave with area fill to bottom
- Pre-computes angles at init, `path(in:)` only scales (Correction #82)
- `WaveOverlayView` wrapper: animated phase drift with `DS.Animation.waveDrift`
- `bottomFade` parameter: smooth gradient mask at bottom edge (0~1)
- `TabWaveBackground`: reusable tab background combining wave + gradient
- `WaveRefreshIndicator`: compact wave animation for loading states
- Applied to: all 4 tab backgrounds (animated), EmptyStateView (static)

### Tab Background Pattern

All 4 tabs use `TabWaveBackground` with their key color:
```swift
.background { TabWaveBackground(primaryColor: DS.Color.activity) }
```

`TabWaveBackground` renders:
1. Wave overlay at top 200pt with `bottomFade: 0.4` (smooth fade-out)
2. Linear gradient from `primaryColor.opacity(0.10)` to clear

| Tab | Primary Color |
|-----|---------------|
| Dashboard (Today) | `.accentColor` (amber) |
| Activity | `DS.Color.activity` (warm emerald) |
| Exercise | `DS.Color.activity` (warm emerald) |
| Wellness | `DS.Color.fitness` (warm green) |

## Responsive Layout

- `sizeClass == .regular` (iPad): larger padding, radius, ring sizes
- `sizeClass == .compact` (iPhone): compact values
- No custom breakpoints — relies on SwiftUI `horizontalSizeClass`

## Key Rules

1. **Correction #82**: No heavy computation in `Shape.path(in:)` — pre-compute at init
2. **Correction #83**: Color instances in hot paths → static caching
3. **Correction #127**: Dark mode opacity minimum 0.06 for visibility
4. **Correction #128**: Repeated UnitPoint/opacity → extract to `DS.Gradient.*`
5. **Correction #129**: Visual changes → v1 (conservative) → v2 (strengthened)
6. **Correction #105**: No gradient/color allocation inside Chart body
