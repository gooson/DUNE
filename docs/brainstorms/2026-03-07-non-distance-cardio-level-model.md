---
tags: [cardio, stair-climber, elliptical, watch, level, intensity]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: 비거리 유산소의 레벨 기반 세션 모델

## Problem Statement

현재 스텝 클라이머와 일부 머신 유산소가 여전히 `sets / reps / weight` 중심 사고방식의 영향을 받고 있다.
이 구조는 Apple Watch 중심 유산소 세션 UX와 맞지 않으며, 특히 Stair Climber에서 다음 문제가 발생한다.

1. 스텝 클라이머가 유산소임에도 세트 기반 입력 흐름으로 빠질 수 있다
2. 시간은 세션이 자동 측정해야 하는데 수동 입력 개념이 남아 있다
3. `floors`를 핵심 입력으로 다루지만, 실제 사용자가 조절하는 값은 머신의 `level`이다
4. 칼로리 추정과 강도 해석이 `level`이 아닌 부정확한 기본값 또는 우회 필드에 의존한다
5. 기록 후 히스토리에서도 `reps` 같은 근력 운동 용어가 재사용될 수 있다

핵심 문제는 Stair Climber를 포함한 비거리 유산소를 “세트 운동”이 아니라 “단일 cardio session”으로 모델링하지 못한 점이다.

## Target Users

- Apple Watch로 실시간 운동을 기록하는 사용자
- Stair Climber, Elliptical 등 머신 유산소를 자주 사용하는 사용자
- 시간은 자동 측정되고, 머신 강도만 빠르게 입력/조절하길 원하는 사용자

## Success Criteria

1. Stair Climber 시작 시 세트 기반 화면이 아니라 cardio live session으로 진입한다
2. 세션 시간은 Apple Watch에서 자동 측정되며 수동 분 입력이 없다
3. 사용자는 세션 중 `level`을 입력하거나 변경할 수 있다
4. 칼로리 및 강도 추정은 time-weighted level 데이터를 사용한다
5. `sets / reps / default sets / body weight 입력`이 비거리 유산소의 핵심 UX에서 제거된다
6. Stair Climber뿐 아니라 Elliptical 등 유사한 비거리 유산소도 동일 원칙으로 처리된다

## Current State

### 이미 존재하는 것

- `stair-climber`는 exercise library에서 `cardio` + `durationDistance`로 정의됨
- `cardioSecondaryUnit` 개념이 있어 비거리/비반복 cardio 모델을 일부 구분 중
- Watch/iOS cardio session 흐름과 live metric 수집 기반이 이미 존재함

### 구조적 문제

- cardio 시작 분기가 “cardio 전체”가 아니라 “distance-based cardio” 쪽으로 기울어져 있음
- Stair Climber는 `floors`를 `WorkoutSet.reps`에 재사용하는 구조가 남아 있음
- history/summary 계층에서 cardio용 의미가 아닌 `reps`, `sets` 용어가 새어 나올 수 있음
- `Body Weight`는 사용자 입력 필드처럼 보일 수 있지만 실제로는 칼로리 추정용 전역 기본값임

## Proposed Approach

### 1. 비거리 유산소를 단일 cardio session으로 통일

- Stair Climber, Elliptical 등 비거리 머신 유산소는 세트 기반 `WorkoutSessionView`로 보내지 않는다
- 시작 즉시 cardio live session으로 진입한다
- 시간은 세션 lifecycle에서 자동 측정한다

### 2. 핵심 사용자 입력을 `level` 중심으로 재정의

- Stair Climber의 핵심 입력은 `floors`가 아니라 `level`
- `floors`는 자동 수집 가능한 보조 metric일 뿐, 필수 입력도 주 KPI도 아니다
- 비거리 유산소는 운동별로 machine intensity field를 노출한다
  - Stair Climber: `level`
  - Elliptical 등: 동일 원칙으로 `level` 또는 `resistance` 성격의 intensity 입력

