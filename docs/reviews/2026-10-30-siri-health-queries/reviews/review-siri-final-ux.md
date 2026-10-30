# Siri health queries — final Apple UX delta review

Scope: read-only static review of `cab56cc6` plus the bounded follow-up diff in `HealthQueryView`, `HealthQueryResultCard`, `HealthDataQASheet`, the shared string catalog, and the SQ scope table. No tests, simulator, Siri host, VoiceOver, or final native capture were run for this review. A generic iOS build passed at `cab56cc6`; 62 unit tests passed at `3999e507`. The parent is running a new generic build; its result is not claimed here.

## Current static verdict

**No remaining P1 or P2 Apple UX blocker found in the reviewed source delta.** The revised scope table explicitly grounds SQ05 in real distance/pace plus the existing record handoff, SQ08 in aggregate stage totals rather than an invented sequence, SQ12 in bounded literal memo highlighting, and SQ14 in one truthful read operation until service phase events exist. These are coherent source-level resolutions of the earlier proposal gaps. A native UI verdict remains pending.

### P3 — Chart descriptions and large-text behavior need native verification
`HealthQueryResultCard.swift:110-139` still gives each chart a generic “Chart of dated measurements” accessibility value instead of a concise trend or notable-value summary. The fixed 180-point chart, adaptive metric rows, sleep-stage bar and large hero values need large Dynamic Type and VoiceOver inspection. This is a verification target, not a measured clipping claim.

## Reconciliation of initial findings

| Initial finding | Final source disposition |
|---|---|
| P1 report notes before preview | **Resolved.** Report records are omitted from the card; the snippet omits report records; the share text includes metrics and limitations, not memos. Share-sheet behavior remains native-unverified. |
| P1 fourteen generic compositions | **Resolved within the revised native scope.** Kind-specific hero/comparison/ring work is joined by real cardio distance/pace, aggregate sleep stages, and bounded memo highlighting. SQ14 is a truthful single-operation progress state; phase events require a future service contract. The HTML direction is not claimed as fully implemented. |
| P2 full card in Siri snippet | **Resolved.** `HealthQueryIntent` uses the separate compact `HealthQuerySnippetView`, capped at three metrics with brief provenance. Siri host sizing and interaction remain native-unverified. |
| P2 routed period mismatch | **Resolved.** Representable incoming intervals select their period, actual custom intervals show “Custom period,” and absent intervals now select the Last 30 days fallback (`HealthQueryView.swift:19-28`). |
| P2 comparison basis/invalid values | **Resolved.** Comparable rows require finite current/previous values and show labels, dates and delta. Actual legibility remains native-unverified. |
| P2 long-analysis progress | **Resolved within the revised native scope.** “Reading health records...” reports the actual single operation and offers cancellation; no fabricated phases or ETA are shown. |
| P2 empty/unavailable/failure actions | **Resolved for the reviewed states.** Lock, no-data, invalid request, unavailable and cancellation are distinguished. Invalid request no longer offers an unchanged retry and instead shows a corrective summary (`HealthQueryView.swift:82-101`, `HealthQueryResultCard.swift:29-39`). |
| P3 large text/VoiceOver | **Partly source-resolved; native-unverified.** Adaptive metric/comparison rows, condition score/date, and the localized “Send question” label are present. Chart description and final reading/layout behavior remain pending. |

## Native approval

**Withheld.** The four initial UI tests failed because a parent accessibility identifier masked children; source placement was changed afterward. A retry never started because another worktree held the simulator lock for 60 seconds. Initial PNGs predate the final UI changes and cannot prove this revision. The new layout-map scope table points to the actual capture status and does not promote synthetic HTML to native evidence. Capture affected SQ states on the owned simulator, including large text, VoiceOver, report preview/share, and the Siri-hosted snippet, before claiming native UX approval.
