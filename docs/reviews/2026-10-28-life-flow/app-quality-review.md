# Life Flow app quality gate — read-only follow-up

Scope: native Life changes in `main...HEAD` plus staged resolver, ViewModel, sheet, and root changes. Inspected `LifeFlowUITests`, `LifeLogReplacementTests`, and relevant project rules. Source build was reported passing by the parent; I did not run tests or touch a simulator in this pass.

## Verdict: needs one test fix and one data-consistency follow-up

### [P2] Prefilled Read total UI test can enter the wrong number

- **File:** `DUNEUITests/Visual/LifeFlowUITests.swift:117-118`
- **Evidence:** The test taps a text field containing `30` and sends four Delete keys, then types `40`. A tap can place the insertion point before or inside the existing value. The test does not verify the field equals `40` before saving. A legal but unintended `340` can save and fail the history assertion; an invalid `4030` can leave the sheet open. The project already has `app.fillTextInput(_:with:)`, which selects all and checks the result (`UITestHelpers.swift:1141-1185`).
- **Fix:** Replace the tap/Delete/type sequence with `XCTAssertTrue(app.fillTextInput("habit-past-record-total", with: "40"))` and assert the field value before Save. This keeps the targeted UI run deterministic.

### [P2] Query-based analytics and relationship-based progress can diverge after sync

- **File:** `DUNE/Presentation/Life/LifeView.swift:1254-1267`; `DUNE/Presentation/Life/LifeViewModel.swift:368-370,462-466,669-670,689`
- **Evidence:** `recalculateAnalytics` resolves the independent `@Query habitLogs`. `prepareLogReplacement` and the sheet merge that query with the relationship to handle a missing inverse. `calculateProgresses`, `historyEntries`, `streakDates`, and `makeCycleSnapshot` still resolve only `habit.logs`. The existing `additionalLogsFillRelationshipGap` unit test confirms an observable log can be available while `habit.logs` is nil, but exercises only replacement preparation.
- **Impact:** The Life hero, Today row, streak, history, or recurring due date can disagree with Rhythm until the inverse relationship catches up.
- **Fix:** Supply a merged per-habit log snapshot to all ViewModel read paths and resolve it consistently; add a read-path test with `habit.logs = nil` and an associated queried log. This is also recorded in `data-review.md`.

## Other checks

- No additional P1 defect found in the inspected native Life code.
- The parent has already queued fixes for the completed recurring Undo state, zero tombstones in management history, and dead child callback/state; this report does not duplicate them.
- New controls expose stable identifiers; past-sheet bounds and numeric validation are enforced in the ViewModel. Dark, maximum Dynamic Type, and iPad behavior remain for the parent’s UI run.
