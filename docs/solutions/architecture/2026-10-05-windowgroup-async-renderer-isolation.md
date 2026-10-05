---
tags: [swiftui, swift-concurrency, mainactor, windowgroup, async-renderer, crash]
category: architecture
date: 2026-10-05
status: implemented
severity: critical
related_files: [DUNE/App/DUNEApp.swift]
related_solutions: []
---

# Solution: WindowGroup lazy builder의 MainActor 검사 크래시

## Problem

My Mac (Designed for iPad) 실행 중 `com.apple.SwiftUI.AsyncRenderer`에서
`EXC_BREAKPOINT`가 발생했다. 제공된 backtrace는 다음 경로를 보였다.

`SwiftUI.LazyView.body` → `closure #1 in DUNEApp.body.getter` →
`swift_task_isCurrentExecutorWithFlagsImpl` → `_dispatch_assert_queue_fail`

`DUNEApp.body`에서 작성한 `WindowGroup` 콘텐츠 클로저가 MainActor 격리를
상속하지만, SwiftUI의 lazy scene content 평가가 AsyncRenderer에서 수행되어
실행 큐 검사가 실패했다. Xcode 27 SDK의 `WindowGroup(makeContent:)`는
`nonisolated`이며 `@escaping () -> Content`를 내부 lazy initializer에 전달한다.
HealthKit unavailable 및 CloudKit refresh 로그 자체는 이 스택의 직접 실패 지점이 아니다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | 기존 콘텐츠를 `windowContent`로 추출하고 `nonisolated makeWindowGroup(content:)` 추가 | actor 상태 접근과 lazy builder 실행 경계 분리 |

`DUNEApp.body`의 MainActor 컨텍스트에서 콘텐츠를 먼저 구성한다.
`nonisolated` helper 내부에서 만들어진 lazy builder는 전달받은 View 값만 반환한다.
기존 splash, sheet, notification handler와 scene의 modelContainer 연결은 유지한다.

```swift
var body: some Scene {
    Self.makeWindowGroup(content: windowContent)
        .modelContainer(appRuntime.modelContainer)
}

nonisolated private static func makeWindowGroup<Content: View>(content: Content) -> WindowGroup<Content> {
    WindowGroup { content }
}
```

### Verification

- Xcode 27 / Swift 6 최소 재현 패턴을 `swiftc -emit-silgen`으로 비교:
  기존 MainActor getter 내부 클로저에는 `_checkExpectedExecutor`가 있고,
  수정한 nonisolated helper 내부 클로저에는 없다.
- `git diff --check` 통과.
- 최초 빌드는 sandbox의 `sandbox_apply: Operation not permitted`로 매크로
  플러그인 실행이 실패했다. 권한 확장 후 동일 스크립트로 1회 재시도.
- `scripts/build-ios.sh --no-regen --log-file .xcodebuild/async-renderer-build.log`
  통과 (`BUILD SUCCEEDED`, generic iOS, code signing 비활성화).
- 사용자가 My Mac (Designed for iPad) 대상으로 재실행 후 크래시가 발생하지
  않음을 확인했다. 백그라운드/포그라운드 전환을 포함한 전체 UI 회귀는 별도 미실행.
- View/Scene 구성 변경이므로 비즈니스 로직 단위 테스트는 추가하지 않았다.
  SIL 비교는 actor 검사 생성 확인이며 UI 실행 성공을 의미하지 않는다.

## Prevention

- lazy scene builder에서 actor 상태를 읽기 전에 실행 경계를 확인한다.
- `MainActor.assumeIsolated`, `DispatchQueue.main.sync`, 런타임 검사 비활성화로
  잘못된 실행 큐를 우회하지 않는다.
- helper 클로저에 App 상태 접근이나 service 호출을 다시 추가하지 않는다.
- 단순한 콘텐츠 반환도 MainActor 컨텍스트에서 클로저를 만들면 격리를
  상속할 수 있으므로 생성 위치를 함께 검토한다.

## Lessons Learned

MainActor에서 선언한 UI 코드라도 framework가 보관한 escaping closure의
실제 호출 큐는 별도로 확인해야 한다. 컴파일러 SIL 비교로 격리 검사의 생성 여부를
확인할 수 있지만, 원래 OS와 렌더링 조건에서의 실행 검증을 대체하지 않는다.
