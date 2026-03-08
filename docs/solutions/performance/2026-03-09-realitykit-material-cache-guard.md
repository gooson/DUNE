---
tags: [realitykit, performance, material, cache, slider, 3d]
date: 2026-03-09
category: performance
status: implemented
---

# RealityKit Material Cache Guard for Continuous UI Controls

## Problem

Continuous UI controls (Slider, DragGesture) bound to RealityKit scene properties trigger
`RealityView update:` on every frame (~60Hz). Without guards, this causes full material
rebuild for ALL entities every frame — including entities unaffected by the changing property.

In the muscle map case: dragging the shell opacity slider was rebuilding `SimpleMaterial`
for ~15 muscle groups + shell models = ~20 allocations/frame, even though only shell opacity changed.

## Solution

### 1. Cache Guard on Material Update Functions

Store the last-applied values and skip rebuild when unchanged:

```swift
private var lastShellOpacity: Float = -1
private var lastShellColorScheme: ColorScheme?

private func updateShellMaterials(colorScheme: ColorScheme, opacity: Float) {
    guard opacity != lastShellOpacity || colorScheme != lastShellColorScheme else { return }
    lastShellOpacity = opacity
    lastShellColorScheme = colorScheme
    // ... material creation
}
```

### 2. Separate Update Paths by Input Group

Split `updateVisuals()` into guarded sections. Shell materials check shell inputs,
muscle materials check muscle inputs. During slider drag, only the affected section runs:

```swift
func updateVisuals(..., shellOpacity: Float) {
    updateShellMaterials(colorScheme: colorScheme, opacity: shellOpacity)

    let muscleInputsChanged = fatigueStates.count != lastMuscleFatigueCount
        || mode != lastMuscleMode
        || selectedMuscle != lastSelectedMuscle
        || colorScheme != lastMuscleColorScheme
    guard muscleInputsChanged else { return }
    // ... muscle material loop
}
```

### 3. Default Parameter for Backward Compatibility

When adding a new parameter to a shared function (`updateVisuals`), use a default value
referencing a named constant to avoid breaking existing callers (e.g., visionOS):

```swift
shellOpacity: Float = MuscleMap3DState.defaultShellOpacity
```

## Prevention

- When adding continuous UI controls to RealityKit scenes, always add cache guards
- Keep the "what changed" check before the "rebuild materials" loop
- Extract default values to named constants in the state enum
- Use `@AppStorage` for persistent visual preferences (not `@State`)
