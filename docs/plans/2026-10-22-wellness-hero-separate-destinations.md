---
topic: Wellness hero score and sleep destinations
date: 2026-10-22
status: approved
confidence: high
related_solutions: [docs/solutions/design/hero-cta-button-pattern.md, docs/solutions/general/2026-10-22-contextual-first-fold-hero.md]
related_brainstorms: [docs/brainstorms/2026-03-14-hero-card-detail-unification.md]
---

# Implementation Plan: Wellness hero score and sleep destinations

## Context

The Wellness hero currently puts both the score and sleep summary inside one score `NavigationLink`. Tapping a sleep bar or duration therefore opens the score detail, while a separate footer opens the sleep detail. The visible data and tap result disagree.

## Requirements

- Score title, ring, and narrative open the Wellness score detail.
- Sleep title, chart, and duration/average open the sleep metric detail when a sleep metric exists.
- No nested links or competing gestures. Keep a visible sleep detail affordance and the score fallback when sleep data is unavailable.
- Preserve compact, regular-width, and accessibility text layouts and useful VoiceOver labels.

## Approach

Use two sibling `NavigationLink`s inside the existing card: one for score content and one for sleep content. Keep the footer as a visible link to the same sleep destination. When the sleep metric is absent, render the sleep content as static information and retain the score detail footer.

### Alternative Approaches Considered

| Approach | Benefit | Cost | Decision |
|---|---|---|---|
| Keep the entire card linked to score | Minimal code | Sleep tap still has the wrong destination | Reject |
| Overlay an invisible sleep button | Preserves exact layout | Hit testing and accessibility ambiguity | Reject |
| Two sibling semantic sections | Clear destinations and VoiceOver actions | Small spacing change on compact width | Adopt |

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift` | Split score and sleep links; independent accessibility |
| `DUNEUITests/Smoke/WellnessSmokeTests.swift` | Seeded route tests and summary accessibility assertion |
| `DUNEUITests/Visual/ThemeMatrixUITests.swift` | Adjust link-bound layout assertions |
| `docs/design/phone-design-map/actual/` | Refresh affected actual screen capture per repository rule |

## Implementation Steps

1. Split the card content into score and sleep sections, preserving iPhone stack and iPad columns. Verify Swift build.
2. Add seeded UI coverage for both tap destinations and the distinct sleep accessibility summary. Update existing layout assertion for the new separate targets.
3. Run the scoped UI plan, focused/required smoke tests on a worktree-owned simulator, and refresh the affected design map capture.

## Edge Cases

| Case | Handling |
|---|---|
| Sleep metric missing | Sleep section remains readable, not tappable; score footer stays available |
| Sleep trend has zero or one valid sample | Existing latest/average display rules remain unchanged |
| Accessibility text on iPad | Stacked layout keeps both links separately reachable |

## Testing Strategy

- Build: `scripts/build-ios.sh`.
- UI: `WellnessSeededSmokeTests` route and data assertions plus required common smoke selected by the UI planner.
- Visual: affected Wellness actual capture and iPad layout check where required by the card layout change.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| SwiftUI merges link accessibility children | Medium | Route or AX test failure | Assign separate link identifiers and assert both destinations |
| Compact section spacing grows | Medium | Hero pushes first fold content | Inspect simulator capture and adjust spacing |
| iPad frame assertions assume one encompassing link | High | Existing UI test failure | Update assertions to each semantic section |
