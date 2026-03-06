---
tags: [whats-new, release-notes, onboarding, navigation, userdefaults, localization, settings]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/Data/Persistence/WhatsNewManager.swift
  - DUNE/Data/Persistence/WhatsNewStore.swift
  - DUNE/Domain/Models/WhatsNew.swift
  - DUNE/Presentation/WhatsNew/WhatsNewView.swift
  - DUNE/Presentation/Settings/SettingsView.swift
  - DUNETests/WhatsNewStoreTests.swift
  - DUNEUITests/Smoke/SettingsSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-28-settings-hub-patterns.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
---

# Solution: Static What's New Surface With Post-Launch Routing

## Problem

첫 배포 이후 사용자가 핵심 기능을 한 번에 이해할 수 있는 `What's New` 공간이 없었고, 버전별 안내를 서버 없이 누적 관리할 구조도 없었다.

### Symptoms

- 첫 설치나 업데이트 후 새 기능을 자연스럽게 노출할 진입점이 없음
- `Settings > About`에서 다시 열어볼 수 있는 릴리스 안내 화면이 없음
- 기능 소개 카드에서 실제 화면으로 이어지는 경로가 없어 설명이 일회성에 그침
- launch splash, consent sheet, 탭별 `NavigationStack`과 충돌 없이 붙일 오케스트레이션 계층이 없음

### Root Cause

- 릴리스 콘텐츠 모델, 마지막 노출 버전 저장소, 전역 deep link 브리지라는 세 가지가 각각 부재했다.
- 앱은 탭별 `NavigationStack` 구조라 launch 레벨 modal과 탭 내부 상세 이동을 한 계층에서 동시에 처리하기 어려웠다.

## Solution

앱 시작 시점의 auto-present는 `DUNEApp`이 담당하고, 실제 화면 이동은 `ContentView`가 signal 기반으로 처리하는 이원 구조를 추가했다. 릴리스 콘텐츠는 타입 안전한 Swift catalog로 유지하고, 마지막 자동 표시 버전은 `UserDefaults`에 저장한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/WhatsNew.swift` | add | 릴리스, feature, destination 모델 정의 |
| `DUNE/Data/Persistence/WhatsNewStore.swift` | add | 같은 버전 자동 재표시 방지 |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | add | 정적 릴리스 카탈로그와 route 브리지 제공 |
| `DUNE/App/DUNEApp.swift` | update | splash/consent 이후 auto-present 순서 제어 |
| `DUNE/App/ContentView.swift` | update | `What's New` destination 수신 후 탭/상세 이동 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | add | 사용자용 hero/highlight/archive UI 및 CTA |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | `Settings > About` 수동 재진입 링크 추가 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | Condition Score route 수신 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | Training Readiness route 수신 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | Wellness Score route 수신 |
| `DUNE/Resources/Localizable.xcstrings` | update | `en/ko/ja` 사용자 문구 추가 |
| `DUNETests/WhatsNewStoreTests.swift` | add | 버전 표시 판정 테스트 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | Settings 재진입 및 deep link smoke test 추가 |

### Key Code

```swift
// DUNEApp.swift
private func presentWhatsNewIfNeeded() {
    guard !showConsentSheet, !showWhatsNewSheet else { return }
    guard let currentRelease = whatsNewManager.currentRelease(for: currentVersion),
          whatsNewStore.shouldPresent(version: currentVersion) else { return }

    whatsNewReleases = whatsNewManager.orderedReleases(preferredVersion: currentRelease.version)
    activeWhatsNewVersion = currentRelease.version
    showWhatsNewSheet = true
}

private func markActiveWhatsNewVersionAsPresentedIfNeeded() {
    guard let version = activeWhatsNewVersion else { return }
    activeWhatsNewVersion = nil
    whatsNewStore.markPresented(version: version)
}

// ContentView.swift
private func handleWhatsNewNavigationRequest(_ destination: WhatsNewDestination) {
    switch destination {
    case .notificationHub:
        selectedSection = .today
        notificationHubSignal += 1
    case .trainingReadiness:
        selectedSection = .train
        whatsNewTrainingReadinessSignal += 1
    case .wellnessScore:
        selectedSection = .wellness
        whatsNewWellnessScoreSignal += 1
    ...
    }
}
```

자동 표시 완료는 시트를 띄우는 순간이 아니라 **닫힐 때 기록**하도록 두어, 사용자가 실제로 보지 못하고 종료한 경우 같은 버전에서 다시 노출될 수 있게 했다.

## Prevention

### Checklist Addition

- [ ] launch-level 신규 modal은 `DUNEApp`에서 splash/consent와 함께 순서를 오케스트레이션하는가?
- [ ] 탭 내부 상세 이동은 전역 manager가 아니라 `ContentView` signal 브리지를 통해 전달하는가?
- [ ] auto-present 기록은 “표시 시도”가 아니라 “사용자 노출 종료” 기준으로 남기는가?
- [ ] `What's New` CTA와 Settings 재진입 링크는 UI 테스트 가능한 accessibility identifier를 갖는가?
- [ ] 새 릴리스 카드 문구는 `Localizable.xcstrings`에 `ko/ja`까지 함께 추가하는가?

### Rule Addition (if applicable)

없음. 기존 `localization`, `testing-required`, `swift-layer-boundaries` 규칙 범위 안에서 해결했다.

## Lessons Learned

- launch 시퀀스와 deep link는 한 계층에 몰아넣기보다, `App`은 표시 순서만, `ContentView`는 탭 라우팅만 맡게 나누는 편이 충돌이 적다.
- 서버 없는 릴리스 카탈로그는 JSON보다 Swift catalog가 MVP 단계에서 더 안전하다. 특히 destination enum과 함께 관리할 때 누락이 줄어든다.
- SwiftUI에서 식별자 안정성이 필요한 경우 `Button`이나 `NavigationLink` 자체보다 실제 `Label` 쪽에 `accessibilityIdentifier`를 두는 편이 UI 테스트에서 더 일관적이다.
