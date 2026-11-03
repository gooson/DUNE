### [P3] Avoid recomputing the comparison date range during chart selection
- **File**: DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift:322
- **Category**: rendering
- **Issue**: The comparison card calculates two Calendar date offsets and formats both dates when its enclosing view body is reevaluated. The chart selection bindings at lines 284–289 update state on the same view, so chart interaction can repeat work even though the period and range have not changed.
- **Impact**: Bounded, minor main-thread work during interaction; no measured user-visible degradation is established.
- **Fix**: Derive the date range when the trend data or selected period changes, and use locale-aware date formatting for display; ensure any cached formatted text is invalidated when locale or calendar changes.
