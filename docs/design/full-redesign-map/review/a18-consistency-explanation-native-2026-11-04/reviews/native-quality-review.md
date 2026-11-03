# A18 final independent native quality review

- Source: `d91f6248fc8a75e26a19822a28543368c1268832`. Staged inventory SHA-256: `d8ed955fefa5eeea90ba5c9a38ff9ca18935c66699686834daaac4e53c1c1062` (47 staged files). Staged evidence JSON SHA-256: `556a54a5fa83da61d1420ba15257271d7b024b2042d040a87725c78835f7992b`; final input SHA-256: `0be0ac166642fee3d375975e131966b9aaa0360e1773ecb0e21bbb3ec5436199`.
- Findings: **P1 0, P2 0, P3 0** across the five corrected native cases and selected gallery evidence. This is read-only visual and AX review; no extra locale, VoiceOver, or font profile was run.
- Result records at source d91: closed Duo normal+MAX 2/2 (`e1a718017aad04897005a7017a97692d72c0267893ec2903be791a2809306843`), open Duo normal 1/1 (`5d52e87c46adaaa14012dd57e4f1f5990e122082715e7e94e1f36ac9d9206689`), phone normal 1/1 (`35dfe43af6c9d6a0dbcdcca7bb9ac9bf08f7dee6f5bf420f694faff688e8f256`), iPad normal 1/1 (`ce046921ba0d58e8219e2614632cf86bb9cd7e87e39a0e5825f96c38117dfc87`); **5/5 actual current cases passed**.

## Four canonical captures

Each hash below was independently recomputed from the sealed raw capture path named in staged `evidence.json`; it equals that evidence entry and the staged image inventory digest. For phone and iPad the native XCTest attachment manifest pairs PNG and AX by action; Duo host images pair with the selected AX/manifest timestamp.

| Profile | Raw PNG | PNG SHA-256 | Raw AX | AX SHA-256 |
|---|---|---|---|---|
| Phone normal | `7C81DA67-B396-44FB-851C-F1446D53F63A.png` | `e971b500ece0825334e0b467604791815c2bbb6af001b92728faf4bca02a185c` | `F6C4AAE1-B230-4026-8ADC-CC85B23FE06A.txt` | `dab28a876d11093f2592030fbb9a292665108b4fcd9e4809502e66d7cd48c208` |
| iPad normal | `E19AADE7-82D8-4F6E-904F-6B98F9AF15EF.png` | `2dd09c0228c93af1e1b2de609a85118bcc8a781671ecd5ae4f5b7cb695468832` | `04A0C847-40E5-4F81-BE9B-7A982F4B5B3F.txt` | `0acbf7856fc59c79ce65c2e0d659a49e898e7dc7293719b263c063c1feefa3f1` |
| Duo closed normal | `015-1398x2034.png` | `665989325c406cd84ef107e40ffb452494a289e6c27068b501857afb4791d2fd` | `015-hierarchy.txt` | `188627d8929e38c10749ea179252e6a5f788e551565aabc0df88ec8c235f143f` |
| Duo open normal | `003-2007x2853.png` | `310a0cb5f88bc4b499800f85954c5b6c5e6e06a6ac7e8d472d4d9edfe791826e` | `003-hierarchy.txt` | `0a36571f43ee1a3b880db20218a8ebd5748b36f53ff3262364aecc250ec06f09` |

## Seven closed Duo dark MAX checkpoints

Each PNG/AX digest was independently recomputed from the sealed closed Duo raw checkpoint and matched staged evidence. These are the true active 1398×2034 closed display captures; the inactive 2007×2853 companion display is excluded.

