---
tags: [personal-records, ui, gamification, charts, rewards, badges, sparkline]
date: 2026-03-29
category: plan
status: approved
---

# Plan: PR (Personal Records) Visual Enhancement

## Context

Brainstorm: `docs/brainstorms/2026-03-29-pr-visual-enhancement.md`
Related solutions:
- `docs/solutions/architecture/2026-03-03-workout-reward-system.md`
- `docs/solutions/architecture/2026-03-28-personal-record-1rm-repmx-volume-pr.md`

## Scope

5 areas of PR feature visual enhancement:
1. PR Section Cards — gradient + sparkline + compact
2. Metric Switcher — horizontal scroll chip bar
3. Timeline Chart — curved line + gradient fill
4. Reward Progression — level guide + badge trophy case + fun comparisons
5. Achievement History — visual hierarchy + monthly grouping

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `Domain/Models/PersonalRecord.swift` | Add `RewardLevelTier`, `WorkoutBadgeDefinition`, `FunComparison` | Low |
| `Domain/Models/ActivityPersonalRecord.swift` | Add `previousValue` for delta calc | Low |
| `Domain/UseCases/ActivityPersonalRecordService.swift` | Supply sparkline data + delta | Low |
| `Data/Persistence/PersonalRecordStore.swift` | Add badge definition queries, level tier lookup | Low |
| `Presentation/Activity/Components/PersonalRecordsSection.swift` | Card redesign: compact + gradient + sparkline | Medium |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Major: chip bar, chart, reward sections, history | High |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | Sparkline data, badge defs, fun comparisons, level tiers | Medium |
| `Presentation/Shared/Charts/MiniSparklineView.swift` | No change (reuse as-is) | None |
| **New**: `Presentation/Activity/PersonalRecords/Components/PRChipBar.swift` | Horizontal scroll chip bar | Low |
| **New**: `Presentation/Activity/PersonalRecords/Components/RewardProgressSection.swift` | Level guide + progress bar + milestone grid | Medium |
| **New**: `Presentation/Activity/PersonalRecords/Components/BadgeTrophyCase.swift` | Badge collection grid | Medium |
| **New**: `Presentation/Activity/PersonalRecords/Components/FunComparisonCard.swift` | Dynamic volume/distance comparison | Low |
| **New**: `Presentation/Activity/PersonalRecords/Components/AchievementHistorySection.swift` | Enhanced history with visual hierarchy | Medium |
| `Shared/Resources/Localizable.xcstrings` | New strings en/ko/ja | Low |

## Implementation Steps

### Step 1: Domain Model Extensions

**Files**: `PersonalRecord.swift`, `ActivityPersonalRecord.swift`, `PersonalRecordStore.swift`

1. Add `RewardLevelTier` struct to `PersonalRecord.swift`:
   - `level: Int`, `name: String`, `pointsRequired: Int`
   - Static array of tiers: Beginner(1-4), Dedicated(5-9), Ironclad(10-14), Titan(15-19), Legend(20-24), Immortal(25+)
   - `static func tier(for level: Int) -> RewardLevelTier`
   - `static func pointsForNextLevel(_ currentPoints: Int) -> (current: Int, needed: Int, progress: Double)`

2. Add `WorkoutBadgeDefinition` struct:
   - `id: String`, `category: BadgeCategory`, `name: String`, `description: String`, `iconName: String`, `isUnlocked: Bool`
   - `BadgeCategory` enum: `.prRecord`, `.volume`, `.streak`, `.milestone`, `.improvement`
   - Static factory: `allDefinitions(unlockedKeys: Set<String>) -> [WorkoutBadgeDefinition]`

3. Add `FunComparison` struct:
   - `metric: String`, `value: Double`, `comparison: String`, `iconName: String`
   - Static factory: `generate(totalVolume: Double, totalDistance: Double, totalCalories: Double) -> [FunComparison]`

4. Add `previousValue: Double?` to `ActivityPersonalRecord` for delta display

**Verification**: Builds without error

### Step 2: ViewModel Extensions

**Files**: `PersonalRecordsDetailViewModel.swift`, `ActivityPersonalRecordService.swift`

1. Add to ViewModel:
   - `sparklineData(for kind: Kind) -> [Double]` — returns last N values (adaptive: min 3, max 10, based on available data)
   - `deltaValue(for record: ActivityPersonalRecord) -> Double?` — current - previous best
   - `levelTier: RewardLevelTier` computed
   - `levelProgress: (current: Int, needed: Int, fraction: Double)` computed
   - `badgeDefinitions: [WorkoutBadgeDefinition]` — all with unlock status
   - `funComparisons: [FunComparison]` — dynamically generated
   - `groupedHistory: [(month: String, events: [WorkoutRewardEvent])]` — grouped by month

2. Extend `ActivityPersonalRecordService` to supply `previousValue` when building records

**Verification**: Unit tests for delta, sparkline, level tier calculations

### Step 3: PR Card Redesign (Section)

**File**: `PersonalRecordsSection.swift`

Layout change from current 148pt to ~120pt:
1. Remove context row (HR/steps/weather) — move to detail only
2. Add `MiniSparklineView` (48x24pt) in top-right corner
3. Add delta badge (`+5.2 kg` in green) replacing context row
4. Add Kind-specific gradient tint (left edge 3pt strip + 0.05 opacity background)
5. Move source badge to small dot overlay in corner
6. Reduce `cardMinHeight` from 148 to 120

Card layout:
```
+----------------------------------+
| [Icon] Title     [Sparkline ~~] |
| Category Name                    |
| 142.5 kg  +5.2  NEW            |
| Mar 15                           |
+----------------------------------+
```

**Verification**: Visual check — cards render correctly, sparkline visible

