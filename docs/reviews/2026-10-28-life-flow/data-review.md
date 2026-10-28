### [P1] Concurrent same-day replacements can merge into an additive total
- **File**: DUNE/Presentation/Life/LifeViewModel.swift:240; DUNE/Presentation/Life/LifeView.swift:1159
- **Category**: concurrency
- **Issue**: Each replacement removes only the logs visible in the local `habit.logs` snapshot and inserts a new `HabitLog` with a fresh UUID. Two offline or simultaneously saving devices can each replace the same habit/day and later sync both new logs. `calculateProgresses` and analytics sum same-day values, so replacing 3 with 8 on one device and 3 with 5 on another can show 13 after CloudKit merge.
- **Risk**: A daily *total* becomes an additive amount; completion, streak, and recurring action order can diverge across devices. Local `isSaving` does not cover cross-device writes.
- **Fix**: Define a deterministic per-habit/day reconciliation rule for manual totals at the read and persistence boundary (for example, pick the latest `completedAt` with a stable tie-breaker and compact older duplicates), and apply it consistently to progress, analytics, history, and cycle replay.

### [P2] Replacement ignores logs visible through the independent log query when the relationship is incomplete
- **File**: DUNE/Presentation/Life/LifeViewModel.swift:237; DUNE/Presentation/Life/LifeView.swift:1118
- **Category**: consistency
- **Issue**: `prepareLogReplacement` gathers existing records exclusively from `habit.logs ?? []`. The same screen has an independent `@Query` for `HabitLog`, and its previous `todayLogs` helper explicitly falls back to that query when the relationship has no rows. If the relationship is temporarily nil or not yet reconciled after sync, saving a total leaves the queried old records in place and inserts another log.
- **Risk**: The entered total is added to the old value, and the new record can then sync as a duplicate.
- **Fix**: Pass the queried logs for the selected habit/day into replacement preparation, or reconcile the relationship/query snapshots before deleting; use the same resolved set for the undo expectation.

### [P2] A same-day recurring action tie has no stable replay order
- **File**: DUNE/Presentation/Life/LifeViewModel.swift:669
- **Category**: consistency
- **Issue**: Cycle replay sorts logs only by `date`, while `HabitLog` normalizes every action date to the start of the day. A completion and skip on the same date therefore compare equal, and the loop's `lastAction`/anchor depends on unspecified order. Such combinations can arise from older records or cross-device merges even though a local replacement removes same-day actions.
- **Risk**: The next due date and today's completed state can change after reload or sync without any user action.
- **Fix**: Establish a stable same-day order using `completedAt` and `id`, or collapse same-day cycle events under an explicit precedence rule before replay. Use that rule in the preview path as well.

## Re-review status

- **Resolved — concurrent totals:** replacement writes a marked daily total (including a zero tombstone). `HabitLogResolution.resolve` selects the latest marked record by `completedAt` and UUID; VM progress, streak, history, cycle replay, Life analytics, and management statistics use it. Preview uses a per-habit override for its unattached candidate.
- **Resolved — incomplete relationship during replacement:** `replaceValue` passes the independent `habitLogs` query into `prepareLogReplacement`; the sheet also passes it into its current-total and preview paths. Undo compares the full current log signature before restoring saved records.
- **Resolved — cycle ties:** replay sorts same-day events by `completedAt` then UUID after resolution; a winning zero tombstone suppresses older completion without becoming a cycle event.

### [P2] Progress and history can disagree with query-based analytics while the inverse relationship lags
- **File**: DUNE/Presentation/Life/LifeView.swift:1254; DUNE/Presentation/Life/LifeViewModel.swift:368
- **Category**: consistency
- **Issue**: `recalculate()` passes habits but not its independent `habitLogs` query to `calculateProgresses`. The ViewModel's progress, streak, history, and cycle methods resolve `habit.logs` alone. The replacement and analytics paths now merge or use the query, so a temporarily nil/stale inverse relationship can yield a correct analytics total alongside an empty or older hero, today row, history, or next due date.
- **Risk**: The same synced record can produce contradictory completion and schedule states until relationship reconciliation, potentially inviting an unintended new action.
- **Fix**: Feed the same merged per-habit query/relationship log set into all ViewModel read paths, then resolve it once under the habit ID before deriving progress, streak, history, and cycle state.

## Final read-path verification

- **Resolved — progress/history/cycle read paths:** `recalculate()` now passes `habitLogs` to `calculateProgresses`, which groups queried logs once, merges them with each habit relationship by ID, and resolves totals. History, cycle snapshot, snooze suggestion, and normal reminder updates in `HabitListQueryView` pass `allLogs(for:)`. The preview uses the same merge and per-habit resolver. `queryLogsDriveAllReadPaths` covers an empty inverse relationship. Management statistics hide zero tombstones, and Undo checks a full content signature before restoring records.

### [P2] Editing an existing recurring habit can schedule reminders from a stale relationship
- **File**: DUNE/Presentation/Life/LifeView.swift:199
- **Category**: consistency
- **Issue**: The outer edit-sheet save path still calls `refreshReminderSchedule(for: habit)` without `additionalLogs`. It has no `@Query` log array, so if `habit.logs` lags behind synced logs when a recurring habit is edited, this reminder calculation falls back to the stale relationship even though the rest of the Life read paths now merge query results.
- **Risk**: The edited habit can retain an incorrect next reminder until another explicit reschedule occurs.
- **Fix**: Fetch the edited habit's logs from `ModelContext` before refreshing, or route the refresh through the query child with its merged log set.
