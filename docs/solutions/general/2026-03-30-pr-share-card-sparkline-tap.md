---
tags: [personal-records, image-renderer, sparkline, navigation, share, swiftui]
date: 2026-03-30
category: general
status: implemented
---

# PR Share Card + Sparkline Tap Interaction

## Problem

1. **No share functionality for PRs**: Users couldn't share their personal records on social media. WorkoutShareCard existed but no equivalent for PRs.
2. **Sparkline not interactive**: MiniSparklineView in PR section cards was display-only (`accessibilityHidden(true)`), missing an opportunity to navigate directly to the relevant metric kind.

## Solution

### PR Share Card

- Created `PRShareCard` and `PRShareService` following the exact pattern from `WorkoutShareCard`/`WorkoutShareService`
- Applied correction #209: `sizeThatFits` + explicit `frame` + `proposedSize` to prevent zero-height ImageRenderer issues
- Added share button to `PersonalRecordsDetailView.currentBestCard`
- Reused existing `ShareImageSheet` and `ShareableImage` for the share flow

### Sparkline Tap Interaction

- Added `@Binding var sparklineTappedKind` to `PersonalRecordsSection`
- Changed `ActivityDetailDestination.personalRecords` to accept `preselectedKind: ActivityPersonalRecord.Kind?`
- In `activityDetailView(for:)`, passes `preselectedKind ?? sparklineTappedKind` to the detail view
- Detail view uses `preselectedKind` instead of `availableKinds.first` when set
- `.onAppear` resets `sparklineTappedKind` to prevent stale state

### Key Pattern: Sparkline tap within NavigationLink

The sparkline is nested inside a `NavigationLink`. The `onTapGesture` on the sparkline sets `sparklineTappedKind` state, and the NavigationLink simultaneously activates. The detail view resolver reads `sparklineTappedKind` from the parent view's state. This avoids the need for programmatic navigation while still passing the kind.

## Prevention

- When adding associated values to enum cases used in `switch` pattern matching, search for all existing `case .enumCase:` patterns — they may compile but behave differently with associated values
- Test files may reference enum cases that now need parentheses (`.personalRecords` → `.personalRecords()`)
- New files must be in the correct directory for the xcodegen target (e.g., `DUNETests/` not `DUNE/DUNETests/`)

## Lessons Learned

- ImageRenderer share pattern is well-established: copy WorkoutShareService for any new share card type
- Enum associated values with defaults (`= nil`) are source-compatible for `switch case` matching but NOT for enum literal usage (`.personalRecords` must become `.personalRecords()`)
- Sparkline tap within NavigationLink: use parent @State + binding + onAppear reset rather than trying to intercept NavigationLink activation
