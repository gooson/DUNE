---
tags: [design, iphone, r13]
category: design
date: 2026-11-21
status: draft
related_files:
  - DUNE/Presentation/Activity/
---
# Solution: R13 · achievement day groups

## Problem

The approved reference hierarchy for A10 is not represented in the existing native view.

## Change

Existing monthly reward history is grouped by calendar day. The date appears once in a left rail at normal text size and stacks above events at accessibility sizes. Day identity uses start-of-day Date; event identity, order, details and points remain.

## Evidence to attach before merge

- Focused tests to run: AchievementHistoryGroupingTests.sameDayRewards and ActivityExerciseRegressionTests.testPersonalRecordsDetailShowsTimelineRewardsAndHistory.
- Fresh native screenshots and capture indices: Regular iPhone, iPad, Duo folded/open A10; same-day events, cross-day, empty state, large text.
- Record build result, exact revision, simulator IDs, and any unverified states. Do not treat proposal PNGs or earlier captures as implementation evidence.
