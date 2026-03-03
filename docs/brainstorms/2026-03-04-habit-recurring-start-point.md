---
tags: [life-record, habit, recurring, start-point, migration]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Habit Recurring 시작 지점 설정

## Problem Statement
`frequency = recurring(interval)` 습관은 현재 생성일(`createdAt`)을 암묵 anchor로 사용한다.  
사용자가 실제 시작일(예: 마지막 교체일/실제 시작일)을 반영하려고 해도 직접 기준점을 지정할 수 없어 due 계산 오차가 발생한다.

## Target Users
- Life 탭에서 주기형 체크리스트를 사용하는 사용자
- 정수기 필터, 분리수거, 소모품 교체처럼 "N일 주기" 루틴을 관리하는 사용자
- 생성일과 실제 시작일이 다른 데이터(소급 입력/미래 예정)를 다루는 사용자

## Success Criteria
- recurring 습관 생성/편집에서 시작 지점을 기본 노출로 설정할 수 있다.
- due 계산이 시작 지점 정책에 맞게 일관되게 동작한다.
- 미래 시작일은 due가 아닌 "예정" 상태로 표시된다.
- 편집에서 시작 지점을 바꿔도 기존 히스토리를 재작성하지 않고, 변경 시점 이후로만 새 정책이 적용된다.
- 기존 데이터는 마이그레이션 후에도 안전하게 동작한다.

## Proposed Approach
1. recurring 시작 지점 정책을 모델에 명시적으로 저장
- 옵션: 생성일, 오늘, 직접 날짜, 첫 완료일 기준
- custom date 및 정책 변경 시점 저장

2. cycle snapshot 계산식 확장
- 시작 지점 + 변경 시점 컷오프를 기준으로 anchor 계산
- 미래 시작일/첫 완료 대기 상태를 `scheduled`로 분기

3. 폼 UI 기본 노출
- recurring 선택 시 시작 지점 Picker 기본 표시
- custom 선택 시 DatePicker 표시

4. 편집 변경의 forward-only 적용
- 시작 지점 정책 변경 시 "설정 시점"을 갱신해 이후 로그만 계산에 반영

5. SwiftData migration 포함
- HabitDefinition 필드 추가 + 스키마 버전 증가 + lightweight migration

## Constraints
- 기존 daily/weekly 로직 회귀 없이 recurring 경로만 확장해야 한다.
- CloudKit 호환성을 유지해야 한다.
- 로컬 알림 스케줄링 규칙(3/1/0일 전)은 기존 정책을 유지한다.

## Edge Cases
- 미래 custom start date: due/overdue false + scheduled 표시
- first completion 기준에서 완료 이력 없음: scheduled 상태 유지
- 시작 지점 변경 직후 기존 과거 로그 존재: 변경 시점 이전 로그는 due 계산에서 제외
- recurring → daily/weekly 변경: 새 시작 지점 필드는 보존하되 계산 경로는 비활성화

## Scope
### MVP (Must-have)
- 시작 지점 4옵션 지원
- 미래 시작 scheduled 상태
- 편집 시 forward-only 적용
- SwiftData migration
- 핵심 단위 테스트 추가

### Nice-to-have (Future)
- 시작 지점 변경 히스토리 표시
- 시작 지점 템플릿 추천(예: monthly/quarterly preset)

## Open Questions
- first completion 모드에서 "시작 대기" 상태 문구/도움말의 최종 카피 확정

## Next Steps
- [ ] /plan habit-recurring-start-point
