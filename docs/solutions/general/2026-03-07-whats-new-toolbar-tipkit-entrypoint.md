---
tags: [whats-new, toolbar, badge, crash, dashboard, ios26]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Persistence/WhatsNewManager.swift
  - DUNE/Data/Persistence/WhatsNewStore.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Settings/SettingsView.swift
  - DUNE/Presentation/WhatsNew/WhatsNewView.swift
  - DUNETests/WhatsNewStoreTests.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
---

# Solution: What's New 툴바 진입점 유지 + TipKit crash 회피

## Problem

Today 탭의 `What's New` 진입점을 홈 카드에서 toolbar 아이콘으로 옮긴 뒤, iOS 26 계열에서 toolbar 렌더링 경고와 함께 앱이 크래시할 수 있었다.

### Symptoms

- 콘솔에 `Unable to simultaneously satisfy constraints`가 반복 출력됨
- `_UIButtonBarButton` / `ButtonWrapper` 폭이 `0`으로 계산되는 경고가 함께 나타남
- 이후 `+[_SwiftUILayerDelegate _screen]: unrecognized selector`로 앱이 종료됨
- 재현 시점은 Today 화면 상단 toolbar가 그려질 때와 일치함

### Root Cause

`DashboardView`의 `What's New` toolbar `NavigationLink`에 `TipKit`의 `.popoverTip(...)`을 직접 부착했다. 이 조합이 toolbar 내부의 `UIButtonBarButton` wrapper와 충돌해 레이아웃이 `0-width` 상태로 흔들렸고, SwiftUI/TipKit layer 업데이트가 잘못된 screen 조회로 이어지며 크래시가 발생했다.

## Solution

`TipKit` popover는 제거하고, build 기반 `new` 점 badge와 수동 toolbar 진입만 유지했다. 사용자는 여전히 Today toolbar의 `sparkles` 아이콘으로 `What's New`에 접근할 수 있고, 새 build 여부는 기존 `WhatsNewStore`의 build 상태로 계속 표시된다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `What's New` toolbar에서 `.popoverTip(...)` 제거, `WhatsNewToolbarTip` 타입 삭제 | 크래시를 유발하는 toolbar popover 경로 제거 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `markWhatsNewOpened()`를 badge 상태 갱신만 수행하도록 단순화 | Tip invalidation 의존 제거 |
| `DUNE/App/DUNEApp.swift` | `TipKit` import 및 `Tips.configure()` 제거 | 런타임이 `TipKit`을 전혀 초기화하지 않도록 보수적으로 차단 |
| `DUNE/Data/Persistence/WhatsNewStore.swift` | 변경 없음 | build 기반 badge/open 상태 저장 정책은 그대로 유지 |

### Key Code

```swift
ToolbarItem(placement: .topBarTrailing) {
    NavigationLink {
        WhatsNewView(
            releases: whatsNewReleases,
            mode: .manual,
            onPresented: markWhatsNewOpened
        )
    } label: {
        whatsNewToolbarIcon
    }
    .accessibilityIdentifier("dashboard-toolbar-whatsnew")
}
```

```swift
private func markWhatsNewOpened() {
    guard !currentWhatsNewBuild.isEmpty else { return }
    whatsNewStore.markOpened(build: currentWhatsNewBuild)
    showWhatsNewBadge = false
}
```

## Prevention

### Checklist

- [ ] `TipKit` `popoverTip`를 iOS toolbar `NavigationLink` / `ToolbarItem`에 직접 부착하지 않는다.
- [ ] toolbar 내 보조 안내는 우선 `badge` / static affordance로 해결하고, runtime popover는 화면 본문 anchor가 있을 때만 검토한다.
- [ ] toolbar overlay가 있으면 `frame` + `overlay(alignment:)` 조합으로 경계를 명시하고, `0-width` 경고가 없는지 콘솔을 확인한다.
- [ ] 새 진입점 변경 후에는 최소 1개 launch smoke + 1개 navigation smoke UI 테스트로 회귀를 확인한다.

## Verification

- App build: `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -quiet` 통과
- UI smoke: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing DUNEUITests/Smoke/DashboardSmokeTests -quiet` 통과
- Unit test: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing DUNETests/WhatsNewStoreTests -quiet` 통과

## Lessons Learned

- toolbar 기반 발견성 개선은 유효하지만, UIKit wrapper 위에 추가 presentation layer를 얹으면 SwiftUI 내부 브리징이 쉽게 불안정해진다.
- 새 build 안내는 tip 없어도 badge + manual entry만으로 충분히 동작할 수 있다.
