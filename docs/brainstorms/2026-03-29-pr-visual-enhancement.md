---
tags: [personal-records, ui, gamification, charts, rewards, badges]
date: 2026-03-29
category: brainstorm
status: draft
---

# Brainstorm: PR (Personal Records) Visual Enhancement

## Problem Statement

Activity tab PR section and detail view are functional but visually plain. Cards waste height, metric switching is cramped, timeline chart is basic, reward system lacks explanation/content, and achievement history has low readability. Need a comprehensive visual upgrade across 5 areas.

## Target Users

- Strength trainers tracking progressive overload (1RM, volume, rep max)
- Cardio users tracking pace/distance PRs
- Users motivated by gamification (badges, levels, milestones)

## Success Criteria

1. PR card height reduced by ~20% while adding visual richness (gradient + sparkline)
2. Metric switcher comfortably handles 9 kinds without feeling cramped
3. Timeline chart looks modern and polished (curved line + gradient fill)
4. Reward section is self-explanatory with guide, progression bar, badge gallery, fun comparisons
5. Achievement history is scannable at a glance with visual hierarchy

---

## Area 1: PR Section Cards (Activity Tab)

### Current
- 2-column LazyVGrid, 148pt min height
- SF Symbol icon + text title + large value + context row + date
- Ultra thin material background

### Proposed: Gradient + Sparkline Hybrid

**Layout (compact, ~120pt target height):**
```
+-------------------------------------+
| [Icon] Title        [Sparkline ~~~] |
| ===================================  |
|   142.5 kg          +5.2 kg  NEW    |
|   Mar 15, 2026                      |
+-------------------------------------+
```

**Visual Changes:**
- **Gradient accent**: Each Kind has a tint color already (`tintColor`). Use subtle horizontal gradient strip at left edge or top edge (2-3pt) as color coding
- **Sparkline**: Embed `MiniSparklineView` (already exists in `Shared/Charts/`) in top-right corner showing last 5-8 PR values. Reuse existing component
- **Compact layout**: Remove context row (HR/steps/weather) from card — move to detail view. This cuts ~30pt height
- **Delta badge**: Show improvement delta (`+5.2 kg`) in green accent instead of context data
- **Source badge**: Move from icon row to overlay corner dot (smaller footprint)
- **Background**: Keep material but add Kind-specific gradient tint at 0.05 opacity

