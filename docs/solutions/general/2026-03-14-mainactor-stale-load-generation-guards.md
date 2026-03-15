---
tags: [swift, concurrency, race-condition, mainactor, viewmodel, stale-response, async]
date: 2026-03-14
category: solution
status: implemented
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNE/Presentation/Activity/ActivityViewModel.swift
  - DUNE/Presentation/Shared/Detail/MetricDetailViewModel.swift
  - DUNE/Presentation/Shared/Detail/AllDataViewModel.swift
related_solutions: []
---

# MainActor ViewModel stale load 방지

## Problem

`@MainActor` ViewModel이라도 여러 `Task`가 연속으로 같은 async load 메서드를 호출하면 오래 걸린 이전 요청이 나중 요청보다 늦게 끝나면서 최신 상태를 덮어쓸 수 있다.

### Symptoms

- period 변경, pull-to-refresh, `.task(id:)` 재실행 직후 화면이 이전 데이터로 되돌아감
- 새로운 요청이 시작됐는데 이전 요청의 `defer { isLoading = false }`가 먼저 실행되어 로딩 상태가 흔들림
- `guard !isLoading else { return }` 때문에 더 최신 요청이 아예 버려짐

### Root Cause

UI 상태는 MainActor에서 직렬로 갱신되더라도, async 경계 이후 어떤 요청이 먼저 끝날지는 보장되지 않는다. 단순 `isLoading` 플래그는 "동시 실행 차단"에는 일부 도움이 되지만, "가장 최신 요청만 상태를 반영"한다는 규칙은 보장하지 못한다.

## Solution

각 재진입 가능 로더에 request generation ID를 두고, 시작 시 ID를 증가시킨 뒤 완료 시점마다 현재 요청인지 검증한다. 최신 요청이 아니면 상태 쓰기와 로딩 종료를 모두 건너뛴다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | `loadRequestID` 추가, 최신 요청만 dashboard 상태 반영 | stale dashboard snapshot이 최신 로드를 덮는 문제 방지 |
| `DUNE/Presentation/Exercise/ExerciseViewModel.swift` | reload/page load에 generation guard 추가 | refresh와 pagination 결과가 엇갈릴 때 이전 페이지 응답 차단 |
| `DUNE/Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift` | `.task(id:)` 재실행 대비 guard 추가 | 이전 HealthKit fetch가 새 입력 집합을 덮지 않게 보장 |
| `DUNE/Presentation/Wellness/WellnessViewModel.swift` 외 8개 ViewModel | 동일 패턴 적용 | period 변경, reload, infinite paging 등 재진입형 load 보호 |
| `DUNETests/*ViewModelTests.swift` | sequenced mock과 latest-wins 테스트 추가 | stale response 회귀 방지 |

### Key Code

```swift
private var loadRequestID = 0

private func beginLoadRequest() -> Int {
    loadRequestID += 1
    return loadRequestID
}

private func isCurrentLoadRequest(_ requestID: Int) -> Bool {
    requestID == loadRequestID && !Task.isCancelled
}

private func finishLoadRequest(_ requestID: Int) {
    if requestID == loadRequestID {
        isLoading = false
    }
}
```

```swift
let requestID = beginLoadRequest()
isLoading = true
defer { finishLoadRequest(requestID) }

let result = await fetch()
guard isCurrentLoadRequest(requestID) else { return }
state = result
```

## Prevention

1. 재실행될 수 있는 `async` ViewModel load 메서드에 `guard !isLoading else { return }`만 두지 않는다.
2. period 변경, refresh, pagination, `.task(id:)` 경로가 있으면 generation guard를 기본값으로 검토한다.
3. 새로운 load 로직을 추가할 때는 "older request finishes later" 회귀 테스트를 같이 만든다.

### Checklist Addition

- [ ] `@MainActor` async load가 여러 번 호출될 수 있는지 먼저 확인했다.
- [ ] 최신 요청만 상태를 반영하도록 request ID 또는 cancelation 전략을 넣었다.
- [ ] stale response 회귀 테스트를 추가했다.

## Lessons Learned

`@MainActor`는 데이터 경쟁을 줄여주지만, 사용자 의도 기준의 최신성은 보장하지 않는다. 화면 상태가 "가장 늦게 끝난 요청"이 아니라 "가장 최근에 시작된 요청"을 따라야 하는 로더는 별도의 최신 요청 규칙을 코드로 명시해야 한다.
