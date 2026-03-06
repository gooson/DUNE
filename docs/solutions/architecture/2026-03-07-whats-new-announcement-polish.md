---
tags: [whats-new, announcement, screenshots, swiftui, ui-testing, accessibility]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/Data/Persistence/WhatsNewManager.swift
  - DUNE/Domain/Models/WhatsNew.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Settings/SettingsView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/WhatsNew/WhatsNewView.swift
  - DUNE/Resources/Assets.xcassets
  - DUNETests/Helpers/URLProtocolStub.swift
  - DUNETests/OpenMeteoAirQualityServiceTests.swift
  - DUNETests/OpenMeteoServiceTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/SettingsSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
---

# Solution: Screenshot-First What's New Announcement

## Problem

`What's New`가 이미 릴리스 surface로는 존재했지만, 실제 공지 품질은 낮았다. 카드와 detail이 추상 artwork에 의존했고, detail 하단의 `기능 열기` CTA는 안정적인 탐색 경험을 보장하지 못했다.

### Symptoms

- 리스트와 상세 화면의 이미지가 기능 이해보다 장식에 가깝게 보였다.
- `Settings > About > What's New`에서 detail을 열어도 CTA가 실제 제품 신뢰도를 높이지 못했다.
- CTA를 유지하려고 Today, Activity, Wellness, Settings까지 전역 route signal이 퍼져 있었다.
- UI smoke test가 `Open Feature` 버튼 존재에 묶여 있어 announcement UX 변경에 취약했다.

### Root Cause

- `What's New`를 소개용 surface와 deep-link launcher 두 역할로 동시에 설계했다.
- screenshot asset 파이프라인이 없어 fallback artwork가 사실상 기본값이 됐다.
- route bridge가 앱 전역 view wiring을 늘려 작은 UX 변경도 큰 구조 수정으로 이어졌다.

## Solution

`What's New`를 read-only announcement surface로 다시 정의했다. screenshot-style asset을 feature별로 번들에 추가하고, detail CTA와 이에 연결된 route bridge를 제거해 화면 책임을 단순화했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | update | thumbnail/hero artwork 중심 레이아웃으로 전환하고 CTA 제거 |
| `DUNE/Domain/Models/WhatsNew.swift` | update | 더 이상 쓰지 않는 `WhatsNewDestination` 제거 |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | update | release catalog 전용 역할만 남기고 route bridge 삭제 |
| `DUNE/App/DUNEApp.swift` | update | pending destination 상태 제거, auto-present 종료 흐름 단순화 |
| `DUNE/App/ContentView.swift` | update | `What's New` 전용 signal 및 라우팅 처리 제거 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | obsolete deep-link task/navigation 정리 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | obsolete deep-link task/navigation 정리 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | obsolete deep-link task/navigation 정리 |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | `What's New` 수동 진입을 읽기 전용 흐름으로 단순화 |
| `DUNE/Resources/Assets.xcassets` | add | `whatsnew-*` screenshot asset 11종 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | artwork accessibility identifier helper 추가 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | CTA 대신 detail 진입과 hero artwork 노출 검증으로 전환 |
| `DUNETests/Helpers/URLProtocolStub.swift` | update | Swift 6 test concurrency 경고를 피하도록 helper 정리 |
| `DUNETests/OpenMeteoAirQualityServiceTests.swift` | update | mutable capture 대신 thread-safe recorder 사용 |
| `DUNETests/OpenMeteoServiceTests.swift` | update | mutable capture 대신 thread-safe recorder 사용 |

### Key Code

```swift
private struct WhatsNewArtwork: View {
    let feature: WhatsNewFeature
    let style: WhatsNewArtworkStyle

    var body: some View {
        if let image = UIImage(named: feature.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityIdentifier("whatsnew-artwork-\(feature.rawValue)-\(style.rawValue)")
        } else {
            WhatsNewFeatureArtwork(feature: feature)
                .accessibilityIdentifier("whatsnew-fallback-\(feature.rawValue)-\(style.rawValue)")
        }
    }
}
```

```swift
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    func orderedReleases(preferredVersion: String? = nil) -> [WhatsNewRelease] { ... }
    func currentRelease(for version: String) -> WhatsNewRelease? { ... }
}
```

핵심은 `What's New`가 더 이상 앱 내부 탐색을 트리거하지 않고, 릴리스 설명과 시각 자산 제공에만 집중하도록 역할을 줄인 것이다.

## Prevention

### Checklist Addition

- [ ] release/announcement 화면은 deep link보다 전달력과 안정성을 우선하는가?
- [ ] feature artwork가 추상 placeholder가 아니라 실제 사용 화면에 가까운가?
- [ ] CTA 제거 시 남는 route signal, modal dismiss relay, destination enum을 함께 정리했는가?
- [ ] UI smoke test가 특정 버튼 존재가 아니라 핵심 읽기 흐름을 검증하는가?
- [ ] screenshot asset이 없을 때 fallback identifier도 함께 노출되어 테스트가 깨지지 않는가?

### Rule Addition (if applicable)

없음. 기존 `testing-required`, `documentation-standards`, `watch-navigation` 범위 안에서 처리 가능했다.

## Lessons Learned

- announcement surface는 기능 탐색과 섞을수록 구조가 급격히 무거워진다.
- 실제 캡처에 가까운 asset만 넣어도 릴리스 카드의 전달력이 크게 좋아진다.
- Swift 6 환경에서는 테스트 코드의 mutable capture도 빌드 게이트가 되므로, 단순 helper라도 thread-safe wrapper를 두는 편이 낫다.
