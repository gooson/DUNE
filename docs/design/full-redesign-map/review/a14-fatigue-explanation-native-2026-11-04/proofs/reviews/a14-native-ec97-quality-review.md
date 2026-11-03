# A14 ec97 closed Duo native quality review — 2026-11-04

Source `ec97aabe0b43cf225099c0c9dd2354a069548685`; archive `.codex-checks/a14/evidence/duo-closed-ec97aabe-passed`. Scope is closed Duo only, normal/light and dark MAX, actual host LCD PNGs paired with guest XCTest AX attachments. No simulator or test was run in this review. Archive result records 2/2 passed with no failures or skipped selectors.

**P1/P2: none found in inspected closed captures.** Normal 004 presents the entire sheet and values legibly. MAX 020 shows the header, with “Calculation” hyphen-wrapped but readable; 022–026 show raw 0.3, decayed/subtotal 0.26, and both modifiers ×1.10. MAX 027–029 shows “Final Fatigue”, `0.02` on one line, “Fully Recovered” on two intact words and tau `79h`; the severe earlier b963 fragmentation is resolved in this actual sample. Legend “Recovered” is hyphen-wrapped across lines but legible. MAX 031 shows the prior muscle-detail sheet after dismissal; matching AX and passed test support actual drag dismissal. Values agree with the intact source assertions (0.26/12 ≈ 0.02 and 96/(1.10×1.10) ≈ 79h, accounting for display rounding). The result aspect-ratio test is a heuristic; the actual visual inspection establishes readability only for this specimen and viewport.

For each row below, host hierarchy bytes match the uniquely named guest XCTest hierarchy attachment for that exact action, and `captures.tsv` associates the host PNG and hierarchy with the same checkpoint. Attachment names carry the action UUID; this is not a claim that the host PNG itself is a guest attachment or has a separately verified capture timestamp. Repeated PNG digests reflect identical screen pixels at adjacent checkpoints. Other device profiles, languages, states, stage output and future captures are not reviewed here.

| Checkpoint | Action | PNG SHA-256 | AX SHA-256 |
|---|---|---|---|
| 004 | normal level | d036b3a1f8e03fc9fef7f9659bcfd44ab0f75277fd975a800ac5fab163609b4e | 838a9b3f505d98940b5f0d7d0ecc0d40f9e99431c83f4d0c86a279cc619be79a |
| 020 | MAX level | 8139eea803103c3310b558b6665c31947fff235a8680e1f3cbd12195c7b5962d | ef1e47d3328e59009dbad0a865d932d2f4181b13308bdbf7b81bfaf06246eade |
| 022 | MAX raw | d0e46fbb689e4771a8a18819189838fd99f9a930b327c204df1764b972a185cb | d53851a217fac36e1b8767e41e5d2c64797f4c07f7e2264342cfc69d10c9334e |
| 023 | MAX decayed | d0e46fbb689e4771a8a18819189838fd99f9a930b327c204df1764b972a185cb | 2ea0a73619847caa50e89f2993dc89ab02d6a5dcda5257f8a560147d3994e7d6 |
| 024 | MAX subtotal | d0e46fbb689e4771a8a18819189838fd99f9a930b327c204df1764b972a185cb | 8b1279489f74c6c11472fbfc4335d36433a74ce12c03513233bfc5b553d6fba5 |
| 025 | MAX sleep | 6bc1c3b9ee72867465258e49f63257b1ffcfac7ed061edacc8f64863c8061f83 | 0b1f6b283ab958bcd21a0d141db56659161c1c4afacdba665b1b21f1f2c2b977 |
| 026 | MAX readiness | 6bc1c3b9ee72867465258e49f63257b1ffcfac7ed061edacc8f64863c8061f83 | 0020f5576a9de576329d65f0f41190576ba7d5ed6e95492c3c001f1eb66e8595 |
| 027 | MAX result | fc88d849d0f952b42878fe0f22503899ce768bc029293f2b42a0e3c52d56f54c | 77ffada073f32d23d8b952ac16c62252bdd621b52e318a4786095a708105b813 |
| 028 | MAX result level | fc88d849d0f952b42878fe0f22503899ce768bc029293f2b42a0e3c52d56f54c | bf0ae7500e8f08a23064d875bcca5f2e28261bf9ec4514cb9e2ccc70c43ade00 |
| 029 | MAX tau | fc88d849d0f952b42878fe0f22503899ce768bc029293f2b42a0e3c52d56f54c | 650dfa88a7882544bef505ef4622f13bdbcfc81c39d3162e053d233d9dac4fe1 |
| 031 | MAX dismissed | 8794aa2f171355a3ebde6339dfae747cc8032346627c3ba4963ee1fb4c4798ec | e228b510b3169da145e02fae7924ce91f8d69a62a294ba46fb8be69265bfbd58 |

