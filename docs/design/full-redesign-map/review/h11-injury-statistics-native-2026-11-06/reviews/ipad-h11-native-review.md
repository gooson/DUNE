# H11 iPad mini native review

**Scope:** Independent read-only inspection of the archived iPad mini (A20 Pro) English/Light, normal-text H11 Injury Statistics method at source `2d1656bb83a3a41ce02e1c41352769e0a867b032`. The H11 `testInjuryStatisticsRouteOpensFromHistory()` case **passed** (59.99 s). The four-case archive is **partial failed**: three passed and the separate H10 detail case failed at `WellnessRegressionTests.swift:600`. This report does not promote the aggregate to a pass. The selected H11 PNG/AX pairs and SHA-256 values are in [ipad-h11-native-review.json](ipad-h11-native-review.json).

## Finding

- **P3 — chart category names touch horizontal plot rules.** The `Shoulder` and `Knee` labels sit on the chart's upper/middle rules in the overview and frequency captures. Both labels, the two orange bars, their `1` counts, and `0–1` scale remain readable. The AX hierarchy exposes `Shoulder: 1`, `Knee: 1`, and separate chart rows with value `1`. This matches the previously observed H11 chart polish issue on Duo; no metric is hidden.

No P1/P2 native finding in the H11 iPad evidence.

## Evidence readback

| Named capture | Observation |
|---|---|
| H11 overview values | Total **2**, Active **1**, Avg Recovery **10d**, Longest **10d** appear in two columns. `Frequency by Body Part` and both bars fit below without horizontal clipping. AX has the four exact value IDs and values. |
| H11 frequency graph | Shoulder **1** and Knee **1** visible in text summary and chart. AX chart exposes each body part and value `1`; the chart frame is within the iPad viewport. |
| tap BackButton | Capture and AX show Injury History after the action. |
| before teardown | Injury History shows active Knee and recovered Shoulder; AX has `injury-history-screen` and both fixture row IDs, with no statistics screen. |

Labels and value tint remain legible on Light surfaces. Original native icons are present. The large blank area below the chart is the iPad viewport after this short content, not clipped content. This evidence does not establish H10 quality, MAX Dynamic Type, Dark appearance, other locales, VoiceOver traversal, or other devices. No app source, Root tracked file, simulator, build, or test was changed for this review.

**Archive:** `.codex-checks/batch01/evidence/ipad-2d1656bb-partial-failed/{execution-metadata.json,summary.json,tests.json,result.json,attachments/}`. The H11 attachment pairs were matched by name and UUID through read-only `xcresulttool get test-results activities` output.
