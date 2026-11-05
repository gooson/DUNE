# Batch03 Duo closed normal: four passed methods native review

## Findings

- P1: None in the four passed methods reviewed.
- P2: None in the four passed methods reviewed.
- P3: None in the four passed methods reviewed.

## Scope and evidence

- Source: `fc308b66b07e53bb2c9ed382d2d2da99f0c84c45`; owned Duo at **0°**, active outer **LCD**, `rot0`, 1398 × 2034 host PNG. Before/after pose readback is recorded in the pair index.
- The five-method SDK archive **failed overall**: 5 executed, 4 passed, 1 failed. Only the four individually passed L02 new/edit, L04 management, and L09 three-kind Cancel methods are cleared here. The L09 numeric method is excluded.
- The 22 selected pairs are bound to the passed SDK case ranges and checked against the raw SDK log, per `duo-closed-normal4-pair-contract.json`; all selected PNG/AX SHA-256 values were verified.

## Native observations

- L02: New/edit hero, name, Save/Cancel and icon controls remain readable on the outer LCD. The keyboard leaves the focused name visible. The Fitness selection changes the hero glyph and remains marked Selected in AX; its grid wraps within the available width.
- L04: Active and Archived counts agree with the segmented filter. History opens and closes; Restore changes Archived `1 → 0` and Active `2 → 3`, with the empty state and Back control visible.
- L09: Read duration, Water count and Morning Stretch check forms show the chosen habit and Nov 5, 2026. Cancel is the passed path and leaves Today unchanged.

## SHA-256 inventory

