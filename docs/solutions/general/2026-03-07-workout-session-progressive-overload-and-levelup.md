---
tags: [workout, progression, level-up, viewmodel, testing]
date: 2026-03-07
category: solution
status: implemented
---

# Workout Session에서 절차 재현 + 중량 증가 + 레벨업 판정 통합

## Problem

`WorkoutSessionView`/`WorkoutSessionViewModel`는 이전 세트 복원 기능은 있었지만, 다음이 부족했다.

1. 세트 완료 직후 다음 세트 중량을 자동으로 점진 증가시키는 규칙
2. 전체 세트 달성 기반 레벨업 추천 판정
3. 위 로직을 보호하는 단위 테스트

그 결과 사용자가 매 세션 수동으로 중량을 조정해야 했고, 목표 달성 후 다음 행동(레벨업 인지)이 일관되지 않았다.

## Solution

### 1) ViewModel에 progression 정책 추가

- `applyProgressiveOverloadForNextSet(afterCompletingSetAt:)` 추가
- 조건:
  - 현재/다음 세트 인덱스 유효
  - 현재 세트 중량/반복 수 유효
  - 현재 reps가 target reps 이상
- 증가 규칙:
  - 하체 복합(primary muscle 기준): +5.0kg
  - 덤벨/보조 계열: +1.0kg
  - 기본: +2.5kg
- 안전장치:
  - 증가폭은 현재 중량의 10%를 상한으로 clamp
  - plate step 반올림 적용

### 2) 레벨업 판정 API 추가

- `shouldSuggestLevelUp()` 추가
- 조건:
  - planned set 전부 완료
  - set별 reps 달성률 >= 90%

### 3) 실제 세트 완료 흐름 연결

- `WorkoutSessionView.completeCurrentSet()`에서
  세트 완료 직후 `applyProgressiveOverloadForNextSet` 호출

### 4) 테스트 보강

`WorkoutSessionViewModelTests`에 신규 케이스 추가:
- target 달성 시 중량 증가
- 미달성 시 동결
- 경량에서 10% 상한 적용
- all sets 완료 시 레벨업 true
- 부분 완료 시 레벨업 false

## Prevention

- 점진 증가식 변경 시 항상 테스트에
  - 증가/동결/상한 시나리오를 함께 추가
- 세트 완료 시점 로직은 View가 아닌 ViewModel API를 통해서만 실행
- 레벨업 기준값 변경 시 문서/테스트를 동시에 갱신
