# Batch03 Duo closed MAX: two passed methods native review

## Findings

- P1: None in the two passed MAX methods.
- P2: None in the two passed MAX methods.
- P3: In the Water count form, the unit `glasses` breaks across two lines inside the trailing input column at MAX size ([HabitPastRecordSheet.swift](../../../../../../DUNE/Presentation/Life/HabitPastRecordSheet.swift#L230)). The field remains usable; adapt the unit layout so a word stays together. Evidence: pair 4.

## Scope and evidence

- Source: `dbb21495ba4454da89f2918dca7ee026f58dabb0`; Duo closed **0°**, active outer **LCD**, `rot0`, 1398 × 2034. Before/after pose readback is recorded in the pair index.
- The archive **failed overall**: 3 executed, 2 passed, 1 failed. Only `testPastRecordKindsAtMaximumAccessibilitySize` (L09) and `testHabitFormNewAndEditAtMaximumAccessibilitySize` (L02) are individually passed. The L04 management-entry method failed before opening management and is excluded.
- All 14 selected MAX-specific host PNG/AX pairs were bound to the passed case spans in `duo-max2-pair-contract.json` and SHA-256 verified.

## Native observations

- L02: New/Edit Habit titles and long hero names wrap within the sheet. Save and Cancel remain visible. The last Chores icon is selected; AX marks it Selected and reports a 156.5 × 133.5 point button frame.
- L09: Read, Water, and Morning Stretch forms show Nov 5, 2026 and their relevant total or Completed control. Cancel returns to the Life root in each passed path. The Water unit wraps as noted above.

## SHA-256 inventory

| # | Screen | Sequence | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---:|---|---|---|
| 0 | L09 | 6 | DUNE_VISUAL_AUDIT_READY L09 MAX Read selected date [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919563.958245 | `a6c66dc4800f1213077f0ed3054c65886a66cfd1ae9e63837a9593b580fafd75` | `a7260c032720dd0be864ccbf79616aa82de7b7b555b17ed7fd416886716ec58a` |
| 1 | L09 | 7 | DUNE_VISUAL_AUDIT_READY L09 MAX Read record control [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919583.057522 | `e345718edd0f8f18046ef9ed360888ddecb3e8fe0f3c089d9289ee9638724d59` | `d6ec11e2b7ba65d8355e81209b3fbe98bbb69083bcea80391e705b2a629719c3` |
| 2 | L09 | 8 | DUNE_VISUAL_AUDIT_READY tap habit-past-record-cancel [DUNEUITests/LifeFlowUITests.swift:56] DEADLINE=1793919598.997294 | `2eb4c89bb0e3490f98276a29a67af7065e86aed112591c06cba538c8f8385a03` | `b3e22c87d62f16dd569bc44e149c3e1952390a97f10390d0641df05de8ee6945` |
| 3 | L09 | 11 | DUNE_VISUAL_AUDIT_READY L09 MAX Water selected date [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919625.625626 | `d2efbab8f8180dfcf9e08efccf219456d5757993bb1376dd2e86b8a16c42f6f4` | `5c2687321fe0160669bce19811c2ada558018a8f7489b43eeac70070a15ba060` |
| 4 | L09 | 12 | DUNE_VISUAL_AUDIT_READY L09 MAX Water record control [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919643.5945969 | `7e8ae2ae3f28d185db38ecdd52bae5456bb5b8649d10d1cbe2726fc11a582497` | `572a6edf5132d197416af9352de52348522cc8577ffaf08f670d3b67a33b2525` |
| 5 | L09 | 13 | DUNE_VISUAL_AUDIT_READY tap habit-past-record-cancel [DUNEUITests/LifeFlowUITests.swift:56] DEADLINE=1793919659.286952 | `b33e1c4ae880b54a7cc0616b01e3c28ca9ebd2f2b2ec5144ab0147d98345fb39` | `34d86ba5d9d52bda215fdd39edd108211063e8b6d0e87365b5cfa03473299c0a` |
| 6 | L09 | 17 | DUNE_VISUAL_AUDIT_READY L09 MAX Morning Stretch selected date [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919696.377322 | `84f1e246ceb93b680d7263bedfdb598f0ca3eb3000ee9a15d6387822b5c4d0a8` | `96b6dcf03962a6c726ad4d12adfdd2efeb378e94e4d288cfd9ca978a93491c1d` |
| 7 | L09 | 18 | DUNE_VISUAL_AUDIT_READY L09 MAX Morning Stretch record control [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919714.928722 | `857409be5e9634325e486fc845b42cc01e257e5fb0bdd4dfb34267e44234b4a4` | `15eda06942735a71661fe86f6f2962c35c87175675011acedad8aca7922cca21` |
| 8 | L09 | 19 | DUNE_VISUAL_AUDIT_READY tap habit-past-record-cancel [DUNEUITests/LifeFlowUITests.swift:56] DEADLINE=1793919730.816355 | `37e68670041bce535a2f23546828f009081b1499b569dc36ea7a33145c996fd1` | `9402cacd46c9b9d8e26002523353a911c6a6dbeb2aedf1e94d4f3fc41dbf390b` |
| 9 | L02 | 24 | DUNE_VISUAL_AUDIT_READY L02 MAX new habit hero [DUNEUITests/LifeRegressionTests.swift:215] DEADLINE=1793919773.950869 | `1162c838cf308abd6f674c6caec4f0146c1d4ac117dd0b6cdce5b2d8c9882271` | `a5d6d9ac50fb001cc0f9c31f103d32dce6197e8a95ea2e892f4dd0bb5b77e438` |
| 10 | L02 | 26 | DUNE_VISUAL_AUDIT_READY L02 MAX final icon selected [DUNEUITests/LifeRegressionTests.swift:222] DEADLINE=1793919794.9088821 | `776943789280f1b301ccdc175697cb005f7507695854ea8423feafb0d691f990` | `4c153df06c0fda495fc8ac46af0bd1650016b6e066c9a5c7c5f7864a2cfbecee` |
| 11 | L02 | 27 | DUNE_VISUAL_AUDIT_READY tap habit-form-cancel [DUNEUITests/LifeRegressionTests.swift:226] DEADLINE=1793919803.937447 | `dc7eaffcab870a6b32ded3d0f5f642983d945ba4d1dd7da33812d6ac271a9db6` | `e2840e7221e3039adc2a7ed5a2271ff0b7ec8e67b78a532885559da252bf64e5` |
| 12 | L02 | 31 | DUNE_VISUAL_AUDIT_READY L02 MAX edit habit hero [DUNEUITests/LifeRegressionTests.swift:234] DEADLINE=1793919838.9414458 | `e1cda784098990f4883af224369dfaf441025d67f8fe48adbba6cb7b7ad13c6d` | `299414d9cb7117992b6ba6c09bdd4b212dc87f10dae9c2b950d06b86addd2ceb` |
| 13 | L02 | 32 | DUNE_VISUAL_AUDIT_READY tap habit-form-cancel [DUNEUITests/LifeRegressionTests.swift:236] DEADLINE=1793919844.242535 | `1469dc3dcd998cd92262c7502dcaccce7afbe8c4e7b623cdf163482f01b310b3` | `c4f61c82ea99456116a55475884f7be651a80f1a56e2bd8d4c6dd6c14ad7f12e` |

Each pair’s source App SHA, path, and exact test are in the adjacent JSON report.

## Limits

L04 entry and the overall MAX run remain failed. This report does not claim unfolded/inner-display Duo, physical-device, dark-mode, or full regression behavior.
