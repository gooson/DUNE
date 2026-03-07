---
tags: [workout, progression, level-up, set-weight, routine-memory]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: 운동 절차 재현 + 레벨업 안내 + 세트당 중량 증가 로직

## Problem Statement

사용자가 수행한 운동 절차(세트 순서, 무게/횟수/휴식 패턴)를 앱이 일관되게 기억하고 다음 세션에서 재현하지 못하면, 훈련의 연속성과 점진적 과부하(Progressive Overload)를 유지하기 어렵다. 또한 사용자가 일정 수준 이상을 달성했을 때 이를 명확히 피드백하고 다음 행동(레벨업 페이지 진입)으로 연결하는 UX가 부재하면 동기 부여가 약해질 수 있다.

핵심 과제는 다음 3가지를 하나의 흐름으로 묶는 것이다.
1. **운동 절차 기억/재현**: 이전 세션 템플릿을 자동 복원
2. **달성 판정**: 목표 충족 여부를 기준으로 레벨업 가능 상태 판단
3. **중량 증가 로직**: 다음 세트/다음 세션에서 안전한 무게 증가 규칙 적용

## Target Users

- 근력 운동을 루틴 기반으로 수행하는 사용자 (초중급~중급)
- 동일 운동을 반복하며 무게를 점진적으로 올리고 싶은 사용자
- 매 세트 기록은 하되, 다음 행동 추천은 자동화되길 원하는 사용자

## Success Criteria

1. 이전 세션의 세트 구성(세트 수/무게/횟수/휴식)이 다음 세션 시작 시 1탭 이내로 복원된다.
2. 사용자가 설정된 달성 기준(예: 목표 reps 달성률, RPE 여유도)을 넘기면 저장 직후 레벨업 진입 CTA가 노출된다.
3. 중량 증가 규칙이 운동 타입별로 예측 가능하게 작동한다.
   - 상체 복합: +2.5kg
   - 하체 복합: +5.0kg
   - 덤벨/보조: +1.0~2.0kg
4. 과도한 증가 방지를 위한 상한/안전장치가 존재한다.

## Proposed Approach

### 1) 운동 절차 기억/재현

- 최근 완료 세션에서 운동별 `lastSuccessfulProtocol`을 추출
- 프로토콜에 포함:
  - setCount
  - per-set target reps
  - per-set weight
  - restSeconds
  - intensity(옵션)
- 새 세션 시작 시 `AutoFill from Previous`를 기본 ON으로 제공
- 사용자가 수동 수정 시 해당 값은 당일 세션 우선으로 반영

### 2) 달성 판정 → 레벨업 안내

- 세션 저장 시 운동별 달성률 계산:
  - `completedSets / plannedSets`
  - `targetRepsAchievedRate`
  - `formPenalty`(추후)
- 레벨업 판단(초안):
  - 필수: completedSets 100%
  - 필수: targetRepsAchievedRate ≥ 0.9
  - 선택: 최근 2회 연속 충족 시 확정
- 충족 시 결과 화면 상단에 배지 + `레벨업 페이지로 이동` CTA 노출

### 3) 세트당 무게 증가 로직

- 기본 방향: **세션 간 증가 + 세트 내 미세 증가 옵션**
- 권장 규칙(초안):
  - 동일 운동에서 모든 세트를 목표 reps 이상으로 완료하면 다음 세션 기준 무게 증가
  - 세트 내 증가는 옵트인 기능으로 제공
    - 예: set1 50kg, set2 52.5kg, set3 55kg
- 계산식 예시:
  - `nextWeight = roundToAvailablePlate(currentWeight + incrementByExerciseType)`
- 보호 장치:
  - 1회 증가 폭 상한 (% 기반)
  - 실패 세트 발생 시 동결 또는 deload(-5~10%)

## Constraints

- 기구/원판 단위(1.25kg, 2.5kg, 5lb 등) 차이로 반올림 규칙이 필요
- 운동별 증가폭 정책은 개인차가 커 사용자 설정 가능성이 필요
- 기존 템플릿/이전기록 autofill과 충돌 가능 (우선순위 정책 필요)
- 레벨업 판정 기준이 과도하게 엄격/완화되면 이탈 가능

## Edge Cases

- **데이터 부족**: 첫 운동(이전 기록 없음) 시 기본 템플릿 fallback
- **부분 완료**: 세트 미완료/스킵이 있는 경우 증가 차단
- **보조자극 운동**: 무게 대신 reps 증가가 더 적합한 운동 존재
- **단위 전환**: kg ↔ lb 전환 후 증가폭 일관성 깨짐
- **피로 누적 주간**: 의도적 디로드 주간에는 레벨업 CTA 비노출 필요

## Scope

### MVP (Must-have)

- 최근 세션 운동 절차 자동 복원
- 달성률 기반 레벨업 CTA 조건 1종 구현
- 운동 카테고리별 고정 증가폭 적용
- 실패 시 증가 억제(동결)

### Nice-to-have (Future)

- RPE/RIR 기반 동적 증가폭
- 2~3회 추세 기반 스마트 레벨업
- 디로드 주간 자동 감지
- 운동별 사용자 커스텀 증가폭

## Open Questions

1. “일정 수준 이상”의 제품 정의를 무엇으로 고정할지? (reps 달성률, RPE, 1RM 추정치 등)
2. 레벨업 페이지 진입 시점은 저장 직후 모달 vs 결과 화면 CTA 중 무엇이 더 적합한지?
3. 세트당 증가를 기본값으로 둘지, 고급 옵션으로 둘지?
4. 증가 실패 시 정책을 동결/감소 중 어떤 방식으로 시작할지?
5. 운동별 증가폭 프리셋을 앱이 강제할지, 사용자 수정 가능하게 열어둘지?

## Next Steps

- [ ] `/plan workout-procedure-levelup-progression` 으로 구현 계획 생성
- [ ] 달성 판정 규칙에 대한 PM/코치 검증
- [ ] kg/lb 반올림 정책 및 plate step 정책 확정
