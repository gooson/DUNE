---
topic: T12 notification message detail redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-10-05-notification-landing-route-audit.md
related_brainstorms: []
---

# Implementation Plan: T12 Notification Message Detail

## Context

`NotificationHubView` pushes `NotificationMessageDetailView` for stored messages. The destination receives only the saved title and body and currently shows both in one undifferentiated standard card. The approved browser gallery snapshot at `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894` includes T12 with sample health metrics/action, but those are fixture-only and unsupported by this destination. The T12 redesign gives the title a clear document hero and the full message a comfortable reading area. It must keep the existing route, text, scroll, and system back behavior.

## Requirements

### Functional

- Show the exact stored title and body, including long and multiline messages. Do not infer notification type, date, count, or status from them.
- Keep the inbox route and native back behavior. Do not add actions that lack a real destination.
- Retain `notification-message-detail-screen` and the existing seeded route fixture.

### Non-functional

- Use DUNE theme colors, background, card surface, and an existing SF Symbol.
- Give iPhone and folded Duo a single column; cap the reading width on iPad and unfolded Duo. Let Dynamic Type grow without clipping.
- Keep T11 and T13 source unchanged. Keep browser proposal and real app captures distinct.

## Approach

Change only the private T12 view within `NotificationHubView.swift`. An opaque ScoreHeroPalette hero holds the original symbol and exact title; a supporting card renders the full body with selectable text. The existing `DetailWaveBackground`, `ScoreHeroPalette`, supporting `StandardCard`, and DS tokens supply the visual language. No new user-facing copy or string catalog key is needed.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Derive rich data from body | More decoration | Invents or misstates message facts | Reject |
| Add route-specific action | Extra interaction | No reliable destination in T12 payload | Reject |
| Two-part reading layout | Clear title and complete body | More vertical space | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | Edit | T12 private view only |
| `DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift` | Edit | Assert saved title/body and native back on existing T12 selector |
| `docs/design/layout-map/notification-message-detail-proposal.md` | Add | Exact T12 layout/data/behavior contract |
| `docs/design/layout-map/index.html` | Edit | Link T12 contract |
| `docs/design/theme-map/themes/dune-notification-message-detail.html` | Add | Preserved illustrative study |
| `docs/design/theme-map/manifest.json`, `README.md`, generated `index.html` | Edit | Register study |

## Implementation Steps

### Step 1: Save design contract

- **Files**: plan, layout map, theme study/manifest/README/index.
- **Changes**: Record exact data source and responsive/accessibility states before native code.
- **Verification**: Theme builder `--check`, links, diff.

### Step 2: Implement T12 view

- **Files**: `NotificationHubView.swift`.
- **Changes**: Opaque themed title hero and body reading card, max-width layout, theme tokens.
- **Verification**: Source parse, T11/T13 byte comparison, existing UI selector design review.

### Step 3: Parent runtime gate and actual map

- **Files**: `docs/design/phone-design-map/actual` T12 captures/metadata.
- **Changes**: Run existing `DesignMapNotificationDetailTests/testNotificationMessageDetail` on owned iPhone, iPad, Duo folded/unfolded, inspect and refresh T12 actual captures.
- **Verification**: Targeted UI receipt, full title/body presence, back navigation, Dynamic Type and scroll.

## Edge Cases

| Case | Handling |
|---|---|
| Long or multiline body | ScrollView and unrestricted Text height; preserve original line breaks |
| Long title / large type | Vertical hero; no fixed text height or line limit |
| Empty historical payload | No fabricated fallback; render saved empty string |
| Narrow and wide devices | Full available compact width and centered capped reading column |

## Testing Strategy

- Unit tests: None; this change adds no model or branch logic.
- UI tests: Existing seeded `DesignMapNotificationDetailTests/testNotificationMessageDetail` strengthened with exact payload and back assertions, with parent runtime/capture gate.
- Static checks: Diff, Swift parse, theme build check, string catalog check if changed (none expected).

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Title/body clipping at accessibility sizes | Medium | Medium | No fixed heights; inspect large-type capture |
| Existing T12 actual map becomes stale | Certain until capture | Medium | Parent refreshes four affected device captures after build |
| Parallel T11 changes in same source file | Medium | Medium | Limit edit to private T12 block and compare surrounding blocks |

## Confidence Assessment

- **Overall**: High for source semantics; runtime layout remains pending parent device verification.
- **Reasoning**: The actual route passes only two strings, and the change adds no conditional logic or new data source.
