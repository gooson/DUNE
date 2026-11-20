---
tags: [design, iphone, r13]
date: 2026-11-21
category: plan
status: approved
---
# R13 · achievement day groups

Approved reference: `docs/design/layout-map/reference-improvement-proposals.md` and `docs/design/theme-map/themes/dune-reference-proposals.html`. Implement as one PR on main `9d2f82398`; preserve DUNE tokens, existing navigation and data semantics.

## Implementation

Existing monthly reward history is grouped by calendar day. The date appears once in a left rail at normal text size and stacks above events at accessibility sizes. Day identity uses start-of-day Date; event identity, order, details and points remain.

## Verification

- Focused tests: AchievementHistoryGroupingTests.sameDayRewards and ActivityExerciseRegressionTests.testPersonalRecordsDetailShowsTimelineRewardsAndHistory.
- Native capture IDs: Regular iPhone, iPad, Duo folded/open A10; same-day events, cross-day, empty state, large text.
- Update the detail layout-map link and actual design map with new source/device/state provenance. Browser proposals are not native captures.
- Use `scripts/build-ios.sh`, the owned simulator UI runner, and `swift scripts/format-xcstrings.swift --check` if a catalog changes.