| # | Screen | Sequence | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---:|---|---|---|
| 0 | L09 | 4 | DUNE_VISUAL_AUDIT_READY L09 duration record hero and date [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793917420.4350328 | `d4dee700a919e76c7fd077ac12335209c0d6ffd793d605513f397542c3bca720` | `1f0a1c968f0b6766f0230e9d4d844ce2dacd55e15336845f43260b7898d841bf` |
| 1 | L09 | 8 | DUNE_VISUAL_AUDIT_READY L09 count record [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793917454.0084882 | `2b8a3855baf271e15075cdc4c3730f87a0a3c8c8206abd5e198d2d8f6aa873ca` | `419813ad5113aa3bc73721c8496c610d02719ffcdf438704875e14b121105488` |
| 2 | L09 | 13 | DUNE_VISUAL_AUDIT_READY L09 check record [DUNEUITests/LifeFlowUITests.swift:31] DEADLINE=1793917498.253735 | `0cc4aecab2f928a4ffc0082622f7acedc8050622e048a8d521a6f7c1ff172b34` | `c1fdd1f7857ac3b0133b53f419b4aa490622750785f090a08867355d7b3e26b3` |
| 3 | L09 | 15 | DUNE_VISUAL_AUDIT_READY before teardown -[LifeFlowUITests testOpeningPastRecordMenuDoesNotMutateToday] [DUNEUITests/UITestBaseCase.swift:120] DEADLINE=1793917508.122119 | `361828d934e00d0900ae52e5f5ddedded1a54799d9cbe417a018b160a5de8abd` | `c60b044aac5e0e1026cb693298593e222b1610af1a6db82d4298fe7dd06d0999` |
| 4 | L02 | 32 | DUNE_VISUAL_AUDIT_READY L02 Edit habit name before save [DUNEUITests/LifeRegressionTests.swift:463] DEADLINE=1793917656.793293 | `e6c8b33ac01afeccd18ab506f370b4293c6d2e8e1fe515a9caad8744ba5e7e58` | `8d3a658d0b391c9aa346b33721d95cd270d4d892c616242e985432416d8b7b57` |
| 5 | L02 | 33 | DUNE_VISUAL_AUDIT_READY tap habit-form-save [DUNEUITests/LifeRegressionTests.swift:191] DEADLINE=1793917662.74527 | `620fa46046ad172c825f6a7569e3c5243cc42acae95d4cdf70ed56455eb405c1` | `3af562c29143726656da6e3da68d25f72e76a8e9194fbad1c5edf76515fe33fa` |
| 6 | L02 | 34 | DUNE_VISUAL_AUDIT_READY before teardown -[LifeRegressionTests testEditFlowRenamesSeededHabit] [DUNEUITests/UITestBaseCase.swift:120] DEADLINE=1793917669.008294 | `620fa46046ad172c825f6a7569e3c5243cc42acae95d4cdf70ed56455eb405c1` | `82afb2a556f21280725a4cf1a0babe1fe54b92d240001baf24bedb55c3e5a65d` |
| 7 | L02 | 38 | DUNE_VISUAL_AUDIT_READY L02 new habit hero [DUNEUITests/LifeRegressionTests.swift:77] DEADLINE=1793917701.581472 | `86676844de9ca90192dd9e4b053c0d4d82218b06a598fb7794bdf4f166a55be6` | `ff043403df148706277652dbeecd97a3ec0e8a4ff188184627916f3afab1ab63` |
| 8 | L02 | 40 | DUNE_VISUAL_AUDIT_READY L02 focused habit name and software keyboard [DUNEUITests/LifeRegressionTests.swift:80] DEADLINE=1793917711.712932 | `9a5e0683e90ef8e3728b9ccac5d4573e2d87f856d8b32f346f1b4c142ec593e1` | `79f2b423c1272f46997fba48cb19318e174d497314f2074da46a414003e7cecb` |
| 9 | L02 | 43 | DUNE_VISUAL_AUDIT_READY L02 new habit named preview [DUNEUITests/LifeRegressionTests.swift:84] DEADLINE=1793917731.6931992 | `c70f05e91b79f71674326029da879dd068482ae45f813aa43ae1d89837edb1a7` | `19ddc355fe38291ac16f74aff5152463b6aed23371a5cc830d6c8a895cc443ad` |
| 10 | L02 | 45 | DUNE_VISUAL_AUDIT_READY L02 selected icon grid [DUNEUITests/LifeRegressionTests.swift:92] DEADLINE=1793917745.229428 | `1e419ddd171dae5707462bb24157294d74c39f227275731b20515037e1bcdaac` | `91759da83ec474d3af7fbc6ce7837d12bcee38158aab7420e60f2738085681f5` |
| 11 | L02 | 46 | DUNE_VISUAL_AUDIT_READY tap habit-form-save [DUNEUITests/LifeRegressionTests.swift:98] DEADLINE=1793917752.069835 | `356b8634094d7326183b0d86bd64a784af11167573c12fc44fe11d4650459bd2` | `8d392a4fdefd775b439b30c16cf2714aeff9e503822d74a04ae70fe98e47fbb0` |
| 12 | L02 | 48 | DUNE_VISUAL_AUDIT_READY before teardown -[LifeRegressionTests testLifeRootRendersAndAddFlowCreatesNewHabit] [DUNEUITests/UITestBaseCase.swift:120] DEADLINE=1793917767.2030249 | `0447c536e8fb3df32a76eabc5c6aa1445c76ea65af4fd4ee7f09f4dc171dd874` | `73c3a1d701c8eb1a890f0f9d96702d1b6a744bbd3943e9ded7d1650b464316f0` |
| 13 | L04 | 54 | DUNE_VISUAL_AUDIT_READY L04 active management hero [DUNEUITests/LifeRegressionTests.swift:348] DEADLINE=1793917822.784347 | `ee28fcfc5d4d9966dc18c71742fa61b0e403b7756435bb5032b22a5438ea6476` | `9804b54197b765de82af6a07f63db33a30f76fdbd27e03291fc344254616c5ea` |
| 14 | L04 | 56 | DUNE_VISUAL_AUDIT_READY L04 archived management hero [DUNEUITests/LifeRegressionTests.swift:357] DEADLINE=1793917837.5164309 | `d208fbff445551057ef09fbd99443cefe962cfe4f6ef390ac68db2976ecce3bc` | `7d1f91cc3c89b664a5819c4f352d678e18faec1ba27193b2b9f4c1690d87fdc7` |
| 15 | L04 | 57 | DUNE_VISUAL_AUDIT_READY L04 archived row and History [DUNEUITests/LifeRegressionTests.swift:363] DEADLINE=1793917843.5537682 | `d208fbff445551057ef09fbd99443cefe962cfe4f6ef390ac68db2976ecce3bc` | `63b41e51a26fbf5682af9f20f081b862d54b972ce279891520d536afdbfd8d8f` |
| 16 | L04 | 58 | DUNE_VISUAL_AUDIT_READY tap habit-management-history-Morning Stretch [DUNEUITests/LifeRegressionTests.swift:364] DEADLINE=1793917847.7673368 | `7f71aa13563573613a9b111ec35ec5a4ad301a70463de7c5caa2088072d04bc0` | `7045112ce04184a13b67dfd57ed09e6ac112aa1c4aa4da5658c9bc1d02b1b729` |
| 17 | L04 | 59 | DUNE_VISUAL_AUDIT_READY L04 archived history [DUNEUITests/LifeRegressionTests.swift:369] DEADLINE=1793917852.193408 | `7f71aa13563573613a9b111ec35ec5a4ad301a70463de7c5caa2088072d04bc0` | `59906ad1560f5ce671bfa4ba0002c1182e83e6e52aca074d46c88250848087ee` |
| 18 | L04 | 60 | DUNE_VISUAL_AUDIT_READY tap habit-management-history-screen [DUNEUITests/LifeRegressionTests.swift:373] DEADLINE=1793917857.3872662 | `d208fbff445551057ef09fbd99443cefe962cfe4f6ef390ac68db2976ecce3bc` | `74d64776da573607561bf4d935d8f19e3a2dbe9a84a52c6c03629232ce7e3de3` |
| 19 | L04 | 61 | DUNE_VISUAL_AUDIT_READY tap habit-management-restore-Morning Stretch [DUNEUITests/LifeRegressionTests.swift:378] DEADLINE=1793917864.052693 | `c3b1cce7217218750a00c03a9cdd477d8e0b1cf203a8491e528e5d82bee74fbe` | `6a7e2fe364157c83d46dd2f9104a2f154c2c4b9385019069ccda9e93d94b9bee` |
| 20 | L04 | 62 | DUNE_VISUAL_AUDIT_READY L04 archived filter after Restore [DUNEUITests/LifeRegressionTests.swift:381] DEADLINE=1793917869.509192 | `c3b1cce7217218750a00c03a9cdd477d8e0b1cf203a8491e528e5d82bee74fbe` | `1f089a7306f0db7441b45c59814ac90d57f7e45cce72aa6937690cf9cebff37a` |
| 21 | L04 | 64 | DUNE_VISUAL_AUDIT_READY before teardown -[LifeRegressionTests testVisualAuditHabitManagement] [DUNEUITests/UITestBaseCase.swift:120] DEADLINE=1793917879.826066 | `12c3867811ae8da9dcf8177a304a68910abc2cbcc4ed341285ffdc60ea1c81d4` | `d302a236fe1aaac5be2aebd96b2261e0f1de4b2f6c7a5d55a219336aa19a3033` |

Per-pair paths, source App SHA, and exact method are in the adjacent JSON report.

## Limits

The numeric method and the aggregate remain failed. No unfolded or inner-display Duo, physical-device, dark-mode, Dynamic Type, or full-regression pass is claimed.