## Open Duo normal — incremental review

Archive `.codex-checks/a14/evidence/duo-open-ec97aabe-passed` records the ec97 normal selector 1/1 passed, including source's calculation-action reachability, nine value checks, math/tau assertions and dismissal/return checks. Canonical host 004 shows complete readable sheet: L1, raw 0.3, decayed/subtotal 0.26, ×1.10 modifiers, 0.02 Fully Recovered, 79h. Host 015 shows returned chest detail and calculation action following dismissal. No P1/P2 found in this specimen. The PNG is host LCD-1 capture; each host AX matches the unique exact-action guest hierarchy attachment and `captures.tsv` binds the corresponding checkpoint. This is English normal/light, one seeded state and pose; no broad locale, VoiceOver, other device, or open MAX claim.

| Open checkpoint | Action | PNG SHA-256 | AX SHA-256 |
|---|---|---|---|
| 004 | normal level (canonical) | 0346fc6ad24d491c4d089bd33087fca1cf3bdd028442a27e7a573ac9bcace293 | ba4947922f9dbe8458da7900dd9818d005fa4c48fb9a55b40c9c002e65860de0 |
| 015 | normal dismissed | 868826dd0bc5e8f914373a2a5d9523c61c67bec7b548b2df8a19e9eb5961faac | 6fa15cc9571b6c24a8345166e46ff8b4b4c221eb45d4fffc1cb05d0c0f2da72f |

The private builder static refresh at hashes in `/private/tmp/a14-gallery-preflight-review.md` includes all nine MAX and inline value checkpoints and its own b963 actual negative history; its ec97 duo-pair input SHA `015630043d522a8e90f8a80f80fb5fef6bbb084ce9251159c2aedb7b0f7df2ce` binds both Duo positives and keeps phone, iPad and inline positive inputs null. Actual output stage and remaining archives are pending.

## iPhone 18 Pro Max normal — incremental review

Archive `.codex-checks/a14/evidence/phone-normal-ec97aabe-passed` records ec97 normal selector 1/1 passed, including source's calculation reachability, nine value checks, math/tau assertions, child dismissal and parent return. Canonical XCTest PNG shows full readable seeded sheet: L1, raw 0.3, decayed/subtotal 0.25, modifiers ×1.10, 0.02 Fully Recovered and 79h. Dismissal image shows chest detail restored. No P1/P2 found in this specimen. Each PNG and guest hierarchy has matching action UUID, device and timestamp in the attachment manifest. This is normal-size/light one seeded state; other locales, VoiceOver and phone maximum-size are not claimed.

| iPhone action | PNG SHA-256 | AX SHA-256 |
|---|---|---|
| normal level (canonical) | 9c9cdb852001f860abebaf00612e5b6d6696ae73c99f18d1163bb3e16f6ec520 | 8a80b248ea4d66780f202458b7bb6773c9df3a00ccb6d54c1fc0c926fcea2d29 |
| normal dismissed | e39f5c35a3e0e076f6813c70565d82d157909b6d0acea0bd8914134c0d776d62 | f4ee3a1be2041502322eeda8967013db8bd42ea4adf4a7afd51786d647ad8cc8 |

## iPad mini normal — incremental review

Archive `.codex-checks/a14/evidence/ipad-normal-ec97aabe-passed` records ec97 normal selector 1/1 passed, including source's calculation reachability, nine value checks, math/tau assertions, child dismissal and parent return. Canonical guest PNG shows readable seeded sheet: L1, raw 0.3, decayed/subtotal 0.25, modifiers ×1.10, 0.02 Fully Recovered and 79h. Dismissal image shows chest detail restored. No P1/P2 found in this specimen. Each PNG and guest hierarchy has matching action UUID, device and timestamp in the attachment manifest. This is normal-size/light one seeded state; iPad inline, other locales, VoiceOver and maximum-size are not claimed.

