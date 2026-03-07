---
tags: [notification, navigation, tabview, navigationstack, navigationpath, swiftui, regression, navbar]
date: 2026-03-08
category: architecture
status: implemented
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNETests/NotificationExerciseDataTests.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - DUNEUITests/Smoke/ActivitySmokeTests.swift
  - docs/corrections-active.md
related_solutions:
  - docs/solutions/architecture/2026-03-08-notification-root-push-from-current-screen.md
  - docs/solutions/general/2026-03-08-review-followup-state-and-migration-fixes.md
---

# Tab-Scoped Notification Push Preserves Navigation Bar

## Problem

`activityPersonalRecords` 알림을 현재 화면 위로 push하려고 `TabView` 바깥에 전역 `NavigationStack`을 추가한 뒤, iOS 탭 화면의 navigation bar/toolbar가 사라졌다.

사용자는 탭 내용은 볼 수 있지만 `Today`, `Activity` 타이틀과 주요 toolbar action이 빠진 상태를 보게 되었다.

## Root Cause

탭 기반 구조에서 각 탭은 이미 자신의 root `NavigationStack`을 가지고 있었다.

그 바깥에 또 다른 `NavigationStack`을 감싸자, SwiftUI가 바깥 stack을 상위 navigation owner로 해석했고, 탭 내부 stack이 담당하던 navigation chrome이 정상적으로 드러나지 않았다.

추가로 각 탭은 이미 `ConditionScore`, `WeatherSnapshot`, `ActivityDetailDestination`, `WellnessScoreDestination` 등 여러 타입의 `NavigationLink(value:)`를 함께 사용하고 있었다. 알림 push용 경로를 typed array로 고정하면 이 heterogeneous navigation 패턴과 충돌할 수 있어, 최종 해법은 tab-scoped `NavigationPath`를 써야 했다.

## Solution

전역 outer stack을 제거하고, 각 탭 root `NavigationStack(path:)`에 동일한 notification destination을 연결했다.

push가 필요할 때는 현재 선택된 탭의 `NavigationPath`만 채우고, 탭 전환/허브 이동 같은 non-push 요청은 모든 탭 path를 먼저 비운다. 이렇게 하면 "현재 화면 위 push" UX는 유지하면서도 탭별 navigation bar ownership은 깨지지 않는다. `NavigationPath`를 쓰면서 기존 탭의 mixed value navigation도 그대로 유지된다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/ContentView.swift` | `NotificationPresentationPaths`를 `NavigationPath` 기반으로 추가, outer `NavigationStack` 제거, tab-scoped path binding 적용 | 현재 탭에서만 알림 상세 push하고 기존 nav bar + mixed value navigation 유지 |
| `DUNETests/NotificationExerciseDataTests.swift` | tab-scoped path reset/store 테스트 추가 | 탭별 path 격리 계약 고정 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | `Today` navigation bar 존재 확인 추가 | nav bar 회귀 직접 감지 |
| `DUNEUITests/Smoke/ActivitySmokeTests.swift` | `Activity` navigation bar 존재 확인 강화 | toolbar만이 아니라 navigation chrome 자체를 검증 |
| `docs/corrections-active.md` | notification push/navigation ownership correction 업데이트 | 같은 구조 회귀 재발 방지 |

### Key Code

```swift
struct NotificationPresentationPaths {
    var today = NavigationPath()
    var train = NavigationPath()
    var wellness = NavigationPath()
    var life = NavigationPath()
}

private func notificationPathBinding(for section: AppSection) -> Binding<NavigationPath> {
    Binding(
        get: { notificationPresentationPaths.path(for: section) },
        set: { notificationPresentationPaths.updatePath($0, for: section) }
    )
}
```

## Prevention

### Checklist Addition

- [ ] `TabView` 기반 iOS 앱에서 overlay push가 필요해도 바깥에 새 `NavigationStack`을 감싸지 않는다.
- [ ] 기존 탭이 여러 `NavigationLink(value:)` 타입을 쓰고 있다면 알림/딥링크 경로 상태는 typed array 대신 `NavigationPath`로 유지한다.
- [ ] 전역 이벤트 상세는 "global stack"보다 "active tab stack path"에 push하는 쪽을 기본 패턴으로 삼는다.
- [ ] 탭 화면 smoke test에 navigation bar title 존재 검증을 넣어, 컨텐츠만 보이고 chrome이 사라지는 회귀를 조기에 잡는다.

### Rule Addition (if applicable)

`docs/corrections-active.md`에 다음 교정을 반영했다.

- `TabView` 바깥에 전역 `NavigationStack` 추가 금지 (#226)
- tab-scoped push 라우터와 tab 전환 라우터를 섞을 때 non-push 요청은 모든 tab path를 먼저 비운다 (#225)

## Related

- 이 해결책은 같은 날의 `notification-root-push-from-current-screen` 접근을 nav-bar-safe 구조로 치환한다.

## Lessons Learned

- SwiftUI navigation 회귀는 "화면이 뜨는가"만으로는 잡히지 않는다. navigation bar/title/toolbar 존재를 따로 확인하는 smoke test가 필요하다.
- 알림용 overlay push를 추가할 때도 기존 탭의 navigation ownership과 value-type 분포를 먼저 봐야 한다.
- tab root가 이미 heterogeneous value navigation을 쓰고 있으면, path state도 그 현실에 맞는 `NavigationPath`로 맞춰야 안전하다.
