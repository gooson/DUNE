---
tags: [swiftui, injury-detail, dynamic-type, accessibility, hero-card]
category: general
date: 2026-11-06
severity: minor
related_files: [DUNE/Presentation/Injury/InjuryHistoryView.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# Solution: Keep injury detail readable without losing record actions

## Problem

### Symptoms

- The prior detail presented severity, body part, status, and duration in a compact summary. At large text sizes, that hierarchy was hard to scan.
- Start, end, recorded date, and memo still needed to remain reachable below the summary. Active records also needed the existing recovery and edit actions.

### Root Cause

The summary used a dense row inside a standard card, while duration was repeated in the timeline. The visual hierarchy did not distinguish the current injury state from record metadata. During iPad validation, the value-based `NavigationLink` inside the mutable Active/Recovered `List` selected the row without presenting detail. The exact SwiftUI mechanism was not isolated, but the route state needed ownership outside those changing rows.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `DUNE/Presentation/Injury/InjuryHistoryView.swift` | Use a severity-tinted `HeroCard` with body part, severity, status, duration, and description; retain timeline and memo cards. | Make the current injury readable first, then show dates and notes. |
| Same | Use a stacked detail-row layout at accessibility text sizes and preserve the conditional side, empty memo, active recovery action, edit sheet, and back navigation. | Keep real record states and actions available. |
| Same | Move row activation to a plain Button that sets `selectedInjury`; present detail with `.navigationDestination(item:)` owned by the history view. | Keep the route alive when recovery moves a record between list sections, and make first tap present detail on iPad. |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | Check active detail/Edit Save, recovery while detail remains open, recovered MAX text, action removal, and return to the updated history. | Guard both record states and the mutable route. |

### Key Code

```swift
let layout = dynamicTypeSize.isAccessibilitySize
    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
    : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
```

The hero owns the duration value; the timeline shows Start, End, and Recorded once each. Severity color is darkened in Light appearance for readable icon and action tint.

## Prevention

### Checklist Addition

- [ ] Review active and recovered records separately at regular and accessibility text sizes, including optional side and memo.
- [ ] After changing detail hierarchy, verify Edit Save, Mark Recovered availability, and back navigation with fresh screen evidence.

## Lessons Learned

A record detail can emphasize one current state while preserving the dates and actions that make it useful. A stacked layout for large text avoids compressing values into narrow columns. Navigation state for a row that can move between sections belongs to the stable history view, not to that row’s identity.

## Validation

Normal iPhone, iPad, Duo closed/open and closed Duo maximum text were checked with the relevant selected methods and independent PNG/AX review. The [native gallery](../../design/full-redesign-map/review/h10-injury-detail-native-2026-11-06/index.html) records each executed source, individual result, fixture, paired assets, preserved failures, and remaining P3 notes. No full-suite, Dark, physical-device or VoiceOver claim is made.