**Reward Summary Row (above grid):**
- Current: Level + badge count + points in one row
- Keep as-is (will be enhanced in Area 4's detail view)

### Data Requirements
- Need last N PR values per kind for sparkline (`chartData` already available in ViewModel)
- Delta calculation: `currentBest.value - previousBest.value` (add to `ActivityPersonalRecord`)

---

## Area 2: Metric Switcher (Detail View)

### Current
- `Picker(.segmented)` with up to 9 options
- All options visible at once — very cramped on smaller devices

### Proposed: Horizontal Scroll Chip Bar

**Layout:**
```
[ Est. 1RM ] [ Rep Max ] [ Volume ] [ Weight ] [ Pace ] [ Distance ] ...
     ^selected (filled, bold)        ← scroll →
```

**Implementation:**
- `ScrollView(.horizontal, showsIndicators: false)` with `HStack(spacing: 8)`
- Each chip: `Capsule()` background + icon + label
- Selected: filled with `kind.tintColor`, white text
- Unselected: `.ultraThinMaterial` background, secondary text
- Auto-scroll to selected chip on load (`.scrollTo(id:)`)
- Animated selection change with `.matchedGeometryEffect` for capsule background

**Sizing:**
- Chip height: 36pt
- Padding: horizontal 12pt, vertical 8pt
- Icon: 14pt, Label: `.subheadline`

**Accessibility:**
- Each chip is a Button with label = kind.displayName
- VoiceOver: "Selected: Est. 1RM" / "Rep Max, button"

---

## Area 3: Timeline Chart (Detail View)

### Current
- `LineMark` + `PointMark` in Swift Charts
- 236pt height, basic styling
- Points all same size (except recent = 80px)

### Proposed: Curved Line + Gradient Fill

**Visual:**
```
        ●  142.5
       / \
      /   ● 138
  ●  /         \  ● 135
   \/           \/
  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  (gradient fill)
  ━━━━━━━━━━━━━━━━━━
  Jan    Feb    Mar    Apr
```

**Implementation:**
- `LineMark` with `.interpolationMethod(.catmullRom)` for smooth curves
- `AreaMark` below with gradient fill: `kind.tintColor.opacity(0.3)` → `.clear`
- Data points as `PointMark` with circle symbol
- PR milestone points: larger dot (10pt) + star annotation above
- Selected point: Popup tooltip with value + date + delta from previous
- Background: subtle horizontal reference lines at y-axis ticks

**Enhanced Features:**
- **Annotation on latest point**: Always show value label on most recent PR
- **Y-axis padding**: Extend range 10% above max for breathing room
- **No-data placeholder**: Wave animation or dashed line for empty periods
- **Transition**: `.opacity` transition when switching period/kind

**Height:** Keep 236pt but add 16pt top padding (chart clipping rule)

---

## Area 4: Reward Progression (Detail View)

### Current
- Single row: star icon + level number + badge icon + count + point icon + total
- No explanation of system

### Proposed: Rich Reward Section (3 subsections)

#### 4A. Level System Guide + Milestone Progress

**Layout:**
```
+--------------------------------------------+
|  ★ Level 12 — Ironclad                     |
|  ━━━━━━━━━━━━━●━━━━━━  2,450 / 3,000 pts  |
|  Next: Level 13 — Titan  (550 pts to go)   |
+--------------------------------------------+
|  Level Milestones                           |
|  ✓ 5  Novice    ✓ 10 Dedicated   ● 15 Titan|
|  ○ 20 Legend    ○ 25 Immortal              |
+--------------------------------------------+
```

**Content:**
- Level name per tier (define ~10 tier names)
- Progress bar: current points / next level threshold
- Milestone grid: past levels (checkmark), current (dot), future (circle)
- Info button: sheet explaining point system (how points are earned)

**Level Name Table (example):**
| Level | Name | Points |
|-------|------|--------|
| 1-4 | Beginner | 0-400 |
| 5-9 | Dedicated | 500-1400 |
| 10-14 | Ironclad | 1500-2900 |
| 15-19 | Titan | 3000-4900 |
| 20-24 | Legend | 5000-7400 |
| 25+ | Immortal | 7500+ |

#### 4B. Badge Trophy Case

**Layout:**
```
+--------------------------------------------+
|  Badges (8/24 unlocked)                    |
|  +------+ +------+ +------+ +------+      |
|  | ●    | | ●    | | ●    | | ○    |      |
|  | 1RM  | | 100  | | 7-day| | 50kg |      |
|  | King | | Club | | Strk | | Jump |      |
|  +------+ +------+ +------+ +------+      |
|            ← scroll →                      |
+--------------------------------------------+
```

**Badge Categories:**
- **PR badges**: First PR, 10 PRs, 50 PRs, PR in every kind
- **Volume badges**: 1,000kg total, 10,000kg, 100,000kg
- **Streak badges**: 7-day, 30-day, 100-day workout streak
- **Milestone badges**: First workout, 100th workout, 1-year anniversary
- **Improvement badges**: 10% improvement, doubled a lift, sub-5min pace

**Visual:**
- Unlocked: Colored icon + label, subtle glow
- Locked: Grayscale silhouette + "?" or lock icon
- Tap unlocked: expand with earned date + description
- Horizontal ScrollView in section

#### 4C. Fun Comparison Cards

**Layout:**
```
+--------------------------------------------+
|  This Month's Volume                        |
|  🏋️ 45,230 kg                              |
|  ≈ 6x grand pianos                         |
|  ≈ lifting a small car 10 times            |
+--------------------------------------------+
```

**Comparison Templates (rotate monthly):**
- Total volume → real-world object equivalents
- Total distance → city-to-city distances
- Total duration → movie/book equivalents
- Total calories → food equivalents

---

## Area 5: Achievement History (Detail View)

### Current
- Simple list: icon + title + detail + date + points
- All rows look the same regardless of event importance

### Proposed: Visual Hierarchy + Badge Decoration

**Layout by Event Kind:**

**Level Up (highest visual weight):**
```
+--------------------------------------------+
|  ★ Level Up!               +50 pts         |
|  You reached Level 12 — Ironclad           |
|  Mar 28, 2026                              |
+--------------------------------------------+
```
- Gold/mint gradient background
- Larger font for title
- Level name badge

**Badge Unlocked:**
```
+--------------------------------------------+
|  🏅 Badge Unlocked          +25 pts        |
|  "Volume King" — Lift 10,000 kg total      |
|  Mar 25, 2026                              |
+--------------------------------------------+
```
- Badge icon thumbnail on left
- Achievement description

**Personal Record:**
```
+--------------------------------------------+
|  🏆 New PR: Bench Press     +15 pts        |
|  Est. 1RM: 142.5 kg (+5.2 kg)             |
|  Mar 22, 2026                              |
+--------------------------------------------+
```
- Activity type color accent
- Delta value shown

**Milestone:**
```
+--------------------------------------------+
|  🎯 Milestone: 100 Workouts  +30 pts       |
|  You've completed your 100th workout!      |
|  Mar 20, 2026                              |
+--------------------------------------------+
```
- Special background treatment

**General Changes:**
- Group by month with section headers ("March 2026")
- Visual weight hierarchy: Level Up > Badge > PR > Milestone
- Points badge: pill-shaped, right-aligned, Kind-specific color
- Empty state: motivational message + first badge to unlock

---

## Constraints

- **No new asset creation for MVP**: Use SF Symbols + gradients + existing MiniSparklineView
- **Performance**: Sparklines in grid cards must be lightweight (max 8 data points)
- **Localization**: All new strings need en/ko/ja in xcstrings
- **Layer boundaries**: Badge definitions in Domain, display in Presentation extensions

## Edge Cases

- **No PR data**: Sparkline hidden, delta badge hidden
- **Single PR**: Sparkline shows single dot, no delta
- **Many kinds (9)**: Chip bar scrollable, auto-scrolls to selected
- **Level 1 user**: Progress bar starts from 0, first milestone highlighted
- **No badges unlocked**: Show locked badge grid with motivational text

## Scope

### MVP (Must-have)
1. PR card redesign (gradient + sparkline + compact)
2. Horizontal scroll chip metric switcher
3. Curved line chart with gradient fill
4. Level progress bar with milestone display
5. Achievement history visual hierarchy

### Nice-to-have (Future)
- Badge trophy case (requires badge definition system)
- Fun comparison cards (requires comparison data templates)
- Celebration animations (confetti on level up/PR)
- Shareable PR cards (export as image)
- 3D badge inspection (Apple Fitness style)

## Open Questions

1. Level name table — 위 제안한 이름이 괜찮은지, 아니면 다른 테마?
2. Badge 시스템을 MVP에 포함할지, Future로 미룰지?
3. Fun comparison card의 비교 데이터를 하드코딩할지, 동적 생성할지?
4. Sparkline 데이터 범위: 최근 5개 PR vs 최근 3개월?

## Affected Files (Estimated)

| File | Change Type |
|------|------------|
| `PersonalRecordsSection.swift` | Major: card redesign |
| `PersonalRecordsDetailView.swift` | Major: chip bar, chart, reward sections |
| `PersonalRecordsDetailViewModel.swift` | Moderate: delta calc, sparkline data |
| `ActivityPersonalRecord.swift` | Minor: delta property |
| `MiniSparklineView.swift` | Minor: reuse/adapt for card size |
| `PersonalRecordStore.swift` | Moderate: badge/level name support |
| `Localizable.xcstrings` | Addition: new strings (en/ko/ja) |
| New: `PRChipBar.swift` | New: reusable chip picker |
| New: `RewardProgressSection.swift` | New: level guide + milestone |
| New: `AchievementHistorySection.swift` | New: enhanced history |

## Next Steps

- [ ] `/plan pr-visual-enhancement` 으로 구현 계획 생성
- [ ] MVP scope 확정 후 Area별 순서 결정
