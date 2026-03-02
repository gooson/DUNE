---
topic: run-review-fix-batch
date: 2026-03-02
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-02-ios-cardio-live-tracking.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
  - docs/solutions/performance/2026-02-28-review-fixes-batch.md
  - docs/solutions/general/2026-03-01-localization-completion-audit.md
related_brainstorms: []
---

# Implementation Plan: Run Review Fix Batch

## Context

전수 리뷰에서 P1/P2 이슈가 확인되었다. 특히 Location 권한 continuation의 race 가능성, localization leak, watch connectivity 계층 중복 모델, 프로덕션 print 로그, 앱 시작 시 fatal 경로를 우선 해결해야 한다.

## Requirements

### Functional

- Location authorization continuation은 단일 resume를 보장한다.
- Wellness partial failure 메시지가 다국어 규칙을 준수한다.
- Watch summary helper의 string leak 경로를 제거한다.
- WatchConnectivity DTO를 단일 소스로 통합한다.
- watch/iOS startup 시 2차 ModelContainer 실패에도 앱이 즉시 crash하지 않도록 fallback을 둔다.

### Non-functional

- Swift 6 concurrency 규칙 위반 없이 구현한다.
- 기존 HealthKit/SwiftData 동작을 보존한다.
- 로그 정책(AppLogger) 일관성을 유지한다.

## Approach

기존 패턴을 최대한 유지하면서 최소 침습 변경을 적용한다.
- continuation race는 actor 전환 대신 lock-protected take/set helper로 해결
- localization은 `String(localized:)` + xcstrings 키 추가
- DTO 중복은 공통 모델 파일을 Domain 레이어에 생성하고 watch target에서 해당 파일을 shared source로 참조
- fatal 경로는 in-memory ModelContainer fallback으로 degrade

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `LocationTrackingService` 전체를 `@MainActor`로 전환 | 단순한 데이터 레이스 제거 | delegate/호출 경계 영향이 큼, 회귀 위험 | 미채택 |
| DTO 중복 유지 + 문서 경고만 추가 | 변경량 최소 | 구조적 drift 위험 지속 | 미채택 |
| 2차 ModelContainer 실패 시 fatal 유지 | 구현 단순 | production crash 지속 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Data/Location/LocationTrackingService.swift | modify | authorization continuation race fix |
| DUNE/Presentation/Wellness/WellnessViewModel.swift | modify | localized partial failure message + logger cleanup |
| DUNEWatch/Views/SessionSummaryView.swift | modify | helper parameter localization leak fix |
| DUNEWatch/WatchConnectivityManager.swift | modify | print 제거, DTO 정의 제거 |
| DUNE/Data/WatchConnectivity/WatchSessionManager.swift | modify | DTO 정의 제거 |
| DUNE/Domain/Models/WatchConnectivityModels.swift | add | shared DTO source of truth |
| DUNE/project.yml | modify | watch target shared DTO source 추가 |
| DUNE/App/DUNEApp.swift | modify | non-fatal fallback container |
| DUNEWatch/DUNEWatchApp.swift | modify | non-fatal fallback container |
| DUNE/Resources/Localizable.xcstrings | modify | partial failure message key 추가 |

## Implementation Steps

### Step 1: Concurrency + Localization P1 수정

- **Files**: `LocationTrackingService.swift`, `WellnessViewModel.swift`, `SessionSummaryView.swift`, `Localizable.xcstrings`
- **Changes**:
  - continuation set/take helper로 중복 resume 방지
  - `partialFailureMessage`를 `String(localized:)`로 전환
  - watch `statItem(title:)` 파라미터를 `LocalizedStringKey`로 전환
  - xcstrings에 신규 키(en/ko/ja) 추가
- **Verification**:
  - 정적 스캔에서 해당 leak/race 패턴 제거 확인

### Step 2: P2 구조/품질 수정

- **Files**: `WatchConnectivityManager.swift`, `WatchSessionManager.swift`, `WatchConnectivityModels.swift`, `project.yml`, `DUNEApp.swift`, `DUNEWatchApp.swift`
- **Changes**:
  - watch print 로그를 `AppLogger`로 교체
  - WatchConnectivity DTO를 공유 모델 파일로 통합
  - ModelContainer 2차 실패 시 in-memory fallback 적용
- **Verification**:
  - 중복 DTO 제거 확인
  - fatalError 경로 제거 확인

### Step 3: Quality Check + Review 재실행

- **Files**: 전체 변경 파일
- **Changes**:
  - 빌드/테스트 실행
  - 6관점 리뷰 체크리스트로 P1 재검증
- **Verification**:
  - P1 = 0 확인
  - 남은 이슈를 P2/P3로 분류

## Edge Cases

| Case | Handling |
|------|----------|
| authorization callback와 timeout 동시 도착 | lock-protected take-and-clear로 단일 resume |
| xcstrings 포맷 키 mismatch | 문자열 보간 형식으로 키 생성 후 ko/ja 동시 추가 |
| persistent store 완전 손상 | in-memory fallback으로 앱 부팅 보장 |
| watch target 컴파일 시 shared file 미포함 | project.yml에 명시 추가 |

## Testing Strategy

- Unit tests: 기존 테스트 재실행, 영향을 받는 HealthKit/WatchConnectivity 테스트 확인
- Integration tests: iOS/watch generic build 시도
- Manual verification: 정적 패턴 검사(`print(`, hardcoded user-facing string, fatalError) 재스캔

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| shared DTO 통합으로 타입 호환 문제 | medium | medium | 두 매니저 시그니처 유지 + 컴파일 확인 |
| in-memory fallback이 데이터 손실을 숨김 | low | medium | 에러 로깅을 명확히 남김 |
| xcstrings 편집 실수 | medium | low | key 단건 추가 + JSON 유효성 확인 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 변경 범위는 명확하지만 watch/iOS 타겟 동시 영향과 환경 제약(시뮬레이터 런타임 부재)으로 완전 실행 검증은 제한적이다.
