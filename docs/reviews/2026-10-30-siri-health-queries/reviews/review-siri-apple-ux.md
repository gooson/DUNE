# Siri health queries — Apple UX static review

Scope: current working tree (`HealthQueryView.swift`, `HealthDataQASheet.swift`, `ContentView.swift`, `HealthQueryIntent.swift`) against `docs/design/layout-map/siri-health-queries-proposal.md` and the theme proposal. Read-only review; no native PNG, simulator, VoiceOver, or Siri host pass claimed.

## Findings

### P1 — Report result shows private notes before the scoped share preview
`DUNE/Presentation/HealthQuery/HealthQueryView.swift:402-449` renders `result.records` and each `record.memo` for every kind, including `.report`, before the report preview. `HealthQueryService+Workouts.swift:95-117` sends report records with memos, while its limitation says shared report excludes notes. The `ShareLink` payload at 536-540 excludes notes, so this is a display/privacy expectation mismatch, not an assertion that notes are shared. In Siri's compact host, SQ13's proposed report summary should show the included stats and explicit exclusion before offering the preview; keep detailed record/memo content out of the report card.

### P1 — Fourteen kinds are not represented by fourteen information-specific compositions
`DUNE/Presentation/HealthQuery/HealthQueryView.swift:342-533` uses one long generic card: first metric, remaining metrics, every series, every record, explanation, limitations, spoken answer, sources. `kindVisual` mostly changes a decorative SF Symbol; only condition has a ring and comparison has a two-value row. This falls short of SQ01–SQ14's information order and main visual differentiators (SQ05 route/distance, SQ08 sleep stages, SQ12 highlighted search context, SQ13 report preview, SQ14 phase state, etc.). Refine the existing result-content view per kind or a few kind families while preserving common provenance/status behavior. This is a contract/implementation mismatch, not a measured visual failure; native PNGs are still needed.

### P2 — Snippet includes the entire app detail card rather than a compact answer
`DUNE/App/Intents/HealthQueryIntent.swift:292-294` passes `HealthQueryResultCard` directly to the system-owned Siri snippet. That card can contain an unbounded-feeling chart/record stack, navigation links, an inline report preview/share action, and a duplicate full spoken answer (`HealthQueryView.swift:380-468`). The proposal separates answer, source, and optional detail. Provide a concise snippet content composition with key result, date/unit and provenance, then open in-app detail when needed. Do not recreate Siri chrome; system controls it. Actual host clipping/interaction behavior requires Siri capture.

### P2 — Period control can disagree with the result opened from Siri
`DUNE/Presentation/HealthQuery/HealthQueryView.swift:198-206,300-309` initializes `period` to `.last30Days` even when `request.interval` is set (for example a selected workout or requested week). The first load keeps the incoming interval, but the Picker still says Last 30 days, then a later kind/period selection replaces the interval. Align the displayed selection to the incoming period when representable, or show the exact requested interval separately and avoid a misleading selected value.

### P2 — Comparison visual hides its comparison basis and may show invalid values
`HealthQueryView.swift:502-516` renders the first two current metric values only, while `:355-377` places previous values as secondary text and omits previous dates for subsequent metrics. SQ07/SQ10/SQ11 require both periods/records and observed delta to be legible together. The visual also does not guard `metric.value.isFinite`, unlike the text list. Build a comparison layout from validated current/previous values, labels, dates and delta; keep uncertainty/limitations adjacent to the explanation.

### P2 — Long analysis has no phase-specific in-app progress
`HealthQueryView.swift:242-273` uses a single generic `Reading health records...` spinner and `Cancel analysis` for all kinds. SQ14 specifies actual query/aggregation/explanation stages and no invented ETA; the current app view never communicates which step is active. If service exposes real phase events, show those; otherwise label the operation truthfully as in progress without a fictional step. The Siri Intent's `progress` at `HealthQueryIntent.swift:167-176` is a one-step completion count and is distinct from this in-app state.

### P2 — Empty, unavailable and failure states do not give specific next actions
`HealthQueryView.swift:326-333` says only “No records found for this period” or “This information is unavailable”; `:268-274` offers a generic retry after any error. The proposal distinguishes successful empty results, lock, AI unavailable/offline/quota and cancelled states. Preserve the status source and explain a next action only when real (e.g. adjust period, unlock, open available records); avoid implying that retry will fix a permission/unsupported feature. This is especially relevant to natural Siri voice output and the project's UX writing rule on observed versus inferred state.

### P3 — Large text and VoiceOver reading order need native verification
`HealthQueryView.swift:345-378,384-400,502-516` uses horizontal metric rows, a fixed 180-point chart, and two side-by-side comparison tiles without a large Dynamic Type fallback or a textual chart summary. The condition ring has an explicit label, but charts have no explicit accessible trend/point summary and the metric may be announced twice. The Q&A send button at `HealthDataQASheet.swift:180-187` is icon-only without an explicit accessibility label. These are concrete verification targets; clipping, focus order and tap area cannot be certified from code alone.

## Native evidence pending

- Capture actual Siri-hosted content for SQ01–SQ14, plus lock/no data/partial/AI unavailable/cancelled states. Separate system Siri chrome from app-supplied snippet content.
- Capture in-app `HealthQueryView` on iPhone, Duo folded/unfolded and iPad where affected; include light/dark, large accessibility text, VoiceOver reading order, chart descriptions and share-sheet preview.
- Capture the Q&A sheet and navigation path from `ContentView.swift:342-349` and `HealthDataQASheet.swift:13-40`, including medium/large detents and Back/Done behavior. Static code shows a native `NavigationStack` and system sheet; no custom Siri shell was found.
- Validate Korean Siri utterances and spoken summaries on device. The HTML proposal PNGs are synthetic browser renders and cannot establish native visual compliance.

## Eight Apple design principles, static verdict

Purpose: partial (result-first hierarchy varies by kind). Agency: partial (record open, preview and cancel exist; compact snippet needs detail handoff). Responsibility: concern (report notes visible despite exclusion copy). Familiarity: partial (native sheet/navigation, system Siri shell retained). Flexibility: pending native large text/VoiceOver/device checks. Simplicity: concern (long generic snippet stack). Craft: pending native PNG and behavior check. Delight: partial (some meaningful ring/medal, most kinds use decorative symbols only).
