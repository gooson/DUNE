---
tags: [watch, quick-start, workout, progression, level-up, sync]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: Watch Quick Start 운동 절차 전체 기억 + Level-Up 통합

## Problem Statement

현재 Watch Quick Start는 최근 운동 선택 우선순위와 마지막 세트의 무게/횟수만 기억하고, 다음 시작 시에는 기본 세트 수 + 마지막 세트 weight/reps 정도만 복원한다. 그 결과 사용자는 이전에 실제로 수행한 절차를 그대로 재현할 수 없고, `1세트/2세트/3세트별 무게·횟수`와 `총 세트 수`를 다시 수동 입력해야 한다.

반면 iPhone의 `WorkoutSessionViewModel`에는 이미 다음 로직이 존재한다.
- 이전 세션 세트 전체 복원 (`loadPreviousSets`)
- 세션 간 첫 세트 중량 증가 (`applyInterSessionOverload`)
- 세트 완료 직후 다음 세트 중량 증가 (`applyProgressiveOverloadForNextSet`)
- 세트 달성률 기반 Level-Up 추천 (`shouldSuggestLevelUp`)

핵심 문제는 Watch Quick Start가 이 기존 progression/level-up 체계와 분리되어 있다는 점이다. 사용자는 Quick Start에서 동일 운동을 다시 시작할 때, 마지막 완료 세션의 절차를 거의 그대로 불러오되 기존 Level-Up 시스템도 함께 적용되는 일관된 경험을 원한다.

## Target Users

- Apple Watch에서 Quick Start로 근력 운동을 반복 수행하는 일반 사용자
- 매번 세트별 무게/횟수를 다시 입력하지 않고, 지난번 절차를 바로 이어서 수행하고 싶은 사용자
- 점진적 과부하와 레벨업 로직을 자동으로 적용받고 싶은 사용자

## Success Criteria

1. 같은 Quick Start 운동을 다시 선택하면 마지막 완료 세션의 `세트별 무게/횟수`와 `총 세트 수`가 그대로 복원된다.
2. 변형 운동은 별개로 취급된다.
   - 예: `paused bench`와 `bench`는 서로 다른 절차를 가진다.
3. 한 세트도 완료하지 않고 종료한 세션은 저장되지 않는다.
4. 이전 기록이 없으면 현재처럼 디폴트 세트 수/무게/횟수로 시작한다.
5. 기존 Level-Up / progressive overload 시스템이 Quick Start 복원 흐름과 충돌 없이 함께 동작한다.
6. iPhone과 Watch가 같은 마지막 완료 절차를 공유한다.

## Proposed Approach

### 1. Quick Start 전용 절차 스냅샷 정의

- 운동별로 `마지막 완료 세션 1개`만 유지하는 procedure snapshot을 도입한다.
- 키는 canonical ID가 아니라 `정확한 exercise ID`를 사용한다.
- 스냅샷에는 최소한 아래 정보를 포함한다.
  - `exerciseID`
  - `completedAt`
  - `totalCompletedSets`
  - `sets[]`
    - `setNumber`
    - `weight`
    - `reps`
- 휴식 시간은 MVP에서 스냅샷에 저장하지 않고, 현재 요구대로 Settings의 글로벌 rest 값을 계속 사용한다.

### 2. 저장 규칙

- Watch Quick Start 종료 시점에, 완료된 세트가 1개 이상일 때만 snapshot을 저장한다.
- 저장 대상은 `실제로 완료된 세트들`만이다.
  - 사용자가 추가 세트를 눌러 4세트를 완료했다면 다음번 총 세트 수도 4로 복원된다.
  - 사용자가 중간에 종료해서 3세트만 완료했다면 다음번에는 그 3세트 절차가 기준이 된다.
- iPhone 쪽 운동 저장 경로도 같은 구조의 snapshot을 만들 수 있어야 하며, 최종적으로 Phone/Watch가 같은 최근 절차를 공유하도록 동기화한다.

### 3. 복원 규칙

- Quick Start 운동 선택 시 기존 `latest set only` prefill 대신 procedure snapshot을 우선 조회한다.
- snapshot이 있으면:
  - 총 세트 수를 snapshot의 completed set count로 맞춘다.
  - 각 세트의 weight/reps를 세트별로 복원한다.
- snapshot이 없으면 현재 동작을 유지한다.
  - `defaultSets`
  - `defaultReps`
  - `defaultWeight`
  - `latest set` fallback

