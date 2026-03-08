---
tags: [sleep, notification, bedtime, habit, engagement]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 평균 취침 시간 2시간 전 일반 취침 알림

## Problem Statement

기존 bedtime reminder는 "Apple Watch를 안 찼을 때만" 동작하는 watch-specific 리마인더였다.
이번 요구사항은 워치 착용 여부와 무관하게, 사용자의 최근 평균 취침 시간보다 2시간 앞서
"지금부터 취침을 준비하면 건강/회복/운동에 도움이 된다"는 성격의 일반 취침 알림으로 전환하는 것이다.

## Target Users

- 수면 시간을 일정하게 유지하고 싶은 사용자
- 회복, 컨디션, 운동 퍼포먼스를 위해 취침 루틴을 만들고 싶은 사용자
- Apple Watch 유무와 관계없이 취침 습관 코칭을 받고 싶은 사용자

## Success Criteria

- 최근 7일 수면 데이터로 평균 취침 시간을 계산한다.
- 계산된 평균 취침 시간 2시간 전에 하루 1회 로컬 알림이 예약된다.
- 수면 데이터가 부족하면 알림을 예약하지 않는다.
- 사용자 설정에는 일반 취침 알림 토글이 노출된다.

## Proposed Approach

- 기존 평균 취침 시간 계산 use case는 유지한다.
- 기존 watch-specific scheduler를 일반 bedtime reminder scheduler로 단순화한다.
- Watch pairing, watch app 설치 여부, wrist temperature 기반 skip 조건은 제거한다.
- 알림 문구는 "건강/회복/운동" 가치를 전달하는 일반 취침 코칭 메시지로 교체한다.
- 향후 리드 타임(30분/1시간/2시간) 사용자 설정은 별도 TODO로 분리한다.

## Constraints

- 평균 취침 시간 계산 기준은 최근 7일을 유지한다.
- 수면 데이터가 없거나 부족하면 알림을 보내지 않는다.
- 기존 앱 lifecycle refresh 지점(DUNEApp, ContentView)은 재사용한다.

## Edge Cases

- 최근 수면 데이터가 비어 있음: pending reminder 제거 후 미예약
- 자정 전후 취침 시간 혼합: 기존 평균 취침 시간 계산의 wrap 처리 유지
- 알림 권한 미허용: pending reminder 제거 후 미예약
- 사용자가 토글을 끈 상태: pending reminder 제거 후 미예약

## Scope

### MVP (Must-have)

- 평균 취침 시간 기반 일반 취침 알림으로 기능 전환
- 리드 타임을 2시간으로 변경
- 설정 라벨과 알림 문구 업데이트
- 관련 단위 테스트 추가

### Nice-to-have (Future)

- 리드 타임 사용자 설정 (30분 / 1시간 / 2시간)
- 평일/주말 분리 평균 취침 시간
- 수면 부채/운동 회복 상태에 따라 문구 개인화

## Open Questions

- 일반 취침 알림 문구를 단일 고정 문구로 둘지, 회복/운동/수면 관점 복수 카피로 확장할지 추후 판단 필요
- 일반 취침 알림을 Notification Hub와 연결할지 여부는 후속 범위로 남김

## Next Steps

- [ ] `/plan general-bedtime-reminder` 로 구현 계획 생성
