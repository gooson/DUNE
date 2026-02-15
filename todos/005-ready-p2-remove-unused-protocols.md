---
source: review/simplicity
priority: p2
status: ready
created: 2026-02-15
updated: 2026-02-15
---

# 미사용 Repository 프로토콜 정리

## Issue
`HealthDataRepository`, `BodyCompositionRepository` 프로토콜이 정의만 있고 구현/참조 없음.

## Files
- `Dailve/Domain/Repositories/HealthDataRepository.swift`
- `Dailve/Domain/Repositories/BodyCompositionRepository.swift`

## Fix
삭제하거나 구현체 추가. MVP에서는 삭제 권장.
