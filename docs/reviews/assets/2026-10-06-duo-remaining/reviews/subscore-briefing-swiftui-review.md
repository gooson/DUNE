# Sub-score chart and Briefing icon: scoped static review

Reviewed current `SubScoreTrendChartView.swift`, Wellness's three card IDs, and `MorningBriefingView.swift`. No tests, build, GUI, simulator, source edit, or Git action.

**Actionable coverage finding:** `SubScoreTrendChartView` has a third direct consumer: `ConditionScoreDetailView.swift` instantiates HRV and RHR charts when its default period is `.week`. The proposed Wellness Closed and Readiness Book gates cover the two screens where overlapping Sleep ticks were observed, but they do not establish the shared change on Condition. Its existing composition-card test scrolls past charts without asserting their axes. Include a targeted Condition chart viewport check, or explicitly retain that consumer as unverified.

The chart source responds to the observed Sleep y-tick collision: at accessibility sizes it scales the chart height, uses three explicit y ticks, moves title/average onto separate rows, limits x labels to actual first/last dates with inward anchors, and clips the plot only so labels can extend outside it. Empty data and normal-size chart paths retain their prior behavior; y-domain and selection overlay calculations are unchanged. The Wellness HRV/RHR/Sleep identifiers are distinct within that screen. Native output remains necessary to verify tick spacing and endpoint labels.

The Briefing icon frame now scales relative to its `.title2` glyph from the same 32-point baseline, addressing the observed 24.4-point icon/title overlap. Text remains in a flexible VStack; normal width is unchanged. The queued Briefing capture must confirm the actual gap. Earlier valid composition-card and Injury observations do not certify these new chart/icon changes; no runtime or visual pass is claimed.
