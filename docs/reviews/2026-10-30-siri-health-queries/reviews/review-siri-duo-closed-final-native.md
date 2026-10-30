# Siri health query: Duo closed native visual review

Reviewed 2026-10-30, read-only. Evidence: `.codex-checks/siri-duo-closed-complete-reviewed/manifest.json`, its 14-kind overview, and individual selector, period, hero, source, seeded-detail, and share PNGs. The manifest identifies owned Duo `40DF6CF9-5984-4137-84C0-2C2AE3E4CBD1` on iOS/Xcode 27.2, app source `adac0a30`, LCD1 1398 × 2034 px. Each individual capture is 1398 × 2034 px and reports a 466 × 678 pt viewport. These dimensions match the closed active LCD evidence. Images show the native app with synthetic DEBUG fixtures or seeded SwiftData records, not Siri system UI.

## P1/P2/P3 findings

No new P1 or P2 visual finding in the inspected closed-posture captures. The previously recorded **P3 top chart tick cutoff** remains visible in the SQ02/SQ13 duration chart when its top `3,000` tick enters the viewport. This affects the axis label, not the main values; the vertical `s` unit is visible.

## Physical image checks

- The 14-kind overview contains rendered query cards for SQ01–SQ14; it is not a black or blank placeholder. The selected kind and period are readable in the standard-size captures.
- At Accessibility XXXL, separate `SQ06-accessibility-body-selector` and `SQ01-accessibility-duration-selector` captures show the complete selected Information labels (`Latest body measurements`, `Latest workout`) inside their tall controls. Separate `*-period` captures show the complete `Last 30 days` label inside the period control. These are **different scroll positions**; no single image is used to claim that both controls and the hero fit in one 466 × 678 pt viewport.
- The separate hero captures show complete `68.4 kg` and `45:00` values within the 466 pt wide native window. The scroll crop above and below them is intentional continuation, not evidence of internal clipping. The final maxAX test reportedly passed in 182.340 s.
- `SQ01-period-source` visibly shows `Last 7 days`, the Oct 24–30 range, `45:00`, and the workout units. Its bottom source block lies below that screenshot and is not visually certified by this frame alone. The test asserted the source element before the period change; the artifact set's source notices elsewhere identify synthetic records.
- `SQ01-back-to-qa` shows the Health Q&A return screen. It presents an Apple Intelligence hardware-availability message on this simulator, while Browse records remains available. This is not evidence that Siri was invoked.
- `SQ03-seeded-record-detail` shows three `60 kg × 10` sets in the native detail; `SQ03-seeded-record-return` shows the Strength sets result and `DUNE record` source again. This supports the seeded local record route and back navigation, not live HealthKit content.
- `SQ13-report-preview` shows statistics plus the explicit body-measurement/personal-note exclusion notice; `SQ13-report-share` shows an iOS share panel with `Workout Report`, Copy, and Save to Files. The panel is visibly open. The passed test supplies the dismissal/return assertion; a still frame cannot prove the subsequent tap path.

All six unique closed-Duo UI cases were reported passing across the initial run and bounded retries: Browse with period/source/back, all 14 kinds, no data, maxAX, seeded record/back, and share cancel. This review did not run them. VoiceOver order, real Siri speech, personal HealthKit data, and open-posture behavior are outside these closed-LCD captures. The separate iPad picker finding remains governed by fresh post-fix iPad evidence.
