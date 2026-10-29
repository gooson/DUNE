# Apple UX quality review — Workout Achievement Board

Scope: static read-only review of `WorkoutAchievementBoard.swift`, its `LifeView.swift` integration, and the selected **성과 보드** variant in `workout-achievement-fragment.html`. iPhone/iPad SwiftUI view only. No native build, simulator, VoiceOver, contrast measurement, or actual screen capture was performed. The browser design PNG is a proposal, not evidence of the native view.

## Counts after targeted delta check

- P1: 0
- Open: P2 0, P3 0
- Resolved in source: P2 3, P3 1
- Known issues excluded: >12-goal dot cap, adaptive strength grid at AX sizes, `weekDates` body recomputation.

## Resolved findings (static source check)

### P2 — Decorative running track becomes an extra VoiceOver stop

Resolved in source: `WorkoutAchievementBoard.swift:425` now hides the curve from accessibility. The numeric row remains a combined metric element (`:414–417`). Actual VoiceOver traversal is pending native validation.

### P2 — Identical action labels for multiple custom goals

Resolved in source: the board action closure now adds `More actions for \(progress.name)` as a localized accessibility label (`LifeView.swift:841–845`). The shared 44-point action button and native confirmation dialog remain. The string catalog has en, ko, and ja values (`%@ 더보기` in Korean).

### P2 — Custom-goal kicker drops the automatic-link meaning

Resolved in source: `WorkoutAchievementBoard.swift:225` now uses `My Goals · Today's workout records`; the catalog provides `내 목표 · 오늘 운동 기록 연동` and `マイ目標 · 今日の運動記録と連携`. This restores the selected prototype's automatic-link context without naming a specific sport.

### P3 — Section names lack header navigation semantics

Resolved in source: the board summary now carries `.isHeader` and starts its accessibility label with the localized title (`WorkoutAchievementBoard.swift:169–172`). The group title texts also carry `.isHeader` (`:287–290`). Native VoiceOver rotor order is pending validation.

## Eight-principle check

| Apple design principle | Static verdict | Evidence |
|---|---|---|
| Purpose | Conforms | Completion count and current metrics lead the card. |
| Agency | Conforms | Challenges can collapse; custom goal actions remain available. |
| Responsibility | Conforms in source | The custom-goal kicker identifies today's workout-record linkage. |
| Familiarity | Conforms | Native `Button` and confirmation dialog retain expected behavior. |
| Flexibility | Conforms in source, pending device check | Dynamic Type alternatives and the reviewed VoiceOver structure are present. |
| Simplicity | Conforms | Single board surface and progressive disclosure match the design contract. |
| Craft | Conforms in source, pending device check | Running art is decorative and board actions name their goal. |
| Delight | Conforms pending capture | Medal, terrain, and completion marks serve as decorative cues; visual fidelity and contrast remain unverified natively. |

## Verification boundary

The localized strings checked in `Shared/Resources/Localizable.xcstrings` have Korean and Japanese values for the board title, challenge title, source footer, principal metrics, revised custom-goal kicker, and goal-specific action label. Static code shows `.fixedSize` or `ViewThatFits` around several long labels and a 44-point action button. Actual light/dark contrast, 320-point clipping, iPad/Duo behavior, AX Dynamic Type layout, VoiceOver traversal, and reduce-motion behavior require native validation and were not asserted here.
