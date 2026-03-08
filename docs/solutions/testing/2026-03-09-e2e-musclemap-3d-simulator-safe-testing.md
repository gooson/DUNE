---
tags: [e2e, ui-test, muscle-map, 3d-view, arview, simulator, xcuitest]
date: 2026-03-09
category: solution
status: implemented
---

# Simulator-Safe E2E Testing for ARView-Backed Views

## Problem

MuscleMap3DView uses RealityKit `ARView` via `UIViewRepresentable`. ARView renders limited or no content on iOS Simulator, making traditional content-based assertions (tap entity, verify rotation, check mesh) unreliable.

## Solution

### Strategy: Test SwiftUI Overlay Only

ARView-backed views typically have SwiftUI overlays (summary cards, pickers, control strips) layered on top. These overlays are fully functional on simulator.

**Test scope:**
- SwiftUI overlay elements: `.exists`, `.waitForExistence`, text content verification
- Mode switching: Picker selection → summary card text changes
- Navigation: entry/exit from 3D view
- Controls: reset button, muscle strip capsules

**Explicitly excluded:**
- ARView entity taps (simulator doesn't render meshes)
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

// ARView container (existence-only assertion)
MuscleMap3DViewer.accessibilityIdentifier("musclemap-3d-viewer")
```

### Navigation via Muscle Tap

MuscleMapDetailView navigates to 3D via `onMuscleSelected` closure (muscle tap → `showing3DMap = true`). There is no dedicated "3D button". In E2E tests, use coordinate tap on the detail screen body diagram area:

```swift
detailScreen.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
```

## Prevention

When adding E2E tests for views backed by native rendering (ARView, SceneKit, Metal):
1. Identify which UI elements are SwiftUI overlays vs native rendering
2. Add AXIDs only to SwiftUI overlay elements
3. Use `.exists` assertion for native rendering containers (not content)
4. Document simulator limitations in test comments