| Checkpoint | Raw PNG | PNG SHA-256 | Raw AX | AX SHA-256 |
|---|---|---|---|---|
| A18 consistency info dark MAX initial detent | `004-1398x2034.png` | `6ff5843598bad33fa853ef0b9adec912a6541136114c2ee180aaa78f950ebb82` | `004-hierarchy.txt` | `69c70b0f151469fad6425b56b90c7390e2894a89ddbc85f9ffd888d54f49a2c2` |
| A18 consistency info dark MAX expanded sheet | `005-1398x2034.png` | `022a1df34d9de0797f59fb6ae14eed627d43d0d37d110b89c395c050657fc7c1` | `005-hierarchy.txt` | `8ea6ff9664db84d7e9318cfa2c0dec89aaa3ce744d0c5c6fc49671221e20a3af` |
| A18 consistency info Overview MAX | `006-1398x2034.png` | `cb07bc6696fe70782cedc9ccc471e907148fc963f7754b9a565ef295f963e810` | `006-hierarchy.txt` | `34876fd82f0b2bb83c5631e8978939068702619e1760d32f714ce7343b8cda61` |
| A18 consistency info Current Streak MAX | `007-1398x2034.png` | `c812fabe962a3600d874d8667ae3994bfa977eae6331b27f8f2734aa0b3c01b9` | `007-hierarchy.txt` | `02038027556b34060adde4361c22518df5c20a0487b2ffa62db51c21bcd41f5c` |
| A18 consistency info Best Streak MAX | `008-1398x2034.png` | `6fb22b6023ff732998300db2e4bdef75657e20b76c06cfeb1109c148a9f189cb` | `008-hierarchy.txt` | `183797af01c72839da0a63f6f6e141b833bcb1e63eb0292060119cefd5feb174` |
| A18 consistency info Monthly Progress MAX | `009-1398x2034.png` | `cb6512555dc6a2b6bfdb0ac7252458d34f8bc386ccba405cec4deaa21632733c` | `009-hierarchy.txt` | `ad9944cf521a1d125fbef5a18d2d67c56fc5af19a2c65f558107be3c9715a247` |
| A18 consistency info Tips MAX | `010-1398x2034.png` | `fa4fa6f76b3b2c631494a5090d7708a87b22fa4af93c685c472f1ad5ce7fc6cc` | `010-hierarchy.txt` | `16425e3c0d89ffd4a15dcc3cb2aa05c319dc66b1c3256c39f36458ff2fddb7b7` |

## Native quality and limits

- Closed Duo normal: canonical Half screen hero/sections, Expanded reading, section checkpoints, then Half screen and genuine Activity return are visible in selected actual PNG/AX. Source-bound review: `/private/tmp/a18-closed-native-quality-review.md` SHA-256 `7efa30561b8fb2292df9063bc4c234518e96a0ec5604396e981b47fcd8d9e36c`.
- Closed Duo dark MAX: initial and expanded native detents and all five section checkpoints are readable, retain original flame/star/calendar/lightbulb category icons, 680-width/card spacing and contrast, and show complete long text through the last Tips bullet with bounded scrolling. Selected `011` is a host lock/Home pixel, so it is **not** visual evidence of dismissal. The XCTest functional close assertion passed; visual return is established separately by normal case PNG/AX. Progress review: `/private/tmp/a18-native-quality-progress.md` SHA-256 `fb231fefcace3396043cee8d2896c034b9db3f1f32eb643534196ba9ca7ddbd2`.
- Duo open normal: actual active 2007×2853 display (pose/readback bound), canonical Half screen, Expanded full reading, Half screen, genuine Activity return. The black 1398×2034 inactive companion is excluded. Review: `/private/tmp/a18-open-native-quality-review.md` SHA-256 `798b42d4e91cab4aef1ae279e5f925e3d0c9f75833fa3a7d52df6b300e710efe`.
- Phone normal: actual 1320×2868, canonical Half screen, Expanded all sections and full last Tips bullet, Half screen, real Activity return with sheet absent in AX. Review: `/private/tmp/a18-phone-native-quality-review.md` SHA-256 `7b817aec379719a9c62ca1cc4f336efd702d8d5a230c0723ead22b6d22ace9fa`.
- iPad normal: actual 1512×2316, canonical Half screen, Expanded full sections including last Tips line, Half screen, real Activity return with sheet/grabber absent in AX. Review: `/private/tmp/a18-ipad-native-quality-review.md` SHA-256 `e9fbb7e5357fc31c2fa604eab4d180a35b848758067b20359efaadbe946e0e8d`.
- Source copy audit found 18 original UI literals/categories and icons preserved, with the changed qualifying day and monthly window statements covered by selected native full-text checks. This visual report does not claim independent runtime recalculation.
- History remains distinct: the first 213c attempt stopped at Swift compile, with null UI counts; the 5aa attempt had MAX route failure and incomplete normal capture on disk exhaustion, without a complete validated SDK aggregate. They are retained as failures/partial evidence, not folded into the corrected 5/5.
