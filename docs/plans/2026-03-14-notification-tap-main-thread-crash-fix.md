---
topic: notification-tap-main-thread-crash-fix
date: 2026-03-14
status: draft
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-13-notification-cold-start-crash-fix.md
  - docs/solutions/general/2026-03-14-notification-navigation-double-task-fix.md
  - docs/solutions/architecture/2026-03-12-notification-ingress-mainactor-hardening.md
related_brainstorms: []
---

# Implementation Plan: Notification Tap Main-Thread Crash Fix

## Context

OS 알림센터에서 알림을 탭해 앱이 cold-start 되는 경로에서 `NSInternalInconsistencyException: Call must be made on main thread`
크래시가 발생한다. 현재 로그는 `AppNotificationCenterDelegate`에서 payload를 main actor로 넘기고,
`NotificationInboxManager`가 `notificationHub` fallback request를 emit하는 지점까지는 정상임을 보여 준다.

추가로 Apple SwiftUI 문서 기준 `View.task(id:_:)` 는 `nonisolated` modifier이며 action은 `@isolated(any)` async closure다.
현재 `ContentView`의 cold-start fallback은 `.task(id: launchExperienceReady)` 내부에서 `await Task.yield()` 이후
`handleNotificationNavigationRequest()` 를 호출한다. 첫 suspension 이후 재개 executor는 main actor로 고정되지 않으므로,
그 안에서 `@State`, `selectedSection`, `NavigationPath` 를 직접 변경하면 UIKit/SwiftUI navigation update가 background thread에서
실행될 수 있다.

## Requirements

### Functional

- OS notification tap cold-start 경로에서 앱이 크래시하지 않아야 한다.
- route-less notification fallback(`notificationHub`)이 기존처럼 Today 탭의 inbox를 열어야 한다.
- 기존 workout / sleep / personal records notification routing 동작을 유지해야 한다.

### Non-functional

- notification navigation state mutation의 actor contract를 코드상 명시해야 한다.
- 기존 warm-start / `.onReceive` delivery fix와 충돌하지 않아야 한다.
- regression을 unit test로 고정해야 한다.

## Approach

notification navigation state write를 `@MainActor` helper 경계 안으로 모으고, cold-start `.task(id:)` fallback에서는
`await MainActor.run { ... }` 으로만 진입하도록 바꾼다. 동시에 direct helper contract를 unit test로 추가해
post-yield executor drift가 다시 들어와도 UI mutation 경계가 무너지지 않도록 고정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `.task(id:)` 에서 `handleNotificationNavigationRequest()` 호출만 `await MainActor.run` 으로 감싼다 | 최소 수정 | 다른 call site는 여전히 contract가 암묵적이고 future regression 방어가 약함 | Rejected |
| `ContentView` 전체를 `@MainActor` 로 승격한다 | actor contract가 넓게 보장됨 | View 전체 격리가 과도하고 unrelated async paths까지 제약할 수 있음 | Rejected |
| notification navigation state mutation helper를 `@MainActor` 로 추출하고 cold-start task는 그 helper로만 진입 | 필요한 범위만 명시적 격리, 테스트 seam 확보, 기존 warm path 유지 | helper 분리와 테스트 보강이 필요함 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/ContentView.swift` | modify | notification navigation state mutation을 `@MainActor` helper로 고정하고 cold-start task에서 main actor 진입 경계를 명시 |
| `DUNETests/NotificationPresentationPlannerTests.swift` | modify | notification navigation state application / main-actor contract regression test 추가 |
| `docs/solutions/general/2026-03-14-notification-tap-main-thread-crash-fix.md` | add | 원인과 예방 패턴 문서화 |

## Implementation Steps

### Step 1: MainActor navigation application helper 도입

- **Files**: `DUNE/App/ContentView.swift`
- **Changes**:
  - notification presentation plan을 pure helper로 계산하는 기존 구조는 유지
  - 실제 `@State` / `NavigationPath` mutation을 담당하는 helper를 `@MainActor` 로 분리
  - `.task(id: launchExperienceReady)` 에서는 `await MainActor.run` 으로만 해당 helper를 호출
  - 필요 시 logging을 보강해 cold-start path 진입 여부를 구분
- **Verification**: cold-start fallback call site에서 post-yield 이후 UI state write가 main actor helper 경유로만 수행되는지 코드 확인

### Step 2: Regression test 보강

- **Files**: `DUNETests/NotificationPresentationPlannerTests.swift`
- **Changes**:
  - notificationHub / sleepDetail / workoutDetail plan application 결과를 pure state object 또는 helper 수준에서 검증
  - main actor helper가 Today/Train/Wellness path mutation을 기대대로 적용하는지 테스트
- **Verification**: `swift test` 또는 targeted `xcodebuild test` 에서 신규 테스트 통과

### Step 3: Solution doc 업데이트

- **Files**: `docs/solutions/general/2026-03-14-notification-tap-main-thread-crash-fix.md`
- **Changes**:
  - `Task.yield()` 이후 actor drift와 SwiftUI `.task(id:)` contract를 정리
  - cold-start notification navigation 규칙을 prevention에 추가
- **Verification**: 문서 frontmatter + Problem / Solution / Prevention 구조 확인

## Edge Cases

| Case | Handling |
|------|----------|
| route-less notification이 hub fallback으로 열리는 경우 | `notificationHub` plan 적용이 main actor helper에서 Today 선택 + hub signal 증가로 유지 |
| cold-start task가 launch gating 이후 재시작되는 경우 | pending request consume는 기존 dedup 유지, state mutation만 main actor로 강제 |
| `.onReceive` / scenePhase fallback과 cold-start task가 경쟁하는 경우 | 기존 consume dedup 로직 유지, helper는 idempotent state application만 담당 |
| warm-start path | 기존 synchronous `.onReceive` 경로 유지, helper의 `@MainActor` contract만 추가 |

## Testing Strategy

- Unit tests: `NotificationPresentationPlannerTests` 또는 인접 테스트 파일에 notification state application regression 추가
- Integration tests: targeted notification routing unit tests 재실행
- Manual verification: 앱 종료 상태에서 route-less notification 탭 → Today 탭 notification hub 진입 및 crash 없음 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| helper 분리 과정에서 warm-start routing regression | Low | Medium | plan/path pure logic 유지, 기존 routing tests와 신규 regression test 함께 실행 |
| `MainActor.run` 추가로 cold-start navigation이 한 frame 늦어짐 | Low | Low | 기존에도 launch gate + `Task.yield()` 가 있어 체감 차이 미미 |
| 테스트 seam이 UI state 구조와 너무 강하게 결합 | Medium | Low | pure plan/application helper 수준으로 한정해 View body 자체는 테스트하지 않음 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 로그상 ingress는 이미 main actor로 들어오고, Apple docs상 `.task(id:)` 는 nonisolated async action이다. 현재 구현의 유일한 post-yield UI mutation 경로가 cold-start fallback이므로 크래시 조건과 일치한다.
