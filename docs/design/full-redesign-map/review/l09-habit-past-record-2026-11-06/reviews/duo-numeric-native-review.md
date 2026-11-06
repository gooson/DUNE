# Batch03 Duo closed numeric native review

## Findings

- P1: None in this exact selector after the bounded viewport correction.
- P2: None in this exact selector after the bounded viewport correction.
- P3: None in this exact selector.

## Scope and result

- Source: `dbb21495ba4454da89f2918dca7ee026f58dabb0`; owned Duo **0°**, active outer **LCD**, `rot0`, 1398 × 2034 host PNG, with before/after pose readback.
- Separate original numeric selector execution **passed 1/1**; its one archived test case is `Passed`. The six selected host PNG/AX pairs were bound to the raw SDK case span and SHA-256 verified; per-pair App SHA values are in the JSON report.
- The original `batch03-duo-closed-normal` check retains **two negative executions**; the first five-method aggregate remains **4 passed, 1 failed**. The attempt-3 receipt records prior pipeline SHA `d71594c1c41e1471d08304703a9d4a784a035ca3199aff8c2b0626fab25eba22` and unchanged pipeline/source.

## Native observations

- The focused decimal field shows existing `30`; AX confirms value `30` and keyboard focus. Typing produces visible and AX value `40`.
- The bounded visible-area Form drag changes the content position. AX then exposes the native Past Record Save toolbar at x315.7/y30, and the subsequent real Save action returns to Today.
- Today Read remains `0/30 min` with `Record updated`. Read history shows `Recorded later`, Yesterday/Nov 5, 2026, and `40/30 min`; AX confirms `40/30 min`.
- This closes the prior runtime uncertainty for the exact 0° outer-LCD selector. It does not establish every possible keyboard dismissal gesture.

## SHA-256 inventory

| # | Sequence | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---:|---|---|---|
| 0 | 5 | DUNE_VISUAL_AUDIT_READY L09 focused duration total and software keyboard [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919183.578518 | `005d06f9f104872ad98a5fd3db48182173dca3a4bc2417e2d8f1fcc2db549bcf` | `0ee31aa44614f42feb8f8fd504e9dce05a36727e4259aefaab2db2ddc4900d5c` |
| 1 | 6 | DUNE_VISUAL_AUDIT_READY L09 replacement total before native Save [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919189.531132 | `e88d2198b06c11b3d3b696ffd40b9cc8338685a9e3214276d72215ea551c16eb` | `dcb4cc7a79d3dd7a382d989c086c614ed02c66ccd35b6edad4c674b4b877863d` |
| 2 | 7 | DUNE_VISUAL_AUDIT_READY L09 numeric Form visible-area drag 1 [DUNEUITests/LifeFlowUITests.swift:128] DEADLINE=1793919195.963371 | `c2082718f97d7defe7a78855387d631909fab31e75a4a072b401dff04f7d6abf` | `b65507ebb9ce9347be0fafe2c63e33add520ac9a4f6b6eb7e8c4b40b800448d0` |
| 3 | 8 | DUNE_VISUAL_AUDIT_READY L09 native Save toolbar restored [DUNEUITests/LifeFlowUITests.swift:96] DEADLINE=1793919200.7751741 | `c1105a715948dbb3e39f35ec841e4d5ecdfdfb95dd7b59c43877b5ecb9f1d440` | `a1c4fc9e7e77e99b440abd84a7ae8ff90f94ab7087182759b772ff216a8225d6` |
| 4 | 9 | DUNE_VISUAL_AUDIT_READY tap habit-past-record-save [DUNEUITests/LifeFlowUITests.swift:97] DEADLINE=1793919205.457553 | `663ea103e92605b3f5e3dd381f06edc3a3ae9139256353ec35d0861fbcd47f92` | `10d8ae4115740a6aa5c594d029525c648e9637a55243f1a4246bbc1624713e1e` |
| 5 | 12 | DUNE_VISUAL_AUDIT_READY L05-Life-history-recorded-later [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793919229.024584 | `3cc5df16eab4682a66979e3c1035465ebd4281a434e43e1d132373cbced0645c` | `161f69a4bc0e696f1c22f0669d909b0d0e4fb6b5780592315d528ea5a49e6abb` |

Pair paths and App source hashes are in the adjacent JSON report.

## Limits

The original two pipeline failures stay negative. No unfolded/inner-display, physical-device, dark-mode, Dynamic Type, closed MAX, or full regression pass is claimed.
