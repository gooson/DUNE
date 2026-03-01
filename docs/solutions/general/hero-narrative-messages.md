---
tags: [ux, hero-card, narrative, localization, domain-model]
date: 2026-03-02
category: solution
status: implemented
---

# Hero Card Data-Driven Narrative Messages

## Problem

Hero score cards (Condition, Training Readiness, Wellness) displayed generic status-based messages ("Condition looks good", "Normal training is fine") that didn't leverage available data. Users couldn't understand *why* their score was what it was.

## Solution

Added `narrativeMessage` computed property to each Domain model struct that generates context-aware messages using available detail/component data:

### Pattern

```swift
// Domain model (no SwiftUI import needed)
struct Score: Sendable {
    let status: Status
    let detail: Detail?

    var narrativeMessage: String {
        guard let detail else { return status.guideMessage }
        // Use detail data to generate specific message
        switch status {
        case .good:
            if detail.someMetric > threshold {
                return String(localized: "Good — specific reason")
            }
            return String(localized: "Good — generic reason")
        ...
        }
    }
}
```

### Key Decisions

1. **Computed property on Domain struct** (not Status enum) — needs access to detail/component data
2. **Fallback to `status.guideMessage`** when detail is nil — graceful degradation
3. **`String(localized:)` in Domain** — acceptable per project rules (Foundation only)
4. **Weakest-component detection** — for TrainingReadiness, identifies which sub-score drags overall score down (threshold: 15 points below average of others)

### Files Modified

| File | Change |
|------|--------|
| `Domain/Models/ConditionScore.swift` | Added `narrativeMessage` using HRV baseline comparison + RHR penalty |
| `Domain/Models/TrainingReadiness.swift` | Added `narrativeMessage` + `findWeakestComponent()` helper |
| `Domain/Models/WellnessScore.swift` | Added `narrativeMessage` using sub-score gap detection |
| Hero views (3 files) | Changed from `status.guideMessage` to `model.narrativeMessage` |

## Prevention

- When adding new score types, always provide both `status.guideMessage` (simple fallback) and `narrativeMessage` (data-driven) per Correction #113
- Narrative messages must use `String(localized:)` for all user-facing text
