---
topic: unit-test-coverage-hardening-followup
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-02-watch-unit-test-hardening.md
  - docs/solutions/testing/2026-03-02-locale-safe-validation-format-tests.md
  - docs/solutions/testing/2026-03-01-date-sensitive-test-boundary.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-unit-test-hardening-including-watch.md
---

# Implementation Plan: Unit Test Coverage Hardening Follow-up

## Context

Domain/Watch 모델 및 WatchConnectivity 검증 경로의 테스트 공백을 보강해 릴리즈 안정성을 높인다.  
동시에 iOS 전체 유닛 테스트 게이트에서 발견된 로케일 고정 assertion 실패를 locale-safe 방식으로 정리한다.

## Requirements

### Functional

- Domain 모델의 기본 규칙(초기화/식별자/코더블 라운드트립) 테스트 추가
- Watch 입력 검증(`validated`)의 경계/이탈 분기 보강
- Watch incoming message 파싱 플래그 분기(`requestWorkoutTemplateSync`) 검증
- Dashboard walking card 테스트를 locale-safe assertion으로 전환

### Non-functional

- Swift Testing 패턴(`@Suite`, `@Test`, `#expect`) 준수
- 기존 테스트 구조/네이밍 컨벤션 유지
- 전체 품질 게이트에서 기존 회귀를 유발하지 않을 것

## Approach

도메인 모델 공통 커버리지 테스트를 1개 파일로 집약하고, Watch 관련 기존 테스트 파일은 분기 중심으로 확장한다.  
Quality gate 실패는 기능 코드 변경 없이 테스트 assertion의 로케일 의존성만 제거해 해소한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 파일별 모델 테스트를 개별 파일로 생성 | 역할이 더 명확함 | 파일 수 과다, 유지보수 분산 | 미채택 |
| DomainModelCoverageTests로 통합 | 빠른 공백 보강, 공통 패턴 유지 | 파일 길이 증가 | 채택 |
| 로케일을 테스트 환경에서 강제(en) | 단기 해결 쉬움 | CI/로컬 환경 의존성 증가 | 미채택 |
| assertion을 `String(localized:)` 기반으로 전환 | 환경 독립, 기존 rule과 일치 | 테스트 일부 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNETests/DomainModelCoverageTests.swift` | Add | Domain/Watch 모델 커버리지 신규 테스트 |
| `DUNETests/WatchWorkoutUpdateValidationTests.swift` | Modify | RPE/duration/restDuration/HR 경계 케이스 추가 |
| `DUNETests/ParsedWatchIncomingMessageTests.swift` | Modify | `requestWorkoutTemplateSync` 플래그 파싱 검증 추가 |
| `DUNETests/DashboardViewModelTests.swift` | Modify | walking card assertion locale-safe화 |

## Implementation Steps

### Step 1: Domain/Watch 모델 테스트 공백 보강

- **Files**: `DUNETests/DomainModelCoverageTests.swift`
- **Changes**:
  - `ActiveRecoverySuggestion`, `InsightPriority`, `CoachingInsight`, `CompoundWorkoutConfig`
  - `NotificationInboxItem`, `ScoreContribution`, `TrendAnalysis`, `BodyScoreDetail`, `StreakPeriod`
  - `WatchWorkoutState/Update/ExerciseInfo/WorkoutTemplateInfo` Codable round-trip
- **Verification**:
  - `xcodebuild test-without-building ... -only-testing DUNETests/ActiveRecoverySuggestionTests ...`

### Step 2: Watch validation/message 분기 강화

- **Files**:
  - `DUNETests/WatchWorkoutUpdateValidationTests.swift`
  - `DUNETests/ParsedWatchIncomingMessageTests.swift`
- **Changes**:
  - `validated()`의 RPE 범위/heart-rate 경계/invalid duration-rest filtering 검증
  - message parser의 `requestWorkoutTemplateSync` 플래그 검증
- **Verification**:
  - `xcodebuild test-without-building ... -only-testing DUNETests/WatchWorkoutUpdateValidationTests -only-testing DUNETests/ParsedWatchIncomingMessageTests`

### Step 3: Full suite 게이트 실패(로케일 고정 assertion) 보정

- **Files**: `DUNETests/DashboardViewModelTests.swift`
- **Changes**:
  - walking card title/unit 기대값을 `String(localized:)` 기반으로 전환
- **Verification**:
  - `scripts/test-unit.sh --ios-only --no-stream-log`

## Edge Cases

| Case | Handling |
|------|----------|
| 로케일이 ko/en/ja 등으로 달라짐 | 하드코딩 문자열 비교 대신 `String(localized:)` 사용 |
| Watch payload 경계값(20/300 bpm, 0/3600 rest, 1/10 rpe) | 경계 포함/이탈 케이스 분리 검증 |
| Template entry optional 필드 누락 | Codable round-trip에서 optional 유지 확인 |

## Testing Strategy

- Unit tests:
  - 신규/보강 suite 대상 `xcodebuild test-without-building` 선검증
  - 이후 `scripts/test-unit.sh --ios-only`로 회귀 확인
- Integration tests:
  - 없음 (범위 외)
- Manual verification:
  - 없음 (테스트 코드 변경)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시뮬레이터 불안정으로 전체 스위트 중단 | Medium | Medium | `test-without-building`로 변경분 우선 검증 후 전체 실행 재시도 |
| 기존 테스트의 추가 로케일 의존 실패 | Medium | Medium | 실패 지점 발견 시 동일 패턴으로 locale-safe assertion 적용 |
| 통합 테스트 실행 시간 증가 | Low | Low | 신규 suite만 빠르게 선택 실행하는 보조 명령 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경 범위가 테스트 코드에 제한되고, 실패 원인도 명확한 assertion mismatch로 재현되어 수정/검증 경로가 명확하다.
