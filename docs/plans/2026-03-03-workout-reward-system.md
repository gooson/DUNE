---
topic: workout-reward-system
date: 2026-03-03
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-02-24-activity-pr-cardio-healthkit-review-fixes.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-03-workout-intensity-post-completion-only.md
related_brainstorms:
  - docs/brainstorms/2026-03-03-workout-reward-system.md
---

# Implementation Plan: Workout Reward System

## Context

운동 보상 시스템의 목표는 운동 지속률/재방문/기록 갱신 유도이며, 1차 성공 지표는 알림 클릭률(CTR)이다.
현재 코드베이스에는 개인기록(PR) 계산/표시와 workoutPR 알림 경로가 존재하지만, 운동별 고정 구간(마일스톤)과 배지/레벨 히스토리가 통합되어 있지 않다.

## Requirements

### Functional

- 기존 PR 시스템 유지 + 정규화된 보상 흐름으로 통합
- 운동별 고정 구간(개인화 아님) 달성 판정
- 운동 종료 후 달성 알림 발송
- 한 세션에서 여러 달성 발생 시 대표 알림 1개만 발송
- 최종 확정 데이터만 사용
- PR 현황 + 달성 히스토리 화면 제공
- 배지/레벨을 MVP에 포함

### Non-functional

- 기존 Notification 설정/권한 흐름과 호환 (`HealthInsight.InsightType.workoutPR` 유지)
- Domain layer import 규칙 준수 (`SwiftUI`, `SwiftData` 금지)
- UserDefaults 저장 키는 bundle prefix 규칙 준수
- 테스트 필수 규칙 준수 (새 로직 분기 테스트)

## Approach

기존 구조를 확장하는 방식으로 구현한다.

