### [P2] No-data muscle states are counted as recovered
- **File**: DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift:144
- **Category**: consistency
- **Issue**: `computeFatigueStates` returns an entry for every muscle even without workouts, and the fatigue calculator assigns `.noData` to muscles without contributions. `isRecovered` includes `.noData` (raw value 0), so an empty history displays all muscles as ready instead of the intended empty prompt; partial histories also count unobserved muscles as ready.
- **Risk**: The new header presents unsupported recovery status as measured readiness.
- **Fix**: Filter out `.noData` states before calculating both counts, and use the resulting count to decide whether to show the empty prompt. Check consistency with the existing recovery overview.

Scope: Static review of the working tree only; no build or runtime validation was performed. No persistence or service changes were present in the reviewed diff.

### Re-review addendum
The `.noData` filtering at lines 143–146 resolves the original header-only misclassification, but introduces a remaining P2 consistency concern: the unchanged `RecoveryOverviewSection` below still uses `fatigueStates.count` and the view model's unfiltered `isRecovered` count. With one observed recovered muscle and other `.noData` muscles, the header shows `1/1 muscles ready` while the same screen's recovery section shows all muscle groups ready; with one fatigued observed muscle, the denominators also differ. Both counts are derived from the same snapshots but describe different populations without explaining the distinction. Use the same observed population in the overview or clearly distinguish the metrics. Static inspection only; no build or runtime verification was performed.

### Final re-review addendum
The prior P2 consistency issue is resolved for the three A03 recovery displays: header, map and recovery overview now receive the same `.noData`-filtered population and recovered predicate. Normal past workout records with positive completed sets in the seven-day volume window also produce a positive fatigue contribution within the 14-day lookback, so filtering does not discard their map volume. Boundary limitation: weekly volume admits future-dated records while fatigue calculation excludes them; such an input can still have volume with `.noData` and be removed from the map's volume mode, despite remaining in the separate volume breakdown. Runtime verification was not performed.

### Map input re-review
The previous map-volume concern is resolved: the map receives the original full fatigue states for its volume index and uses the filtered array only for its recovery subtitle. Header, map recovery subtitle, and overview progress now use the same observed population. Existing callers retain their original summary behavior via the nil default. A remaining future-date edge is that the overview's `nextRecovery` still comes from the unfiltered view model: an otherwise empty history containing only a future-dated record can show the training prompt alongside a next-ready time. No runtime verification was performed.

### Final status
Open findings: P1: none; P2: none; P3: none in the reviewed changes. The original no-data recovery count and cross-summary consistency findings are resolved. The map-volume input concern is resolved by retaining the full map input. The no-data-only next-recovery display concern is resolved by checking that the selected muscle is observed before displaying it (MuscleMapDetailView.swift:116–117). Static source review only; no build, tests, or runtime verification were performed.