### Step 4: Metric Chip Bar

**New file**: `PRChipBar.swift`

1. `ScrollView(.horizontal, showsIndicators: false)` + `HStack(spacing: 8)`
2. Each chip: `Button` with `Capsule()` background
3. Selected: filled with `kind.tintColor`, white text, icon
4. Unselected: `.ultraThinMaterial`, secondary text, icon
5. Height: 36pt
6. Auto-scroll to selected: `.scrollTo(selectedKind, anchor: .center)`
7. Animated selection with `matchedGeometryEffect` for background capsule
8. Namespace: `@Namespace private var chipAnimation`

**Integration**: Replace `metricPicker` in `PersonalRecordsDetailView.swift`

**Verification**: All 9 kinds scrollable, selection works, animation smooth

### Step 5: Timeline Chart Enhancement

**File**: `PersonalRecordsDetailView.swift` (timelineChart section)

1. Change `LineMark.interpolationMethod` to `.catmullRom` (already present — verify)
2. Add `AreaMark` below line with gradient fill:
   ```swift
   AreaMark(x: .value("Date", record.date), y: .value("Value", record.value))
       .foregroundStyle(
           LinearGradient(
               colors: [kind.tintColor.opacity(0.3), kind.tintColor.opacity(0.0)],
               startPoint: .top, endPoint: .bottom
           )
       )
       .interpolationMethod(.catmullRom)
   ```
3. Larger data points (60 default, 100 for latest)
4. Always show value annotation on latest point
5. Y-axis range: extend 10% above max with `.chartYScale(domain:)`
6. Keep `.padding(.top, 16)` and `.clipped()` per chart clipping rule

**Verification**: Chart renders smooth curve with gradient, latest point annotated

### Step 6: Reward Progress Section

**New file**: `RewardProgressSection.swift`

Three subsections:

**6A. Level Progress:**
- Current level + tier name
- Progress bar: `ProgressView(value:)` styled with `kind.tintColor`
- Points: `2,450 / 3,000 pts`
- Next level hint: `"Next: Level 13 — Titan (550 pts to go)"`
- Info button → sheet explaining point system

**6B. Badge Trophy Case** (`BadgeTrophyCase.swift`):
- Horizontal `ScrollView` of badge cards
- Unlocked: colored icon + name, tint border
- Locked: gray silhouette + lock overlay
- Tap unlocked → expand with earned date + description
- Counter: "8/24 unlocked"

**6C. Fun Comparison Card** (`FunComparisonCard.swift`):
- Dynamic comparison based on monthly totals
- Volume → real-world objects (piano = 400kg, car = 1500kg, elephant = 6000kg)
- Distance → cities (marathon = 42km, Seoul-Busan = 325km)
- Rotates randomly among applicable comparisons

**Integration**: Replace `rewardSummaryCard` in DetailView

**Verification**: Level progress bar fills correctly, badges show, comparisons render

### Step 7: Achievement History Enhancement

**New file**: `AchievementHistorySection.swift`

1. Group events by month with section headers ("March 2026")
2. Visual weight hierarchy per event kind:
   - `levelUp`: gold/mint gradient background, larger title font
   - `badgeUnlocked`: badge icon thumbnail, achievement description
   - `personalRecord`: activity type color accent, delta value
   - `milestone`: special background treatment
3. Points badge: pill-shaped, right-aligned, Kind-specific color
4. Empty state: motivational message

**Integration**: Replace `achievementHistorySection` in DetailView

**Verification**: Events grouped by month, visual hierarchy visible

### Step 8: Localization

**File**: `Shared/Resources/Localizable.xcstrings`

Add en/ko/ja for all new strings:
- Level tier names (Beginner, Dedicated, Ironclad, Titan, Legend, Immortal)
- Badge names and descriptions
- Fun comparison templates
- Section headers, labels, empty states
- Progress indicators

### Step 9: Build & Unit Tests

1. `scripts/build-ios.sh`
2. Unit tests for:
   - `RewardLevelTier.tier(for:)` — boundary cases
   - `FunComparison.generate()` — various volume/distance ranges
   - Delta calculation — positive, negative, zero, nil cases
   - Sparkline data extraction — empty, single, full cases

## Test Strategy

| Area | Test Type | Coverage |
|------|-----------|----------|
| Level tiers | Unit test | Boundaries: 0, 4, 5, 14, 15, 25+ |
| Fun comparisons | Unit test | Zero values, large values, edge cases |
| Delta calculation | Unit test | Positive/negative/zero/nil |
| Sparkline data | Unit test | Empty/1/N records, adaptive sizing |
| Badge definitions | Unit test | Unlock/lock status, all categories |
| PR cards | Visual | Sparkline renders, gradient visible |
| Chip bar | Visual | Scroll, selection, animation |
| Chart | Visual | Curve smooth, gradient fill, annotation |
| Reward section | Visual | Progress bar, badges, comparisons |
| History | Visual | Monthly grouping, visual hierarchy |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Card height reduction breaks layout | Medium | Test with various data lengths, use `minimumScaleFactor` |
| Chip bar scrolls past edge | Low | `ScrollViewReader` + `.scrollTo(anchor: .center)` |
| AreaMark overlaps with PointMark | Low | AreaMark rendered first (behind) |
| Badge definitions hardcoded | Low | Static array, easy to extend later |
| Fun comparisons feel forced | Low | Only show when data > threshold |

## Edge Cases

- 0 PR records → sparkline hidden, delta hidden, empty state
- 1 PR record → sparkline single dot, no delta
- All same kind → chip bar shows 1 item (no scroll needed)
- Level 1 user → progress starts from 0, motivational text
- No badges unlocked → all locked, motivational text
- Volume = 0 → fun comparison section hidden
