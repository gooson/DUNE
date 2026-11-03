# A15 fatigue calculation explanation redesign

Base: ed9458c1. A15 is `FatigueAlgorithmSheet`, opened from the recovery map info button and legend; A14 is the distinct per-muscle `FatigueInfoSheet`. The prototype is a design proposal, not runtime evidence.

## Contract

Keep the existing large native sheet, scroll and drag dismissal, original title/function symbol, 14-day overview, exact decay formula, corrected effective τ formula and existing sleep and biometric examples, ten level descriptions and legend. Group the existing explanation into readable cards, using the existing opaque adaptive hero palette; no invented measurements, denominator, navigation, or health claims. Keep formula and values as source text, not sample health data. Text must wrap at accessibility sizes. No domain, calculation, catalog or A14 change.

## Verification pending

Run the original `ActivityExerciseRegressionTests/testVisualAuditRecoveryAlgorithmExplanation` with actual Phone, iPad and Duo closed/open captures and a relevant MAX/Dark case. Inspect full formula, all sections, example values, all levels and legend, scrolling and dismissal, as well as AX hierarchy and contrast. Source preparation is not a build, native run or actual-map update. Fresh A15 actual-map captures and independent reviews remain required.

The former τ size examples were recovery-hour inputs, not effective τ; the displayed equation now matches the bounded service calculation. The normal/MAX selector checks formula, effective τ, all ten level descriptions, legend presence, scroll and native dismissal; compilation and execution remain pending.