### 4. 기존 Level-Up / Progression 시스템과의 통합

- MVP에서는 iPhone에 이미 있는 progression 체계를 그대로 유지하고 Quick Start 복원 위에 얹는다.
- 우선순위는 다음과 같다.
  1. 마지막 완료 세션 절차를 정확히 복원한다.
  2. 기존 세션 간 overload 규칙이 충족되면 첫 세트에만 증량 overlay를 적용한다.
  3. 운동 진행 중에는 기존처럼 세트 완료 직후 다음 세트 증량 규칙을 적용한다.
  4. 세션 종료 시 기존 Level-Up 추천 판정을 그대로 사용한다.
- 즉, “절차 복원”이 baseline이고, “레벨 승급/증량”은 그 위에 덧씌워지는 progression layer로 취급한다.

### 5. 동기화 전략

- Watch는 오프라인 즉시 복원을 위해 로컬 snapshot을 유지한다.
- iPhone은 `ExerciseRecord.completedSets` 기반으로 동일 snapshot을 재구성하거나 수신 후 저장한다.
- 최종 동작은 cross-device 동기화를 기준으로 맞춘다.
- sync가 지연되더라도 Watch는 마지막 로컬 snapshot으로 바로 시작할 수 있어야 한다.

## Constraints

- 현재 Watch Quick Start payload는 `defaultSets/defaultReps/defaultWeightKg` 중심이라 세트 배열 전체를 직접 전달하지 않는다.
- 최근/인기 정렬에는 canonical grouping을 쓰지만, 절차 기억은 exact ID 기준이어야 한다.
- “그대로 복원”과 “첫 세트 자동 증량”은 UX상 긴장 관계가 있으므로 우선순위와 표기 방식이 필요하다.
- Watch와 iPhone의 저장 시점이 다르므로 timestamp 기반 최신값 승자 규칙이 필요하다.

## Edge Cases

- 이전 기록 없음: 디폴트 사용
- 한 세트도 완료하지 않음: 저장 안 함
- 변형 운동: 별개 snapshot 유지
- extra set 추가: 추가된 세트 수까지 snapshot에 포함
- 계획은 5세트였지만 3세트만 완료 후 종료: 완료된 3세트만 다음 기준으로 사용
- sync 실패/지연: Watch 로컬 snapshot 우선, 이후 iPhone과 최신 timestamp 기준 병합
- Level-Up 조건 충족으로 첫 세트가 자동 증량된 경우: 사용자가 “복원이 틀렸다”라고 느끼지 않도록 설명이 필요할 수 있음

## Scope

### MVP (Must-have)

- Quick Start에서 마지막 완료 세션 1개 기준 절차 복원
- 세트별 weight/reps 복원
- 총 세트 수 복원
- exact exercise ID 기준 저장/조회
- 기록 없을 때 디폴트 fallback
- 한 세트도 완료하지 않은 세션 미저장
- 기존 inter-session overload / next-set overload / Level-Up 추천과 통합
- iPhone/Watch 동기화

### Nice-to-have (Future)

- 첫 세트 자동 증량 배지 또는 “Level up applied” 안내
- 세트별 RPE까지 복원
- 절차 복원 on/off 토글
- 여러 최근 세션 중 선택 복원
- 운동별 progression 규칙 사용자 설정

## Open Questions

1. 세션 간 overload가 적용되어 첫 세트가 자동 증량될 때, 이를 조용히 적용할지 아니면 Quick Start preview/session 화면에서 명시적으로 안내할지?
2. 현재 iPhone 로직의 기준은 `inter-session overload = 모든 세트 목표 reps 달성`, `level-up suggestion = 90% 이상 달성`으로 분리되어 있는데, Quick Start에서도 이 분리를 그대로 유지할지?
3. Watch 로컬 snapshot과 iPhone 저장 기록이 동시에 최신 후보일 때, 충돌 해소를 timestamp only로 충분히 볼지 아니면 source priority까지 둘지?

## Next Steps

- [ ] `/plan watch-quickstart-procedure-memory-levelup` 으로 구현 계획 생성
- [ ] Watch Quick Start 현재 prefill 경로와 iPhone `WorkoutSessionViewModel` progression 경로를 연결하는 설계 확정
- [ ] snapshot 저장/동기화 구조를 `RecentExerciseTracker` 확장 vs 별도 sync model 중 하나로 결정
