---
topic: life-tab-healthkit-auto-achievements
date: 2026-03-04
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-life-tab-exercise-auto-achievements.md
---

# Implementation Plan: Life 탭 HealthKit 자동 달성

## Context
Life 탭의 기존 습관 추적은 수동 입력 중심이라, 운동 기록 기반 주간 목표 달성(5회/7회, 근력, 부위별, 러닝 거리)을 자동으로 보여주지 못한다.  
요구사항은 `New Habit`과 분리된 자동 시스템, HealthKit 기반 집계, 월요일 시작, 소급 적용, 전 규칙 포함이다.

## Requirements

### Functional

- 자동 달성 규칙 엔진 추가:
  - 주간 운동 5회 이상
  - 주간 운동 7회 이상
  - 주간 근력 운동 3회 이상
  - 주간 부위별 근력 3회 이상(가슴/등/하체/어깨/팔)
  - 주간 러닝 15km 이상
- `Life` 탭에서 사용자 수동 습관과 별도의 자동 달성 섹션 노출
- 월요일 시작 기준으로 주간 진행률/달성 여부 계산
- 과거 HealthKit 연동 운동 기록으로 streak 소급 반영

### Non-functional

- 기존 Life 탭 수동 Habit CRUD 동작 회귀 없음
- O(N) 단순 집계로 충분히 빠르게 동작 (모바일 로컬 데이터 규모 기준)
- SwiftData 모델 스키마 변경 없이 구현해 migration 리스크 최소화

## Approach

`ExerciseRecord` 중 HealthKit 연동 레코드(`healthKitWorkoutID` 보유 또는 `isFromHealthKit=true`)를 대상으로,  
도메인 서비스에서 주간 지표를 계산하여 `LifeViewModel`의 별도 상태로 전달한다.

- 장점:
  - 기존 HabitDefinition/HabitLog 구조를 건드리지 않아 안정적
  - `New Habit`과 시각적으로 분리된 자동 시스템 구현 가능
  - 소급 적용은 히스토리 집계만으로 즉시 제공 가능

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 자동 달성을 HabitDefinition/HabitLog로 영속화 | 기존 UI 재활용 용이 | 스키마/마이그레이션 필요, 중복/삭제 동기화 복잡 | 기각 |
| HealthKit 쿼리를 Life 탭에서 직접 수행 | 데이터 원천 명확 | 권한/비동기/에러 처리 복잡, 테스트 난이도 상승 | 보류 |
| HealthKit 연동 ExerciseRecord 기반 계산 | 구현 단순, 테스트 용이, 소급 쉬움 | HK write 실패 레코드 누락 가능 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/LifeAutoAchievementService.swift` | add | 주간 자동 달성 규칙 계산 서비스 추가 |
| `DUNE/Domain/Models/HabitType.swift` | update | 자동 달성 표시용 Progress DTO 확장 |
| `DUNE/Presentation/Life/LifeViewModel.swift` | update | 자동 달성 계산 상태/메서드 추가 |
| `DUNE/Presentation/Life/LifeView.swift` | update | 자동 달성 섹션 UI 추가 + recalculate 연동 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | add | 규칙 엔진 단위 테스트 추가 |
| `DUNETests/LifeViewModelTests.swift` | update | ViewModel 연동 회귀 테스트 보강 |

## Implementation Steps

### Step 1: 규칙 엔진 추가

- **Files**: `DUNE/Domain/UseCases/LifeAutoAchievementService.swift`
- **Changes**:
  - 월요일 시작 주간 계산 유틸
  - HealthKit 연동 레코드 필터링 + 중복 제거
  - 각 규칙별 진행률/달성/streak 계산
- **Verification**:
  - 서비스 단위 테스트로 규칙별 pass/fail 검증
  - 주 경계 테스트(월요일 기준) 검증

### Step 2: ViewModel 연결

- **Files**: `DUNE/Presentation/Life/LifeViewModel.swift`, `DUNE/Domain/Models/HabitType.swift`
- **Changes**:
  - 자동 달성 Progress 상태 추가
  - recalculate 루틴에서 수동 습관 계산과 분리된 자동 계산 실행
- **Verification**:
  - 기존 Habit 생성/검증 테스트 회귀 없음
  - 자동 달성 목록 비어있지 않은 케이스 추가

### Step 3: Life 탭 UI 분리

- **Files**: `DUNE/Presentation/Life/LifeView.swift`
- **Changes**:
  - `Auto Workout Achievements` 섹션 추가
  - 사용자 Habit 목록과 시각 분리
  - recalculate 시 운동 기록 변화에 따라 자동 갱신
- **Verification**:
  - 수동 Habit CRUD/토글/입력 동작 유지
  - 자동 섹션이 read-only로 표시되는지 확인

### Step 4: 테스트/검증

- **Files**: `DUNETests/LifeAutoAchievementServiceTests.swift`, `DUNETests/LifeViewModelTests.swift`
- **Changes**:
  - 규칙별 경계값 및 소급(streak) 검증
  - 월요일 시작 주차 검증
- **Verification**:
  - `xcodebuild test`로 관련 테스트 통과 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 동일 HealthKit workout 중복 레코드 | workout ID 기반 dedup |
| 거리 단위 혼재 | 비정상 큰 값(m 단위 추정) km 환산 방어 |
| 근육 정보가 없는 근력 운동 | activityType/category 기반 보조 판정 |
| 과거 데이터 없음 | 진행률 0, streak 0으로 안정 표시 |

## Testing Strategy

- Unit tests: 규칙 엔진 (운동 횟수/거리/근력/부위별/소급)
- Integration tests: LifeViewModel의 자동 progress 갱신
- Manual verification: Life 탭에서 자동 섹션 렌더링 + 수동 habit 동작 회귀 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| HK write 실패 레코드 누락 | Medium | Medium | `isFromHealthKit` + `healthKitWorkoutID` 동시 지원 |
| 근력 분류 오탐/미탐 | Medium | Medium | muscle + activityType 복합 판정 |
| 대량 기록에서 계산 비용 증가 | Low | Medium | 단순 집계 + dedup 1회 스캔 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 아키텍처를 유지하며 도메인 서비스 추가로 요구사항을 충족할 수 있고, 스키마 변경이 없어 회귀 리스크가 낮다.
