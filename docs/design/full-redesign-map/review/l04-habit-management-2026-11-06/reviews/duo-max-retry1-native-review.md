# Duo closed MAX L04 archive/restore native review

**Findings:** P1 none; P2 none; P3 one target-size follow-up.

Exact source `1012c7fccb4e1d8c6a785b53af279de59b644a34`; App SHA-256 `bbb69778b1ed51e275ae3e50d8c8895fe3977905a3b5da8be827e657409c2b4e`. The archived SDK result and exact `tests.json` method are **Passed, 1/1**. The original closed MAX 3/2/1 aggregate remains failed; this is a separate exact-selector retry. All eight selected PNG/AX files are present and match the indexed SHA-256. Pose contract and pair index record 0° closed Duo, active LCD, rot0, 1398 × 2034, with before/after readback.

The visible sequence shows Life’s archived link, 2 Active → 1 Archived, Morning Stretch and a reachable Restore control, then 0 Archived with the empty state, 3 Active containing Morning Stretch, and Back to Life. The scrolled archived card and Restore label are unobscured; AX gives Restore 161 × 59.3 pt and the Life archived link 353.3 × 140.7 pt.

## P3 follow-up

At MAX, AX reports each system segmented filter button at 175 × 32 pt and the shared BackButton at 38 × 38 pt. The passed test taps the filter and Back successfully, and the captures show no overlap or clipping. Consider checking effective 44 pt hit areas in a separate accessibility pass. This does not block the observed restore flow.

## Selected pair inventory

| Host | Observation | PNG SHA-256 | AX SHA-256 |
| ---: | --- | --- | --- |
| 5 | Life root shows Manage Habits and 1 archived habits link; both readable. | `3a1eae114ea3d75ba359a3b1a95e090ce0260422c629610e5d2d254cf6484131` | `39f0d85193d3272f0ef4d6c2602125467c7b8eb9333f0a9135cf479fc9745f04` |
| 7 | Management Active hero reads 2 Active; filter and first card visible. | `f244b31ea3e6a836706f737bcf8da7f617c36ae54be7b455e8f5a01c90cae363` | `f2a0dbb9d555095f5c66fdb9c974d9f7922040cd5597bf7dae2a8dcfa44f2b60` |
| 9 | Archived hero reads 1 Archived; Morning Stretch card visible. | `a83b007d69f4d70b4bd3e7d717491c44544db94c29acf9d9e09b84bb97dfaa9f` | `d690b7a031749654233fbb998c52054c7c4a368c1bcc096adb218afc9c7d90be` |
| 10 | Scrolled archived card exposes Restore and History; Restore label unobscured. | `02c6e83dd10c0579b33a0c3cd406945bfae03e1128e0bca83a8691bab1461287` | `da4fe2456ea58002fea2194285448588f32c16633bf44d5f78f0f2735e02a137` |
| 11 | After Restore, Archived count is 0 and empty state reads No Archived Habits. | `3f8d8de31c42b1829bf561bb0c139bbbf1e44626e5914e59cb13aa0c4b7b6b89` | `1548091150a529f6818aad906a82d8e2ac2cec3c2a7427441339df78f21d1194` |
| 12 | Empty archived state remains readable, with Active (3) available. | `3f8d8de31c42b1829bf561bb0c139bbbf1e44626e5914e59cb13aa0c4b7b6b89` | `6d4d4723bc11ffed8f49884f705ce323b1e0d96a944188450f2bc3806b3b1b89` |
| 14 | Active filter reads 3 Active and Morning Stretch appears among active cards. | `23a61fe72cc4551ebb3016867a02a04abce97badb7de83b0abe1c0d84e980149` | `e697a723c10a7614199d6d767271364272a2fee869a2dd03e3049de2c00f3c30` |
| 17 | Returned Life root shows Morning Stretch and a readable actions menu. | `7ccbd1cb12e689f4438023d9ed2c5c966762e0744fa2b782fa89117a618fc0b2` | `a39811c862a8a9c5eb729d13dac5b76e57238758997c92bdc242ce0b92c3c3b5` |

**Scope:** L04 Duo closed MAX only. This review does not claim Duo open, the Batch03 full matrix, actual-map publication, final PR HEAD runtime, full suite, Dark, physical device or VoiceOver.
