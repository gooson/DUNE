---
tags: [ios, watchos, walking, steps, dashboard, healthkit]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Walking Step Count Visibility

## Problem Statement
현재 걷기 운동 관련 화면에서 step count 노출이 일관되지 않아, 사용자가 "걷기 1회에서 실제 몇 걸음을 걸었는지"를 즉시 확인하기 어렵다. 특히 대시보드에서 걷기 카드 존재가 보장되지 않고, 운동 기록 상세/운동 세션 중 표시도 통합되어 있지 않아 사용자 기대(걷기=걸음 수 확인 가능)를 충족하지 못한다.

## Target Users
- 주요 사용자: iPhone + Apple Watch를 함께 사용하며 걷기 운동을 기록하는 사용자
- 핵심 니즈: 걷기 운동마다 step count를 항상 확인하고, 대시보드에서 걷기 활동을 독립 카드로 빠르게 인지하고 싶음

## Success Criteria
- 걷기 운동 기록 상세 화면에서 step count가 항상 표시된다.
- 대시보드에 걷기 카드가 존재하고, 걷기 관련 핵심 수치를 확인할 수 있다.
- 운동 세션 중에도 걷기 step count를 실시간/준실시간으로 확인 가능하다.
- 집계는 운동 1회별을 기본으로 제공하고, 동일 데이터의 일/주 단위 구간 조회가 가능하다.
- iOS와 watchOS 모두에서 동일한 의미의 지표를 제공한다.

## Proposed Approach
- 데이터 기준 통일
  - "걷기 워크아웃 구간의 steps"를 단일 진실 원천으로 정의
  - workout 시작/종료 시각 기반으로 `.stepCount`를 조회해 per-workout step count 산출
- 화면별 노출 전략
  - 대시보드: 걷기 전용 카드 추가(최근 걷기 1회 + 오늘/주간 요약 진입점)
  - 운동 기록 상세: 걷기 workout detail에 step count 고정 표시
  - 운동 세션 중: 진행 중 step count를 노출하고 세션 종료 시 최종값 확정
- 구간 집계
  - 기본: 운동 1회 단위(step count per workout)
  - 파생: 일 단위/주 단위 집계(걷기 workout들의 step count 합산/통계)
- 플랫폼 정합성
  - iOS/watchOS 공통 모델(걷기 step metric DTO)로 의미를 통일
  - 플랫폼별 UI 컴포넌트만 분리하고 계산 규칙은 공유

## Constraints
- HealthKit step data는 소스/동기화 타이밍에 따라 지연 반영될 수 있어, 세션 중 값과 세션 종료 후 확정값이 다를 수 있음
- 동일 구간에 iPhone/Watch 동시 기록이 있는 경우 중복/우선순위 정책(HealthKit aggregate 기준) 명확화 필요
- watchOS 실시간 표시 주기와 배터리 영향의 균형 필요

## Edge Cases
- 걷기 운동은 존재하지만 해당 구간 step count가 지연/누락된 경우(권한, 동기화 지연)
- 운동 시작 직후/종료 직후 값 튐(샘플 반영 지연)
- 자정 경계에 걸친 걷기 운동(1회 데이터와 일 단위 집계의 날짜 귀속)
- 실내 걷기/야외 걷기/혼합 활동의 분류 일관성
- 세션 중 일시정지/재개가 반복된 경우 구간 합산 정확성

## Scope
### MVP (Must-have)
- iOS + watchOS 모두에서 걷기 운동 상세에 step count 항상 표시
- 대시보드에 걷기 카드 추가
- 운동 세션 중 걷기 step count 표시
- 운동 1회별 step count를 기준으로 일/주 단위 집계 제공

### Nice-to-have (Future)
- 월 단위/커스텀 기간 집계
- 걷기 pace, cadence, 고도 등과 결합한 인사이트 카드
- step goal 대비 달성률/알림 연계

## Open Questions
- 대시보드 걷기 카드의 기본 KPI 우선순위(최근 1회 steps vs 오늘 누적 vs 주간 합계) 최종 선택 필요
- 세션 중 표시 주기(예: 5초/10초)와 watch 배터리 정책 기준 확정 필요
- step count 지연 시 사용자에게 보여줄 fallback 문구/상태(동기화 중 등) UX 결정 필요

## Next Steps
- [ ] /plan walking-step-count-visibility 로 구현 계획 상세화
- [ ] 걷기 workout 구간 기반 step query API(공통 계층) 설계
- [ ] iOS/watchOS 화면별 데이터 바인딩 및 상태 UX 정의
- [ ] 운동 1회/일/주 집계 테스트 케이스 추가
