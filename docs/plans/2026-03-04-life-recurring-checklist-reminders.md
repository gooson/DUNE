---
topic: life-recurring-checklist-reminders
date: 2026-03-04
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/testing/2026-03-04-unit-test-coverage-hardening-followup.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-life-checklist-reminder.md
---

# Implementation Plan: 라이프 주기 체크리스트 + 다음 주기 알림

## Context
Life 탭은 현재 일/주 단위 습관 달성 중심으로 구현되어 있고, "완료일 기준으로 다음 주기 재계산 + 다중 알림 + 미루기/건너뛰기 + 히스토리" 요구를 직접 충족하지 못한다.  
기존 SwiftData 모델을 최대한 재사용하면서 주기형 체크리스트 동작을 추가한다.

## Requirements

### Functional
- 반복 규칙에 "주기(일 단위 interval)" 지원 (예: 7/30/90일)
- 체크 완료 시 `완료일 + 주기`로 다음 예정일 계산
- 다중 알림(기본 3일 전/1일 전/당일) 예약
- 미루기(예정일 이동) / 건너뛰기(이번 주기 스킵) 액션 제공
- 주기 액션(완료/미루기/건너뛰기) 히스토리 조회 제공

### Non-functional
- 기존 daily/weekly 습관 동작 회귀 방지
- SwiftData schema 신규 모델 추가 없이 기존 필드로 확장
- ViewModel validation + 주기 계산 로직 단위 테스트 추가

## Approach
`HabitDefinition.frequencyTypeRaw + weeklyTargetDays`를 재해석해 interval 주기를 저장하고, `HabitLog.memo`의 시스템 마커로 skip/snooze 액션을 표현한다.  
새 SwiftData 모델을 추가하지 않아 migration 리스크를 줄이고, Life 화면의 기존 CRUD 흐름에 주기 계산/알림 예약 훅을 연결한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 신규 `HabitScheduleState` 모델 추가 | 상태 표현 명확 | schema/migration + CloudKit 리스크 큼 | 미채택 |
| UserDefaults 기반 주기 상태 저장 | 구현 빠름 | 데이터 일관성/동기화 취약 | 미채택 |
| 기존 모델 필드 재사용 + memo action marker | migration 최소, 기존 구조 재사용 | memo 파싱 규약 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Domain/Models/HabitType.swift | modify | `HabitFrequency.interval(days:)` 및 interval helper 추가 |
| DUNE/Data/Persistence/Models/HabitDefinition.swift | modify | frequency raw 매핑에 interval 지원 |
| DUNE/Presentation/Life/LifeViewModel.swift | modify | 주기 snapshot 계산, skip/snooze/히스토리, 알림 예약 유틸 추가 |
| DUNE/Presentation/Life/LifeView.swift | modify | 완료/미루기/건너뛰기 액션 연결 + 히스토리 시트 추가 |
| DUNE/Presentation/Life/HabitFormSheet.swift | modify | 주기(interval day) 입력 UI 추가 |
| DUNE/Presentation/Life/HabitRowView.swift | modify | next due / due 상태 표시 및 주기형 체크 UX 반영 |
| DUNETests/HabitTypeTests.swift | modify | interval frequency 테스트 추가 |
| DUNETests/LifeViewModelTests.swift | modify | interval validation + cycle snapshot + history/skip/snooze 테스트 추가 |

## Implementation Steps

### Step 1: Domain/Model 주기 규칙 확장
- **Files**: `HabitType.swift`, `HabitDefinition.swift`
- **Changes**:
  - `HabitFrequency`에 `interval(days:)` 케이스 및 helper(`intervalDays`) 추가
  - persistence raw value `"interval"` 해석/저장 로직 추가
- **Verification**:
  - `HabitTypeTests`에서 interval equality/helper 검증

### Step 2: LifeViewModel 주기 계산 + 알림 예약 로직 추가
- **Files**: `LifeViewModel.swift`
- **Changes**:
  - 완료/미루기/건너뛰기 액션 분류 및 history entry 생성
  - 완료일 기준 `nextDueDate` 계산(snapshot) 추가
  - 다중 알림(3일 전/1일 전/당일) 예약 유틸 추가
- **Verification**:
  - `LifeViewModelTests`에서 nextDue 재계산, snooze 반영, history 정렬 검증

### Step 3: Life UI 반영
- **Files**: `HabitFormSheet.swift`, `LifeView.swift`, `HabitRowView.swift`
- **Changes**:
  - form에서 interval day 입력 추가
  - row에서 due/overdue/next due 표시
  - context menu에 `미루기/건너뛰기/히스토리` 액션 추가
  - save/toggle/skip/snooze 후 reminder 재예약 연결
- **Verification**:
  - Life 화면 수동 점검: 항목 생성 → 완료 → next due 이동 → 알림 예약 호출

### Step 4: 테스트/품질 검증
- **Files**: `DUNETests/*`
- **Changes**:
  - 신규/수정 테스트 추가 후 iOS unit test 실행
- **Verification**:
  - `scripts/test-unit.sh --ios-only` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| interval이 비정상 값(0, 음수, 과대) | 1...365 범위로 clamp |
| 기존 daily/weekly legacy habit | 기존 계산 경로 유지 |
| 알림 권한 미허용 | 예약 실패를 무시하고 기능 계속 동작 |
| 같은 날 반복 완료/액션 중복 | 최신 action 기준 snapshot 계산 |
| snooze 후 다시 완료 | 완료일을 새 기준(anchor)으로 재계산 |

## Testing Strategy
- Unit tests: `HabitTypeTests`, `LifeViewModelTests` 확장
- Integration tests: 없음 (범위 외)
- Manual verification: Life 탭에서 7/30/90일 주기 생성, 완료/미루기/건너뛰기 + 히스토리 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| memo marker 파싱 누락으로 액션 오인식 | medium | medium | marker 상수 단일화 + 파싱 테스트 추가 |
| interval 도입으로 기존 streak 계산 혼선 | medium | low | interval은 별도 snapshot 경로로 분리 |
| 로컬 알림 과예약/중복 | low | medium | habitID prefix 기반 pending request 선삭제 후 재등록 |

## Confidence Assessment
- **Overall**: Medium
- **Reasoning**: 기존 모델을 재사용해 migration 리스크는 낮지만, 주기형 UX와 legacy daily/weekly를 함께 유지해야 해 회귀 검증이 필요하다.
