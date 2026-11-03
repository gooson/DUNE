# A12 independent stage and publication review

Findings: P1 = 0, P2 = 0, P3 = 0 confirmed in the reviewed stage. The publication stage is clear for the separately controlled installer; this does not itself install or publish it.

Source HEAD: bb79f250497786526d37d420fd839de5c2df5dee
Stage inventory SHA-256: a253ee8f314afa0c1f23d517380efa462e818dd5202d46af1c6f8221dedb1864

## Evidence and preservation

- The inventory contains 51 hashed files: 19 existing allowlisted output paths and 32 new gallery files. All staged hashes match; no extra staged file or symbolic link was found. The 19 existing baseline hashes match the current repository. The stage has no .claude files; the source worktree was clean at the reviewed source HEAD.
- All 409 validated input hashes match their source files. Across all four capture indexes and the embedded compare evidence, non-A12 capture objects are unchanged. All non-A12 card articles in each tier index are unchanged. Bitmap differences in the four activity boards are contained in the A12 tile; the tiles were visually located on the board. No non-A12 tile pixels changed.
- The four normal images and paired AX text and all nine MAX images and paired AX text are byte-identical to the corresponding archived raw files and the hash values in evidence.json. The native reviewer inspected these selected files; this is evidence reuse, not a new native execution. The stage HTML link audit resolved 943 local references against stage plus unchanged repository targets, with no missing links.
- All four historical before images match the existing A12 maps and visually show Exercise Mix. The phone before shows the summary; the iPad and both Duo before images show the prior distribution viewport and are explicitly labeled as different from the new summary viewport. Original provenance is not asserted. The four current captures are the bb79 normal summary; the nine closed Duo MAX checkpoints match their named actions and paired AX text.
- The source and native judgments are taken from /private/tmp/a12-final-source-review.md and /private/tmp/a12-native-bb79-quality-review.md. On bb79 the actual bounded cases were closed Duo normal + Dark MAX (2/2), open Duo normal, phone normal, and iPad normal (1/1 each). These are not claims of universal VoiceOver, locale, contrast, devices, or every possible state. The original failure archives remain historical records, including mixed 5f and the earlier 6706 readability issue; neither is relabeled as the final source result.
- Watch CI failed before tests when simulator cloning returned 401 and a destination ID was absent; see /private/tmp/a12-ci-watch-environment-review.md. This is not a Watch pass. Do not claim all CI green or attribute source-head CI to a later documentation commit. Publication and final status must retain those limits.

## Selected evidence hashes

| Capture | PNG SHA-256 | AX SHA-256 |
| --- | --- | --- |
| regular normal | 6ff667cf8261b748fed873af1da78907edfb719b9191184ecada8b7d2d63d727 | e09f3479c7a09efb982e3e32178cf3485dd48390a286624c3f4eaf0532c0a5d5 |
| ipad normal | fd85c388f5af4a2eb086d6974f417fa72f04c3a1b7ee4387f73fdf1cf123b909 | acbbdd0bdb2bcaa4525761f40d9ba2294865c17ed873fbbd071f53d29294793b |
| duo normal | 4b2db347c2f4d51d58d539704fe07019533ef955096daa7052a9dcc719218d50 | 67352ab51979caf172d21f17fe5b1b8695045fef7e8c3088c5cfb79c4bcf5a72 |
| duo-open normal | 377df62cc3b53b2d47d61d179c3f7b398f06c6038cfb356ee0fc601f44240c10 | b6010ab8534019ba5a1c5db22678d5f3f7bdda24e445747267314dfa7904b390 |
| 003 A12 exercise mix summary MAX | 8be067b958e29a6ac21dc0f44a29b03b16725cc6f9a531ac3794a104dc1dc6f5 | 028f2af65540d0fa195c0af41b7429a4bb730ef2405799fe3b44a28afddde49d |
| 004 A12 exercise mix weekly MAX | a593edd9ca309f608b11ac6b8f5531ceb305ebffdfc4b5d1d914e30285fdb217 | 4571e1f5bb7e1167aa6e4a44d7a8d0920f61ff5775f67c2d754be646a99cec12 |
| 005 A12 exercise mix muscles MAX | 10506867e40ca23f4c57a0a2a8814ae4f6a912cd5ac11b20868fb997e0469eae | 99e94057d36d2703e7e81c56bcaf7145837453fc92f260b1ea88644bffb13c1c |
| 006 A12 exercise mix cardio MAX | 63d0cae2ed3616958087e191747efd3fb8cef1ed7ec8c6df065789b2c0d26f4d | 8baeda161d6dabb9491327a942f025d552124ab3518bfb96319ce8e4b09c1fef |
| 007 A12 exercise mix full donut MAX | c69d6c92d61548fedd688c68e91d6aff0a989c90ebae816c649c6da586374e69 | 0f5bff6aaeac78bf307321553e78ed33f6b916e18c8bb3021d0a57a4beb58558 |
| 008 A12 exercise mix first selected donut MAX | f076cdcb0faed9ccd238729e66c0401296295b9169bf68e500086fbf6cf93b7f | e2db34a75f13004287dd04a1d3de5181971074e436353a343aa99560c9125c61 |
| 009 A12 exercise mix selected donut MAX | 3b1a935049e49da6e2ed580e64ef5e340bb79abe18433ddab5328808d6fdaa3a | 8b0659d8695f75b61a5ec5280ec36ec2d08ba6934372320ebfa7c060d0d781ba |
| 010 A12 exercise mix frequency MAX | bdf6f610f6fcd4a2afe68c22e1dadc105136bc60e2c61d556af9f40e171e003e | f3506068f87e74790b7268ae13d0e1df121b4da84a5fdf263e5866e48adcfc5f |
| 011 A12 exercise mix cleared selection MAX | b176eb6f5c1775619f0a6bc4b9c87f3fb93c115fe870e73165b2c75bb52ec7fd | 48ade06e8907c39138452710c70f9c36baef69c5fddbb4919e294190db097421 |

The selection is bound to the exact stage inventory and source above. This review performed no build, simulator operation, test execution, stage installation, or repository mutation.