| iPad normal action | PNG SHA-256 | AX SHA-256 |
|---|---|---|
| level (canonical) | 39d93f6114ede019c484363d7053e751eba81192aa1f7a1341b929ae8ba6cbc3 | 8d6019bd8dd8afc574dd79a375e0ee00eef12d7248d9ca47bf67f15f2eea7ea8 |
| dismissed | b7401218152b3c6c6b9d109728edf2f5671613756fee1b08da46d5b1c7060d3f | 7d3dd3194099f9762a5b01c96967d45b1c302696449e506e7ad19b2063f87e44 |

## iPad inline consumer — incremental review

Archive `.codex-checks/a14/evidence/ipad-inline-ec97aabe-passed` records ec97 1/1 passed for actual muscle-map inline consumer. Selected nine value captures show the real calculation sheet, with L1, raw 0.3, decayed/subtotal 0.25, both modifiers ×1.10, 0.02 완전 회복 and 79시간; Back capture shows Activity root after dismissal/navigation. The test checks nine nonempty, full-frame leaves, grabber dismissal and Back; it does not duplicate numerical math assertions, which belong to the separately passed primary tests. Exact action, device, UUID and timestamps match each guest PNG/AX pair. Repeated PNG hashes mean identical screen pixels, not substituted evidence.

No new P1/P2 identified in this sample. **P3, pre-existing:** Korean inline view retains English headings “Workout Load (14 days)” and “Bio Adjustment”; both are present in pre-A14 `d12b22848e8f00918d5727c7f961f1f8a7b08f9f` source and absent as exact keys in the shared string catalog. This observation is confined to this actual sample; no complete localization, VoiceOver, accessibility size, or all-theme coverage is claimed.

| iPad inline action | PNG SHA-256 | AX SHA-256 |
|---|---|---|
| A14 inline fatigue level | cdfa5980cfcb941f6f89eb1b06e992a1f8c36669bc6e8804f5db23e1cbb46278 | 6b0e93a22bd386280c03f3cae66e475c6f416b4effef4db8720c66af41c0829c |
| A14 inline fatigue contribution-raw | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | b942e61b923560a3a920fbab5530de95067e3745870aacd40eb19eec3e33eb0f |
| A14 inline fatigue contribution-decayed | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | 178cd750193f578d4a8d7cb0a3179ef0d7d911abc1ae9226a8ee82ea886b898f |
| A14 inline fatigue subtotal | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | e60254884209772678758a118f155720fc1c3b158bd6bf4370b5e437a6358135 |
| A14 inline fatigue sleep-value | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | 6a04c783d9cecc83aff89e7b9a9e04fbcf4c5fea300fd9d3c9e983ef7327cb4e |
| A14 inline fatigue readiness-value | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | ef775d08b4651bef264201c2b7d2a78fd12ba020b4acafbb614d6a9e3fe4ae9e |
| A14 inline fatigue result-value | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | d7282c61f31ff934e1eac8fb5065997d5365c1a1a883aec341e21dbb6ae4b6aa |
| A14 inline fatigue result-level | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | f95f487faf36f5bc4f2b2e770392eab04dc642c7c85f14ba0aab726c2c2e72df |
| A14 inline fatigue tau-value | f63f4a8f7511780f107d1f809b9fed0402110ea11fc16f65b543e3393713cf03 | df785ae8f8e9129cfa5c6732e9de6df527e486c2ee5db75715f1e8ebea07a1ff |
| tap BackButton | 2b044548992d1450ae6879a85a373dd21ac21ccbccf92c890e1f338f5e224785 | bc2c54ca59c699b707c47398e7a32e1cbb9fc0f039f0e0a24377d212282bbcfa |

## Current bedf Korean iPad inline — final representative sample

