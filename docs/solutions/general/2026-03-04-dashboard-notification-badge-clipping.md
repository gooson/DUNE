---
tags: [swiftui, toolbar, notification, badge, clipping, dashboard]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
related_solutions: []
---

# Solution: Today 툴바 알림 뱃지 상단 잘림

## Problem

### Symptoms

- Today 탭 우상단 알림 벨 아이콘의 unread 뱃지(빨간 캡슐) 상단이 잘려 보임
- unread count가 있을 때만 재현되며, 아이콘 자체 동작(알림 허브 이동)은 정상

### Root Cause

`DashboardView.notificationBellIcon`에서 뱃지를 `offset(x: 8, y: -8)`로 위쪽으로 크게 이동했다.
툴바 아이템 렌더링 경계를 넘어가면서 캡슐 상단이 클리핑되었다.

## Solution

음수 Y offset 의존을 제거하고, `overlay(alignment: .topTrailing)` + 고정 프레임으로 배치를 전환했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | `notificationBellIcon`를 `Image + overlay` 구조로 변경, `frame(width: 22, height: 22)` 적용 | 툴바 경계 내에서 뱃지를 안정적으로 렌더링 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | `dashboardToolbarNotifications` AXID 상수 추가 | 테스트에서 알림 버튼 식별자를 문자열 하드코딩 없이 재사용 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | `testNotificationButtonExists()` 추가 | 알림 버튼 존재 회귀 검증 |

### Key Code

```swift
Image(systemName: "bell")
    .frame(width: 22, height: 22)
    .overlay(alignment: .topTrailing) {
        if unreadNotificationCount > 0 {
            Text(unreadBadgeLabel)
                .background(Color.red, in: Capsule())
                .offset(x: 6)
        }
    }
```

## Prevention

### Checklist

- [ ] Toolbar 뱃지/라벨은 큰 음수 Y offset으로 경계를 넘기지 않는다.
- [ ] 툴바 오버레이 요소는 `overlay(alignment:)`와 명시적 프레임으로 배치한다.
- [ ] 툴바 접근성 ID는 UI 테스트 상수(`AXID`)에 함께 등록한다.

## Verification

- App build: `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -quiet` 통과
- Unit test: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/DashboardViewModelTests -quiet` 통과
- UI test: CoreSimulatorService 연결 불안정으로 실행 실패 (`Unable to find a device matching...`) — 코드 실패 아님
