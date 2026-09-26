---
tags: [fatigue, training-volume, regression, muscle-recovery]
category: general
date: 2026-09-26
status: implemented
severity: important
related_files:
  - DUNE/Domain/UseCases/FatigueCalculationService.swift
  - DUNETests/FatigueCalculationServiceTests.swift
---

# Solution: 근육 피로도 운동량 중복 계산 수정

## Problem

마지막 가슴 운동 6일 후에도 L10이 표시되었다. `ExerciseRecordSnapshot.totalWeight`는 이미 세트별 무게 × 반복 횟수의 합인데, `sessionLoad`가 총 반복 횟수를 다시 곱했다.

제보 기록에서 6,200 × 80 / 7,000 = 70.857, 5,600 × 72 / 7,000 = 57.6으로 화면의 최초 부하가 재현된다. 시간 경과 후 부하 합계 18.82는 가슴 임계값 12를 초과한다.

## Solution

`FatigueCalculationService`의 근력 부하는 합산 운동량 / 70 / 100으로 계산한다. 반복 횟수는 다시 곱하지 않는다. 유효한 합산 운동량은 반복 횟수가 누락되어도 사용하고, 무한대는 기존 세트 수 fallback으로 처리한다.

`FatigueCalculationServiceTests`에 제보된 두 운동의 세트별 기록, 반복 횟수 독립성, 비정상 운동량 검증을 추가했다. 기존 운동량 및 포화 테스트 입력도 snapshot 계약에 맞게 변경했다.

제보 시점과 유사한 경과 시간 및 수면 0.90, readiness 1.05에서 점수는 약 0.020이며 기존 모델의 L1에 해당한다. 회복 시간 상수와 등급 임계값 자체는 변경하지 않는다.

## Prevention

- 합산 필드는 생산자와 소비자 양쪽에서 단위를 확인한다.
- 실제 세트 데이터를 합산한 회귀 테스트를 유지한다.
- 동일 운동량에 반복 횟수만 바뀌어도 결과가 같음을 검증한다.

## Lessons Learned

필드명 `totalWeight`를 단일 중량으로 해석하면 이미 반영된 반복 횟수를 중복 적용할 수 있다. 테스트 데이터도 snapshot의 합산 운동량 계약을 따라야 한다.

## UI 회귀 검증

`fatigue-regression` 시나리오는 제보된 두 운동의 실제 세트 값을 독립된 테스트 저장소에 넣는다. 일반 mock 운동을 섞지 않고 실제 Activity snapshot 생성 및 계산 경로를 통과시킨다. `FatigueCalculationRegressionTests`는 가슴의 L1, 6일 전, 주간 10세트와 계산 화면의 0.9/0.8 부하, 최종 0.02를 검증하고 스크린샷을 남긴다.
