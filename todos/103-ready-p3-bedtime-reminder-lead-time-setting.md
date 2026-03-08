---
source: brainstorm/general-bedtime-reminder
priority: p3
status: ready
created: 2026-03-08
updated: 2026-03-08
---

# Bedtime reminder lead time setting

## Context

일반 취침 알림은 현재 평균 취침 시간 2시간 전으로 고정되어 있다.
사용자별 선호가 다르므로 이후에는 30분 / 1시간 / 2시간 중 직접 선택할 수 있어야 한다.

## Scope

- Settings에 리드 타임 선택 UI 추가
- 선택값 persistence 및 scheduler 반영
- 기존 기본값은 2시간 유지

## Done When

- [ ] 사용자가 리드 타임을 변경할 수 있다
- [ ] 변경 직후 pending bedtime reminder가 즉시 재스케줄된다
- [ ] 단위 테스트로 선택값별 trigger time이 검증된다
