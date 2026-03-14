---
topic: notification main-thread publisher hardening
date: 2026-03-14
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
  - docs/solutions/architecture/2026-03-12-cloudkit-remote-change-mainactor-ingress.md
  - docs/solutions/general/2026-03-14-notification-navigation-double-task-fix.md
related_brainstorms: []
---

# Implementation Plan: Notification Main-Thread Publisher Hardening

## Context

`Publishing changes from background threads is not allowed` 경고가 notification-driven UI refresh 이후 계속 남았다.
기존 수정은 `.onReceive` 내부에서 `Task { @MainActor in ... }`로 state mutation만 감쌌지만,
`NotificationCenter.Publisher` 자체의 delivery thread는 background일 수 있어 ingress contract가 완전히 닫히지 않았다.

이번 작업은 notification publisher 자체를 main run loop에 고정하고, 그 과정에서 verification을 막던
기존 test/build blocker도 함께 정리해 pipeline을 끝까지 닫는 것을 목표로 한다.

## Requirements

### Functional

- NotificationCenter 기반 `.onReceive` 경로에서 SwiftUI state mutation이 main-thread delivery를 보장해야 한다.
- 기존 notification navigation, inbox refresh, simulator mock refresh, power-state update 동작은 유지되어야 한다.
- `CalculateTrainingReadinessUseCase.Input`, `CalculateWellnessScoreUseCase.Input`가 evaluation date를 주입할 수 있어 테스트 계약과 구현이 일치해야 한다.
- DUNEVision build에서 사용하지 않는 AI template generator 의존성이 빌드를 깨지 않도록 타깃 구성이 정리되어야 한다.

### Non-functional

- 변경 범위는 notification ingress와 verification blocker 정리에 한정한다.
- 기존 navigation timing fix, refresh coordinator 흐름, view model 동작은 바꾸지 않는다.
- 회귀 테스트와 문서가 현재 구현 계약과 일치해야 한다.

## Approach

`NotificationCenter`에 `mainThreadPublisher(for:)` helper를 추가해 `receive(on: RunLoop.main)`을 공용화하고,
현재 남아 있는 notification ingress는 모두 이 helper를 통해 `.onReceive` 하도록 바꾼다.

