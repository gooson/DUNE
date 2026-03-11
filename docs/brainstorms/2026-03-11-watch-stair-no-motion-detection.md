---
tags: [watch, cardio, stair-climber, motion-detection, inactivity]
date: 2026-03-11
category: brainstorm
status: draft
---

# Brainstorm: 천국의 계단 손목 고정 시 무움직임 오탐 방지

## Problem Statement

Apple Watch 유산소 세션에서 `천국의 계단`(stair climber) 운동 중 손목이 고정되면,
실제로 운동을 계속하고 있어도 `No movement detected` 알림이 뜰 수 있다.

현재 `DUNEWatch/Managers/WorkoutManager.swift`의 무움직임 판정은
`distance` 또는 `steps` 증가만 motion 신호로 사용한다.
이 방식은 손목 스윙 기반 step detection이 약한 stair/machine cardio에 불리하다.

## Target Users

- Apple Watch로 stair climber를 기록하는 사용자
- 손잡이를 잡거나 손목 움직임이 적은 상태로 machine cardio를 수행하는 사용자
- 세션 자동 종료 추천의 오탐에 민감한 사용자

## Success Criteria

1. stair climber 수행 중 손목이 거의 움직이지 않아도 false positive no-motion prompt가 크게 줄어든다.
2. 실제로 운동을 멈췄을 때는 기존 종료 추천 UX가 완전히 무력화되지 않는다.
3. 러닝/걷기 같은 distance cardio의 현재 동작은 불필요하게 흔들리지 않는다.
4. 변경 기준을 Swift Testing으로 고정할 수 있다.

## Current State

- 무움직임 판정: `distance > lastObservedDistance || steps > lastObservedSteps`
- stair 관련 live metric: `floorsClimbed`
- machine cardio 보조 신호 후보: `activeCalories`, `heartRate`
- 관련 UX copy:
  - `No movement detected`
  - `We haven't detected movement for a while. Are you still working out?`

## Proposed Approach

### Option A. Stair 전용 보수적 수정

- stair 기반 activity(`stairClimbing`, `stairStepper`)에서는 `floorsClimbed` 증가도 motion으로 인정한다.
- 장점:
  - 변경 범위가 작다
  - 기존 distance cardio 동작을 거의 건드리지 않는다
- 단점:
  - stair machine에서 `floorsClimbed` 업데이트가 드문 환경이면 오탐이 남을 수 있다

### Option B. Machine cardio 공통 신호로 확장

- `supportsMachineLevel == true`인 machine cardio에서는
  `distance/steps` 외에 `floorsClimbed` 또는 `activeCalories` 증가를 motion proxy로 인정한다.
- 장점:
  - stair뿐 아니라 elliptical/time-only machine cardio까지 함께 보호 가능
  - 손목 고정 환경에 더 강하다
- 단점:
  - 실제 정지 후에도 calorie update 지연으로 prompt가 늦어질 수 있다

### Option C. 생리 신호 guard 추가

- stair/machine cardio에서 `heartRate`가 일정 수준 이상 유지되면 no-motion prompt를 지연 또는 억제한다.
- 장점:
  - 손목/거리 metric이 모두 약한 경우를 보완할 수 있다
- 단점:
  - 심박은 recovery lag가 있어 정지 후에도 높게 남을 수 있다
  - threshold 설계가 필요하다

## Decision

- 범위: `천국의 계단` 한정이 아니라 `machine cardio` 전체
- detector 신호: `Recommended MVP` 기준 채택
- 우선순위: prompt 속도보다 false positive 감소 우선

## Recommended MVP

Option B를 기본안으로 확정한다.

- stair 기반 activity에서는 `floorsClimbed` 증가를 motion으로 인정
- machine cardio 전체에서는 `activeCalories` 증가를 fallback activity signal로 인정
- 기존 threshold(`75s` / `120s` / `10s countdown`)는 우선 유지
- copy와 UX 단계는 바꾸지 않고 detector만 activity-aware하게 수정
- 구현은 pure helper로 분리해 테스트 가능한 형태로 둔다

이 방향이 사용자 요청을 직접 해결하면서도,
이미 존재하는 machine cardio 모델(`supportsMachineLevel`)과 맞는다.

## Constraints

- HealthKit live metric cadence는 activity별로 일정하지 않을 수 있다
- stair machine의 `floorsClimbed`는 환경에 따라 신뢰도가 달라질 수 있다
- no-motion detector가 너무 관대해지면 실제 종료 추천이 늦어진다
- watch-only logic이므로 DUNEWatch target에서 검증 가능해야 한다

## Edge Cases

- 손잡이를 잡은 stair climber: steps 증가 없음, floors/calories만 증가
- level은 고정이지만 계속 운동 중인 경우
- 실제로 멈췄지만 heart rate만 한동안 높은 경우
- very low intensity stair session에서 calorie 증가가 느린 경우
- elliptical 같은 다른 machine cardio도 동일 문제가 재현되는 경우

## Scope

### MVP (Must-have)

- `WorkoutManager` inactivity detector를 activity-aware signal로 확장
- stair/machine cardio 기준 테스트 추가
- 기존 cardio inactivity policy threshold 유지

### Nice-to-have (Future)

- activity별 detector policy 분리
- heart-rate-based guard 도입
- 사용자 설정으로 detector sensitivity 조정

## Resolved Decisions

1. 변경 범위는 `machine cardio` 전체로 확장한다.
2. `activeCalories` 증가를 movement proxy로 사용하는 것을 허용한다.
3. 실제 정지 감지 속도보다 false positive 감소를 우선한다.

## Next Steps

- [ ] detector helper 설계 및 Swift Testing 추가
- [ ] `WorkoutManager` inactivity signal을 machine-cardio aware 로 확장
- [ ] `/plan watch-stair-no-motion-detection` 으로 구현 계획 생성
