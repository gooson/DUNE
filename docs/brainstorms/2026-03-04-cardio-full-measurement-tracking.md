---
tags: [cardio, walking, fitness, measurement, steps, pace, distance, healthkit, corelocation, coremotion]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 유산소 전체 실측 기반 기록 강화

## Problem Statement

현재 iOS 카디오 세션은 거리/페이스/칼로리 중심으로 동작하지만, 고급 사용자가 기대하는 **실측 기반 데이터 전체(걸음수, 케이던스, 고도 포함)**를 일관되게 남기기에는 부족하다.

특히 권한/디바이스 제약이 발생할 때도 최소한의 기록 일관성이 필요하다.

- 목표: 유산소(걷기 포함)에서 측정 가능한 값을 최대한 실측으로 수집하고 저장
- 제약 상황 정책: GPS/Watch/일부 센서가 불가해도 **걸음수 중심 fallback 기록** 유지

## Target Users

- 러닝/워킹 고급 사용자
- 페이스, 거리, 걸음수, 고도, 케이던스 등 세부 지표를 확인하는 사용자
- iPhone 단독/Watch 연동/권한 제한 등 다양한 환경에서 기록 연속성을 원하는 사용자

## Success Criteria

1. 카디오 세션 종료 시 실측 지표가 ExerciseRecord와 HealthKit에 최대한 일치하게 저장된다
2. 최소 포함 항목: 활동시간, 거리, 페이스, 걸음수, 칼로리
3. 가능 항목: 케이던스, 고도(누적 상승), 심박(HealthKit 연동 시)
4. 권한 제약 상황에서도 세션 저장 실패 없이 fallback 기록이 남는다
5. 세션 상세 화면에서 저장된 핵심 지표를 확인할 수 있다

## Proposed Approach

### 측정 소스 통합

- `CoreLocation`: 실외 거리/GPS 기반 페이스
- `CoreMotion(CMPedometer)`: 걸음수, 케이던스, 고도, 보행 기반 페이스/거리
- `HealthKit`: 워크아웃 저장 + 통합 조회(WorkoutSummary)

### 기록 우선순위

- 거리: Outdoor는 GPS 우선, 실패 시 Pedometer distance fallback
- 페이스: 거리+시간 기반 평균 페이스를 기본값으로 저장
- 걸음수: CMPedometer 값을 기본 저장 지표로 사용
- 고도/케이던스: 값이 유효할 때만 저장

### 실패 정책

- 위치 권한 거부/수신 불가: 걸음수 중심으로 저장
- Watch 미연동/심박 없음: 심박 제외 저장 허용
- 일부 측정치 nil이어도 세션 저장은 계속 진행

## Constraints

- Motion 권한(`NSMotionUsageDescription`) 및 CoreMotion 프레임워크 추가 필요
- SwiftData 모델 확장 시 migration plan 업데이트 필요
- HealthKit에는 가능한 샘플/metadata만 기록하고, 미지원 항목은 로컬 보존

## Edge Cases

1. 세션 매우 짧음(수초): 페이스/거리 유효성 검사 필요
2. 걸음수는 있지만 거리 없음: pace nil 허용
3. GPS 점프/노이즈: 기존 distance sanity 필터 유지
4. 백그라운드 전환: 세션 종료 시 최종 pedometer query로 누락 최소화
5. 센서 데이터 NaN/무한대: 저장 전 validation 필수

## Scope

### MVP (Must-have)

- [ ] 실시간 걸음수 추적(CMPedometer)
- [ ] 케이던스/고도/페이스 보조 측정값 수집
- [ ] CardioSessionRecord/ExerciseRecord 저장 필드 확장
- [ ] HealthKit 워크아웃 write 시 steps/metadata 반영
- [ ] 권한 실패 시 걸음수 fallback 기록 정책 구현
- [ ] 세션 상세 화면에 저장 지표 표시
- [ ] 유닛 테스트 업데이트

### Nice-to-have (Future)

- [ ] GPS route(HKWorkoutRoute) 저장/시각화
- [ ] 구간(lap) 자동 분할
- [ ] 심박 존(zone) 실시간 고도화
- [ ] 센서 품질 점수(accuracy score) 기록

## Open Questions

1. HKWorkoutRoute를 즉시 포함할지(복잡도 높음) 후속 단계로 분리할지
2. 케이던스/페이스 단위를 사용자 설정(분/킬로 vs 분/마일)로 즉시 확장할지
3. HealthKit 미연동 환경에서 "실측 신뢰도" 배지를 노출할지

## Next Steps

- [ ] `/plan cardio-full-measurement-tracking`으로 구현 계획 확정
