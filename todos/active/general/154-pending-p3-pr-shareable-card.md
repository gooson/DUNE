---
source: brainstorm/pr-visual-enhancement
priority: p3
status: pending
created: 2026-03-29
updated: 2026-03-29
---

# Shareable PR Card

## Description

PR 달성 시 Instagram Stories용 이미지 자동 생성 (Hevy 스타일). `ImageRenderer`로 PR 데이터가 포함된 카드를 렌더링하고 공유 시트를 통해 내보내기.

## Scope

- `ImageRenderer` 기반 PR share card template
- Dark/light variant
- 운동 종류, PR 값, 날짜, 델타 표시
- UIActivityViewController 통합
- `ImageRenderer` explicit size 필수 (correction #209)

## Related

- `docs/brainstorms/2026-03-29-pr-visual-enhancement.md` — Future Work #2
- `WorkoutShareCard.swift` / `ShareImageSheet.swift` — 기존 share 패턴 참고
