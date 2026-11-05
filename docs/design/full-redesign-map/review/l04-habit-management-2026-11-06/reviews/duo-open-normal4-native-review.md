# Duo open normal: four passed methods native review

- Source: `1012c7fccb4e1d8c6a785b53af279de59b644a34`; profile: 180° / LCD-1 / rotated active PNG 2853×2007.
- SDK archive: **5 executed, 4 passed, 1 failed, 0 skipped**. The failed `testOpeningPastRecordMenuDoesNotMutateToday()` is excluded.
- Reviewed all **24** selected PNG/AX pairs; file hashes, dimensions, active display, and App source hashes match the index.
- Findings: **P1 0 · P2 0 · P3 0**.

## Visible flow evidence

- L09 008-012: Read, Nov 5, current total 30, typed replacement 40, keyboard, and Save remain legible; 012 returns to Life with Today 1/3 and Read 0/30 min. 015 shows the Read history as Recorded later, Completed, Yesterday, 40/30 min.
- L02 023-025: edited Morning Stretch AM is visible in the hero and field, Save returns to Life with the renamed row. 029-039: New Habit hero, keyboard and typed Evening Walk, selected Fitness icon, Save return with Today 1/4 and Evening Walk row are visible.
- L04 045-055: 2 Active to 1 Archived, Morning Stretch row with History and Restore, history sheet and close, then 0 Archived / 3 Active after Restore; back to Life. Labels, symbols, and controls show no observed clipping or overlap in these captured states.

## Scope

- The enclosing five-method SDK run failed 4/5. The failed past-record menu/cancel method is excluded and has no native-pass claim.
- This review covers English, Light, normal text size on the unfolded Duo LCD-1 and these four passed methods only; no dark mode, MAX, physical device, or full suite claim.

Exact pair inventory: [JSON](duo-open-normal4-native-review.json).
