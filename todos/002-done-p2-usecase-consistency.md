---
source: review/architecture
priority: p2
status: ready
created: 2026-02-15
updated: 2026-02-15
---

# UseCase 패턴 일관적 적용

## Issue
컨디션 점수만 UseCase 패턴, 수면 점수는 SleepViewModel에 직접 구현. 일관성 부족.

## Files
- `Dailve/Presentation/Sleep/SleepViewModel.swift` (calculateSleepScore)
- `Dailve/Domain/UseCases/` (새 UseCase 추가)

## Fix
`CalculateSleepScoreUseCase` 추출하여 Domain/UseCases에 배치.
