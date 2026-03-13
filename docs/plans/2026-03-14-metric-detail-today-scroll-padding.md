---
topic: metric detail today scroll padding
date: 2026-03-14
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-chart-scrollable-axes-visible-domain.md
  - docs/solutions/general/2026-03-08-chart-long-press-scroll-regression.md
  - docs/solutions/architecture/2026-03-11-metric-detail-weekly-chart-current-day-alignment.md
  - docs/solutions/general/2026-03-12-condition-score-rhr-baseline-and-chart-scroll.md
related_brainstorms: []
---

# Implementation Plan: Metric Detail Today Scroll Padding

## Context

HRV metric detail weekly chart shows the current-day value pinned to the far right edge, the visible range header shifts left to `3.7 – 3.14`, and the user cannot scroll far enough to fully reach the current day. The chart data itself is present, but the scroll domain ends at `Date()` instead of the next calendar boundary, so Swift Charts clamps the latest visible window before the intended today-aligned start.

## Requirements

### Functional

- HRV/RHR/detail charts must allow the current period to align to the full current day instead of clamping at the current time.
- Current-day point must remain reachable at the right edge without cutting off the final axis label.
- Condition Score detail and shared metric detail must stay consistent because they share the same scroll behavior.

### Non-functional

- Do not widen HealthKit fetch windows into the future.
- Keep gesture/selection behavior unchanged.
- Add regression coverage for the date-boundary helper and/or ViewModel scroll domain.

## Approach

Introduce a period-aware helper that computes the scroll/display upper bound aligned to the next calendar boundary for the selected period. Use that helper only for chart scroll domain calculation, while leaving data fetch ranges based on `now`. This fixes the clamp without changing summary calculations or adding future data queries.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Extend fetch end to tomorrow/end-of-day | Easy to reason about | Queries future empty buckets, mixes display concern into data layer | Rejected |
| Add extra x-domain padding only in `DotLineChartView` | Small chart-only diff | Leaves `RangeBarChartView` and condition detail divergent, duplicates time logic | Rejected |
| Separate display-domain helper used by ViewModels | Fixes root cause once, reusable across detail charts, keeps fetch logic intact | Requires small model/API expansion and tests | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/TimePeriod.swift` | modify | Add helper for scroll/display upper bound aligned to next boundary |
| `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift` | modify | Use aligned display domain for `scrollDomain` |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | modify | Use same aligned display domain for score detail chart |
| `DUNETests/TimePeriodTests.swift` | modify | Add deterministic regression test for today-inclusive scroll upper bound |
| `DUNETests/MetricDetailViewModelTests.swift` or new related test | modify | Add regression around scroll domain / visible start behavior |

## Implementation Steps

### Step 1: Add display-domain boundary helper

- **Files**: `DUNE/Domain/Models/TimePeriod.swift`, `DUNETests/TimePeriodTests.swift`
- **Changes**: Add a helper that returns the exclusive upper bound for chart scrolling aligned to the next hour/day/month/year boundary as appropriate for the selected period.
- **Verification**: Unit test proves `.week` on `2026-03-14 02:52` resolves to `2026-03-15 00:00`.

### Step 2: Apply aligned upper bound to detail view models

- **Files**: `DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift`, `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift`
- **Changes**: Keep `extendedRange.end` for data loading, but compute `scrollDomain` with the new helper so the visible domain is not clamped by `now`.
- **Verification**: ViewModel-level test or assertion confirms weekly scroll domain upper bound covers the full current day.

### Step 3: Validate chart behavior and guard regressions

- **Files**: test files only unless additional helper wiring is required
- **Changes**: Add/adjust tests for weekly detail chart alignment and run targeted test/build commands.
- **Verification**: Targeted unit tests pass; manual reasoning confirms header can remain today-inclusive (`3.8 – 3.14`) without cutting off the right edge.

## Edge Cases

| Case | Handling |
|------|----------|
| Current time is early morning | Scroll domain still extends to next day boundary, preventing leftward clamp |
| Sparse metrics with no sample today | Domain still shows the current day window without requiring fake data |
| Day period charts | Helper uses the next hour/day boundary appropriate for full-day display without changing fetch range |
| Six-month/year charts | Helper aligns to the next month/year boundary so long-period scroll remains stable |

## Testing Strategy

- Unit tests: `TimePeriod` helper boundary tests, ViewModel scroll-domain regression tests.
- Integration tests: Not adding a new UI test unless unit coverage proves insufficient; existing chart interaction UI suite remains the broader safety net.
- Manual verification: Confirm weekly HRV detail header/right edge no longer clamps before today and current-day point is reachable.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Helper overcorrects long-period charts | Low | Medium | Cover week/day explicitly and keep helper boundary logic period-specific |
| Visible range labels diverge from actual chart domain | Low | Medium | Reuse the same period semantics already used by `visibleRangeLabel` |
| Existing selection/scroll interaction regresses | Low | High | Keep gesture code untouched and run targeted tests/build |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The screenshot matches Swift Charts clamp behavior exactly, and the fix is localized to the display domain path already called out in earlier chart-scroll solutions.