1. `WorkoutActivityType`에 운동별 고정 구간 판정 규칙을 추가한다.
2. `PersonalRecordStore`에 구간 진행 상태/보상 상태/달성 히스토리를 추가한다.
3. `BackgroundNotificationEvaluator`에서 PR + 구간 달성을 통합 평가하고 대표 1개 이벤트로 알림을 보낸다.
4. `ActivityViewModel`/`ActivityView`에서 보상 요약(배지/레벨)과 달성 히스토리 화면을 노출한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 workoutPR 알림 타입 재사용 | 설정/권한/토글 호환, 변경 범위 작음 | 알림 타입 의미 확장 필요 | 채택 |
| 새 알림 타입(workoutMilestone/rewardLevelUp) 추가 | 의미 분리 명확 | 설정 UI/스토어/토글 모두 수정 필요 | 미채택 |
| 별도 RewardStore 신규 파일 생성 | 관심사 분리 명확 | 파일/프로젝트 참조 증가 | 미채택(이번 변경은 기존 Store 확장) |
| 구간 판정을 distance only로 제한 | 구현 단순 | "모든 운동" 요구 미충족 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WorkoutActivityType.swift` | Modify | 운동별 고정 구간 판정 규칙 추가 |
| `DUNE/Domain/Models/PersonalRecord.swift` | Modify | 보상 상태/히스토리 모델 추가 |
| `DUNE/Data/Persistence/PersonalRecordStore.swift` | Modify | 구간/배지/레벨 상태 저장 + 대표 이벤트 선택 |
| `DUNE/Domain/UseCases/EvaluateHealthInsightUseCase.swift` | Modify | PR+구간+레벨 보상 알림 문구 생성 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | Modify | 운동 종료 후 통합 보상 평가 + 알림 발송 |
| `DUNE/Presentation/Activity/ActivityViewModel.swift` | Modify | 보상 요약/달성 히스토리 로딩 |
| `DUNE/Presentation/Activity/ActivityDetailDestination.swift` | Modify | Achievement History 목적지 추가 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Modify | 달성 히스토리 섹션 + 상세 진입 |
| `DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift` | Modify | PR 섹션에 레벨/배지 요약 노출 |
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Modify | 보상 요약 노출(선택) |
| `DUNETests/PersonalRecordServiceTests.swift` | Modify | 구간 판정/대표 이벤트/레벨업 테스트 추가 |
| `DUNETests/EvaluateHealthInsightUseCaseTests.swift` | Modify | 통합 보상 알림 생성 테스트 추가 |

## Implementation Steps

### Step 1: Reward Domain 규칙 확장

- **Files**: `WorkoutActivityType.swift`, `PersonalRecord.swift`
- **Changes**:
  - 운동 타입별 구간 metric(distance/steps/duration) 및 고정 threshold 정의
  - 보상 이벤트/레벨 상태 모델 정의
- **Verification**: 구간 판정 및 threshold 경계값 테스트

### Step 2: Store 기반 보상 상태/히스토리 구현

- **Files**: `PersonalRecordStore.swift`
- **Changes**:
  - activityType별 최고 달성 구간 저장
  - 보상 이벤트 append + 중복 방지
  - 배지 수/레벨 계산(포인트 누적) 및 대표 이벤트 선택
- **Verification**: 동일 세션 다중 달성 시 대표 1건 선택, 레벨업 반영 테스트

### Step 3: Background 알림 통합

- **Files**: `BackgroundNotificationEvaluator.swift`, `EvaluateHealthInsightUseCase.swift`
- **Changes**:
  - 기존 PR 탐지에 구간/레벨 보상 결합
  - 대표 이벤트 기반 workoutPR 알림 메시지 생성
  - route는 기존 workoutDetail 유지
- **Verification**: 이벤트 없음/PR만/구간만/동시달성 케이스 테스트

### Step 4: Activity 화면 확장

- **Files**: `ActivityViewModel.swift`, `ActivityView.swift`, `ActivityDetailDestination.swift`, `PersonalRecordsSection.swift`, `PersonalRecordsDetailView.swift`
- **Changes**:
  - PR 화면에 레벨/배지 현황 추가
  - Achievement History 섹션 및 상세 화면 연결
- **Verification**: Activity 탭에서 요약 노출 + 히스토리 네비게이션 동작 확인

### Step 5: Quality Check + Review + Docs

- **Files**: 테스트/문서/PR 메타
- **Changes**:
  - xcodebuild test 실행
  - 6관점 리뷰 체크리스트 기반 자체 점검
  - solution 문서 작성 + 커밋
- **Verification**: 테스트 통과, P1 없음

## Edge Cases

| Case | Handling |
|------|----------|
| 한 세션에서 여러 구간 달성 | 대표 이벤트 1건만 선택하여 알림 |
| PR + 구간 동시 달성 | 우선순위 규칙으로 대표 이벤트 결정 (레벨업 > 신규 배지 > PR > 구간) |
| 동일 workout 재평가(중복 동기화) | workoutID 기반 idempotency key로 중복 히스토리 방지 |
| stepCount 미수집 운동 | distance/duration fallback 구간 판정 |
| 알림 비활성/권한 거부 | 히스토리는 저장, 알림만 미발송 |

## Testing Strategy

- Unit tests:
  - 구간 threshold 경계값
  - 대표 이벤트 선택 규칙
  - 레벨 포인트 누적/레벨업
  - 통합 알림 메시지 생성
- Integration tests:
  - Background evaluator의 workout sample 처리에서 route/workoutID 유지
- Manual verification:
  - Activity 탭 PR 요약/달성 히스토리 표시
  - 알림 탭 시 workout detail route 동작

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 운동별 구간 규칙 과도 단순화 | Medium | Medium | category 기반 기본 규칙 + future 확장 포인트 확보 |
| 백그라운드 평가에서 통계 필드 부족 | Medium | Medium | distance/duration fallback 유지 |
| UserDefaults 데이터 스키마 변경 호환성 | Low | Medium | decode 실패 시 safe reset + 기본값 복구 |
| 알림 메시지 과다/혼란 | Medium | Medium | 대표 1건 정책 강제 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 PR/알림 기반이 이미 있어 확장 경로는 명확하지만, "모든 운동" 구간 규칙의 실효성은 실제 데이터 분포 검증이 필요하다.
