# A16 final native visual review

- Source: `6d186b3ac51f4fa94c91c06455ea6e267a0a037d` (clean).
- Findings: **P1 0 / P2 0 / P3 0** for the selected actual native screens.
- Actual targeted XCTest: 6/6 passed, 0 failed, 0 skipped; these are selector runs, not a full suite.
- Archives are sealed under `.codex-checks/a16/evidence/` for closed Duo, open Duo, normal phone, normal iPad, and iPad A03 inline.
- Selection manifest SHA-256: `31f1cad88f5d731ed2ca3c2e2217f61a30c2b0434a104a9fe51e0a46e9392b21`; final inputs SHA-256: `506d3c9bf9db7655b4c4d6d642ce26b2e2602d63477a52c05317680264b31293`.
- Stage inventory SHA-256: `28e6831e55d5395720f91afd0fe048855f4c04e2cde5867a824678f815f8a2c4` (55 staged paths); stage preservation is separately reviewed by release.

## Actual selectors

- Duo closed (0°): testVisualAuditVolumeAlgorithmExplanation() 99.287s Passed, testVolumeAlgorithmExplanationAtMaximumAccessibilityTextSize() 149.637s Passed.
- Duo open (180°): testVisualAuditVolumeAlgorithmExplanation() 98.824s Passed.
- iPhone 18 Pro Max (fixed): testVisualAuditVolumeAlgorithmExplanation() 70.577s Passed.
- iPad mini (A20 Pro) (fixed): testVisualAuditVolumeAlgorithmExplanation() 82.640s Passed.
- iPad mini (A20 Pro), A03 inline (fixed): testRegularMuscleMapSetsLegendOpensVolumeAlgorithm() 60.829s Passed.

## Visual and AX findings

- Four normal profiles show the original chart-bar hero, overview, calculation card, five level rows and original color legend. The iPad sheet remains centered within the 680-point maximum width; the scrolled iPad view exposes complete tips and five legend stops. The phone and both Duo orientations expose the same hierarchy without observed card overlap or clipped tested copy.
- Duo closed MAX AX and screenshots show the formula, level 0/2/4 descriptions, and both horizontal legend endpoints (`0 sets`, `16+`) within the viewport. Long text remains contained in cards. This visual review is bounded to the selected English MAX text size, not a full Dynamic Type or VoiceOver audit.
- The real A03 iPad inline path has a five-stop original Sets legend, opens the same explanation sheet with the secondary contribution and formula, then shows the actual Muscle Map after dismissal and Activity after Back. Those two return PNGs are valid app-screen evidence. Closed primary teardown PNGs are home screens; dismissal for that case is supported by its passed XCTest assertions and not claimed from those PNGs.
- Native gesture behavior is evidenced by the final passed selectors only. The earlier query and dismissal failures remain in their separate raw archives; this report does not erase them.

## Selected evidence hashes

| Group | Action | PNG SHA-256 | AX SHA-256 |
|---|---|---|---|
| canonical/regular | Volume algorithm explanation | `35afffd04d073b590891f2625a34a74b8556c9359de37a73528d8098985862cb` | `5317ba30a17e5ea4ce3a44f7c6347f4606b5f8cc3aa0f6e0f9020c22089c1e51` |
| canonical/ipad | Volume algorithm explanation | `f08ad5fc42e4599ad62cb698f2f8ff2643ba419b8f3efed000c65343e19f0148` | `3958b40827efcb16332377f9ca847528a43365327560493c82c3877c456feb8c` |
| canonical/duo | Volume algorithm explanation | `44f92cdadc28a7cc6f5565f7e0bdeeaa2e626d491f8b3bb0d88650afb77dd41d` | `e0ea8d76dc2ca0afd37af04ca08958d32b3157f390e723cd30216411204d0ec5` |
| canonical/duo-open | Volume algorithm explanation | `0d7c1ef6b645a43b006beb7b8214836e8e5bb6e6ae289d874316540346e29efe` | `02756014de5c0e60fc44dcc7e1933ed47642d1cf0ba0018672dc806c90b6e4a8` |
| max/0 | A16 volume formula MAX | `1b7e1e568df39eede7e5604ef6db4f872277556b8ba2ec5bb18ccdb34aaec2ee` | `60787c8f5a079f7c2fa0dcefe4c147f5b6a0ec3eee8ac9a2655e35e611144a11` |
| max/1 | A16 volume level 0 MAX | `6d6b39077124913f41c63968e8ee20cc858df81748e4e228a3400c6a58429b42` | `f15fc7c8df8393134059215797154c12f1839044ec7c32165b6a7b5c9ea2eeb1` |
| max/2 | A16 volume level 2 MAX | `d97e5e632e87befc90748ce161db00576c39a0154bc7c557622e5218eee6aec7` | `edcbcdcb780ffc1d7d3090a5a5acebe8f67f223d7f2d2df2dd34fc8827566b59` |
| max/3 | A16 volume level 4 MAX | `f178738a3e07e35dc38edf0bc2dae9ab0c583403365d8f3c803836f84cbade45` | `4319589f1d309434a5821a8b8d7968e1b7990bb69e0856c4abb5e8c17830685f` |
| max/4 | A16 volume legend 0 sets MAX | `75b3d6f545a0e0902a1c6055ec4ad5180c82c8c377e825d8483ce0a462e96c8d` | `a6744930cde16d01107a2fe29d3a07033c2ec7b1c2c271aa706e753eac5a8183` |
| max/5 | A16 volume legend 16+ MAX | `338811aa49ed40436044536730459ca61d52ca38405b69d419705a12ecc2eb48` | `fe4a49aa2ca18e8cb096d37c3b8ab437f0b825555541db5fdb0545d6adb8bd8c` |
| inline/0 | A16 A03 sets legend | `d4df0521807f02253a989795467248195ada4e71d66352102524ee1597d06303` | `3b25b18f6ff31509c2bf0aedbba1b7507b9c193d91046719aafeeb97471ef315` |
| inline/1 | A16 A03 volume formula | `f8cd27da859db72ab758d0a18fd8611aa034a95fc02369a2cc33cefccafdbaa8` | `d39854bb3fe29e838288d2a58b9b055d8fbaa4e0c2477020fabd6dfdbe1bb8fa` |
| inline/2 | A16 A03 secondary contribution | `f8cd27da859db72ab758d0a18fd8611aa034a95fc02369a2cc33cefccafdbaa8` | `08f75a873351e6db010b30fb1df24db33ebca98cbb4516b1cd2fa1f8ceb38658` |
| inline/3 | A16 A03 volume dismissed | `fe0bed89f9b2b439d7478b10622cc0dbafdb2e8705aa26571c78e0bf027bd543` | `4dc415b6542a4675d2d3f75a1f83e67d3879eaa0d4f28b118e48e6cb8fe52bec` |
| inline/4 | A16 A03 returned to Activity | `b2e6bbdddd3915aca8b15167a50a772b27482c82dd735e48da23b565fd36197b` | `8be9f67b3ad788618bd29036e22af68cfabd1ab34f511cfb70de459896dd0aea` |

## Stage binding

- `/private/tmp/a16-gallery-preview-6d-v1/stage-inventory.json` contains 55 path/hash entries; selected PNG/AX pairs above match original sealed archive files.
- The staged actual design-map A16 images and review gallery are provenance-bound through the selected manifest and inventory. This review does not assert repository installation or final build status.
