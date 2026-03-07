---
tags: [whats-new, json, sf-symbol, refactoring, data-driven]
date: 2026-03-08
category: plan
status: approved
---

# Plan: What's New 기능 개편

## Summary

What's New 시스템을 enum 하드코딩에서 JSON 데이터 드리븐으로 전환하고, 이미지를 SF Symbol 조합 카드로 교체한다.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Domain/Models/WhatsNew.swift` | **Major rewrite** | enum → Codable struct |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | **Major rewrite** | 하드코딩 → JSON 파싱 |
| `DUNE/Data/Resources/whats-new.json` | **New** | 릴리스 카탈로그 JSON |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | **Major rewrite** | Artwork → SF Symbol 카드 |
| `DUNE/App/DUNEApp.swift` | Minor update | 타입 참조 업데이트 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | Minor update | 타입 참조 업데이트 |
| `DUNE/Presentation/Settings/SettingsView.swift` | Minor update | 타입 참조 업데이트 |
| `DUNETests/WhatsNewManagerTests.swift` | **Rewrite** | JSON 파싱 테스트 |
| `Shared/Resources/Localizable.xcstrings` | Verify | 기존 번역 유지 확인 |
| `DUNE/project.yml` | Minor update | whats-new.json 리소스 등록 |

## Implementation Steps

### Step 1: Domain 모델 재설계

**WhatsNew.swift** 전면 교체.

**기존**: `WhatsNewFeature` enum (11 cases) + computed properties
**변경**: `WhatsNewFeatureItem` / `WhatsNewReleaseData` Codable struct

```swift
// WhatsNewArea는 enum 유지 (6개 고정, 탭 구조와 1:1)
enum WhatsNewArea: String, Codable, Sendable {
    case today, activity, wellness, life, watch, settings

    var badgeTitle: String { ... } // 기존 유지
}

// enum → struct
struct WhatsNewFeatureItem: Codable, Identifiable, Hashable, Sendable {
    let id: String           // "widgets"
    let titleKey: String     // "Widgets" (xcstrings 키)
    let summaryKey: String   // "Check condition score..." (xcstrings 키)
    let symbolName: String   // "rectangle.3.group"
    let area: WhatsNewArea

    var title: String { String(localized: String.LocalizationValue(titleKey)) }
    var summary: String { String(localized: String.LocalizationValue(summaryKey)) }
}

struct WhatsNewReleaseData: Codable, Identifiable, Hashable, Sendable {
    let version: String
    let introKey: String
    let features: [WhatsNewFeatureItem]

    var id: String { version }
    var intro: String { String(localized: String.LocalizationValue(introKey)) }
}
```

**Verification**: 컴파일 성공, 기존 WhatsNewRelease와 동일 인터페이스

### Step 2: JSON 카탈로그 생성

**DUNE/Data/Resources/whats-new.json** 신규 생성.

현재 `releaseCatalog`의 0.2.0 데이터를 JSON으로 마이그레이션:

```json
{
  "releases": [
    {
      "version": "0.2.0",
      "introKey": "Start with condition, weather, sleep debt, and training readiness — and see how your body is doing at a glance.",
      "features": [
        {
          "id": "widgets",
          "titleKey": "Widgets",
          "summaryKey": "Check your condition score, weather guidance, ...",
          "symbolName": "rectangle.3.group",
          "area": "today"
        }
      ]
    }
  ]
}
```

**주의**: titleKey/summaryKey 값은 기존 `String(localized:)` 인자와 정확히 동일해야 xcstrings 매핑 유지.

**Verification**: JSON 유효성, key-xcstrings 매칭

### Step 3: WhatsNewManager JSON 파싱

**WhatsNewManager.swift** 리팩토링.

```swift
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    private let releases: [WhatsNewReleaseData]

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "whats-new", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(WhatsNewCatalog.self, from: data)
        else {
            releases = []
            return
        }
        releases = catalog.releases
    }

    // 기존 메서드 시그니처 유지
    func orderedReleases(preferredVersion: String? = nil) -> [WhatsNewReleaseData] { ... }
    func currentRelease(for version: String) -> WhatsNewReleaseData? { ... }
}
```

