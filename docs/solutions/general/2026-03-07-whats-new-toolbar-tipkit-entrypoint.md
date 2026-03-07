---
tags: [whats-new, tipkit, toolbar, onboarding, dashboard, build-number]
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
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
---

# Solution: What's New 진입점 툴바 이동 + build 기반 TipKit 안내

## Problem

Today 탭 최상단의 `What's New` 카드는 새 기능을 항상 상단에 고정 노출해 핵심 지표 흐름을 방해했다. 동시에 업데이트 직후 사용자가 새 기능 위치를 놓치지 않도록 최소한의 발견성은 유지해야 했다.

### Symptoms

- Today 화면 첫 진입에서 `What's New` 카드가 항상 최상단을 차지함
- 업데이트와 무관하게 동일 카드가 계속 노출되어 정보 피로를 유발함
- 새 버전 안내가 full-screen modal과 카드 두 군데에 중복 노출됨
- 알림처럼 가벼운 네비게이션 진입점이 없어 홈 화면 밀도가 높아짐

### Root Cause

- `What's New`가 “일시적 온보딩”이 아니라 “고정 홈 카드”로 배치되어 있었다.
- 업데이트 노출 상태가 app version 기준 auto-present 중심으로 설계되어, build별 1회 안내와 수동 열람 상태를 분리하지 못했다.

## Solution

고정 카드와 자동 full-screen 노출을 제거하고, Today 툴바에 독립 `sparkles` 아이콘을 추가했다. 새 build에서는 `TipKit` popover를 1회만 노출하고, 사용자가 `What's New` 화면을 실제로 열기 전까지는 툴바 아이콘에 `new` 점을 유지한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/App/DUNEApp.swift` | `TipKit` configure 추가, 기존 auto `What's New` full-screen 제거 | 강제 노출 대신 툴바+tip 구조로 단순화 |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | 현재 build 번호 조회 API 추가 | build 기준 안내/배지 판단 지원 |
| `DUNE/Data/Persistence/WhatsNewStore.swift` | `lastOpenedBuild` 저장소로 재정의 | 현재 build에서 이미 열람했는지 추적 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 상단 카드 삭제, 툴바 아이콘/`new` 점/`TipKit` 추가 | 홈 흐름 방해 제거 + 가벼운 진입점 제공 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | `onPresented` hook 추가 | 실제 화면 열람 시점에 상태를 일관되게 업데이트 |
| `DUNE/Presentation/Settings/SettingsView.swift` | 보조 진입점에서도 동일 build 열람 처리 | 툴바/Settings 간 상태 불일치 방지 |
| `DUNETests/WhatsNewStoreTests.swift` | build 기준 badge/open 분기 테스트로 갱신 | 저장소 정책 회귀 방지 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | 툴바 `What's New` AXID 추가 | UI smoke selector 단일화 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | Today 툴바 진입 smoke test 갱신 | 카드 제거 후 새 진입점 회귀 방지 |

### Key Code

```swift
private var whatsNewToolbarTip: (any Tip)? {
    guard showWhatsNewBadge,
          let currentRelease = currentWhatsNewRelease,
          !currentWhatsNewBuild.isEmpty else {
        return nil
    }

    return WhatsNewToolbarTip(
        buildNumber: currentWhatsNewBuild,
        bodyMessage: currentRelease.intro
    )
}

private func markWhatsNewOpened() {
    guard !currentWhatsNewBuild.isEmpty else { return }
    let tip = whatsNewToolbarTip
    whatsNewStore.markOpened(build: currentWhatsNewBuild)
    showWhatsNewBadge = false
    tip?.invalidate(reason: .actionPerformed)
}
```

```swift
private struct WhatsNewToolbarTip: Tip {
    let buildNumber: String
    let bodyMessage: String

    var id: String { "whats-new-toolbar-tip-\(buildNumber)" }

    var options: [any TipOption] {
        Tips.IgnoresDisplayFrequency(true)
        Tips.MaxDisplayCount(1)
    }
}
```

`TipKit` tip ID를 build 번호에 묶고 `MaxDisplayCount(1)`를 적용해 같은 build에서는 한 번만 안내하고, 새 build로 바뀌면 자동으로 새 tip으로 취급되도록 했다.

## Prevention

### Checklist

- [ ] 홈 상단 고정 카드가 “일시적 안내” 성격이면 툴바/배지/TipKit 같은 lighter surface를 우선 검토한다.
- [ ] “한 번만 보여줄 안내”와 “사용자가 직접 확인했는지”는 같은 저장 키로 섞지 않는다.
- [ ] `NavigationLink` 부수효과는 탭 gesture가 아니라 실제 destination `onAppear`로 옮겨 접근성 경로를 포함해 일관되게 처리한다.
- [ ] 툴바 배지는 기존 notification badge처럼 `overlay(alignment:)` + 명시적 frame 조합으로 배치한다.
- [ ] UI 테스트 selector는 홈 카드/레이블 텍스트가 아니라 툴바 accessibility identifier를 기준으로 유지한다.

## Verification

- App build: `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -quiet` 통과
- UI test: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing DUNEUITests/Smoke/DashboardSmokeTests/testNavigateToWhatsNew -quiet` 통과
- Unit test: `DUNETests` 타깃이 기존 `DUNETests/Helpers/URLProtocolStub.swift`의 Swift 6 concurrency 오류로 빌드 실패하여 이번 변경 분기 테스트는 실행 불가

## Lessons Learned

- 새 기능 발견성은 “강제 full-screen”보다 툴바 진입점 + 1회 tip 조합이 훨씬 덜 침습적이다.
- build 기준 상태와 marketing version 기준 릴리스 카탈로그는 목적이 다르므로 분리하는 편이 확장에 유리하다.
- 접근성까지 고려하면 `NavigationLink` 부수효과는 gesture보다 화면 열림 시점에 묶는 편이 안전하다.
