---
topic: habit-recurring-start-point
date: 2026-03-04
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-04-life-recurring-checklist-reminders.md
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
  - docs/solutions/architecture/2026-03-01-swiftdata-schema-model-mismatch.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-life-checklist-reminder.md
  - docs/brainstorms/2026-03-04-habit-recurring-start-point.md
---

# Implementation Plan: Habit Recurring 시작 지점 설정

## Context
현재 recurring(interval) 습관은 생성일 기반 암묵 anchor를 사용해 실제 시작일과 due 계산이 어긋날 수 있다.  
요구사항은 시작 지점을 기본 노출로 설정 가능해야 하며(생성일/오늘/직접 날짜/첫 완료일), 미래 시작은 예정 상태로 처리하고, 편집 변경은 변경 시점 이후에만 적용되어야 한다.

## Requirements

### Functional
- recurring 시작 지점 4옵션 지원: `createdAt`, `today`, `customDate`, `firstCompletion`
- recurring 생성/편집 폼에서 시작 지점 기본 노출
- 미래 시작 시 `scheduled` 상태 표시 (due/overdue 아님)
- 편집으로 시작 지점 변경 시 기존 히스토리를 재기록하지 않고 변경 시점 이후만 새 정책 적용
- 기존 데이터에 대한 SwiftData migration 경로 제공

### Non-functional
- daily/weekly 습관 동작 회귀 없음
- CloudKit/SwiftData 호환 유지
- 기존 알림 재스케줄 동작 유지

## Approach
`HabitDefinition`에 시작 지점 정책 필드를 추가하고, cycle snapshot 계산에 "정책 설정 시점(cutoff)"을 도입한다.  
cutoff 이전 로그는 snapshot 계산에서 제외하여 forward-only 변경을 보장한다.  
UI는 recurring 선택 시 시작 지점 설정을 기본 노출하고, custom date 선택 시 날짜 선택기를 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `HabitLog`에 anchor 변경 이벤트를 이벤트소싱으로 저장 | 변경 이력 정확 | 모델/계산 복잡도 과도 | 미채택 |
| 기존 `createdAt` 재사용 + UI만 추가 | 구현 빠름 | 요구사항(모든 옵션/forward-only) 불충족 | 미채택 |
| `HabitDefinition`에 정책+cutoff 필드 추가 | 구현 단순, migration 용이 | 필드 증가로 상태 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Domain/Models/HabitType.swift | modify | recurring 시작 지점 enum 추가, progress DTO 확장 |
| DUNE/Data/Persistence/Models/HabitDefinition.swift | modify | 시작 지점 raw/customDate/configuredAt 필드 추가 |
| DUNE/Data/Persistence/Migration/AppSchemaVersions.swift | modify | AppSchemaV9 + V8→V9 lightweight stage 추가 |
| DUNE/Presentation/Life/LifeViewModel.swift | modify | 시작 지점 validation/state + cycle snapshot scheduled/cutoff 계산 |
| DUNE/Presentation/Life/HabitFormSheet.swift | modify | recurring 시작 지점 입력 UI 추가 |
| DUNE/Presentation/Life/HabitRowView.swift | modify | scheduled 상태/시작일 표시 UX 추가 |
| DUNE/Resources/Localizable.xcstrings | modify | 신규 UI 문자열 en/ko/ja 등록 |
| DUNETests/HabitTypeTests.swift | modify | 시작 지점 enum 안정성 테스트 추가 |
| DUNETests/LifeViewModelTests.swift | modify | 시작 지점별 snapshot/forward-only/scheduled 테스트 추가 |

## Implementation Steps

### Step 1: Model + Migration 확장
- **Files**: `HabitType.swift`, `HabitDefinition.swift`, `AppSchemaVersions.swift`
- **Changes**:
  - `HabitRecurringStartPoint` enum 추가
  - HabitDefinition에 `recurringStartPointRaw`, `recurringCustomStartDate`, `recurringStartConfiguredAt` 필드 추가
  - AppSchemaV9 및 migration stage 추가
- **Verification**:
  - 빌드 성공
  - 기존 recurring 데이터가 fallback(.createdAt)로 해석되는지 단위 테스트 검증

### Step 2: ViewModel cycle 계산 규칙 반영
- **Files**: `LifeViewModel.swift`
- **Changes**:
  - 폼 state/validation에 recurring start point 입력 반영
  - 시작 지점 + configuredAt cutoff 기반 snapshot 계산
  - scheduled 상태(미래 start, firstCompletion 대기) 명시
  - 편집 시 시작 지점 변경 감지 후 configuredAt 갱신
- **Verification**:
  - LifeViewModelTests에서 due/scheduled/forward-only 케이스 통과

### Step 3: UI 반영
- **Files**: `HabitFormSheet.swift`, `HabitRowView.swift`, `Localizable.xcstrings`
- **Changes**:
  - recurring 섹션에 시작 지점 picker + custom date picker 추가
  - row 상태 문구에 scheduled/start 표시 추가
  - 신규 문자열 로컬라이즈 등록
- **Verification**:
  - 수동 확인: 생성/편집에서 시작 지점 변경 가능
  - 미래 시작일에서 due 버튼 비활성 + scheduled 문구 확인

### Step 4: 테스트 + 품질 검증
- **Files**: `DUNETests/HabitTypeTests.swift`, `DUNETests/LifeViewModelTests.swift`
- **Changes**:
  - enum rawValue 안정성, snapshot 분기 테스트 추가
- **Verification**:
  - `scripts/test-unit.sh` (또는 최소 해당 테스트) 통과

## Edge Cases

| Case | Handling |
|------|----------|
| custom start date가 미래 | `scheduled=true`, due/overdue false |
| firstCompletion + 완료 이력 없음 | 시작 대기 상태 유지 |
| 편집 전 로그 다수 존재 | configuredAt 이전 로그는 snapshot 계산 제외 |
| recurring→daily/weekly 전환 | 기존 계산 경로 유지, recurring 필드는 비활성 |

## Testing Strategy
- Unit tests: `HabitTypeTests`, `LifeViewModelTests` 확장
- Integration tests: 없음 (범위 외)
- Manual verification: Life 탭에서 recurring 생성/편집/미래 시작/첫 완료 기준 시나리오 점검

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| cutoff 계산 실수로 기존 due 회귀 | medium | high | forward-only 테스트 케이스 추가 |
| migration 누락으로 컨테이너 생성 실패 | low | high | AppSchemaV9 + stages/schemas 동시 갱신 |
| 신규 문자열 번역 누락 | medium | medium | xcstrings en/ko/ja 동시 추가 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 요구사항 충족 경로는 명확하지만 cycle 계산 분기가 증가해 테스트 커버리지가 중요하다.
