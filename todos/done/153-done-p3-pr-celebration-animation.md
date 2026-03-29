---
source: brainstorm/pr-visual-enhancement
priority: p3
status: pending
created: 2026-03-29
updated: 2026-03-29
---

# PR Celebration Animation

## Description

Level up / PR 달성 시 confetti + haptic 효과 추가 (Apple Fitness 스타일). 운동 완료 후 새 PR이나 레벨업이 감지되면 축하 애니메이션을 화면에 표시.

## Scope

- Confetti particle effect (Canvas 기반)
- Haptic feedback (UINotificationFeedbackGenerator)
- Level up 시 full-screen overlay
- PR 달성 시 inline toast animation

## Related

- `docs/brainstorms/2026-03-29-pr-visual-enhancement.md` — Future Work #1
- `RewardProgressSection.swift` — 레벨업 표시 위치
- `PersonalRecordsSection.swift` — PR 카드 NEW badge 위치
