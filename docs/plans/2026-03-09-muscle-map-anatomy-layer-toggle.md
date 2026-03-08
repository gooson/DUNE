---
topic: muscle-map-anatomy-layer-toggle
date: 2026-03-09
status: draft
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-svg-extruded-muscle-map-shared-scene.md
  - docs/solutions/performance/2026-03-09-realitykit-material-cache-guard.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-muscle-map-real-3d.md
  - docs/brainstorms/2026-03-08-muscle-map-3d-upgrade.md
---

# Implementation Plan: Muscle Map Anatomy Layer Toggle

## Context

TODO #099 requests an anatomy layer toggle for the 3D muscle map. The current shipped USDZ bundle
contains `body_shell` plus `muscle_*` entities, but no separate skeleton/bone mesh. That means a
literal muscle-to-bone toggle is blocked by missing asset prerequisites. The shippable scope for
this turn is to add a layer toggle that controls the currently available anatomy layers:
skin-enabled, muscle-only, and focus/highlight-only.

## Requirements

### Functional

- Add a visible anatomy layer control to `MuscleMap3DView`
- Let the user switch between shell+muscle, muscle-only, and focus-only presentation
- Preserve current recovery/volume mode switching and muscle selection behavior
- Keep selected muscle emphasis when the focus layer is active
- Update TODO #099 to `done` if the feature ships in this scoped form

### Non-functional

- Reuse the current USDZ asset without introducing external Blender or USD authoring work
- Avoid unnecessary RealityKit material rebuilds during layer changes
- Keep localization compliant for any new user-facing labels
- Cover new pure logic with Swift Testing

## Approach

Introduce a new anatomy-layer enum that maps directly to the assets that exist today.

- `skin`: existing shell + colored muscles
- `muscles`: hides shell and shows all muscles normally
- `focus`: hides shell and dims non-selected muscles so the selected muscle reads as the only active layer

This keeps the UI honest about current asset capabilities while still delivering the requested
layer-toggle interaction. The scene logic will compute shell opacity and per-muscle emphasis from
the selected layer instead of forcing the view to hand-build multiple visual presets.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Wait for real skeleton asset and do nothing | Matches original TODO text literally | Not shippable now, leaves task blocked | Rejected |
| Add only another opacity slider preset | Smallest diff | Does not create an actual toggle workflow | Rejected |
| Add skin / muscles / focus layer toggle using existing asset | Shippable now, aligned with brainstorm notes, no asset work required | Bone layer remains future work | Chosen |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | Modify | Add anatomy-layer model and scene visual rules |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | Modify | Add anatomy-layer picker and pass layer state into viewer |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | Modify | Add unit coverage for anatomy-layer logic |
| `Shared/Resources/Localizable.xcstrings` | Modify | Add labels for the new layer control |
| `todos/099-pending-p3-muscle-map-anatomy-layer-toggle.md` | Modify | Mark done and record updated date once shipped |

## Implementation Steps

### Step 1: Define anatomy-layer state and scene mapping

- **Files**: `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift`
- **Changes**:
  - Add a `MuscleMap3DAnatomyLayer` enum with localized labels
  - Add helper logic in `MuscleMap3DState` for effective shell opacity and non-selected muscle dimming
  - Extend `updateVisuals` to accept the anatomy layer without breaking existing caching discipline
- **Verification**: New helper logic is unit-testable and compiles

### Step 2: Add the user-facing layer toggle

- **Files**: `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift`
- **Changes**:
  - Persist anatomy-layer preference with `@AppStorage`
  - Insert a segmented or compact picker near the existing mode control
  - Keep the current skin opacity slider only where it still makes sense for the `skin` layer
  - Pass the selected anatomy layer into `MuscleMap3DViewer`
- **Verification**: Build succeeds and the control updates the scene live

### Step 3: Add tests and localization

- **Files**: `DUNETests/MuscleMapDetailViewModelTests.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - Add Swift Testing coverage for layer-derived shell opacity/dimming logic
  - Add localized strings for `Layer`, `Skin`, `Muscles`, and `Focus`
- **Verification**: Targeted unit tests pass and xcstrings contains en/ko/ja entries

### Step 4: Finish task bookkeeping

- **Files**: `todos/099-pending-p3-muscle-map-anatomy-layer-toggle.md`
- **Changes**:
  - Rename file status from `pending` to `done`
  - Update frontmatter `status` and `updated`
  - Clarify that this shipped scope is the current anatomy-layer toggle on top of the existing asset
- **Verification**: TODO naming/frontmatter match `done`

## Edge Cases

| Case | Handling |
|------|----------|
| No selected muscle in focus mode | Fall back to the existing default selected muscle logic |
| No fatigue data for a muscle | Keep the current no-data color, only dim further when focus mode requires it |
| User switches away from skin mode | Shell opacity control should not leave stale partial shell visibility |
| Repeated picker toggles | Reuse scene cache guards so only changed material groups rebuild |

## Testing Strategy

- Unit tests: add coverage for anatomy-layer helper logic in `DUNETests`
- Integration tests: none planned; change is scene/view composition without a new domain workflow
- Manual verification:
  - Open Muscle Map 3D
  - Toggle `Skin` / `Muscles` / `Focus`
  - Confirm shell visibility and non-selected muscle dimming match the chosen layer
  - Switch recovery/volume modes and change selected muscle to ensure highlight stays correct

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Focus mode makes non-selected muscles too faint or too bright | Medium | Medium | Centralize alpha/tint rules in scene helpers and tune with manual verification |
| New strings leak without localization entries | Low | Medium | Add xcstrings entries in the same change set |
| Layer changes bypass cache guards and rebuild too often | Medium | Medium | Include anatomy layer in the scene's last-applied input cache |
| Users expect an actual bone mesh | High | Low | Document shipped scope in TODO and compound doc as current asset-backed anatomy toggle |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: The code change is straightforward, but the task name overstates what the current asset can do. The implementation is safe if it explicitly maps the feature to the layers that actually exist today.
