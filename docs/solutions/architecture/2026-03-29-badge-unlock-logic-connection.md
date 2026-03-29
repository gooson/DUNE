---
tags: [badge, unlock, gamification, personal-records, reward, stats-aggregation]
date: 2026-03-29
category: architecture
status: implemented
---

# Badge Unlock Logic Connection

## Problem

16개 `WorkoutBadgeDefinition`이 UI에 정의되어 있지만, `PersonalRecordStore`의 실제 unlock 판정과 연결되지 않아 모든 배지가 영구적으로 잠김 상태로 표시됨. 기존 `unlockedBadges` key namespace (`"milestone-{activity}-{key}"`, `"pr-{activity}-{prType}"`)와 새 배지 정의 ID (`"badge-first-pr"` 등)가 다른 namespace를 사용.

## Solution

### Architecture

```
ActivityViewModel.loadPersonalRecords()
  → computeBadgeStats() — single-pass aggregation from snapshots + PRs
  → PersonalRecordStore.evaluateBadges(stats:) — checks 16 rules, persists unlocks
  → unlockedBadgeKeys → PersonalRecordsDetailView → ViewModel.badgeDefinitions
```

### Key Decisions

1. **Badge evaluation rules in Domain** (`WorkoutBadgeDefinition.evaluateUnlocks`) — pure function, testable
2. **Persistence in Data layer** (`PersonalRecordStore.evaluateBadges`) — manages RewardState
3. **Stats aggregation in ViewModel** — has access to both snapshots and PRs

### Review Fixes

- `totalVolumeKg`: Changed from PR peak sum to actual exercise snapshot weight sum
- `totalPRCount`: Changed from display row count to reward history event count
- `computeBadgeStats()`: Consolidated from 6 passes to 2 single-pass loops + cached Calendar

## Prevention

- **Volume aggregation**: Never sum PR values as "cumulative total" — PRs are peak records, not running totals. Use `allExerciseSnapshots.totalWeight` for actual volume.
- **PR count**: Display rows (merged/deduped for UI) ≠ historical PR events. Use `workoutRewardHistory.filter(.personalRecord).count` for event count.
- **Calendar in loops**: Always `let cal = Calendar.current` before loops, per performance-patterns.md.
