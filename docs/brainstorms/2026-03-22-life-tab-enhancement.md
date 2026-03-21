---
tags: [life-tab, habits, notifications, ux, analytics]
date: 2026-03-22
category: brainstorm
status: draft
---

# Brainstorm: 라이프탭 고도화 및 사용성 개선

## Problem Statement

라이프탭의 간격(interval) 기반 습관에서 두 가지 핵심 사용성 문제가 있다:
1. **알림 타이밍 부적절**: 7일 간격 습관에 3일 전 알림은 너무 이르다 (하드코딩 `[3, 1, 0]`)
2. **조기 완료 불가**: due date 전에는 체크할 수 없어, 미리 처리하고 싶을 때 불편하다

추가로 Streaks/Habitify/Productive 대비 통계/분석과 습관 그룹핑이 부족하다.

## Target Users

- DUNE 앱의 기존 라이프탭 사용자
- 간격 기반 습관(주간 체크리스트 등)을 사용하는 사용자

## Success Criteria

- 간격 비례 알림: 짧은 간격(7일)은 당일+1일전만, 긴 간격(30일)은 더 많은 단계
- 사이클 중 언제든 완료 가능, 다음 due date는 원래 앵커 기준 유지 (drift 방지)
- 기존 습관 데이터/스트릭 영향 없음

## Current Implementation

### 알림 시스템 (`HabitReminderScheduler`)
- 위치: `LifeViewModel.swift:664-731`
- 오프셋: `reminderOffsetsInDays = [3, 1, 0]` (하드코딩)
- 시각: 오전 9시 고정
- 알림 ID: `dune.life.habit.{habitID}.{offsetDays}d`

### 완료 조건 (`canCompleteCycle`)
- 위치: `LifeViewModel.swift` 내 `makeCycleSnapshot()`
- 조건: `isDue || isOverdue || neverCompleted`
- due 전에는 `canCompleteCycle = false` → 체크 버튼 비활성

## Proposed Approach

### Phase 1: 알림 + 완료 개선 (MVP, Priority)

#### 1-A. 간격 비례 알림 자동 조정

현재 고정 `[3, 1, 0]` → 간격 길이에 비례하여 자동 결정:

| 간격 (일) | 알림 오프셋 | 근거 |
|-----------|------------|------|
| 1 (매일) | [0] | 당일만 |
| 2-3 | [1, 0] | 전날 + 당일 |
| 4-7 | [1, 0] | 전날 + 당일 |
| 8-14 | [3, 1, 0] | 현행 유지 |
| 15-30 | [7, 3, 1, 0] | 1주전 추가 |
| 31+ | [14, 7, 3, 0] | 2주전 추가 |

**변경 범위**: `HabitReminderScheduler`의 오프셋 계산 로직만 수정.

#### 1-B. 언제든 완료 + 앵커 유지

- `canCompleteCycle` 조건을 항상 `true`로 변경 (첫 완료 전 제외)
- 완료 시 로그는 현재 날짜로 기록
- **다음 due date 계산**: 완료 시점이 아닌 **원래 앵커 기준** + interval
  - 예: 앵커=3/1, interval=7일 → due dates: 3/8, 3/15, 3/22...
  - 3/5에 미리 완료해도 다음 due는 3/15 (3/8 앵커 기준)
- UI: 미리 완료 시 "다음 체크: N일 후" 표시

**변경 범위**:
- `LifeViewModel.makeCycleSnapshot()`: `canCompleteCycle` 조건 완화
- `LifeViewModel.calculateProgresses()`: 완료 후 다음 due date 계산 로직
- `HabitRowView`: 미리 완료 상태 표시 (이미 완료 + 다음 due date)

### Phase 2: 통계/분석 강화 (Future)

경쟁 앱 벤치마크 기반 추가 기능:

