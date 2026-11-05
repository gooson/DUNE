# Batch03 iPad normal native review

## Findings

- P1: None in the scoped iPad states.
- P2: None in the scoped iPad states.
- P3: None in the scoped iPad states.

## Scope and result

- Source: `fc308b66b07e53bb2c9ed382d2d2da99f0c84c45`; simulator profile: iPad normal.
- The first owned SDK run passed **5/5 exact methods**, with zero failed or skipped. Each method is individually `Passed` in the archived `tests.json`.
- All 32 selected PNG/AX pairs were SHA-256 verified against `ipad-pairs.json`.

## Native observations

- L02: The new and edit forms show the hero, name, icon grid, and Save/Cancel within the iPad sheet. Focused name and software keyboard remain readable. “Evening Walk” updates the preview, Fitness gains selected AX state, and both saved names appear on Today cards.
- L04: Active and Archived heroes match the segmented counts. History opens, closes, and shows a completed entry. Restore changes Archived `1 → 0` and Active `2 → 3`, then shows the empty archive message.
- L09: Read duration, Water count, and Morning Stretch check records show the same Nov 5, 2026 date and their relevant total or toggle controls. Cancel does not change Today. The focused numeric field retains `30` beside the iPad keyboard popover; saving `40` leaves Today Read at `0/30 min` and shows `Recorded later` with `40/30 min` in history.

## SHA-256 inventory

