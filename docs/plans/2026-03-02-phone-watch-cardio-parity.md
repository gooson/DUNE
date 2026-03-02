---
topic: phone-watch-cardio-parity
date: 2026-03-02
status: draft
confidence: medium
related_solutions:
  - architecture/2026-03-02-ios-cardio-live-tracking.md
  - healthkit/ios-cardio-live-tracking.md
related_brainstorms:
  - 2026-03-02-phone-watch-cardio-parity.md
---

# Implementation Plan: Phone/Watch Cardio Parity

## Context

iPhone에서 앱 내부 시작으로 생성된 유산소 기록(특히 달리기) 상세 화면이 워치/Apple Fitness 대비 지표가 적게 보이는 케이스가 있다. 현재는 값이 없으면 핵심 카드를 숨기기 때문에, 같은 유산소라도 운동별/기기별 UX가 달라 보인다.

## Requirements

### Functional

- 거리 기반 유산소(달리기/걷기 등)는 상세 헤더에서 거리(km)를 항상 노출한다(값 없으면 0.00 + 안내 맥락).
- 심박/페이스 카드가 값 누락 시에도 일관된 레이아웃을 유지하고 안내 텍스트를 제공한다.
- iPhone 저장 경로에서 HealthKit write 시 activity type을 명시적으로 전달해 기록 타입 일관성을 높인다.
- 한국어 운동명 기반 매핑에도 안전하게 동작한다.

### Non-functional

- 기존 HealthKit Query 방어 로직(range/finite guard) 유지
- SwiftUI 레이아웃 회귀 없이 iPhone/Watch 비교 시 정보 구조 정합성 개선
- 기존 테스트 패턴(Swift Testing) 준수

## Approach

1. `HealthKitWorkoutDetailView`에 “distance-based 핵심 카드 고정 + no-data 안내” 규칙을 추가한다.
2. `HealthKitWorkoutDetailViewModel`에서 heart-rate fallback 표시값(요약 카드용)을 계산하게 하여 UI 분기 단순화.
3. cardio 저장/쓰기 경로(`CardioSessionSummaryView`, `WorkoutSessionView`, `CompoundWorkoutView`)에서 `WorkoutWriteInput.activityType`을 명시 전달한다.
4. `ExerciseCategory.hkActivityType` 키워드 매핑에 한국어 별칭을 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 상세뷰에서 값 없으면 기존처럼 숨김 유지 | 변경 범위 최소 | 폰/워치 체감 불일치 유지 | 기각 |
| HealthKit Query에서 누락 데이터를 강제 추정 | 카드 수치 풍부 | 정확도/신뢰성 저하 위험 | 기각 |
| 표시 규칙 통일 + no-data 안내 + activityType 명시 전달 | UX 일관성 + 데이터 품질 개선 | UI/쓰기 경로 동시 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift` | Modify | 거리/심박/페이스 카드 표시 규칙 통일, no-data 안내 카드 추가 |
| `DUNE/Presentation/Exercise/HealthKitWorkoutDetailViewModel.swift` | Modify | HR summary fallback 계산용 표시 헬퍼 추가 |
| `DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift` | Modify | WorkoutWriteInput에 activityType 전달 |
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | Modify | WorkoutWriteInput에 activityType/distanceKm 전달 |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | Modify | WorkoutWriteInput에 activityType/distanceKm 전달 |
| `DUNE/Data/HealthKit/ExerciseCategory+HealthKit.swift` | Modify | 한국어 운동명 키워드 매핑 보강 |
| `DUNETests/HealthKitWorkoutDetailViewModelTests.swift` | New | 상세뷰 표시 fallback 규칙 테스트 |
| `DUNETests/WorkoutWriteServiceTests.swift` | Modify | 한국어 이름 매핑, activityType 전달 영향 검증 |

## Implementation Steps

### Step 1: Detail 표시 규칙 통일

- **Files**: `HealthKitWorkoutDetailView.swift`, `HealthKitWorkoutDetailViewModel.swift`
- **Changes**:
  - 거리 기반 활동은 헤더 거리 항목을 항상 노출
  - Avg/Max HR, Avg Pace 카드에서 값이 없으면 `No data` 안내 텍스트 표시
  - HR 카드 값은 `WorkoutSummary` 우선, 없으면 `viewModel.heartRateSummary` fallback
- **Verification**: 달리기(거리/심박 없음)와 걷기(데이터 있음) 샘플 각각에서 카드 수/배치 일관성 확인

### Step 2: HealthKit write activity type 정합성 강화

- **Files**: `CardioSessionSummaryView.swift`, `WorkoutSessionView.swift`, `CompoundWorkoutView.swift`
- **Changes**:
  - `WorkoutWriteInput` 생성 시 `activityType` 명시 전달
  - 가능한 경우 거리(`distanceKm`)도 전달
- **Verification**: 저장 입력값 생성 코드 경로에서 cardio가 `.other` fallback으로 빠지지 않는지 확인

### Step 3: 이름 매핑 보강 + 테스트

- **Files**: `ExerciseCategory+HealthKit.swift`, `WorkoutWriteServiceTests.swift`, `HealthKitWorkoutDetailViewModelTests.swift`
- **Changes**:
  - running/walking/cycling/swimming/hiking/rowing/elliptical/dance 등 한국어 키워드 매칭 추가
  - 표시 fallback 및 매핑 회귀 테스트 추가
- **Verification**: `xcodebuild test`로 신규/수정 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| 0초~1분 짧은 세션으로 거리 샘플 없음 | 거리 카드는 유지(0.00 또는 No data 맥락), 페이스는 No data |
| iPhone 단독 세션으로 HR 없음 | HR 카드에 No data, 심박수 차트는 기존 placeholder 유지 |
| 운동명 로컬라이즈 문자열(예: 러닝, 걷기) | 한국어 키워드 매핑으로 activityType 추론 보강 |
| non-distance 운동 | 거리/페이스 고정 카드 규칙 적용 제외 |

## Testing Strategy

- Unit tests: `HealthKitWorkoutDetailViewModelTests`, `WorkoutWriteServiceTests`
- Integration tests: 없음(HealthKit 실제 쿼리/쓰기는 단위 테스트 범위 밖)
- Manual verification:
  - iPhone에서 달리기/걷기 기록 상세 화면 비교
  - 데이터 없음 상태에서 안내 문구 및 레이아웃 유지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| no-data 카드 추가로 시각적 밀도 증가 | Medium | Low | 기존 카드 스타일 유지, 텍스트 최소화 |
| activityType 강제 전달이 일부 수동 기록과 충돌 | Low | Medium | 기존 fallback 로직 유지 + 매핑 테스트 추가 |
| 한국어 키워드 과매칭 | Low | Low | 대표 키워드만 최소 추가하고 테스트로 고정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: UI 일관성과 write 정합성은 개선 가능성이 높지만, iPhone 센서 한계(심박 미수집)로 모든 지표를 워치 수준으로 완전 일치시키는 데는 물리적 제약이 있다.
