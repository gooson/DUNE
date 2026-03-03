---
tags: [testing, ui-test, unit-test, coverage]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: UI Test 최대 보강 + 전 화면 절차 단위 테스트 강화

## Problem Statement
현재 테스트는 핵심 로직 단위 테스트가 상당수 존재하지만, UI는 스모크 중심이고 일부 화면 전용 ViewModel 테스트가 누락되어 있다. 사용자의 목표는 전 화면/전 절차 관점에서 회귀를 최대한 조기에 감지하도록 테스트 커버리지를 공격적으로 확장하는 것이다.

## Target Users
- 기능 개발자: 리팩터링 후 회귀 여부를 빠르게 확인해야 함
- 리뷰/릴리즈 담당자: 출시 전 핵심 사용자 절차가 깨지지 않았음을 보장해야 함
- QA: 수동 점검 범위를 줄이고 자동 회귀에 의존할 수 있어야 함

## Success Criteria
- 누락된 화면 전용 ViewModel 테스트 공백 해소
- 핵심 탭(Today/Activity/Wellness/Life/Settings) 사용자 절차 UI 테스트 보강
- PR 단계에서 컴파일 및 선택 테스트가 안정적으로 통과
- 테스트 실패 시 원인이 명확한 메시지/식별자(AXID) 기반으로 드러남

## Proposed Approach
1. 누락 ViewModel 테스트를 우선 추가해 로직 회귀 방어선 확장
2. 기존 스모크 UI 테스트에 절차 검증(진입/취소/유효성/탐색) 추가
3. 테스트 가능한 UI 식별자 누락을 최소 범위로 보완
4. 유닛 테스트 우선 실행 + UI 타깃 build-for-testing으로 CI 컴파일 안정성 확인

## Constraints
- UI 런타임 테스트는 시뮬레이터 상태에 따라 장시간 정체 가능
- 일부 화면은 AXID가 부족해 절차 검증 깊이에 한계
- "모든 화면/모든 절차" 100% 달성은 단일 라운드에서 현실적으로 과대 범위

## Edge Cases
- 시뮬레이터/권한 상태로 UI 테스트가 hang 되는 경우
- 날짜 기반 로직에서 월/주 경계 시 flaky 가능성
- HealthKit 의존 경로는 단위 테스트에서 mock 경로로만 보장 가능

## Scope
### MVP (Must-have)
- 누락 ViewModel 테스트 파일 생성 및 핵심 분기 검증
- 탭별 핵심 절차 UI 테스트 보강
- 신규/수정 테스트 코드 컴파일/실행 검증

### Nice-to-have (Future)
- 모든 상세 화면(Detail/Nested flow) E2E UI 테스트 확장
- iPad 전용 네비게이션/레이아웃 절차 별도 스위트 강화
- UI 테스트 안정화용 공통 wait/retry 유틸 확장

## Open Questions
- 전 화면 기준에 Watch 화면(`DUNEWatch`)까지 포함해야 하는가?
- "모든 절차"에 삭제/편집/오류 배너/빈 상태까지 포함하는가, 아니면 생성/탐색 중심인가?
- CI 게이트에서 UI 런타임 테스트를 필수로 둘지, nightly 전용으로 둘지?
- 테스트 작성 우선순위를 iPhone 우선으로 할지, iPad parity까지 동시 강제할지?

## Next Steps
- [ ] /plan 으로 2차 테스트 확장 계획 생성
