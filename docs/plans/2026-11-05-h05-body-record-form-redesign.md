---
topic: H05 body record form
date: 2026-11-05
status: completed
---

# H05 · Body record Form

**Binding:** H04 is merged at clean `103ecfd15d8cff8263e8c351e46d7f510f2cef2f`; its tree is byte-identical to preparation `b8e03ed4e57ac2246f759f583fe220fad2ff79d5`. Form SHA-256 is `7aec9585bd2335c3a94fba720139cceff9be199f496f4673ab6b4c74721fc6b1`; test SHA-256 is `40b9bb21e1cd82edc50ddf9d54fe8b4134402e3af077276175c33656175bdd91`.

## Scope

The same `BodyCompositionFormSheet` serves Wellness add and Body History edit under H05. H06 remains the separate Body History screen; using its edit route does not complete H06. Keep the native `NavigationStack`/`Form`, Date & Time future-date limit, optional Weight (kg), Body Fat (%), Muscle Mass (kg), memo, numeric keyboard and Clear Input/Done, validation/error display, fixed Cancel/Save, Save disabled until a measurement, save/dismiss/success feedback, existing AX identifiers, caller create/update behavior and HealthKit synchronization. Preserve Weight `scalemass.fill`, Body Fat `percent`, and Muscle Mass `figure.strengthtraining.traditional`. No Watch H05, model, query, unit, or localization/catalog change is planned.

First add the seven scoped H05 layout/theme map outputs listed below. The dedicated layout contract and static DUNE prototype describe add/edit, keyboard, lower fields and MAX scrolling. Their sample values are illustrative, not native evidence. The new H05 map entries append to current H04 layout/theme index and manifest without changing H04 entries. The five existing map baselines now match the merged base exactly; the two new H05 files are absent. The private theme builder and `--check` passed. Run the theme builder check again on the final installed map.

Implement only the three header replacements in `DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift`: the three existing localized measurement section headers become a small shared `Label` helper. Header text uses `DS.Color.textSecondary`, while only the existing category icon uses its theme color and is hidden from AX. Inputs, validation, actions and layout containers remain unchanged. Update only `DUNEUITests/Full/WellnessRegressionTests.swift` with the reviewed capture additions; it adds four factual `VisualAudit.capture` calls to existing add/edit flows. It adds no assertions: the unchanged empty-form Save attempt/form-stays-visible and filled save/history assertions retain the functional gate. The current H04 methods and helpers are byte-identical in the private patched test candidate. The previously reviewed header and capture hunks are unchanged. Both patches pass `git apply --check` against the clean merged base; the private patched UI candidate preserves all H04 methods and helpers byte-for-byte.

## Focused native gate

Use the existing owned simulator runner, lock and deadlines with one device at a time. Run `DUNEUITests/WellnessRegressionTests/testBodyAddFlowSavesRecord` on iPad then regular iPhone, reusing the current generic iOS SDK cache where valid. Run that same add selector plus `testBodyHistoryEditAndSaveAtMaximumAccessibilityTextSize` on one closed Duo, then the add selector on the same Duo open: **five cases in four sequential UI runs**. No automatic extra normal edit selector, unit suite, full Vision, or Watch gate follows from these header-only changes. Capture fresh paired PNG/AX for the observed empty form after a Save attempt, filled Weight before save, saved history, populated MAX edit, lower fields, keyboard dismissal and saved return as the flows actually reach them. The unchanged Save disabled predicate is source-reviewed; the captures must record actual button state if visible and must not be labeled as new assertion proof. Do not infer an error state that the tests do not produce.

For each newly owned input simulator, check hardware keyboard disconnection and visible software keyboard as the `.codex/ui-execution.md` form-input prerequisite. A successful `typeText` alone does not establish software-keyboard visibility; check actual before/after focus PNG and AX within the planned case rather than adding a separate probe or generic helper edit. Record fresh PNG and keyboard AX on the owned UID when the field is focused, and keep keyboard environment proof separate from form/save test outcomes. The prior user-confirmed keyboard setting is context, not automatic proof for new H05 devices.

After reviewed native results, replace the four H05 actual-map images from their respective source-pinned device captures, update only H05 map rows/boards and add a native review gallery. The four existing H05 PNGs are historical identity references without paired current-source AX. Any unobserved state stays labeled unverified.

## Files and risks

The app/test files above, this plan, and these seven design outputs are the implementation allowlist:

- `docs/design/layout-map/body-record-form-h05.html`
- `docs/design/theme-map/themes/dune-body-record-form-h05.html`
- `docs/design/layout-map/index.html`
- `docs/design/layout-map/README.md`
- `docs/design/theme-map/manifest.json`
- `docs/design/theme-map/README.md`
- `docs/design/theme-map/index.html`

Actual H05 native images, capture metadata, four H05 map cards/boards, and a separate evidence gallery follow only after observed device results. Historical images are not matched-source before proof. Header wrapping/contrast and icon visibility need actual MAX/lower-field captures. The decorative image must not replace the localized label or alter input/Save ownership. Verify software keyboard from focused PNG and AX before classifying input failures. The related existing TODO `todos/done/070-done-p2-e2e-dune-body-composition-form-sheet.md` already records the unchanged entry/AX contract; it is not a new incomplete task.

## Native result and publication

The shared Form headers were implemented at `42a1b774`; a reviewed one-line normal Add keyboard Done interaction followed at `d8fca250`. The app SHA remained `735641ce268afe852e8564a7e2ddf1b16ef3d4e872c13941544cbd14e2c51c5d`; final UI test SHA is `4d4f499d6ec070e4ed8187d594d6f72112272c5725fa75c1c5cf0b8828d9e7ed`. Five effective existing cases passed: phone Add, iPad Add, Duo closed Add/MAX Edit and Duo open Add. The first iPad attempt remains failed, so historical execution is six cases: five passed and one failed. Eighteen selected original PNG/AX pairs were independently reviewed; the 62-output H05-only native map/gallery stage was independently approved. All 111 card IDs per tier and other screens' board pixels are preserved.

The iPad original Save tap computed {-1,-1}. Its later Done tap did not prove dismissal, although Save and history then passed. Phone and open Duo post-Done captures show dismissal. Actual archive provenance is Xcode 27.2 (27B52); original pipeline labels using 27.1 remain untouched with an additive metadata correction. English/default Add on all four profiles and closed MAX Edit were observed; dark, all locales, VoiceOver, live HealthKit, MAX Add and open MAX were not run. Model/query/validation paths are unchanged, so no extra unit/full/Watch/Vision suite is required.

See [native review gallery](../design/full-redesign-map/review/h05-body-record-native-2026-11-05/index.html) and [solution](../solutions/testing/2026-11-05-native-form-metric-headers-and-keyboard-evidence.md). The actual map now uses new source-pinned Add images for all four tiers. Old images remain historical identity only. All three owned devices were deleted after evidence preservation; reusable build cache is retained for the next authorized screen.