| # | Screen | Checkpoint | PNG SHA-256 | AX SHA-256 |
|---:|---|---|---|---|
| 0 | L02 | tap habit-form-name | `49ff1464c64146f43fade788dd6149265875e317d426a7e2d7dd023acd072ea3` | `401cf58f6f5b05acb13b363fec3b1196f89217b706ae10fa43e3d08e0c495934` |
| 1 | L02 | tap habit-form-name-clear | `13453869b14c0e7180eb945b9d176d081d26411d4222be20bd0db7b4d3d1c328` | `0623b277a8869b6ebf3d48f2db9a8111f7cc5d705f287b0016e902dd749aac27` |
| 2 | L02 | L02 Edit habit name before save | `275a754f84c49c0e2f6fd587f78875098b85c48f43e576953d669c86a0df6cc7` | `2736f3aaf45881d71e9afe95538440f660196fe83a295282b6b32db6fa16660c` |
| 3 | L02 | tap habit-form-save | `2d59fffb27ccd87e6767eec8cd0ec11c524533947d8286eb17ecc71340b441f0` | `37acf1ec568d1ff3679f88150f72505fd6ce6e322372f9f8c88634426d5973ab` |
| 4 | L02 | L02 new habit hero | `c4efa19b12835d497811bbfb4626c8905719c3858df452e1405bab5755b3ad1c` | `999eefb28eed9b8757b1d874a9f77e8a4887481b54c6c46a42b1db9a27f6853a` |
| 5 | L02 | tap habit-form-name | `1fdc4c9d1c26ed6aa70f4bc2838c0babcb30dfce37c3a7bba5cd506950c3a029` | `c844306d489f3972d79b80516f30c21d3743505739f3ef0cda12ca96a4e20d33` |
| 6 | L02 | L02 focused habit name and software keyboard | `1fdc4c9d1c26ed6aa70f4bc2838c0babcb30dfce37c3a7bba5cd506950c3a029` | `851f46959a49eff1d324a8be8c804f48bef850f28e91a7f32b0d8af73eb2e77d` |
| 7 | L02 | tap habit-form-name | `62885615584ee5d71256bb49116a6f37d9091b30451b592973a3137920bce63e` | `babb470785a9f6f7d7966422baee55b1f2cd8d213f9155d10e7879ffe4766956` |
| 8 | L02 | L02 new habit named preview | `1ae53bad013ffa81c37b0fa761bdb89822c6c1ab04d83ffc0f25211f0acc48b3` | `f1fee3a61a64b0c59ba94fc9ede752d0c98c3d4b71e1ddc2c26085806c12f6b7` |
| 9 | L02 | tap habit-form-icon-fitness | `cf038137cc39a460365f1e317b5734fb38a1bcd6d4025bf4eed86b2b740837f0` | `aa09b26460cdcf42b8eac660b84b9db362ad47155c80ce92733d5e8955cd110d` |
| 10 | L02 | L02 selected icon grid | `cf038137cc39a460365f1e317b5734fb38a1bcd6d4025bf4eed86b2b740837f0` | `d470c09a042e60691fe869b07d2e32bd797057c62645fffe3ff201e90c6b0f0d` |
| 11 | L02 | tap habit-form-save | `49fe04cfc1d523b981d2209efc631cc7b9a5c37b04615d67a6bbe649dde89eed` | `3ffc9ed02c0bd3055128410cf74f00b4a6f4e58045c7582c1aa56016153f1712` |
| 12 | L04 | root after setup -[LifeRegressionTests testVisualAuditHabitManagement] | `f77ceb071262fcc41463fe9f6c8b03023fe042ab61e2ad3042581474bee94244` | `abab78b503e62bf3cdf93f23ca36d5b51dc85053a9385b1bd1cd3be4590bd74b` |
| 13 | L04 | L04 active management hero | `d1fb2fe4905f77431d7cc0c500607bed761d3bd201b6459fa8f4388a9b199375` | `4ade9f0112106dd3ef74883d71d0b8f85f1002a5ad1f068159d0002c8a0d0696` |
| 14 | L04 | L04 archived management hero | `92fb1f9f20176b0ce9b87cda497ab589f1e5cdc72ef5954e6cc64a10c7d91972` | `e5f4c9b531ba988636ea3a93be0131f5bc8019213051f21f7bc3fea14c839d98` |
| 15 | L04 | L04 archived row and History | `92fb1f9f20176b0ce9b87cda497ab589f1e5cdc72ef5954e6cc64a10c7d91972` | `d8432421caead7ec1843d6267366dc4377ddf084ff092deba7783b4d725ff671` |
| 16 | L04 | tap habit-management-history-Morning Stretch | `3661a315ef5563d1ed64603d57ab3a8097528b2eec4c9ad3373313ae99f1eb9a` | `20f2185e247da04b2902c4bfa7e7f8419cce829e2924446f7f0611edc9c3ca79` |
| 17 | L04 | L04 archived history | `3661a315ef5563d1ed64603d57ab3a8097528b2eec4c9ad3373313ae99f1eb9a` | `00f696b5d49a6d32ac793787e3236c779a85e62c7c315ed3c771504b41399237` |
| 18 | L04 | tap habit-management-history-screen | `2fac5a771105bc2bbf9db3d2f10e6aea46bf0caeade460162f667368accac301` | `21ec2a32ccbb06fdfabc877fdbfc38101ed34b2ca4f3a598990d905e9b2070e4` |
| 19 | L04 | tap habit-management-restore-Morning Stretch | `0560377b060ef1a345bb0c2ac983e355be3d07e1afb506518e5c8a923dafed7c` | `9ca40137b545ee3c6c917f8f1bbd6550310706ee9be141f87ad9be6da74188f9` |
| 20 | L04 | L04 archived filter after Restore | `0560377b060ef1a345bb0c2ac983e355be3d07e1afb506518e5c8a923dafed7c` | `a96b3b431e28a0a2a38fb6a9c5a55240e62f2be42934c5a7802b6a3099d3dbc6` |
| 21 | L04 | before teardown -[LifeRegressionTests testVisualAuditHabitManagement] | `2fbeb1ac5f602fb9a8ac3eade9ec16a7755cee1aa22f541878ce4b7abe67743e` | `501169c0c8c6efc21eaa14f22b0829a4bcf9ea85db4b0db65061afa64889c467` |
| 22 | L09 | L09 duration record hero and date | `9e1b0f79cae84d24e4a46eaa800373400e56680ff4d6782838213bb7ae70e1a7` | `62f96da5987001dedee40dfd8ffa30f2fa607e18b4fd233af7ad8f63b8cb9760` |
| 23 | L09 | tap habit-past-record-cancel | `cdea74be93db14919134a921d67b388cf004886cc1defeadd5b110108381a3eb` | `c19f9acc901daeb35fd2c6b6a76a0cbe93a257b7404724ab8d208e174825aea7` |
| 24 | L09 | L09 count record | `3fc6cc091e4331e61143677e619501573bc503ea8f830a5d0c09933b4d203c1d` | `60c0954ad597c969745f3df5127abcfef7c20a644301be2ce4039fb708945076` |
| 25 | L09 | tap habit-past-record-cancel | `3d4038dd6244362432827d0586bc4fed227b6f5bbc11786ecd4c31ad7396b426` | `9d0a76758da239b62f347dcd2f7fba939f985fd33ab3862ad3d4ab2d8463fde1` |
| 26 | L09 | L09 check record | `564eca9b65b812bfcdaae324705d214388f8b1f7793ba6b88c8f87ed6d2c0ab8` | `cfeb54eadd7834a3a22f3b297451baea38616c18af5c61c62cac1021d90bfa4a` |
| 27 | L09 | tap habit-past-record-cancel | `563b201e3096f3dea7a450a1d2aa66d3e22fa9605fb1d33c75eedaaacf964c0a` | `d7c50b9fea68d9b2e253b7575fb98c26add07095af0c7dc6c990d7a6da8b5ac8` |
| 28 | L09 | tap habit-past-record-total | `0555dd577a23722570ab60000cb25fc1423b989ac4167b3379d5dae549edf494` | `d5fb4f24eedce2eb25b7401daa8734eb3a1eb4e39d081107fd066fe569e007a7` |
| 29 | L09 | L09 focused duration total and software keyboard | `88c0c7e8ac0d410005536b0c3e78384448beb0a4f062196166c857f506752f46` | `f8f862fb41752851809d4d2a1d09b5a8177455ae42d07589746f87edf9ca2d82` |
| 30 | L09 | tap habit-past-record-save | `bb6ad2b85c8193c8759825d437792f9b6f5ad632953db74c241cad33499b52f2` | `e74444b55865e593e38b81d2dc0df378c1c4257f778b15c2fc84230015b341d7` |
| 31 | L09 | L05-Life-history-recorded-later | `83375883b62602485f1c4d6f4b7ac98448c30e93a2e4b2c84b5ae552e1bc9e41` | `dcc97bd28f1cd3ea7a2e521c1cfb6e1e6039effe4281ad623e413a3510889d35` |

Each pair’s paths, source, and exact test name are in the adjacent JSON report.

## Limits

This review covers only the owned iPad normal simulator and five exact methods. Physical-device, dark-mode, Dynamic Type, Duo, closed MAX, and full regression behavior are outside the claim. History child screens are observed as outputs of these routes.
