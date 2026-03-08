---
tags: [swiftui, dashboard, navigation, launch, race-condition, skeleton, refresh]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
related_solutions:
  - docs/solutions/performance/2026-03-08-navigation-request-observer-clear-paths-guard.md
  - docs/solutions/architecture/2026-03-08-notification-navigation-multi-update-warning.md
---

# Solution: Dashboard First-Load Appearance Gate

## Problem

Dashboard launch 직후 `Update NavigationRequestObserver tried to update multiple times per frame.` 경고가 다시 보일 수 있었다.

### Symptoms

- 앱 시작 직후 HealthKit observer 등록 로그 뒤에 navigation multi-update 경고가 출력됨
- 사용자가 탭을 누르지 않아도 Today 화면이 skeleton에서 실제 카드 레이아웃으로 너무 일찍 전환될 수 있음

### Root Cause

`DashboardView.loadDashboard()`는 `await viewModel.loadData()` 이후 곧바로 `hasAppeared = true`를 켰다. 하지만 `DashboardViewModel.loadData()`는 이미 로딩 중이면 `guard !isLoading else { return }`로 즉시 반환한다.

이 구조에서는 launch 중 observer-driven refresh나 추가 refresh signal이 `loadDashboard()`를 재진입시킬 때, 실제 첫 로드는 아직 진행 중인데도 두 번째 호출이 빠르게 끝나며 `hasAppeared`를 먼저 켤 수 있다. 그러면 skeleton guard가 조기에 해제되고, `NavigationLink`/`navigationDestination` 트리가 첫 로드 도중 붙으면서 launch warning을 다시 유발할 수 있다.

## Solution

첫 로드 완료 조건을 "함수 호출이 끝났다"가 아니라 "ViewModel이 더 이상 로딩 중이 아니다"로 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 첫 로드 동안 `viewModel.isLoading && !hasAppeared` 조건으로 skeleton 유지 | 실제 카드 navigation tree가 중간 상태에서 붙지 않도록 보장 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `await loadData()` 직후 `guard !viewModel.isLoading else { return }` 추가 | 재진입 refresh가 첫 로드 완료를 앞당기지 못하도록 차단 |

### Key Code

```swift
private func loadDashboard() async {
    await viewModel.loadData(shouldAutoRequestHealthKitAuthorization: shouldAutoRequestHealthKitAuthorization)
    guard !viewModel.isLoading else { return }

    if !hasAppeared {
        withAnimation(.easeOut(duration: 0.3)) {
            hasAppeared = true
        }
    }
}
```

## Prevention

비동기 View helper는 "호출이 반환됐다"와 "실제 로드가 완료됐다"를 같은 의미로 취급하면 안 된다.

### Checklist Addition

- [ ] `await viewModel.loadData()` 이후 UI phase flag를 바꿀 때, underlying ViewModel이 in-flight guard로 조기 반환할 수 있는지 먼저 확인한다.
- [ ] skeleton/placeholder 해제 조건은 함수 반환이 아니라 실제 data-ready 상태(`isLoading == false`, payload ready 등)에 묶는다.
- [ ] launch/foreground refresh처럼 재진입 가능한 경로에서는 "첫 성공 로드 완료" 플래그가 중복 호출에 의해 앞당겨지지 않는지 점검한다.

### Rule Addition (if applicable)

새 규칙 파일 추가는 생략한다. 이 패턴은 Dashboard launch race에 한정된 구현 교정으로 solution 문서에 기록한다.

## Lessons Learned

SwiftUI launch warning은 navigation API를 직접 두 번 건드린 경우만이 아니라, placeholder에서 실제 navigation tree로 넘어가는 타이밍을 잘못 열어도 재현될 수 있다. 비동기 로드가 재진입 가능한 화면에서는 appearance gate를 data-ready 조건에 맞춰야 한다.
