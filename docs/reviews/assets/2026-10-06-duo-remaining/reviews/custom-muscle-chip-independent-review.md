# Independent SwiftUI review: custom exercise muscle chips

Scope: current `CreateCustomExerciseView.swift` Primary Muscles delta only, compared with the saved Book/max-AX `Shoulders` four-line wrapping evidence and the prior scoped review. No app edit, build, test, simulator, or Git action.

**Findings:** No actionable source regression found. `@Environment(\.dynamicTypeSize)` drives one flexible grid column only for accessibility sizes; the ordinary adaptive grid with 90-point minimum remains. Each AX chip label accepts the proposed column width, expands vertically for its words, fills the column, and has at least 44 points of content height before its existing padding. The button's toggle of `selectedMuscles`, selected/unselected colors, plain style, `MuscleGroup.displayName`, and per-muscle accessibility ID are unchanged. No new user-facing string or localization key was added.

The optional `maxWidth`/`minHeight` values match SwiftUI's frame modifier shape, and the earlier delegated parse check passed; this independent review did not build. Native Template gate 36345 still must confirm `Shoulders` paints as a readable word within the capsule, remains wholly inside the Form viewport, and can be selected. No visual or runtime pass is claimed.
