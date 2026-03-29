---
tags: [badge, unlock, personal-records, gamification, reward]
date: 2026-03-29
category: plan
status: approved
---

# Plan: Badge Unlock Logic Connection

## Context

16개 `WorkoutBadgeDefinition`이 정의되어 있지만 (`PersonalRecord.swift`), `PersonalRecordStore`의 실제 unlock 판정과 연결되지 않음. `unlockedBadgeKeys`가 ViewModel에 빈 Set으로 남아 있어 모든 배지가 잠김 상태로 표시됨.

## Current State

- `PersonalRecordStore.RewardState.unlockedBadges` — 기존 badge key: `"milestone-{activity}-{key}"`, `"pr-{activity}-{prType}"`
- `WorkoutBadgeDefinition` — 새 badge ID: `"badge-first-pr"`, `"badge-10-prs"`, etc.
- 두 시스템의 key namespace가 다름 → 연결 필요

## Approach

`PersonalRecordStore`에 **badge evaluation method** 추가. 누적 통계(PR 횟수, 볼륨, 스트릭, 운동 횟수 등)를 기반으로 16개 배지 ID를 unlock 판정하고, `RewardState.unlockedBadges`에 추가.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `Data/Persistence/PersonalRecordStore.swift` | Add `evaluateBadges()`, `unlockedBadgeKeySet()`, stats aggregation | Medium |
| `Domain/Models/PersonalRecord.swift` | Add `BadgeEvaluationStats` struct | Low |
| `Presentation/Activity/ActivityViewModel.swift` | Pass unlocked badge keys to detail view | Low |
| `Presentation/Activity/ActivityView.swift` | Thread `unlockedBadgeKeys` to detail view | Low |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Accept + pass badge keys | Low |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | Minor — already supports it | None |
| `DUNETests/PRVisualEnhancementTests.swift` | Add badge evaluation tests | Low |

## Implementation Steps

### Step 1: Domain — BadgeEvaluationStats

Add to `PersonalRecord.swift`:

```swift
struct BadgeEvaluationStats: Sendable {
    let totalPRCount: Int
    let distinctPRKindCount: Int
    let totalVolumeKg: Double
    let bestStreakDays: Int
    let totalWorkoutCount: Int
    let daysSinceFirstWorkout: Int
    let bestImprovementPercent: Double
    let bestPacePerKm: Double  // seconds per km, 0 if no pace data
}
```

### Step 2: PersonalRecordStore — Badge Evaluation

Add methods:
1. `evaluateBadges(stats: BadgeEvaluationStats)` — checks all 16 badges, returns newly unlocked IDs
2. `unlockedBadgeKeySet() -> Set<String>` — returns current unlocked badge IDs
3. Wire `evaluateBadges` into `evaluateReward()` (call after PR/milestone eval)

Badge → Stat mapping:
| Badge ID | Condition |
|----------|-----------|
| badge-first-pr | totalPRCount >= 1 |
| badge-10-prs | totalPRCount >= 10 |
| badge-50-prs | totalPRCount >= 50 |
| badge-all-kinds | distinctPRKindCount >= 5 |
| badge-1k-volume | totalVolumeKg >= 1_000 |
| badge-10k-volume | totalVolumeKg >= 10_000 |
| badge-100k-volume | totalVolumeKg >= 100_000 |
| badge-7-streak | bestStreakDays >= 7 |
| badge-30-streak | bestStreakDays >= 30 |
| badge-100-streak | bestStreakDays >= 100 |
| badge-first-workout | totalWorkoutCount >= 1 |
| badge-100-workouts | totalWorkoutCount >= 100 |
| badge-365-days | daysSinceFirstWorkout >= 365 |
| badge-10pct-improve | bestImprovementPercent >= 10 |
| badge-double-lift | bestImprovementPercent >= 100 |
| badge-sub5-pace | bestPacePerKm > 0 && bestPacePerKm <= 300 |

### Step 3: ActivityViewModel — Stats Aggregation & Passing

1. Add `computeBadgeStats()` that aggregates from existing data
2. Call `PersonalRecordStore.shared.evaluateBadges(stats:)` during `recomputePersonalRecordsOnly()`
3. Add `unlockedBadgeKeys: Set<String>` published property
4. Pass to `PersonalRecordsDetailView`

### Step 4: View Wiring

- `ActivityView`: pass `viewModel.unlockedBadgeKeys` to `PersonalRecordsDetailView`
- `PersonalRecordsDetailView`: accept, pass to ViewModel in `.task`
- ViewModel already uses it for `badgeDefinitions`

### Step 5: Unit Tests

Test `evaluateBadges()` with various stat combinations:
- Zero stats → no badges
- Exactly at threshold → badge unlocked
- Idempotent — calling twice doesn't duplicate

## Test Strategy

| Test | Coverage |
|------|----------|
| Zero stats | No badges unlocked |
| First PR threshold | badge-first-pr only |
| Volume thresholds | 1K/10K/100K progressive |
| Streak thresholds | 7/30/100 progressive |
| Pace threshold | Sub 5min/km |
| All badges | Max stats → all 16 unlocked |
| Idempotent | Double call → same result |

## Risks

| Risk | Mitigation |
|------|------------|
| Stats aggregation expensive | Compute only during PR refresh (not per render) |
| Badge key collision with existing | New badge keys prefixed with `badge-` — no collision |
| Missing streak data | Default to 0 if WorkoutStreak is nil |

## Edge Cases

- No workout data → all badges locked, empty stats
- WorkoutStreak nil → streak badges stay locked
- Pace data only in meters → convert to seconds/km
