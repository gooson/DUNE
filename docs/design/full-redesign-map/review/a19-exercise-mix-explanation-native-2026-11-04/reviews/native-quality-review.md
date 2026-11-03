# A19 final independent native quality review

Source `9c7c2cad9a6fbfaf73dc75f76a75f737496e46ec`. Stage `/private/tmp/a19-gallery-preview-9c7/stage-inventory.json` SHA-256 `02335664d2b820082181628bc0e068eaf34523c50a309f34b7cf919df5a86e55`; all 45 staged file hashes match the inventory. Each selected staged image and AX proof equals its inspected sealed raw source hash below. The four sealed archives contain exactly five actual XCTest cases: closed Duo 2/2, open Duo 1/1, regular phone 1/1, iPad 1/1; total 5/5 passed, zero failed or skipped. These counts apply only to the A19 scoped native matrix.

## Canonical captures: raw PNG / AX SHA-256

| Profile | PNG | AX |
|---|---|---|
| regular phone | `fca9440293e56159055a7fca0c2aaab36b68373d924fc0bcb159034536cd209e` | `4007d309aad820dedc8315cd6fed09bd243004a55c271fe6a9c96506bf13b83c` |
| iPad | `5b04c5f8f13d332a607bedf1c46fb3f846a8bf236651a1cab26e1afe5b0ea05b` | `969ca8a045486dfe567371506f5a263e5bdc21309c6e04de1cedb773fe2c5fbf` |
| closed Duo | `c2200c9612c2b92f93bbd80ee2a9ac4edd7dc704845788c02c97d7f500aab673` | `6d487e7473f813bac755e1625a8f90fa42c6f7d24d99b80ef405ff5c43a91076` |
| open Duo, active LCD-1 | `a929d54876dbbdb7cd19628fb1b66130a664d02b3bcb3f5612b76adf59a00fc2` | `8daa9f8affb860eb68151786662ce597a938bac3532b6466b04121c3a73466ca` |

## Closed Duo maximum text checkpoints: raw PNG / AX SHA-256

| Stage | PNG | AX |
|---|---|---|
| 00 initial | `f58fce913f0111f744c1acc09e2f1adbc76bf1eec93a7bf14cf64e4eb312c399` | `efcc78b3626afc85a95685919b63ecf77fa62cd6e697a7b2fb1afc3d50779929` |
| 01 expanded | `fc1f1391a72838173bb22e8890d20ec30b6c54db374dd652ccaab68e9667132d` | `0b5646b78b3256b1cef96e0b92bfb4d836fbb33b339d5cb959fa289b35a4f90e` |
| 02 Overview | `647f2d624dad8b8832acc987e0d3a435f48c94279ce084bc54480df321e0fae8` | `9dfd796ace4470f01625e851753075ec798f853844220a32d70070ad901b2162` |
| 03 measured | `888e83648ca0e725c8792b0ff0b6cea21cff190e029be03d045def38e86e7b00` | `2b389cd432940da956c948a2d4168dbb8750f2b66b68deceb48b88faf381944e` |
| 04 balance | `ff509f1733a26a64efc7ea801e0dee4d8498515b11b94237106a56de006d5b00` | `bc0fca329a4cde5436c8e40508f9c7df2cf11c3adf088fdea30ffd4bb40aaa4d` |
| 05 Tips | `20759805dca665c7d5d4b522376e2212cecf3ba76173a742a91c3db9b11af7a7` | `942895936b925b0ebeacdf9ba90570de28ac36d42223ce3f37c1d1163fdbaba1` |

## Visual and interaction assessment

P1 0, P2 0, P3 0 for the scoped native selection. I inspected actual active PNGs and matching AX, including canonical, expanded reading, final Tips, collapse, and dismissal for all four normal profiles. The dark Exercise Mix hero, original four section icons, card spacing, body wrapping, and text contrast remain legible. The phone expanded 1320 × 2868 and iPad expanded 1512 × 2316 captures show the final Tips line in full. The initial iPad medium sheet clips lower content at its viewport boundary as expected; the expanded sheet exposes it. AX reports `Expanded` after the native grabber gesture and `Half screen` after the collapse for phone and iPad. Their dismissed captures visibly show the Activity screen and Exercise Mix info entry; AX has no sheet or grabber. The same genuine return was independently established for closed and open Duo normal cases. Open Duo pose proof reports 180° and active LCD-1 2007 × 2853; inactive 1398 × 2034 black output was excluded.

The closed Duo MAX source checkpoints show the four readable groups across the expanded scroll sequence and their complete selected body leaves. Closed Duo MAX checkpoint 010 is an OS lock/Home image and is **excluded from visual dismissal proof**; its XCTest dismissal assertion passed, while normal-case return images provide actual visual proof. The review establishes the selected English native states, not all locales, VoiceOver, or a full suite pass. Earlier A19 source and open/closed native reports remain separate evidence; this report adds phone/iPad inspection and stage binding.
