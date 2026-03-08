---
tags: [e2e, ui-test, muscle-map, 3d-view, realityview, native-renderer, simulator, xcuitest]
date: 2026-03-09
category: solution
status: implemented
---

# Simulator-Safe E2E Testing for Native 3D Views

## Problem

MuscleMap3DView now uses RealityKit `RealityView`, but it is still a native-rendered 3D surface. On iOS Simulator, native 3D content remains a poor target for content-level assertions (entity hit, rotation result, mesh correctness), so tests that treat it like a regular SwiftUI tree stay brittle.

## Solution

### Strategy: Test Stable SwiftUI Surface + Semantic Entry Point

Native 3D views still expose reliable SwiftUI overlays (summary cards, pickers, control strips) and stable navigation affordances around them. Those are the right E2E target surface.

**Test scope:**
- SwiftUI overlay elements: `.exists`, `.waitForExistence`, text content verification
- Mode switching: Picker selection → summary card text changes
- Navigation: entry/exit from 3D view
- Controls: reset button, muscle strip capsules

**Explicitly excluded:**
- Native 3D entity hit-testing
- Camera rotation/pan gestures (no visual feedback to verify)
- 3D content correctness (entity colors, positions)

### AXID Placement Pattern

```swift
// Screen-level (ScrollView wrapping everything)
.accessibilityIdentifier("activity-musclemap-3d-screen")

// SwiftUI overlays (always testable on simulator)
summaryCard.accessibilityIdentifier("musclemap-3d-summary-card")
Picker.accessibilityIdentifier("musclemap-3d-mode-picker")
muscleSelectionStrip.accessibilityIdentifier("musclemap-3d-muscle-strip")
toolbarButton.accessibilityIdentifier("musclemap-3d-reset-button")

// Native 3D container (existence-only assertion)
MuscleMap3DViewer.accessibilityIdentifier("musclemap-3d-viewer")
```

### Navigation via Muscle Tap

MuscleMapDetailView navigates to 3D via `onMuscleSelected` closure (muscle tap → `showing3DMap = true`). There is no dedicated "3D button". Coordinate tap on the body diagram was flaky across device sizes, so each muscle button now exposes a stable AXID. In E2E tests, use a concrete muscle selector:

```swift
let chestButton = app.buttons["musclemap-body-front-chest"].firstMatch
XCTAssertTrue(chestButton.waitForExistence(timeout: 10))
chestButton.tap()
```

## Prevention

When adding E2E tests for views backed by native rendering (RealityView, ARView, SceneKit, Metal):
1. Identify which UI elements are SwiftUI overlays vs native rendering
2. Add AXIDs to stable entry points and surrounding SwiftUI controls
3. Use `.exists` assertion for native rendering containers (not content)
4. Avoid coordinate taps when a semantic selector can exist
5. Document simulator limitations in test comments
