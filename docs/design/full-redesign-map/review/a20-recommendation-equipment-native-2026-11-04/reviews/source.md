# A20 final net source review

Base `cc7ac2dae246317bd3a52d6621ed0d80b645e75d`; clean HEAD `52dfe9b909c48c183d6412efdce8a16d2e54df0e`. Net app/UI test/catalog diff SHA256 `8f2f3ab381ae588ae440dc6df5553144130cf6cdfa519a0c2deed3c7a881a4d4`; `git diff --check` passes. The nine current source/consumer/catalog/project/runner pins are exactly those in `/private/tmp/a20-native-execution/manifest-52dfe9b9.json` SHA256 `9f6b12d5afff23e36a59e6cdb50f2135356481bd9291fa3c1870747f3606ffc8`:

| Path | SHA256 |
| --- | --- |
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | `42b7a5708161df2599caf4b994b3f4cd0f8f24d2b3061dd39759ed206c0338cc` |
| `DUNE/Presentation/Activity/ActivityView.swift` | `9f985b8a15aff300eae065162153060d2c5e8e7cba54213035b0bc5d2ba01cc2` |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | `77b5cbf7952c94182447cddac3c16ef9bc277a67b5c4d32bf03e47edd57189b5` |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | `cffdf67519a59a85be313f664bee19ec3a84c9234510813eff621f702548f87f` |
| `Shared/Resources/Localizable.xcstrings` | `cd1dd17796bf5be4f8888e2826214c82bb775bc6f8717125cc4a5d9155732ae1` |
| `DUNE/project.yml` | `abb3fc5181d069908878fff5d14ffe3347318cd42ba5fde8bc08ed92bf752a52` |
| `scripts/test-ui.sh` | `2289203358eebb3bd32522b731623103925c11bfffda65b273e55f0a02a54d59` |
| `scripts/duo-visual-audit.py` | `c5f6140dad478b2fcac58d161bde88354311725edd64eeffcf790f40e5fc3425` |
| `scripts/codex-pipeline.py` | `2d12b83aefb64bf03ecb4551faf00dff9be3f71667bf243f33d4390192bda53c` |

**Open findings: P1 0, P2 0, P3 0.** This is source review only, not a five-case native or publication pass. The current MAX result reported by the owner is not treated as completion of the still-running normal/profile matrix.

## Perspectives

- **Security:** No new external input, permission, network, persistence or data export path. The accessibility ID interpolates a closed `Equipment` enum raw value; the sheet retains the native button, Toggle and dismiss callback.
- **Data integrity:** The ActivityView/ActivityViewModel/settings-store producer paths are byte unchanged. Every original selectable equipment case except `.other`, original SVG row labels, bound availability callbacks, context-specific storage and existing empty-set/bodyweight fallback are preserved. The explanation text moved verbatim from the footer into the hero; it does not claim that the last tapped switch must stay on. No workout/recommendation computation or migration changed.
- **Architecture:** A private presentation view adds theme, color scheme and dynamic type environments, plus a small `equipmentOverview`; no new model/service layer, shared state or alternate navigation owner. The final net component is the original native `NavigationStack`/`List`/`.primaryAction` toolbar ownership, after the speculative stable-wrapper change was reverted.
- **Performance:** `AnyLayout` branches on dynamic type and renders a fixed small set of rows. There is no new data fetch, sorting, repeated persistent lookup beyond the original Toggle bindings or unbounded app loop. UI test scroll loops are bounded and run only in scoped selectors.
- **Simplicity:** The hero reuses the existing palette and design spacing. The two new stable IDs serve title/row selection without replacing visible labels. Test helpers are local to two selectors, with one optional reverse List drag before actual native Done and no alternate dismissal or retry loop. The original canonical capture remains first.
- **SwiftUI/native UX:** At accessibility sizes the hero stacks icon and copy, preserving full text width and original icon; at regular sizes it uses the familiar horizontal layout. Opaque palette surface/border and the original native List/Toggle/Done remain. Source captures title, full explanation, first/last rows, real switch change/reopen/restore, and alternate Gym/Home heading. Native contrast, wrapping, AX, scrolling and dismissal are still subject to actual capture review. Apple's toolbar guidance permits scroll-dependent chrome; the 656 before-mutation AX sequence corrected the earlier restoration-only hypothesis. The final test checks a real Done after at most one reverse List gesture and retains sheet nonexistence/return assertions.
- **Test contract:** Exact full-label predicate, visible viewport/overlap checks, real child switch and value waits, original four normal profiles plus closed dark MAX, no font cap or fabricated persistence claim. The normal case verifies the alternate heading through the real context picker and restores it. The test does not claim to exercise separate storage across contexts.
- **Localization:** Net catalog change is exactly `Gym Equipment` and `Home Equipment`, both `manual` with English, Korean and Japanese values. The existing explanation key remains manual with Korean/Japanese translations; typed `LocalizedStringKey` is used for the new hero heading, while fixed-English navigation title policy remains intact. Catalog formatter/manual checks were reported earlier by the owner; this review checked the resulting JSON values, not a new formatter run.
- **Agent-native:** N/A. No `.claude` agents, skills or adapter configuration changed.

The A20 layout/theme maps and plan describe proposed/pending native captures, not completed pixels. Actual map replacement, visual review, and final quality/publication gates remain separate from this source result. No build, test, simulator or ROOT mutation was performed for this review.
