---
tags: [swiftui, metal, shader, theme, animation, one-piece, shanks]
category: general
date: 2026-03-08
severity: important
related_files:
  [
    DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift,
    DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift,
    DUNE/Resources/Shaders/ShanksSceneEffects.metal,
    DUNE/Presentation/Shared/Extensions/AppTheme+View.swift,
    DUNETests/ShanksThemeEnhancementTests.swift,
  ]
related_solutions: []
---

# Solution: Shanks 테마를 motif overlay에서 cinematic ocean scene으로 전환하기

## Problem

샹크스 테마가 파도 위에 상징 요소를 얹은 수준에 머물러 있어서, 팬서비스용 세계관 테마로 보기에는 장면 밀도와 몰입감이 부족했다.

### Symptoms

- 네비바 아래에 이어지는 바다 질감이 아니라 장식 오버레이가 붙은 배경처럼 보였다.
- 표면 거품, 수중 빛무늬, 배, 카무사리 에너지가 하나의 장면으로 묶이지 않았다.
- 탭, 디테일, 시트가 각각 다른 장식 조합을 가져서 테마 일관성이 약했다.

### Root Cause

기존 구현은 `ShanksWaveBackground.swift` 안에서 `깃발`, `하키 streak`, `카무사리 crack`를 개별 오버레이로 조합하는 구조였다. 이 방식은 상징은 빠르게 추가할 수 있지만, 바다의 깊이감과 장면 계층을 만드는 데는 한계가 있다. 특히 화면 타입별로 레이어 조합이 분리되어 있어서, 동일한 세계관을 다른 강도로 재사용하기 어려웠다.

## Solution

`ShanksCinematicSceneBackground`라는 공통 scene composer를 만들고, 기존 Shanks tab/detail/sheet 배경을 모두 이 composer로 위임했다. 바다 본체, 표면 거품, 수중 caustic, 해적기 텍스처, 배 실루엣, 카무사리 필드를 하나의 scene style로 관리하고, shimmer/glow/warp는 Metal stitchable shader로 처리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | scene style, foam, caustic, ship, kamusari, wake 레이어 추가 | 장면 중심 구조로 재조합하기 위해 |
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | 기존 tab/detail/sheet를 thin wrapper로 축소 | 전 화면에서 동일한 scene engine을 쓰기 위해 |
| `DUNE/Resources/Shaders/ShanksSceneEffects.metal` | sea shimmer, kamusari glow, water warp shader 추가 | SwiftUI만으로 부족한 발광/왜곡을 GPU 레벨에서 처리하기 위해 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | abyss/current/foam/caustic palette 확장 | Shanks scene 전용 색을 디자인 토큰으로 승격하기 위해 |
| `Shared/Resources/Colors.xcassets/*` | 새 색상 asset 추가 | 라이트/다크에서 같은 이름으로 재사용하기 위해 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | foam crest/ship silhouette path 테스트 추가 | 새 custom shape 회귀를 막기 위해 |

### Key Code

```swift
struct ShanksCinematicSceneBackground: View {
    let style: ShanksSceneStyle
    let accentTint: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            ZStack(alignment: .top) {
                ShanksWaterMassScene(style: style, accentTint: accentTint ?? .red)
                ShanksUnderwaterCausticOverlay(style: style, elapsed: elapsed)
                ShanksShipHeroOverlay(style: style, elapsed: elapsed)
                ShanksSurfaceFoamOverlay(style: style, elapsed: elapsed)
            }
            .ignoresSafeArea()
        }
    }
}
```

## Prevention

새 테마를 만들 때는 “상징 요소를 얹는 배경”이 아니라 “scene composer + style preset” 구조를 먼저 잡는다. 레이어를 독립 오버레이로 늘리는 대신, 공통 배경 엔진 하나를 만들고 tab/detail/sheet는 강도와 높이만 조절한다.

### Checklist Addition

- [ ] 테마 배경이 tab/detail/sheet에서 같은 scene engine을 공유하는지 확인
- [ ] 장면 계층이 `water mass / surface / hero / atmosphere`로 분리되는지 확인
- [ ] 고비용 애니메이션은 `TimelineView` 최소 주기와 `Reduce Motion` pause를 갖는지 확인
- [ ] 셰이더 도입 시 custom shape/path 테스트가 최소 1개 이상 추가됐는지 확인

### Rule Addition (if applicable)

없음.

## Lessons Learned

- 테마 완성도는 상징 개수보다 장면 계층 설계에서 결정된다.
- SwiftUI만으로도 충분한 레이아웃과 마스킹은 가능하지만, 물 반사와 에너지 왜곡은 Metal shader를 섞어야 급이 달라진다.
- full-screen 테마는 탭/디테일/시트 별도 구현보다 style preset 기반 공통 composer가 유지보수와 일관성 모두 유리하다.