### 3. level 변화 이력을 세션 데이터로 저장

- 단일 고정 level만 저장하면 실제 운동 강도와 어긋날 수 있다
- 세션 중 level 변경 이벤트를 기록하고, 시간 가중 평균으로 강도를 계산한다
- MVP 저장 후보:
  - current level
  - average level
  - max level
  - level timeline or level change events

### 4. calorie estimation을 level 기반으로 조정

- 비거리 유산소는 기본 MET에 고정하지 않는다
- session duration + time-weighted level로 adjusted MET를 계산한다
- Stair Climber 전용 보정 로직을 cardio session 계층으로 이동하고, 비거리 유산소 공통 패턴으로 일반화한다

### 5. cardio와 strength의 표시 언어를 분리

- 비거리 유산소에서 `sets`, `reps`, `Total Reps` 같은 strength 용어를 사용하지 않는다
- history, summary, detail은 다음 축으로 표시한다
  - elapsed time
  - average level
  - max level
  - estimated calories
  - optional secondary metrics (`floors`, steps, elevation 등)

## Constraints

- 주 사용 흐름은 Apple Watch이므로 watch UX가 source of truth여야 한다
- machine level은 HealthKit 표준 metric이 아니므로 앱 자체 저장 모델이 필요하다
- 다른 쓰레드에서 동일 운동 merge 작업이 진행 중이므로 exercise identifier/merge 전략과 충돌하지 않게 분리 설계해야 한다
- 기존 `floors -> reps` 재사용 구조가 남아 있어 history/analytics 영향 범위를 함께 검토해야 한다

## Edge Cases

- 사용자가 level을 한 번도 입력하지 않은 세션: 기본 MET로 fallback하되 “approximate” 성격 유지
- 사용자가 세션 중 여러 번 level을 변경한 경우: 마지막 값이 아니라 시간 가중 평균 사용
- 기기/운동마다 `level` 대신 `resistance`만 있는 경우: 공통 intensity abstraction 필요
- Apple Watch에서 `floorsAscended`가 잡혀도 Stair Climber 핵심 UX를 그 값에 의존하지 않는다
- 과거 기록은 `reps/floors` 기반일 수 있으므로 read path 호환이 필요하다

## Scope

### MVP (Must-have)

- [ ] Stair Climber를 세트 기반 입력 플로우에서 제거
- [ ] 비거리 유산소를 cardio session flow로 통일
- [ ] Apple Watch 세션에서 level 입력/변경 UI 추가
- [ ] level 기반 calorie estimation 도입
- [ ] Stair Climber의 `floors` 사용자 입력 제거
- [ ] history/summary에서 strength 용어 누수 제거
- [ ] Elliptical 등 유사 비거리 유산소에 동일 원칙 적용

### Nice-to-have (Future)

- [ ] iPhone에서 세션 후 level timeline 편집
- [ ] machine별 intensity 타입 세분화 (`level`, `resistance`, `incline`, `watts`)
- [ ] level 기반 personal record / workout insights
- [ ] 과거 cardio 기록 migration 또는 재해석 도구

## Open Questions

1. MVP에서 `level`과 `resistance`를 하나의 공통 필드로 시작할지, 운동별 타입을 처음부터 분리할지
2. 기존 Stair Climber 과거 기록의 `floors/reps` 표시는 그대로 둘지, cardio-friendly label로 재해석할지
3. Watch 세션 중 level 변경 입력 UI를 Crown/stepper/buttons 중 어떤 방식으로 둘지

## Notes

- 2026-03-03의 `stair-climber-flights-tracking` 방향은 “floors 표시 강화”가 중심이었다
- 이번 방향은 그보다 상위 개념으로, Stair Climber를 `floors input` 운동이 아니라 `level-based cardio session`으로 다시 정의한다

## Next Steps

- [ ] `/plan non-distance-cardio-level-model` 로 구현 계획 생성
