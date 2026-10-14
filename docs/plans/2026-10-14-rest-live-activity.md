---
tags: [ios27, wwdc26, activitykit, widgetkit, dynamic-island, watch-smart-stack]
date: 2026-10-14
category: plan
status: approved
topic: Rest timer Live Activity layouts
confidence: high
related_solutions:
  - docs/solutions/general/2026-10-14-rest-live-activity-layouts.md
related_brainstorms: []
---

# Implementation Plan: Rest timer Live Activity layouts

## Context

The rest timer Live Activity already renders on the Lock Screen and Dynamic Island. iOS 27 adds a constrained landscape Dynamic Island presentation, and the Live Activity can opt into a smaller rendering for the paired Apple Watch Smart Stack. The current compact trailing view always uses the regular countdown width, and the Lock Screen view has no family-specific layout.

## Requirements

### Functional

- Preserve the existing ActivityKit attributes, countdown interval, and normal Dynamic Island/Lock Screen rendering.
- Use `isDynamicIslandLimitedInWidth` to fit the countdown in the narrow compact trailing presentation.
- Opt into `ActivityFamily.small` and render a concise exercise, set, and countdown layout when that family is active.
- Keep user-visible labels localized through existing SwiftUI string catalog behavior; provide accessible combined context for the compact Watch layout.

### Non-functional

- Limit app code changes to the DUNEWidget Live Activity view.
- Do not change Live Activity start/update/end behavior or shared attributes.
- Record device-specific UI validation and actual screen captures; do not report unavailable captures as complete.

## Approach

Read `activityFamily` in a small content view used by the ActivityConfiguration Lock Screen closure. Keep the current Lock Screen VStack for `.medium`; use a compact view for `.small`. Add `.supplementalActivityFamilies([.small])`. In the Dynamic Island compact trailing closure, preserve the existing countdown and regular width when space is available; when limited, keep the same countdown interval and use a smaller single-line font/width.

This uses the APIs shown in WWDC26 session 223: `@Environment(\.isDynamicIslandLimitedInWidth)`, `@Environment(\.activityFamily)`, and `.supplementalActivityFamilies([.small])`.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Replace the narrow countdown with an icon | Maximum width savings | Hides the remaining time in the exact context where it is useful | Rejected |
| Keep the same view for every activity family | Smallest source diff | Existing Lock Screen layout is too dense for Watch Smart Stack | Rejected |
| Compact the countdown and add a Watch-specific layout | Preserves timer behavior while fitting both contexts | Requires device presentation verification | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWidget/WorkoutRestLiveActivity.swift` | Modify | Adapt the constrained countdown and add `.small` family rendering |
| `docs/plans/2026-10-14-rest-live-activity.md` | Add | Record implementation, risks, and validation plan |
| `docs/solutions/general/2026-10-14-rest-live-activity-layouts.md` | Add | Record the reusable Live Activity layout pattern after implementation |
| `docs/design/live-activity-captures/README.md` | Add | Keep the exact pending capture matrix and required output paths visible |

## Implementation Steps

### Step 1: Add adaptive Live Activity presentations

- **Files**: `DUNEWidget/WorkoutRestLiveActivity.swift`
- **Changes**: Compact the countdown only when Dynamic Island width is limited; opt in to `.small`; use `activityFamily` to show exercise, set, and the same active countdown on Watch.
- **Verification**: Inspect the focused diff and run static syntax/whitespace checks. Xcode build and UI execution are deferred until the host is available.

### Step 2: Capture the affected device presentations

- **Files**: `docs/design/live-activity-captures/README.md`, `docs/design/phone-design-map/actual/` when that map is available in this worktree.
- **Changes**: Capture the iPhone portrait baseline, iPhone landscape limited-width Dynamic Island, and paired Watch Smart Stack `.small` activity. Update the integrated actual design map for the affected surfaces.
- **Verification**: Confirm each PNG is captured from the current implementation and identify device/OS state. If unavailable, keep the IDs pending with the specific reason.

## Edge Cases

| Case | Handling |
|------|----------|
| Countdown displayed in narrow landscape Island | Use smaller single-line typography and constrained width while retaining the same timer interval |
| Activity rendered on Lock Screen/iPad/Mac at medium family | Preserve the existing Lock Screen content |
| Activity rendered in Watch Smart Stack | Use the small family layout with exercise, set, and live countdown |
| Watch or simulator unavailable | Leave the relevant capture and UI verification pending; do not claim completion |

## Testing Strategy

- **Unit tests**: None for this view-only change; the project testing rule exempts SwiftUI `View.body` logic.
- **Build**: Build the app/widget scheme after the host is available; confirm iOS 27 WidgetKit APIs compile.
- **UI verification**: Verify Dynamic Island portrait and landscape constrained presentations, Watch Smart Stack small family, VoiceOver grouping, and countdown progression. A generic app UI test cannot directly host these system surfaces; use the Live Activity preview/system host or device capture workflow.
- **Captures**: `docs/design/live-activity-captures/iphone-dynamic-island-portrait.png`, `docs/design/live-activity-captures/iphone-dynamic-island-landscape-limited.png`, and `docs/design/live-activity-captures/watch-smart-stack-small.png`, then synchronize the actual design map when available.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Countdown text still truncates at a particular landscape width | Medium | Medium | Verify on the narrowest available supported Dynamic Island and adjust only compact typography/width |
| `.small` presentation differs across paired Watch sizes | Medium | Medium | Capture on a paired Watch simulator/device with current OS and review VoiceOver output |
| Xcode compilation unavailable during this implementation turn | Certain | Medium | Mark build/UI results unverified and resume once host capacity is released |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: Apple’s WWDC26 session and WidgetKit/SwiftUI documentation show the exact APIs and intended family routing. Runtime appearance remains unverified until the requested host window is available.