**Verification**: WhatsNewManagerTests 통과

### Step 4: SF Symbol 조합 카드

**WhatsNewView.swift**에서 `WhatsNewArtwork` + `WhatsNewFeatureArtwork` 전체 교체.

새 `WhatsNewFeatureCard`:
- 영역별 DS 색상 그라디언트 배경 (RoundedRectangle)
- 대표 SF Symbol 1개 (feature.symbolName)
- 보조 장식 (area별 2번째 symbol, opacity 낮게)
- thumbnail (138px) / hero (260px) 두 가지 스타일

```swift
private struct WhatsNewFeatureCard: View {
    let feature: WhatsNewFeatureItem
    let style: CardStyle

    enum CardStyle { case thumbnail, hero }

    var body: some View {
        RoundedRectangle(cornerRadius: style == .hero ? 20 : 12)
            .fill(areaGradient)
            .overlay {
                Image(systemName: feature.symbolName)
                    .font(style == .hero ? .system(size: 64) : .system(size: 36))
                    .foregroundStyle(.white)
            }
            .frame(height: style == .hero ? 260 : 138)
    }
}
```

**WhatsNewStyle.tintColor** → area 기반 색상 매핑 유지 (DS 토큰 사용).

기존 `UIImage(named:)` fallback 로직과 WhatsNewFeatureArtwork 전체 삭제.

**Verification**: UI 렌더링 확인 (Preview)

### Step 5: 소비자 View 업데이트

타입명 변경에 따른 소비자 업데이트:

| 소비자 | 변경 |
|--------|------|
| `DUNEApp.swift` | `WhatsNewRelease` → `WhatsNewReleaseData`, `WhatsNewFeature` 참조 제거 |
| `DashboardView.swift` | `WhatsNewRelease` → `WhatsNewReleaseData` |
| `SettingsView.swift` | `WhatsNewRelease` → `WhatsNewReleaseData` |
| `WhatsNewView.swift` | 내부 이미 변경됨 (Step 4) |

**Verification**: 빌드 성공

### Step 6: 테스트 업데이트

**WhatsNewManagerTests.swift** 리팩토링:
- JSON 파싱 성공/실패 테스트
- 0.2.0 릴리스 데이터 검증
- orderedReleases 정렬 검증
- Bundle에서 test JSON 로드

**WhatsNewStoreTests.swift**: 변경 불필요 (WhatsNewStore는 변경 없음)

**Verification**: 전체 테스트 통과

### Step 7: project.yml 리소스 등록

`DUNE/project.yml`에 `whats-new.json` 포함 확인.
XcodeGen의 sources/resources 설정에 `Data/Resources/` 패턴이 이미 포함되어 있으면 추가 작업 불필요.

### Step 8: Asset Catalog 정리

기존 `whatsnew-*.imageset` 11개 삭제 (SF Symbol 카드로 대체).

**Verification**: 빌드 성공, 런타임 이미지 로드 에러 없음

## Test Strategy

| 테스트 대상 | 접근 방법 |
|------------|----------|
| JSON 파싱 | WhatsNewManagerTests — 정상/비정상 JSON |
| 모델 Codable | WhatsNewFeatureItem, WhatsNewReleaseData 인코딩/디코딩 |
| orderedReleases | 다중 버전 정렬 검증 |
| Localization | titleKey → String(localized:) 변환 확인 |
| UI (수동) | Preview로 SF Symbol 카드 렌더링 확인 |

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| JSON 파싱 실패 (번들 누락) | `releases = []` fallback → What's New 비표시 (graceful) |
| xcstrings 키 불일치 | JSON의 titleKey를 기존 코드와 byte-for-byte 동일하게 유지 |
| WhatsNewStore 호환성 | UserDefaults 키는 build 기반이므로 영향 없음 |
| 기존 imageset 참조 | imageAssetName 프로퍼티 제거, UIImage 로드 코드 삭제 |
| LaunchExperiencePlanner | WhatsNewManager API 시그니처 유지로 영향 최소 |

## Out of Scope

- Build-time git 스크립트 (Future)
- 버전별 히스토리 스크롤 UI 개선 (Future)
- 애니메이션 카드 전환 (Future)
