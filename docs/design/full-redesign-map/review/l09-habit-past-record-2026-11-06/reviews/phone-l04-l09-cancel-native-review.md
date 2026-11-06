# Batch03 L04 and L09 Cancel iPhone native review

## Findings

- P1: None in the two passed methods reviewed.
- P2: None in the two passed methods reviewed.
- P3: None in the two passed methods reviewed.

## Scope

- Source: `b7993b5e0fb4c9a5a5817f2d8c545794d4a1cc19`; profile: iPhone normal.
- Passed: `testVisualAuditHabitManagement` (L04) and `testOpeningPastRecordMenuDoesNotMutateToday` (L09 duration, count, and check Cancel).
- The retry SDK archive **failed overall**: 3 executed, 2 passed, 1 failed. `testPastReadTotalReplacesYesterdayAndLeavesTodayUnchanged` is not cleared.
- Verified SHA-256 for all 19 indexed PNG/AX pairs. Indices 0–15 are from passed methods; 16–18 are from the failed numeric method and are diagnostic only.

## Native observations

- L04 active and archived heroes and segmented counts agree. The archived row presents History and Restore. History opens the existing L06 child sheet with the completed entry, and Back/Close navigation returns to management.
- Restore changes the archived count from 1 to 0 and the active count from 2 to 3; the archived empty state is visible and unclipped.
- L09 duration, count, and check record sheets show the chosen habit and Nov 5, 2026. The count total field and check Completed switch are visible when the sheet expands.
- The passed Cancel method covers all three kinds and confirms Today is unchanged.

## SHA-256 inventory

| # | Scope | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---|---|---|
| 0 | passed-method | root after setup -[LifeRegressionTests testVisualAuditHabitManagement] | `578156d36f9ad5e7bd635c0541fcef12fa65602a4adfc8cf47fde7422e334f1b` | `e16d779078c7d642b4e812378adf3dd5cbbaa482bea9d26b6f05127998d32706` |
| 1 | passed-method | L04 active management hero | `1d07754cee6308830908422a6f86f4e7449051b2046a1be2de0600fd3826211b` | `ad4b78d9e833c13a51365f1ff464995f16c5a7191446bf6515d5d205ef10aec9` |
| 2 | passed-method | L04 archived management hero | `9642c8fd43a6f6a6eaef05f176ebd745d5aa028771820df7a3dc5b4de4eccf83` | `bc1754c3256b072512018d5bf7a4efc319f6e83f536f1da9c8dddb276e1e369c` |
| 3 | passed-method | L04 archived row and History | `9642c8fd43a6f6a6eaef05f176ebd745d5aa028771820df7a3dc5b4de4eccf83` | `28737987eb7ad34184a35d4666b8d5e222bfd0c2275a59b33c22e19348e9401a` |
| 4 | passed-method | tap habit-management-history-Morning Stretch | `0e838af5b54991aa77d7b0c29db56eefd22e54a9c29f936c4087fbf737c0d3af` | `dc11f15ecf2188eaa2f3fa17a4e069c6ffccf99cb283814223c55fb8c9d9a05e` |
| 5 | passed-method | L04 archived history | `0e838af5b54991aa77d7b0c29db56eefd22e54a9c29f936c4087fbf737c0d3af` | `a9fdbb8f0c6c91f05d066fb067d1ff3d6e8fe5099b0fec018d53ee1296337952` |
| 6 | passed-method | tap habit-management-history-screen | `3ed9e171cf5acae4c09ea6f8e753639f48842589482a4feed997ae776d681296` | `a48ebb376e29c75a4b7b7afd5502b1f0c56497994510eb09a630d7d258cc9e3f` |
| 7 | passed-method | tap habit-management-restore-Morning Stretch | `50e7d5f035f05c506c16aac484e7456400d188c44041f10ebb459f8f29a118cd` | `9af55980db367223399cadc789cdd699b8ed40154e3c8a4b2ae9f1ea61fedb90` |
| 8 | passed-method | L04 archived filter after Restore | `50e7d5f035f05c506c16aac484e7456400d188c44041f10ebb459f8f29a118cd` | `a316217c3968e77aba87cb39235133a5b1c0116f227c97918ac9f35182ace1d9` |
| 9 | passed-method | before teardown -[LifeRegressionTests testVisualAuditHabitManagement] | `ce7f17d224c695477eb676a45a48794c923aa0acc85e27d690c5a72bfbba0ee8` | `44b6833fcdf93e4331153f934d523bef307803aec65ee84f0441e4bba81ef035` |
| 10 | passed-method | L09 duration record hero and date | `a122d3a488ac79e8570a916c3c7bc69516f878cdcc07479de8b53656adcbfdfa` | `83920a416aea2649a970bd4b2f360ea8076f5c10a8f1024d5cffcef34b082436` |
| 11 | passed-method | tap habit-past-record-cancel | `1480db42455e416d2c4902468bd597e2c30ab5f9e57b283cf32444a327312127` | `4993f9d795d2da9bd7d7873ce0c20243107926fcd1855d77e294837a542b8870` |
| 12 | passed-method | L09 count record | `b37b2d17efb5a54c69e584761783df8a0a62e65ae69e9b6493bdee8a730b885d` | `d63e9ac9ea349dafe28946a9c1b63c6b0ea748109586c97e5d7e7237a04296fc` |
| 13 | passed-method | tap habit-past-record-cancel | `c49e585d3615eee271ac66c2edc85cdca1d431de19da023342854dab34af20b0` | `0253bf9bb85cc8f000cbb069e32aa1dad5bdae2ea5209921b154b215a278bf47` |
| 14 | passed-method | L09 check record | `4c3a7a6fe04fb26dd8b66d221ad01b94709aac1fcfa576277b7f49dc53286533` | `e04e44819dccae9b29d79067f3dd56644f66e6fecc1f86274d8c9c1b6da7a4be` |
| 15 | passed-method | tap habit-past-record-cancel | `96d44fd1e6206daaee8838c05c59944809d02de3650d3c1e671461deab04188f` | `07352e86a91aaeb2c562c5976d343e98fbbab1e25a3069a5474922489eb9ab4e` |
| 16 | failed-method-diagnostic-only | tap habit-past-record-total | `300a63d37ca1d3fe08ad427d17a9d0b60c3e64189b826259b4691eccd7dffbb3` | `5d515bd07db532f5b4dc1f852ec9fcf32440dc01839299f52ee851a41cf10ad5` |
| 17 | failed-method-diagnostic-only | L09 focused duration total and software keyboard | `4279ba406969c63e181c0d724fcb7ac5f0639f9638136364afc2a1962d0350f6` | `6479d5344b93f95840d9dd27b1dd060977d652e7b3c6c89239845fbd22c85805` |
| 18 | failed-method-diagnostic-only | tap habit-past-record-total | `5a2309b2bf8d4e5a0fd69867469dace1f3880202a6a03013bbe21e36946eccb8` | `457d4c65bad9c7a347365209edf395888749ca0a1382c29221b7c24cb88a2ca8` |

Artifact paths and method names are in the adjacent JSON report.

## Limits

The failed numeric method and the overall three-method SDK retry remain failed. This review does not claim a broader phone or other-device pass.