동시에 테스트가 의존하는 evaluationDate injection contract를 production Input 타입에 명시적 initializer로 복원하고,
visionOS에서 쓰지 않는 AI template generator 계열 파일은 DUNEVision target source set에서 제외한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `.onReceive`마다 `Task { @MainActor in ... }` 유지 | 최소 코드 변경 | publisher delivery thread는 여전히 background일 수 있음 | Rejected |
| 각 화면에 개별 `receive(on: RunLoop.main)` 체인 추가 | 동작은 맞음 | 중복이 많고 같은 규칙이 쉽게 누락됨 | Rejected |
| `NotificationCenter.mainThreadPublisher(for:)` 공용 helper 도입 | 선언적이며 재사용 가능, 누락 검색 쉬움 | Combine import가 한 파일 추가됨 | Selected |
| 테스트를 production API에 맞춰 `evaluationDate` 제거 | 당장 컴파일만 맞춤 | 시간대 보정 로직 검증이 사라짐 | Rejected |
| vision build blocker를 무시하고 iOS만 검증 | 작업량 적음 | vision 파일을 수정한 현재 변경의 검증이 불완전함 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/NotificationCenter+MainThread.swift` | add | main-thread notification publisher helper 추가 |
| `DUNE/App/ContentView.swift` | modify | route / simulator notification ingress를 helper 기반으로 전환 |
| `DUNE/App/DUNEApp.swift` | modify | CloudKit / ubiquitous notification ingress를 helper 기반으로 전환 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | inbox refresh ingress를 helper 기반으로 전환 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | modify | inbox refresh ingress를 helper 기반으로 전환 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | modify | power-state ingress를 helper 기반으로 전환 |
| `DUNEVision/*` 관련 view files | modify | simulator mock refresh ingress를 helper 기반으로 전환 |
| `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift` | modify | evaluationDate 주입 가능한 Input initializer 추가 |
| `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift` | modify | evaluationDate 주입 가능한 Input initializer 추가 |
| `DUNE/project.yml` | modify | DUNEVision target에서 불필요한 AI generator files 제외 |
| `DUNETests/NotificationCenterMainThreadPublisherTests.swift` | add | background-posted notification의 main-thread delivery 보장 회귀 테스트 |

## Implementation Steps

### Step 1: Notification ingress contract를 publisher 단계에서 main으로 고정

- **Files**: `DUNE/Data/Services/NotificationCenter+MainThread.swift`, `DUNE/App/ContentView.swift`, `DUNE/App/DUNEApp.swift`, dashboard/ocean/vision view files
- **Changes**:
  - `mainThreadPublisher(for:)` helper 추가
  - 기존 `.onReceive(NotificationCenter.default.publisher(for: ...))`를 helper 사용으로 치환
  - 기존 내부 로직은 유지하고, 필요한 경우에만 후속 `Task { @MainActor in ... }`를 둠
- **Verification**:
  - 검색 결과에서 notification ingress가 helper로 통일되었는지 확인
  - iOS app build 성공

### Step 2: Verification blocker였던 domain Input 계약 복원

- **Files**: `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift`, `DUNE/Domain/UseCases/CalculateWellnessScoreUseCase.swift`
- **Changes**:
  - nested `Input` struct에 explicit initializer를 추가해 `evaluationDate`를 주입 가능하게 복원
  - existing call sites는 기본값 `.now`를 그대로 사용
- **Verification**:
  - `CalculateTrainingReadinessUseCaseTests`, `CalculateWellnessScoreUseCaseTests` compile/test 통과

### Step 3: visionOS build blocker 제거

- **Files**: `DUNE/project.yml`
- **Changes**:
  - DUNEVision target의 `Data/Services` source set에서 `AIWorkoutTemplateGenerator.swift`와 관련 iOS-only AI service를 제외
  - project regeneration 후 vision scheme build 재확인
- **Verification**:
  - `scripts/lib/regen-project.sh`
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' -quiet`

### Step 4: Regression test와 문서를 현재 구현 계약에 맞춤

- **Files**: `DUNETests/NotificationCenterMainThreadPublisherTests.swift`, 관련 solution docs
- **Changes**:
  - background post -> main-thread delivery 회귀 테스트 추가
  - solution 문서에서 기존 `Task { @MainActor in ... }` 중심 설명을 publisher-level fix 기준으로 갱신
- **Verification**:
  - 테스트 file 존재 확인
  - docs 내용이 현재 코드와 일치하는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| notification이 background queue에서 연속 발행 | publisher 단계에서 main run loop delivery 보장 |
| `.onReceive` 내부에 async reload가 필요한 경우 | ingress는 helper로 main 고정, 후속 async work만 `Task { @MainActor in ... }` 유지 |
| 기존 call site가 evaluationDate를 전달하지 않는 경우 | explicit initializer default `.now`로 하위 호환 유지 |
| vision target에서 iOS-only AI service가 다시 추가되는 경우 | project.yml excludes로 source contract 명시 |

## Testing Strategy

- Unit tests: `NotificationCenterMainThreadPublisherTests`, `PersistentStoreRemoteChangeRefreshTests`, `AppNotificationCenterDelegateTests`, `CalculateTrainingReadinessUseCaseTests`, `CalculateWellnessScoreUseCaseTests`
- Integration tests: `scripts/build-ios.sh`, `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' -quiet`
- Manual verification:
  - notification/CloudKit/mock refresh 후 console에 background publish warning 미발생 확인
  - notification navigation / inbox badge / wave low-power toggle 동작 유지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| helper 도입 후 특정 화면에서 import/target 누락 | low | medium | 공용 Data/Services에 두고 build로 검증 |
| evaluationDate initializer 추가가 call site ambiguity를 만들 수 있음 | low | low | 기본값 유지, 기존 call site compile 확인 |
| vision target excludes가 과도해 필요한 파일도 빠질 수 있음 | low | medium | usage search 후 regeneration + build로 즉시 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 문제는 notification ingress contract와 verification blocker 두 축으로 좁혀졌고, 둘 다 작은 범위 수정과 명확한 build/test command로 확인 가능하다.
