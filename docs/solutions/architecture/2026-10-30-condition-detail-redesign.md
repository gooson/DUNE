---
tags: [swiftui, condition-score, chart-window, accessibility, design-map, xcresult]
category: architecture
date: 2026-10-30
severity: important
related_files:
  - DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift
  - DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift
  - DUNE/Presentation/Shared/Extensions/ConditionScore+View.swift
  - DUNEUITests/Full/ConditionDetailRedesignTests.swift
related_solutions:
  - 2026-03-14-score-detail-unification.md
---

# Solution: Condition detail with synchronized evidence and history

## Problem

A visual prototype used example contribution percentages and a separate summary card. Translating that layout literally would misrepresent the actual condition model and duplicate date ranges. The native view also needed a single calculation disclosure while retaining the original explanations, five periods, subscore charts, and limited-history behavior.

### Symptoms

- A missing or insufficient RHR baseline could appear as an applied zero adjustment.
- Calendar summaries could disagree with a chart using a fixed visible duration, especially at month ends or DST boundaries.
- AX existence alone let a test take screenshots or tap coordinates outside the viewport.
- At maximum Accessibility text, a scaled 620pt inner chart overflowed its 360pt outer frame and drew an axis value over period controls.

### Root Cause

Presentation needed the actual model's applicability rules, and history needed one captured reference window. Two independent chart heights and existence-only scrolling hid geometry regressions until fresh PNG review.

## Solution

| File | Change | Reason |
|------|--------|--------|
| `ConditionDetailHeader.swift` / `ScoreHeroPalette.swift` | Reuse Today palette and native ring; show actual measurements and model impacts | Preserve the tab's visual identity without inventing contributions |
| `ConditionScore+View.swift` | Share domain minimum-baseline eligibility between RHR adjustment and contribution impact | Distinguish unavailable adjustment from a valid zero |
| `ConditionScoreDetailViewModel.swift` | Use one fixed-duration history window, full-window navigation, and raw visible/prior samples | Keep query, chart, date label, and summary aligned |
| `ConditionScoreDetailView.swift` | Integrate controls/chart/summary, one native disclosure, 44pt content shapes | Retain existing functions with less duplication |
| `ConditionScoreDetailView.swift` | Let `DotLineChartView` own its scaled height | Reserve actual chart space at AX sizes without changing the shared component |
| `ConditionDetailRedesignTests.swift` | Reveal real viewport/hittable targets; compare rendered chart footprint against controls | Verify pixels and interaction geometry, not just AX presence |

### Key Code

For duration `D`, captured reference `now`, and chart buffer count `N`:

```text
U = now (day), otherwise next calendar-day start
A = U - D
L = A - N * D
chart domain = L ... U
initial visible start = A
navigation target = current start +/- D, accepted only in L ... A
```

Statistics use half-open windows from raw hourly/daily data before chart aggregation. Remove unused legacy summary production and its two dedicated queries; retain independent highlight/subscore semantics.

## Prevention

- Test month-end, leap-day, DST, today inclusion, contiguous navigation, and query bounds with fixed references.
- Keep unavailable, valid zero, and signed nonzero adjustments distinct in presentation tests. Cover a nonempty neutral model contribution during baseline building; both its label and color must consume the gated impact.
- Let a scaled chart establish its own layout height; compare its actual probe footprint with adjacent controls at maximum AX text.
- Drag in a scroll gutter and verify target geometry before coordinate taps. Coarse card navigation must check a real viewport intersection before handing off to precise value positioning; AX existence alone can silently skip that phase. Allow only a negligible floating-point tolerance around44pt.
- Export xcresult attachments immediately. Preserve failed-run receipts and pair a new PNG with the same capture event's AX data and explicit source revision.
- Refresh only the changed screen in each device map and assert that unrelated capture-index entries remain unchanged.

## Lessons Learned

A visual design is ready when its values, windows, touch targets, and large-text geometry agree with the native model. A passed AX-existence assertion does not establish visible placement; inspect fresh images as a separate quality step. Shared components can often stay unchanged when a conflicting constraint belongs to the new consumer.
