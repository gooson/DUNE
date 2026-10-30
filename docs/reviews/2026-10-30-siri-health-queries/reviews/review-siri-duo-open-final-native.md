# Siri health query: Duo open native visual review

Reviewed 2026-10-30, read-only. Evidence: `.codex-checks/siri-open-final-before-displays.json` and the 29 PNGs, overview, and manifest in `.codex-checks/siri-open-host-complete-reviewed/`. The preflight identifies LCD-1 display 3 as the sole active display (backlight on), rotated to a 2853 × 2007 px landscape viewport; LCD display 1 is inactive. Every host capture is 2853 × 2007 px with a 951 × 669 pt native readback at 3× scale. Every manifest checkpoint is acknowledged and marked valid; a pixel-variation check also found no black/blank capture. Source is `485e50eb` on iOS/Xcode 27.2. This supports an **open-display capture**, without asserting a physical hinge angle.

## P1/P2/P3 findings

No new P1 or P2 visual finding in these captures. The previously recorded **P3 top chart tick cutoff** is still visible: the `3,000` y-axis label at the top of the workout-duration chart in `SQ13-report-preview` is partly cut at the plot boundary. The chart's vertical `s` unit and the primary duration values remain readable.

## Image observations and limits

- The 14-kind overview shows rendered SQ01–SQ14 native query panes alongside the Today pane; the captures are populated and legible at standard text size.
- In the Accessibility XXXL selector frames, `Latest body measurements` and `Latest workout` fit inside their respective Information controls. The body label wraps with a line-break hyphen (`measure-` / `ments`) but is not cropped within the control. In the separate period frames, `Last 30 days` fits inside the Period control. The control above it is partly behind the navigation bar in these scrolled frames; that is viewport continuation, not internal control clipping. These are separate positions, not a claim that both controls and the hero fit at once.
- The separate hero frames show the complete `68.4 kg` and `45:00` values inside the open query pane, including their value context. The sticky Health information navigation and back control remain visible.
- `SQ01-period-source` shows the selected `Last 7 days`, Oct 24–30 range, and `45:00`; its lower source block is outside this frame. `SQ01-back-to-qa` shows the Health Q&A return screen and Browse records control. Still images support these visible states, while the passed UI test supplies the route assertions.
- `SQ03-seeded-record-detail` shows three `60 kg` × `10 reps` sets. `SQ03-seeded-record-return` shows the result with `Open record` and a visible `DUNE record` source plus prepared/retrieved timestamps. The manifest correctly marks these as seeded SwiftData with the production query service; other query images use synthetic DEBUG fixtures.
- `SQ13-report-preview` shows the synthetic-data disclosure and body-measurement/personal-note exclusion notice. `SQ13-report-share` shows an iOS share panel for `Workout Report`, with Copy and Save to Files actions. A still image does not prove subsequent dismissal.

The parent reported all six unique open-Duo UI cases passing. This review did not run tests or operate the simulator. The images do not establish actual Siri speech/system UI, real personal HealthKit data, VoiceOver traversal, closed posture, or iPad picker behavior. The older black XCUI screenshot path is separate from these acknowledged host captures; fresh post-fix iPad photos are required before closing the iPad P2.
