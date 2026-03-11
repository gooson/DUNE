---
topic: metric detail weekly chart current day alignment
date: 2026-03-11
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-chart-scroll-unified-vitals.md
  - docs/solutions/architecture/2026-03-08-chart-scroll-domain-sparse-data.md
  - docs/solutions/testing/2026-03-08-training-volume-daily-volume-scroll-and-day-bucket-alignment.md
related_brainstorms: []
---

# Implementation Plan: Metric Detail Weekly Chart Current Day Alignment

## Context

HRV metric detail week chart can clamp to the last day that has an actual data point instead of preserving the current 7-day window. In practice, when today has no HRV sample yet, the chart shifts left and the user sees Tuesday as the last x-axis label even on Wednesday. The visible range header is also computed with an exclusive end boundary, so the label can show a one-day-larger end date than the actual visible buckets.

## Requirements

### Functional

- HRV weekly detail chart must keep the current visible 7-day window even when today has no data point.
- RHR detail chart should follow the same rule because it uses the same chart/domain pattern.
- Visible range header for week mode must display the inclusive end date that matches the visible buckets.

### Non-functional

- Reuse the existing `scrollDomain` and shared chart domain patterns already introduced for vitals/body composition.
- Keep the fix surgical to metric detail charts and period label formatting.
- Add regression tests for the date label logic and affected detail view model behavior.

## Approach

Pass `MetricDetailViewModel.scrollDomain` into HRV/RHR chart views so Swift Charts uses the intended date domain rather than deriving it from sparse points. Then fix `TimePeriod.visibleRangeLabel(from:)` to render the inclusive end date for range-based windows by formatting the last visible instant instead of the exclusive boundary.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Fill missing HRV/RHR dates with zero-value points | Forces today to appear in data | Physiologically wrong for vitals, distorts line shape and summaries | Rejected |
| Change HealthKit query/service to always synthesize empty buckets | Could centralize gap handling | Service layer should stay data-authentic; UI domain problem remains | Rejected |
| Pass explicit chart domain + fix label formatting | Matches existing chart architecture and preserves real data points | Requires touching both view and date-label formatting | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | Code | Pass `scrollDomain` to HRV/RHR chart views |
| `DUNE/Presentation/Shared/Extensions/TimePeriod+View.swift` | Code | Format inclusive end date for visible range labels |
| `DUNETests/TimePeriodTests.swift` | Test | Lock week visible range label against exclusive-end off-by-one regression |
| `DUNETests/MetricDetailViewModelTests.swift` | Test | Cover current-week behavior and preserve metric detail regression expectations |

## Implementation Steps

### Step 1: Align HRV/RHR chart domain with the current window

- **Files**: `DUNE/Presentation/Shared/Detail/MetricDetailView.swift`
- **Changes**: Inject `viewModel.scrollDomain` into `.hrv` and `.rhr` `DotLineChartView`/`RangeBarChartView` calls, matching the vitals fix pattern.
- **Verification**: Confirm HRV/RHR chart constructors now receive an explicit x-domain source.

### Step 2: Fix inclusive visible range labeling

- **Files**: `DUNE/Presentation/Shared/Extensions/TimePeriod+View.swift`
- **Changes**: Compute a display end date from the last visible instant instead of the exclusive boundary for range-based labels.
- **Verification**: Week range labels render the last visible day rather than the next day.

### Step 3: Add regression coverage

- **Files**: `DUNETests/TimePeriodTests.swift`, `DUNETests/MetricDetailViewModelTests.swift`
- **Changes**: Add/adjust tests for week visible range label formatting and HRV detail current-window expectations.
- **Verification**: Targeted unit tests fail before the fix and pass after it.

## Edge Cases

| Case | Handling |
|------|----------|
| No HRV/RHR data at all | Chart still uses explicit domain; empty-state behavior stays unchanged |
| Today has partial data late in the day | Explicit domain still keeps today in view; actual point appears when available |
| User scrolls into history | Inclusive header formatting should continue to match the last visible day/month in the scrolled window |

## Testing Strategy

- Unit tests: `TimePeriodTests`, `MetricDetailViewModelTests`
- Integration tests: build the iOS app to catch SwiftUI/chart API regressions
- Manual verification: open HRV detail in week mode with no current-day sample and confirm Wednesday remains visible on 2026-03-11

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Inclusive label fix affects six-month labels unexpectedly | Low | Medium | Keep change formatter-based and cover week explicitly; inspect six-month output during review |
| Explicit scroll domain changes initial chart placement | Low | Medium | Reuse the already-shipped vitals/body composition pattern rather than inventing new logic |
| Tests depend on locale-sensitive date formatting | Medium | Low | Assert against calendar-derived expected end dates instead of hard-coded localized strings where possible |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: The current HRV/RHR code path is the only metric detail chart path still missing `scrollDomain`, and the date label bug is directly visible in `visibleRangeLabel(from:)`.
