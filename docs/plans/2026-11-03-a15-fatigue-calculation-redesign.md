# A15 fatigue calculation explanation redesign

Base: ed9458c1. A15 is `FatigueAlgorithmSheet`, opened from the recovery map info button and legend; A14 is the distinct per-muscle `FatigueInfoSheet`. The prototype is a design proposal, not runtime evidence.

## Contract

Keep the existing large native sheet, scroll and drag dismissal, original title/function symbol, 14-day overview, exact decay formula, corrected effective τ formula and existing sleep and biometric examples, ten level descriptions and legend. Group the existing explanation into readable cards, using the existing opaque adaptive hero palette; no invented measurements, denominator, navigation, or health claims. Keep formula and values as source text, not sample health data. Text must wrap at accessibility sizes. No domain, calculation or A14 implementation change. The explanatory τ catalog key is replaced with a manually localized en/ko/ja equation; its unused inaccurate predecessor is removed.

## Verification pending

Run the original `ActivityExerciseRegressionTests/testVisualAuditRecoveryAlgorithmExplanation` with actual Phone, iPad and Duo closed/open captures and a relevant MAX/Dark case. Inspect full formula, all sections, example values, all levels and legend, scrolling and dismissal, as well as AX hierarchy and contrast. Source preparation is not a build, native run or actual-map update. Fresh A15 actual-map captures and independent reviews remain required.

The former τ size examples were recovery-hour inputs, not effective τ; the displayed equation now matches the bounded service calculation. The normal/MAX selector checks formula, effective τ, all ten level descriptions, legend presence, scroll and native dismissal; compilation and execution remain pending.

## Current integration and necessary native scope

Actual A14 merge `cfe6970c72bcc14a20123c8b565dce09d1c4e589` is integrated at `99575779`; existing A12/A13/A14 app, tests, catalogs and actual maps remain. The current test delta adds explicit dark MAX, the complete effective-τ equation assertion, representative level captures while retaining all ten full-frame level checks, and actual native grabber dismissal. A new regular iPad A03 recovery-legend route checks the same generic sheet and native Back; it is distinct from A14's selected-muscle calculation.

The required matrix is four original normal cases (iPhone/iPad/folded/unfolded Duo), one folded dark Accessibility XXXL case, and one regular iPad recovery-legend consumer case. One owned device runs at a time and is archived/deleted before the next. No device or case is yet claimed to pass at this preparation stage; no unrelated full regression is added. All 29 helper-localized labels and the direct header text keys were checked against the catalog before execution.
