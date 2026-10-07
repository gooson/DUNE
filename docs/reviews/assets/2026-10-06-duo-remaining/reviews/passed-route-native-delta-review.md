# Passed-route native UX delta review — Book, max AX

Inspected the specified active PNGs once, using their hierarchy snapshots and `captures.tsv` to distinguish interior overlap from normal scroll-edge cutoff.

- **Injury edit form (`005`) and saved detail (`006`)**: `005` is the actual Edit Injury form. The selected Minor severity icon ends at x108.0; its description begins at x124.7 (16.7 pt gap). The `Minor` title ends at y576.7 and description begins at y578.7 (2.0 pt gap). The visible form has no icon/text collision; lower text continues beyond the viewport normally. In saved detail `006`, `Minor` and its description also remain separate (2.1 pt vertical hierarchy gap). These captures support the specific prior overlap fix, not every form state.
- **Readiness (`006–011`) / Wellness (`015–018`)**: Shared Score Composition titles, weights, bars, and scores remain whole in the inspected viewports (Readiness 54/82/82/82/55; Wellness 99/90/75; remaining rows available by scrolling). No new clipping within those cards. This does not establish the initial nil Condition consumer or other states.
- **Weather (`003`)**: The visible upper detail has whole `21°C`, `Clear`, `Seoul`, Best Time `10PM`/`100`/`18°C`, and outdoor-score text without interior clipping. Lower weather content is outside this capture.
- **Morning Briefing (`002–008`)**: The sheet scrolls through full cards; its changing top/bottom cutoffs are normal viewport boundaries. The date fix is not directly verifiable from these visible crops.

**Actionable P2 — Morning Briefing weather card icon/title overlap.** In `004–007`, the `cloud.sun.fill` symbol visibly crosses the beginning of `Clear 21°` inside the card. At `005`, the symbol frame is x17.7–100.4 and title starts x76.0, a 24.4 pt overlap. Resize the leading icon allocation with Dynamic Type or separate it from the title, then recapture this card.

**Additional observed P2 — Readiness/Wellness preceding Sleep Duration chart y-axis labels overlap.** In `006–008` and `015–018`, multiple right-side tick values (`6.5`–`8.5`) draw on top of each other within the chart. Both consumers instantiate `SubScoreTrendChartView(title: "Sleep Duration")` in `TrainingReadinessDetailView.swift:139` and `WellnessScoreDetailView.swift:145`. The shared chart in `Activity/TrainingReadiness/Components/SubScoreTrendChartView.swift` uses a fixed `.frame(height: 120).clipped()` near line 47 and has no explicit `.chartYAxis` tick policy. The native overlap is confirmed; the exact layout cause needs a targeted fix/recapture. This is outside the Score Composition card and is not scroll cutoff.

No VoiceOver speech, other poses, lower Weather content, or full Injury form-state coverage is claimed.
