---
tags: [ipad, activity-tab, sync, ui-freeze, responsiveness, background-sync, toast]
date: 2026-03-02
category: brainstorm
status: draft
---

# Brainstorm: iPad Activity 탭 UI 락 재발 및 동기화-UI 업데이트 개선

## Problem Statement

iPad 앱을 실행하고 Activity 탭으로 이동하면 백그라운드 동기화 시점에 UI 무반응과 스크롤 정지가 재발한다. 과거 1차 수정 후에도 동일 증상이 다시 발생해 동기화 타이밍/스레드 처리/UI update 경로를 함께 개선해야 한다.

## Target Users

- iPad에서 Health 앱의 Activity 탭을 사용하는 사용자
- 앱 실행 직후 Activity 데이터를 바로 확인하는 사용자

## Success Criteria

- 앱 실행 직후 Activity 탭 진입 시 무반응/스크롤 멈춤이 재현되지 않는다.
- 백그라운드 싱크 중에도 UI가 60fps에 가깝게 유지된다.
- 탭 전환 및 스크롤 입력이 즉시 반응한다.
- 동기화 실패 시 상단 토스트로 에러를 표시하고, UI는 계속 조작 가능하다.

## Proposed Approach

### 1. Sync orchestration 정리

- 앱 시작 시점의 초기 동기화를 단계화하고, Activity 탭 렌더링과 경쟁하지 않도록 우선순위를 조정한다.
- 중복/동시 sync 트리거를 coalescing하여 한 번의 파이프라인으로 합친다.
- 백그라운드 sync 완료 시 UI 반영은 batched update로 묶어 메인 스레드 점유 시간을 줄인다.

### 2. Main-thread load 경감

- 데이터 fetch/가공은 background task에서 수행하고, main actor에는 최소 diff만 전달한다.
- 스크롤 중에는 고비용 recompute를 지연(throttle/debounce)하여 frame drop을 줄인다.
- Activity 탭의 observed state 범위를 좁혀 불필요한 전체 re-render를 방지한다.

### 3. UI update reliability 개선

- initial loading, syncing, stale, error 상태를 분리한 state model을 도입한다.
- sync state 변화와 UI state 변화를 단일 reducer/handler로 직렬화해 race condition을 줄인다.
- 동기화 실패 시 상단 toast를 표시하고 retry action을 제공한다.

### 4. Verification strategy

- iPad 실행 직후 -> Activity 탭 진입 시나리오를 반복 테스트한다.
- sync 중 스크롤/탭 전환 interaction test를 추가한다.
- iPhone 회귀 여부를 smoke test로 확인한다.

## Constraints

- 기존 동기화 정책은 유지하되, 사용자 체감 반응성을 우선한다.
- 특정 아키텍처 제약은 없으므로 과도한 리팩터링 없이 재발 방지 중심으로 수정한다.
- iPad 우선 대응이지만 iPhone 동작 회귀를 유발하면 안 된다.

## Edge Cases

- 동기화 중 네트워크 지연/실패: 상단 토스트로 실패 표시, 기존 화면 조작 가능 상태 유지
- 앱 실행 직후 데이터가 비어 있는 경우: 빈 상태 UI를 먼저 렌더링하고 sync 결과를 점진 반영
- 연속 탭 전환/빠른 스크롤 중 sync 완료: 전환 끊김 없이 안전하게 state 반영
- 중복 sync 요청 발생: 이전 작업 취소 또는 병합(coalesce) 처리

## Scope

### MVP (Must-have)

- [ ] iPad Activity 탭 UI 락(무반응/스크롤 정지) 재발 원인 제거
- [ ] 앱 시작 백그라운드 sync 타이밍과 UI 렌더링 충돌 완화
- [ ] 메인 스레드 점유 축소(배치 반영, 불필요 re-render 억제)
- [ ] sync 실패 상단 토스트 표시 및 기본 retry 흐름 제공
- [ ] iPad 재현 시나리오 반복 검증 + iPhone smoke regression 확인

### Nice-to-have (Future)

- 없음 (요청 범위를 이번 작업에 모두 포함)

## Open Questions

1. 상단 토스트의 표시 시간과 스타일(자동 사라짐, 수동 닫기, retry CTA) 기준은 무엇으로 통일할지?
2. sync 진행 상태를 Activity 탭 내에서 어느 정도까지 노출할지? (minimal indicator vs 상세 상태)
3. iPhone 동일 시나리오 자동 UI test를 이번에 포함할지, 다음 배치로 분리할지?

## Next Steps

- [ ] `/plan ipad-activity-tab-sync-ui-lock-fix` 으로 구현 계획 생성
