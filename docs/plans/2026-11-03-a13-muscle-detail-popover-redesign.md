# A13 Muscle Detail Popover redesign

Base `ed9458c1e5996e0040bd65241e8605c6f44805fd`; prototype `refs/codex/snapshots/f6123bb0dce51eb02ac8fecddbc9345965b70d50:docs/design/detail-redesign-map/manifest.json` A13 is a proposal with illustrative values and unsupported navigation/tabs. Source contract: `MuscleDetailPopover` is presented by Activity as a medium sheet and embedded inline by MuscleMapDetailView. Both must retain selected muscle and actual status. 3D remains disabled with implementation preserved.

## Change

Theme-aware opaque header uses original `muscle.iconName`, actual muscle name and fatigue status. Existing fatigue level, weekly set count, last training, conditional sleep modifier/base recovery, conditional calculation button and recommended exercise equipment symbols and names remain. Explicit no-data state is preserved. Sheet content scrolls within its existing medium detent for large text; inline layout remains parent-owned. Keep native sheet dismissal and calculation presentation. No model, 3D, menus or calculations change. Weekly volume has no target/denominator in this component: do not invent a progress percentage or mislabel a bar as a goal.

Files: `DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift`, narrowly scoped existing A13 UI selector if needed, linked layout/theme proposals. No catalog changes expected.

## Remaining validation

No builds/tests/simulators in source preparation. Run exact `ActivityExerciseRegressionTests/testVisualAuditMuscleDetailPopover` and relevant A03 inline selection/calculation selector with actual seeded data. Check first/scrolling content, each real status/value, original calculation and drag dismissal on affected Phone, iPad and Duo closed/open; exercise constrained closed-Duo MAX/Dark geometry and conditional no-data/base/compound states where supported. Fresh A13 actual-map captures and independent source/native reviews are required; historical images are not after captures. Risks: sheet ScrollView and selected inline container are both consumers; color contrast and large text require actual native review.

Source test scope: the existing Activity sheet selector and a new MAX/Dark selector share one helper covering selected chest/status, each seeded fatigue/volume/last-trained/sleep value, calculation visibility and native drag dismissal; the existing A03 2D-selection selector additionally checks the inline selected chest and values in its actual pane. Normal four-device sheet captures plus one relevant MAX profile and one A03 inline route avoid duplicating every consumer across all tiers. All new hierarchy, full-frame, drag and native behavior is unverified until actual execution.

## A12 integration before native validation

Merged actual A12 main `e1f4efa42c3253923c2405bc0a6bb612db7f9023`, preserving all published A12 comparisons, selected-sector behavior and original tests. The five documentation conflicts retain main plus the A13 proposal. A13 sheet and inline consumers remain separate native contracts. Use one closed-Duo Dark/MAX case as the constrained profile, normal captures on all four profiles, and the existing iPad inline/calculation flow; no full regression or duplicated MAX cases are requested.
