---
tags: [cumulative-stress, score-history, swiftdata, dynamic-type, contrast, native-evidence]
category: architecture
date: 2026-11-02
severity: important
related_files:
  - DUNE/Data/Services/ScoreRefreshService.swift
  - DUNE/Presentation/Dashboard/CumulativeStressDetailViewModel.swift
  - DUNE/Presentation/Dashboard/CumulativeStressDetailView.swift
  - DUNE/Presentation/Dashboard/Components/CumulativeStressLevelGuide.swift
  - DUNEUITests/Full/CumulativeStressDetailRedesignTests.swift
related_solutions:
  - 2026-04-05-cumulative-stress-detail-view.md
  - 2026-10-30-shared-score-history-contract.md
---

# Cumulative stress: consistent history, visible evidence and readable levels

## Problem

The detail needed a stronger score hero and clearer spacing without losing its original factor scores, symbols, explanations or period controls. A capped history read could omit recent records, while calendar summaries could disagree with the chart's visible interval. Current applied contribution shares also needed to remain distinct from the model's base weights.

Actual native review additionally found faint small interval labels: tertiary text combined with opacity on the entire inactive row. Merely asserting that an accessibility element existed did not prove that its glyphs were readable or unobscured by navigation material.

## Solution

| Area | Contract |
|---|---|
| History read | Complete half-open date slices of at most 31 days, cancellation checks, finite 0–100 values and deterministic newest-row-per-hour selection. No arbitrary replacement cap or database cleanup. |
| Visible statistics | Shared fixed-duration windows; hourly observations for day and original daily aggregates for longer periods. Summarize raw observations before plot bucketing. Missing observations remain missing. |
| Async state | Generation and cancellation checks prevent stale successes or failures replacing the newly selected period. Loading, empty and error remain distinct. |
| Factor presentation | Original symbols and raw scores, horizontal progress, display-only effective shares. Preserve the calculator and base 40/35/25 weights. |
| Explanation | One native disclosure contains the definition and three original factor explanations; current evidence stays visible separately. |
| Readability | Use the existing opaque `DS.Color.textSecondary` interval ink and remove whole-row fading. Preserve the original four ranges, symbols, guidance and current-level bold title/badge. |

The focused legend UI test reveals each combined row inside a viewport excluding native navigation/tab chrome, checks all four original ranges and the Moderate-only Current badge, and captures both light and dark appearances. Existing UI tests keep their original helper behavior by default.

## Verification and limits

Fresh iPhone checks cover the hero, original factors, five periods, paging, visible statistics, chart drag/selection, single disclosure, maximum accessibility text and dark appearance. The baseline six selectors passed before the two-style contrast fix; two follow-up selectors compiled and exercised the updated app. A separate Duo OPEN test then exposed all four guide ranges in both appearances: one selector passed, with 12 acknowledged paired host checkpoints. Actual sampled interval contrast was at least 6.097:1 in light and 11.184:1 in dark. These are scoped results, not a full suite or every theme/locale certification.

Native captures retain their actual validation commit. A combined validation checkout is not relabeled as the individual PR checkout. Source equality is checked for reused components. Historical before images are identified as historical: the iPad/folded fixture shows 9/Low while phone/open shows 42/Moderate, and some old displayed weights differ. They do not establish a product calculation change or identical inputs.

Four-device map completion and final shipping are recorded separately when their remaining gates close. The preexisting shared DotLine date-axis glyph issue remains open in TODO 158. The one approved animation-mask diagnosis was negative; its temporary change was restored. Functional test success does not resolve that visual defect.

## Prevention

- Keep base model weights and applied display shares explicitly separate.
- Derive summaries from the same half-open interval as the visible chart, before aggregation for plotting.
- Preserve original icon identity and explanation content while changing hierarchy.
- For small text, inspect actual solid glyph ink against the local material in both appearances; do not infer readability from an asset or AX existence alone.
- Exclude translucent navigation chrome when collecting a visibility proof.
- Store original result bundles, pose readback, PNG/AX pairs and failure history outside disposable worktrees. Check script execution permission before starting a native capture.
- Do not import diagnostic Python modules into tracked directories during a frozen run. A cache-only fingerprint warning still needs explicit, reproducible source closure; never rewrite it as a successful pipeline receipt.

## Lessons learned

A richer visual hierarchy can preserve existing behavior when each original datum and action has a traceable contract. Native execution, source equality and pixel review answer different questions; none substitutes for the others.
