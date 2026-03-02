---
tags: [watchos, ios, healthkit, workout-delete, sync]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Watch Manual Workout Delete Parity

## Problem Statement
폰(iPhone)에서 직접 입력한 운동은 삭제가 가능하지만, 애플워치에서 직접 입력한 운동은 iPhone 앱에서 삭제가 되지 않거나 HealthKit 동기 데이터가 남는 것으로 보인다. 입력 출처(폰/워치)와 관계없이 동일한 삭제 동작이 필요하다.

## Target Users
- 주요 사용자: iPhone + Apple Watch를 함께 쓰며 운동을 직접 입력하는 사용자
- 핵심 니즈: 워치에서 입력한 운동도 폰에서 확실하게 삭제되고, 동기화 후에도 재등장하지 않아야 함

## Success Criteria
- 워치 직접 입력 운동을 iPhone 앱에서 삭제하면 앱 목록에서 즉시 사라진다.
- 동일 항목이 HealthKit 동기 데이터에서도 삭제된다.
- 앱 재실행/동기화 이후에도 삭제된 항목이 다시 나타나지 않는다.

## Proposed Approach
- 운동 삭제 경로에서 `source(폰/워치)`별 분기 여부를 점검하고 공통 삭제 플로우로 통합
- 워치 직접 입력 운동의 식별자(예: UUID/metadata/sourceRevision)가 iPhone 삭제 경로에서 누락되지 않도록 정합성 보강
- 앱 DB 삭제와 HealthKit 샘플 삭제를 하나의 원자적 시나리오로 다루고 실패 시 롤백/재시도 정책 정의

## Constraints
- 별도 기술/일정 제약 없음

## Edge Cases
- 워치 직접 입력 운동만 처리 대상(자동 기록/서드파티 유입 운동은 MVP 제외)
- iPhone 오프라인/백그라운드 전환 중 삭제 요청 발생
- 이미 일부만 삭제된 불일치 상태(앱에는 없음, HealthKit에는 존재 또는 그 반대)

## Scope
### MVP (Must-have)
- 워치 직접 입력 운동을 iPhone에서 삭제 가능하게 수정
- 삭제 시 HealthKit 동기 데이터까지 함께 삭제
- 삭제 후 재동기화 시 재등장하지 않도록 보장

### Nice-to-have (Future)
- 워치 앱에서도 직접 삭제 지원
- 출처별 삭제 상태 진단 로그/관리 화면

## Open Questions
- 워치 입력 운동 식별자가 저장 계층에서 어떤 키로 매핑되는지(현재 구현 확인 필요)
- 삭제 실패 시 사용자 노출 UX(토스트/재시도 버튼) 수준

## Next Steps
- [ ] /plan watch-manual-workout-delete-parity 로 구현 계획 구체화
- [ ] 폰/워치 입력 운동의 저장 스키마 및 삭제 경로 차이 분석
- [ ] 삭제 통합 경로 구현 후 HealthKit 포함 회귀 테스트 추가
