---
source: brainstorm/pr-visual-enhancement
priority: p3
status: pending
created: 2026-03-29
updated: 2026-03-29
---

# Sparkline Tap Interaction

## Description

PR 섹션 카드 내 스파크라인 탭 시 해당 Kind로 상세 진입 + 차트 포커스. 현재 스파크라인은 표시만 되고 인터랙션 없음.

## Scope

- 스파크라인 영역에 탭 제스처 추가
- 탭 시 해당 Kind를 pre-select하여 PersonalRecordsDetailView 진입
- Detail view에서 해당 Kind의 차트가 즉시 표시

## Related

- `MiniSparklineView.swift` — 현재 `accessibilityHidden(true)`
- `PersonalRecordsSection.swift` — 스파크라인 탭 핸들러 추가 위치
