# A20 recommendation equipment redesign

Status: implementation plan; native and quality review pending. Base actual A19 merge `cc7ac2dae246317bd3a52d6621ed0d80b645e75d`.

## Scope and implementation

The sole private `RecommendationEquipmentSheet` lives in `SuggestedWorkoutSection.swift` and opens through Activity recommendation equipment information. Keep the original native List, all selectable equipment and their actual SVG icons, original order, Toggle bindings, Gym/Home context-specific store, `.other` exclusion and Done. Keep the deliberate fixed-English native navigation title policy. Move the existing at-least-one-equipment explanation from its footer into a shared opaque themed hero with a typed localized Gym/Home context heading. Register those two new manual English/Korean/Japanese keys and audit the existing description, gear labels and action. Use intrinsic sizing, flexible text and existing activity tint on native switches; no count/score/metric is invented.

No changes to recommendation logic, persisted defaults, constraints or the existing bodyweight fallback. The store reads missing/invalid/empty arrays as context defaults and sanitizes an empty saved set to bodyweight; the explanation does not mean the last tapped toggle stays on. Retain original callbacks and equipment model. Do not add redundant unit tests for unchanged storage logic.

Files: `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift`, `Shared/Resources/Localizable.xcstrings`, `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, target layout/theme maps and fresh actual captures. Refer to the existing recommendation filter/card UX solution and earlier native explanation capture solutions. The private draft is a proposal until applied and verified.

## Bounded validation

Preserve original normal selector `testVisualAuditRecommendationEquipmentInfo` and original initial capture/action. Add one closed Duo English dark maximum-text sibling. Five actual cases planned: four normal profiles (iPhone, iPad, Duo closed/open) plus closed MAX, four serial runs using one owned simulator at a time and current incremental cache. No all-locale or full local regression is required. Typed localized context headings and manual translations are audited statically; do not add a redundant locale run.

Assert the hero through a specific title identifier rather than a global Gym/Home title that also names the native navigation bar. Check native first/last gear labels and readable horizontal/text bounds with bounded scrolling, original explanation, native switch values, a reversible representative toggle with dismiss/reopen persistence and restoration, and Done return. Verify the alternate context heading through the real parent picker in normal cases and restore the original context; MAX covers its initial context. Context-key isolation and empty-set fallback are established by unchanged store source, not claimed as cross-context runtime storage tests. Do not disable every item or use real user data. A native List's table/view hierarchy and scroll offset must be observed rather than borrowed from explanation ScrollViews.

## Risks and release gates

MAX toggle labels and context hero may wrap; preserve full text and hit targets rather than shrink fonts. Gym/Home navigation remains English by established app policy while body/hero localize. Original layout and settings behavior must be source-reviewed independently, then real PNG/AX and interactions reviewed across the selected states. Archive/seal every native result before further runs/source edits, delete only owned unused devices, retain every failed attempt and use existing standing authorization for necessary corrective runs without questions.

Separate source, native visual, stage preservation and final publication reviews plus Compound and ordinary screen PR merge are required. Publish old/new comparison only after matching historical equipment-screen identity and fresh current captures; unknown historical source/device/pose remain explicitly unknown. Preserve all other map rows and board pixels. Final documentation-only publication must retain tested source pins. No completion or test pass is claimed by this plan.