| 기능 | Streaks | Habitify | Productive | DUNE 현재 |
|------|---------|----------|------------|-----------|
| 완료율 차트 | O (원형) | O (상세) | O | X |
| 스트릭 시각화 | O (강력) | O | O (체인) | 숫자만 |
| 히트맵/캘린더뷰 | X | O | X | X |
| 주간/월간 리포트 | X | O | O | X |
| 시간대별 그룹 | X | O (아침/오후/저녁) | O (아침/오후/저녁) | X |
| 습관 카테고리 | X (태스크만) | O (생활영역) | O (색상/아이콘) | 아이콘 카테고리만 |
| 습관 템플릿 | X | O | O | X |
| 부정 습관 (끊기) | O | X | X | X |
| 위치 기반 알림 | X | X | O | X |
| 동기부여 문구 | X | X | O | X |

**우선순위 높은 Future 항목**:
1. 완료율 차트 + 스트릭 시각화 (히어로 카드 확장)
2. 시간대별 그룹핑 (아침/오후/저녁)
3. 주간 리포트 (대시보드 연동 가능)

### Phase 3: 습관 그룹/카테고리 (Future)

- 현재 `iconCategoryRaw`가 12개 카테고리 존재 (health, fitness, study 등)
- 시간대(아침/오후/저녁) + 기존 카테고리를 조합한 2차원 분류 고려
- `HabitDefinition`에 `timeOfDay` 필드 추가 또는 `habitGroup` 관계 추가

## Constraints

- CloudKit 호환: `@Relationship` optional 필수
- 기존 데이터 마이그레이션: `VersionedSchema` 필요 시 새 버전
- Phase 1은 모델 변경 없이 ViewModel 로직만으로 해결 가능

## Edge Cases

### 알림
- 간격 1일(매일): 당일 알림만 → 기존 daily frequency와 동일 동작
- 알림 권한 미부여: 스케줄링 시도만 하고 실패 무시 (현행 유지)
- 앱 삭제/재설치: 알림 재등록 (`refreshReminderSchedule` 호출 시점)

### 조기 완료
- 같은 사이클 내 중복 완료: 기존 로그 삭제 후 재생성 (현행 패턴 유지)
- 완료 후 skip/snooze: 이미 완료된 사이클에 skip/snooze 금지 (UI 비활성)
- 앵커 drift 방지: 완료 시점 ≠ 앵커 기준. 앵커는 `recurringStartDate` 고정
- 스트릭 계산: 조기 완료도 해당 사이클의 정상 완료로 인정

## Scope

### MVP (Must-have) — Phase 1
- [ ] 간격 비례 알림 오프셋 자동 조정
- [ ] 사이클 중 언제든 완료 허용
- [ ] 앵커 기준 다음 due date 유지 (drift 방지)
- [ ] 미리 완료 상태의 UI 표시

### Nice-to-have (Future) — Phase 2, 3
- [ ] 완료율 차트 (주간/월간)
- [ ] 스트릭 시각화 개선 (히트맵 또는 캘린더뷰)
- [ ] 시간대별 습관 그룹핑 (아침/오후/저녁)
- [ ] 습관 카테고리 기반 필터/정렬
- [ ] 주간 리포트
- [ ] 습관 템플릿 라이브러리

## Open Questions

1. **알림 시각**: 현재 오전 9시 고정 — 사용자별 커스텀 시각도 Phase 1에 포함할지?
2. **미리 완료 시 알림 취소**: 조기 완료하면 해당 사이클의 남은 알림을 즉시 취소할지?
3. **스트릭 표시**: 조기 완료 시 "연속 N회 완료" 카운트에 어떻게 반영할지?
4. **weekly frequency**: 주간 빈도(예: 주 3회)도 조기 완료 개념이 필요한지?

## Competitor References

- [Streaks](https://streaksapp.com/) — Apple Design Award 수상, 강력한 스트릭 시각화
- [Habitify](https://habitify.me/) — 통계/분석 중심, 시간대별 그룹핑, 히트맵
- [Productive](https://productiveapp.io/) — 시간대별 루틴, 동기부여 문구, 위치 기반 알림

## Next Steps

- [ ] Phase 1 범위 확정 후 `/plan` 으로 구현 계획 생성
- [ ] Open Questions 사용자 확인
