# Life native quality review

Review scope: `LifeView`, `LifeHabitHeroView`, `HabitRowView`, `HabitPastRecordSheet`, `LifeRhythmCard`, and `HabitPurpose+View` against the Life redesign prototype. Static inspection only.

## P2 findings

1. **[P2] Social habits appear under Life, contrary to the agreed purpose map.** `HabitPurpose+View.swift:38-41` maps `.social` to `.life`; the prototype's purpose table places social with mindfulness in Mind/Relationships. The Mind filter will hide a social habit while Life shows it. Map `.social` with `.mindfulness`, leaving finance and chores in Life.

2. **[P2] Hydration count cards omit the unit.** `HabitRowView.swift:168-174` displays only `value / goal` for every count habit. The water prototype requires an explicit glass unit next to the number, and the water drops are decorative/hidden from accessibility (`HabitRowView.swift:186-194`). A reader cannot tell whether `4 / 8` means glasses or repetitions. Show the configured unit in the numeric label and its accessible value.

3. **[P2] VoiceOver focus jumps to Today's Practice after every value change, including a single count increment.** `LifeView.swift:1139-1149` always sets `todayFocused = true` after replacement. The prototype calls for focus restoration when a completed row moves into the collapsed group; repeated count and duration edits should retain the action context. Set focus only when the row actually leaves its visible group, and announce the updated value/undo state for other edits.

4. **[P2] Past record editing does not preview a changed recurring due date.** `HabitPastRecordSheet.swift:181-186` shows a generic statement that schedules may change, and `save()` at lines 211-241 writes without showing the next due date. The past-record contract requires the next date to be shown before replacing a recurring completion, so a backdated entry can silently shift the schedule. Calculate and display the predicted due date for the selected habit/date/value before Save.

5. **[P2] Rhythm graphs appear before the first manual record.** `LifeView.swift:465-473` always renders both `LifeRhythmCard` and `LifeWeeklyReviewCard` whenever a manual habit exists; `LifeRhythmCard.swift:30-64` always renders the seven-day chart and 28-day grid. The prototype specifies a first-record state without invented bars/heatmap. Gate the charts on actual manual history and present the short first-record state when empty.

6. **[P2] Empty category filters have no inline recovery.** `LifeView.swift:601-610` shows `No habits due today` when the chosen purpose has zero items. That text implies a schedule state rather than an empty filter and does not offer the prototype's `Show all` action. Keep the All chip, but add a filtered-empty message and an inline reset action.

7. **[P2] Past total parsing fails for locales with a comma decimal separator.** `HabitPastRecordSheet.swift:205-207` populates the text field using locale-aware number formatting, but `HabitPastRecordSheet.swift:220-224` parses with `Double(trimmed)`, which accepts a period decimal separator. On a comma-decimal device, an existing `1,5` cannot be saved without manual reformatting. Parse with a locale-aware number formatter or normalize the current decimal separator.

## P3 findings

8. **[P3] Weekly card repeats the weekly target without a weekday completion visualization.** `LifeView.swift:628-635` shows completed days above the row while `HabitRowView.swift:48-51` repeats only the target count; neither shows the prototype's completed weekday marks. The day count and today's value are correctly separated, but the visual rhythm of the weekly target is absent. Add a noninteractive weekday completion strip based on distinct completed dates.

9. **[P3] Large type duration editor remains horizontal.** `HabitRowView.swift:114-129` uses an `HStack` for the text field and Save control at accessibility Dynamic Type sizes. The count controls switch to `AnyLayout`, but the duration editor does not. Use a vertical layout when `dynamicTypeSize.isAccessibilitySize` so the field and button retain their width on narrow phones.

No P1 finding from this static UI review. Runtime geometry, VoiceOver order, and build results were outside this review scope.

## Delta re-review — current files

Read-only inspection of the final changed paths; no build, simulator, or source edits in this pass.

| Finding | Current status | Evidence |
|---|---|---|
| 1 Social purpose | Resolved | `HabitPurpose+View.swift:38-41` groups social with mindfulness in Mind. |
| 2 Count unit | Resolved | `HabitRowView.swift:171-177` renders `goalUnit` with the count. Hydration drops remain decorative at lines 189-197. |
| 3 Focus after value edit | Resolved | `LifeView.swift:1147-1162` compares prior/current completion and restores focus only when a row changes group while completed items are collapsed. |
| 4 Recurring date preview | Resolved | `HabitPastRecordSheet.swift:130-137,207-223` calls the VM preview and shows the next scheduled date before saving. `LifeViewModel.swift:251-295` simulates the replacement using the same daily-total memo contract. |
| 5 No-history chart | Resolved | `LifeView.swift:464-479` gates charts on a positive recorded completion and shows a first-record card otherwise. |
| 6 Empty purpose filter | Resolved | `LifeView.swift:603-611` distinguishes an empty filter and offers Show all. |
| 7 Locale decimal input | Resolved | `HabitPastRecordSheet.swift:120-127,237-244` normalizes the current decimal separator and disables grouping in displayed input. |
| 8 Weekly weekday marks | Resolved | `LifeView.swift:631-650,1311-1320` renders seven dated completion marks from distinct completed dates. |
| 9 Accessibility duration editor | Resolved | `HabitRowView.swift:114-132` switches its editor to vertical layout for accessibility Dynamic Type sizes. |

No new concrete SwiftUI or UX defect found in the changed paths. Runtime VoiceOver tree and target geometry remain for the parent's queued UI checks.