The earlier ec97 iPad inline sample above is historical pre-fix evidence. Current archive `.codex-checks/a14/evidence/ipad-inline-korean-bedf8566-passed` records 1/1 actual passed, source `bedf85663cf4997063e58a4b3d9e92224059f367`, UID `7D3` (full UID retained in archive). Actual heading PNG and AX show both `운동 부하 (14일)` and `생체 보정` fully within the sheet, without the earlier two English headings. The Korean heading P3 is resolved for this sample. Nine real value checkpoints and Back remain visible/reachable; Back image returns to Activity. The inline test validates presence and full frames, not numeric math, which was asserted by ec97 primary tests. PNG/AX pairs below match exact action, UUID, device and timestamp.

Final representative matrix is five actual English ec97 cases plus one actual Korean bedf case; original ec97 Korean inline remains additional historical success (seven total successful cases across both sources). English static equivalence is documented separately and is not a claim of five bedf executions. Other Korean profiles, Japanese, VoiceOver, all themes and other size/state coverage are not claimed. No P1/P2 in inspected current specimen.

| Current Korean action | PNG SHA-256 | AX SHA-256 |
|---|---|---|
| A14 Korean calculation headings | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | 53c097dbd76cd8fcd1762cf833ff067efba9215cad70fda9c86a7a0a019566d0 |
| A14 inline fatigue level | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | 5d1fccaeb0aef21d7c2b5e917a724511bfac8ea7cc0134f813a79ffa553f2754 |
| A14 inline fatigue contribution-raw | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | c7745ce2b8bb64f2c9ff2924f4a4451ba4be7b952d4824797a31f7a71cd88392 |
| A14 inline fatigue contribution-decayed | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | 69aa463584e87f0f014d18a925161e47c97ff474d30fbc0ff97e40ee9d22f4ad |
| A14 inline fatigue subtotal | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | a71a67c6b9ac13f52b134b30a539186f2cd5536a710e496558c978a491ae8513 |
| A14 inline fatigue sleep-value | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | 4968c6290e0e08b6f7ced808a79e983881aa8adcd4c456d22c0cba67eed11c39 |
| A14 inline fatigue readiness-value | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | b212691b6a147ca7c8fb3b428130cc1df99897dde3fea83612063e8d24d7045c |
| A14 inline fatigue result-value | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | fa2dbb86f279b6102e8f7884c286af1b8c056203ad00da096bede34976e35cb3 |
| A14 inline fatigue result-level | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | 19ca185ccef741b2082a168478ae45efb6aaebb45a8331b6405ff686376632f6 |
| A14 inline fatigue tau-value | 3579ad40e228c9247da884455bfcdacc821b16a79c5709a3f716208e32180bc0 | b51bee9dca0f0e27c5ae66565d6f5bd40b40534f90165859aa89b8711f92a28d |
| tap BackButton | 237afe042e29cb644a677c1e52f0439941bfa84eee9dfe9e3a8bca3c90ac6970 | 19e9a4dc66ee9a9dc48671bdb04dd76976ec086ef1fd3e5aee27a0a7b2cb1c25 |

## Native evidence binding to private v2 stage

For `/private/tmp/a14-gallery-preview-bedf-v2`, source `bedf85663cf4997063e58a4b3d9e92224059f367`, stage-inventory SHA-256 `9dc3a3c6dc4aa62ed7cc8a1e15f95c6cf5320257d6988c70d9ae79bd00c92dfd`: all 75 inventoried files matched their actual hashes at review; all four ec97 canonical, ten ec97 MAX and eleven bedf Korean inline staged PNG/AX pairs matched both their evidence.json digests and the actual reviewed hashes above. This binds native visual evidence only; independent stage content/preservation/install review remains separate. The five English ec97 cases retain their actual revision; the bedf Korean case is the sole current-source native execution in this matrix.

## Final private v3 native binding

`/private/tmp/a14-gallery-preview-bedf-v3` inventory SHA-256 `2bfbbe045c576583d1b62bf1be6466c65d3985f5ead7a63e795249da4b9d9f12`. Both v2 and v3 actual files independently match their 75-entry inventories; the sets are identical and only the gallery `index.html` digest differs. Thus all 19 map outputs, evidence JSON and all 25 previously reviewed selected PNG/AX pairs are byte-identical to the bound v2 native evidence. This is native image/AX binding, not the independent caption, preservation or installation review. The five historical ec97 English cases and one current bedf Korean case retain their actual source distinction; no new execution is claimed.
