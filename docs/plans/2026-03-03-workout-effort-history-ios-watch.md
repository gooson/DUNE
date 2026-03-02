---
topic: workout-effort-history-ios-watch
date: 2026-03-03
status: implemented
confidence: high
related_solutions: []
related_brainstorms:
  - docs/brainstorms/2026-03-02-workout-intensity-redesign.md
---

# Implementation Plan: Workout Effort History iOS + Watch

## Context

운동 종료 시 강도(Effort, 1-10) 입력이 일부 플로우(유연성/특정 경로)에만 노출되어 일관성이 깨졌고, Apple Fitness 스타일의 "히스토리 기반 추천 + 사용자 수정 가능" UX가 iOS/Watch 양쪽에서 동일하게 제공되지 않았다.

## Requirements

### Functional

- iOS 단일 운동 종료 시 강도 추천/입력에 최근 이력을 표시한다.
- iOS 복합 운동(Compound) 종료 시에도 동일한 추천/입력이 노출된다.
- Watch 운동 종료 시에도 강도 추천/입력이 노출되고 사용자가 수정 가능해야 한다.
- Watch에서 저장/전송된 강도(`rpe`)가 iPhone 수신/저장 경로에서 유지된다.
- 추천값은 최근 히스토리 기반이며, 사용자는 추천값을 다른 값으로 변경할 수 있어야 한다.

### Non-functional

- 기존 `WorkoutIntensityService` 패턴과 입력 검증 규칙을 유지한다.
- Watch DTO 필드 추가 시 iOS/Watch 양쪽 동기화를 유지한다.
- 테스트 가능 범위(UseCase)에서 회귀를 추가 검증한다.

## Approach

공용 도메인에서는 `EffortSuggestion`에 최근 이력 컨텍스트를 추가하고, iOS 종료 UI에서는 추천 배지/최근 히스토리를 노출한다. Watch는 타깃 의존성 제약을 고려해 `SessionSummaryView` 내부에 경량 추천 모델을 두고 동일 UX를 제공한다. 데이터 파이프라인은 `rpe`를 WatchConnectivity DTO에 포함해 저장/동기화까지 연결한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Watch에서도 `EffortSuggestion`/`WorkoutIntensityService` 직접 재사용 | 로직 단일화 | Watch target 컴파일 의존성 충돌 위험 | 미선택 |
| Watch 전용 경량 추천 모델 사용 | 컴파일 안정성, 빠른 적용 | 일부 추천 로직 중복 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WorkoutIntensity.swift` | 수정 | `EffortSuggestion`에 `recentEfforts` 추가 |
| `DUNE/Domain/UseCases/WorkoutIntensityService.swift` | 수정 | 추천 생성 시 최근 이력 포함/유효성 필터 |
| `DUNE/Presentation/Exercise/Components/EffortSliderView.swift` | 수정 | 추천 배지 + 최근 이력 UI |
| `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | 수정 | Compound 종료 시 추천 계산/전달 |
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | 수정 | `WatchWorkoutUpdate.rpe` 추가 |
| `DUNEWatch/WatchConnectivityManager.swift` | 수정 | set completion 전송 시 DTO 필드 동기화 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | 수정 | 수신 `rpe` 범위 검증 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 수정 | Watch 종료 강도 UI/추천/저장/전송 |
| `DUNETests/WorkoutIntensityServiceTests.swift` | 수정 | recent history 기반 추천 테스트 강화 |

## Implementation Steps

### Step 1: 도메인 추천 모델 확장

- **Files**: `WorkoutIntensity.swift`, `WorkoutIntensityService.swift`
- **Changes**: 최근 강도 히스토리(최대 5개, 1...10) 포함 추천 모델 확장
- **Verification**: 기존 intensity 테스트 + 신규 recent history 테스트 통과

### Step 2: iOS 종료 UI/플로우 확장

- **Files**: `EffortSliderView.swift`, `CompoundWorkoutView.swift`
- **Changes**: 추천 텍스트/최근 이력 노출, Compound 저장 경로에서 추천 계산 후 시트 전달
- **Verification**: 종료 시트에서 추천 기본값 노출 + 사용자 override 가능

### Step 3: Watch 종료 UX + 데이터 파이프라인 확장

- **Files**: `SessionSummaryView.swift`, `WatchConnectivityModels.swift`, `WatchConnectivityManager.swift`, `WatchSessionManager.swift`
- **Changes**:
  - Watch 종료 화면에 추천/슬라이더/최근 이력 표시
  - Strength/Cardio 모두 `rpe` 저장
  - Watch→iOS 전송 DTO에 `rpe` 포함 및 iOS 수신 검증
- **Verification**: Watch target 빌드 성공, DTO decode/validation 경로 오류 없음

### Step 4: 품질 검증 + 문서화/배포 준비

- **Files**: 테스트/문서/PR 메타
- **Changes**: 타깃 테스트 실행, 리뷰 결과 반영, solution 문서 작성, PR 생성/머지
- **Verification**: `xcodebuild test` 성공, 리뷰 P1=0

## Edge Cases

| Case | Handling |
|------|----------|
| 히스토리가 없는 사용자 | 추천 미노출, 기본값(중간 강도)에서 수동 조정 |
| 히스토리에 잘못된 값 포함 | 1...10 범위 필터링 후 추천 계산 |
| Cardio에서 exerciseDefinitionID 부재 | Watch에서 전역 최근 이력 fallback |
| Watch 수신 데이터 오염 | iOS `validated()`에서 `rpe` nil 처리 |

## Testing Strategy

- Unit tests: `DUNETests/WorkoutIntensityServiceTests`에 recent history 추천 케이스 추가
- Integration tests: `xcodebuild test`로 iOS+Watch 포함 빌드 경로 검증
- Manual verification:
  - iOS 단일 운동 종료 시 추천/이력/수정 가능
  - iOS Compound 종료 시 추천/이력/수정 가능
  - Watch 종료 시 추천/이력/수정 가능, 저장 후 재운동 시 히스토리 반영

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Watch 타깃 의존성 누락으로 컴파일 실패 | 중간 | 높음 | Watch 전용 경량 추천 모델 사용 |
| DTO 필드 확장 시 양측 불일치 | 중간 | 중간 | 단일 DTO 파일 수정 + iOS/Watch 동시 빌드 |
| localization 누락 | 낮음 | 중간 | 리뷰 단계에서 UI 문자열 수동 점검 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 핵심 요구사항(iOS+Watch 종료 강도 추천/입력/히스토리/수정 가능)이 코드와 테스트로 반영되었고, Watch 빌드 실패 원인(공용 타입 의존성)도 구조적으로 해소했다.
