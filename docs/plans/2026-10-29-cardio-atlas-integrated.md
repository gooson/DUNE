---
topic: cardio-atlas-integrated
date: 2026-10-29
status: approved
confidence: medium
related_solutions:
  - ../solutions/healthkit/ios-cardio-live-tracking.md
  - ../solutions/general/2026-03-08-share-image-renderer-proposed-size.md
related_brainstorms:
  - ../brainstorms/2026-10-29-running-map-sharing-achievements.md
---

# Implementation Plan: Integrated Cardio Atlas

## Context

The user selected one Atlas workout detail, three share styles, Journey progress and Passport achievements, then explicitly invoked `/run`. All indoor and outdoor cardio is included. The accepted browser proposal is a design reference, not native test evidence. Current `origin/main` is `b8cf5a29`; the working branch is `codex/cardio-atlas-integrated`. The other detail redesign is preserved by adding a self-contained section to both existing workout details.

## Requirements

- Real recorded outdoor routes and real selected indoor/stationary places; honest missing-route states.
- Atlas, Pace Ribbon and Signature image export; Journey/Passport independently included. Ribbon requires usable timestamped geometry.
- Sharing location controls never mutate the private detail. Hide-place removes tiles, pin, route and names; endpoint trimming removes geometry only, retaining original workout statistics.
- Actual history drives Journey and same-activity Passport thresholds. Linked local/HealthKit workouts count once. Floors, steps and machine levels do not become fictional distance.
- Preserve existing metrics, heart rate, sets, navigation and themes; en/ko/ja and accessibility.
- Native iPhone, iPad and Duo evidence; existing Watch routes can be read from HealthKit. This change does not introduce a Watch GPS recording service.

## Approach

Store route/place metadata in a separate CloudKit-compatible `WorkoutLocationRecord`, associated by local and HealthKit IDs. Adding this model in V20 preserves the V19 existing-model checksum and avoids modifying frozen relationship pairs. Local iOS completion persists this metadata and writes authorized outdoor route data to HealthKit. Query existing HealthKit routes lazily in detail. A Foundation-only progress engine recalculates achievements from deduplicated current history rather than maintaining a stale reward ledger.

| Alternative | Decision |
|---|---|
| Add route fields to ExerciseRecord | Rejected: unnecessarily changes the existing relationship schema. |
| Private JSON sidecar | Rejected: weaker deletion, synchronization and alias lifecycle. |
| Territorial ownership / generated streets | Rejected: user selected achievements and actual history. |

## Affected Files

| Area | Change |
|---|---|
| Domain/Models/WorkoutLocation.swift, CardioAtlasProgress.swift | Validated metadata, privacy geometry, deterministic Journey and Passport. |
| Data/Persistence/Models, Migration | New metadata model and V20 additive migration. |
| Data/Location, Domain/Services | Bounded validated route capture and pause/gap segmentation. |
| Data/HealthKit | Route read/write and authorization, indoor metadata. |
| Presentation/Exercise/CardioSession | Persist metadata with completed actual sessions. |
| Presentation/Exercise/CardioAtlas | Native map, location editor, history progress, export styles. |
| HealthKitWorkoutDetailView, ExerciseSessionDetailView | Add integrated Atlas while preserving analysis. |
| Shared string catalog | en/ko/ja new UI strings, canonical formatting. |
| DUNETests, DUNEUITests | Logic/migration/capture tests and focused native flows. |
| docs/design and docs/solutions | Layout contract, fresh actual captures, final solution. |

## Implementation Steps

1. Preserve accepted designs and approved plan in a dedicated commit. Route/data, progress engine and map/export components have nonoverlapping owners and explicit shared API contracts.
2. Implement metadata persistence/capture and actual-history calculation with unit tests. Verify additive migration, invalid coordinates, duplicates, paused segments and thresholds.
3. Integrate real data into existing details; implement editable selected place, share controls and localized states. Verify empty/no-permission states and private/share isolation.
4. Build through `scripts/build-ios.sh`; run targeted tests through standard simulator runners on owned devices, then capture impacted phone/tablet/Duo layouts and sync actual maps.
5. Six-perspective review plus SwiftUI, Apple UX, performance and app-quality checks required by `/run`; resolve relevant blockers, document, create/merge PR and clean up.

## Edge Cases

| Case | Handling |
|---|---|
| Existing indoor/stationary workout has no route | Select a place or show unset state; never generate a track. |
| Missing HealthKit route or unavailable read authorization | Explain unavailable data without inferring denial; retain actual metrics. |
| Location permission denied or inaccurate samples | Keep the workout; filtered/empty geometry and manual place remain valid. |
| Pause, jump, sparse route | Segment route; do not bridge with pace or line. |
| Very short route trimmed at both ends | Empty share geometry; retain metrics. |
| Local workout also appears in HealthKit | Central linked-ID/type-date dedup, preserving unrelated Watch records. |
| Edit/delete historical session | Recompute progress, no permanently stale reward ledger. |
| Snapshot or export failure | Recoverable retry/error, no fake map or zero-size image. |

## Testing Strategy

- Unit: validated payload, pause/gap capture, additive schema, actual-history dedup/threshold crossing, privacy trimming, valid exported image dimensions.
- Integration: current detailed workout navigation, source linking and existing cardio tests.
- UI: seeded outdoor route, indoor place/unset, Journey and Passport, all share styles/privacy, place correction/cancel. Compact, regular, Duo folded/unfolded and large text are impacted. Existing Watch UI is unchanged; shared source still builds.
- `scripts/plan-ui-tests.py --base main` records a conservative recommendation. Generic `/run` does not authorize an entire unrelated suite under the Codex adapter; execute feature checks plus relevant smoke and document broader unrun coverage.

## Risks

| Risk | Mitigation |
|---|---|
| HealthKit saves workout but route fails | Workout success remains success; report route issue without retrying entire workout. |
| Large routes / snapshot memory | Bound route samples, downsample and cancel stale snapshot tasks. |
| CloudKit migration | New optional/defaulted independent model; V19 remains byte-for-byte model-compatible. |
| History window / restricted HealthKit data | Label progress from available history; local records and current session always included. |
| Actual device capture blocked | Record exact missing screen/state; never reuse concept PNGs as actual evidence. |

## Confidence Assessment

Medium: accepted UX and extension points are clear; HealthKit route APIs, shared Watch schema and native export need real build/test validation. User-visible progress is based on available authorized history, not an assertion that every historical workout was readable.
