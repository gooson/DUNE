---
tags: [theme, sakura, wave-background, premium-ui, dark-mode, watchos, accessibility, performance]
category: general
date: 2026-03-03
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift
  - DUNE/Presentation/Shared/Components/SakuraPetalShape.swift
  - DUNE/Presentation/Shared/Components/SakuraBranchShape.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNEWatch/Views/WatchWaveBackground.swift
  - DUNETests/SakuraPetalShapeTests.swift
  - DUNETests/SakuraBranchShapeTests.swift
  - Shared/Resources/Colors.xcassets/SakuraAccent.colorset/Contents.json
  - Shared/Resources/Colors.xcassets/SakuraPetal.colorset/Contents.json
  - Shared/Resources/Colors.xcassets/SakuraCardBackground.colorset/Contents.json
  - Shared/Resources/Colors.xcassets/SakuraTabWellness.colorset/Contents.json
related_solutions:
  - docs/solutions/design/2026-03-02-sakura-calm-theme.md
---

# Solution: Sakura Wave Identity + Premium Recovery Atmosphere

## Problem

기존 Sakura Calm은 색상 토큰은 존재하지만 배경 실루엣과 카드 표면이 Forest 계열과 시각적으로 충분히 분리되지 않아 “사쿠라 고유성”과 “프리미엄 회복 분위기”가 약했다.

### Symptoms

- 탭/디테일/시트 배경이 사쿠라보다는 일반 웨이브 계열처럼 보임
- 카드 표면에서 사쿠라 색감이 약하게 표현되어 테마 인지성이 낮음
- 다크 모드에서 사쿠라 레이어 대비가 부족해 분위기 전달력이 떨어짐
- watch에서는 사쿠라 시그니처가 거의 없어 iOS 대비 테마 일관성이 낮음

### Root Cause

- Sakura 배경이 petal 파형 1종 중심 구성이라 branch/petal drift 같은 식별 신호가 부족했다.
- 카드는 경계선 중심 강조만 있고 표면 tint 레이어가 없어 고급감이 약했다.
- 다크 모드 opacities가 보수적으로 설정되어 색감이 소실됐다.
- watch는 성능 제약을 의식해 사쿠라 전용 레이어가 생략되어 있었다.

## Solution

사쿠라 전용 실루엣(Branch) + drift petal overlay + 강화된 sakura color token + 카드 표면 tint를 결합해 테마 고유성을 높였고, watch에는 저비용 petal dot를 추가해 일관성을 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SakuraPetalShape.swift` | 파형 하모닉/roughness/cluster 로직 재설계 | Forest 느낌을 줄이고 벚꽃 능선 느낌 강화 |
| `SakuraBranchShape.swift` | 신규 branch+twig 실루엣 Shape 추가 | 사쿠라 고유 시각 신호 제공 |
| `SakuraWaveBackground.swift` | tab/detail/sheet에 branch 레이어, drift petals, dark mode 대비 강화 적용 | 실제 벚꽃 분위기 + 회복 무드 + 다크모드 가독성 개선 |
| `GlassCard.swift` | `sakuraHeroSurface`, `sakuraStandardSurface` 추가 | 카드 단위에서 사쿠라 톤/프리미엄감 강화 |
| `WatchWaveBackground.swift` | 경량 `WatchSakuraPetalDots` 및 sakura gradient 보강 | watch 일관성 확보, 성능 부담 최소화 |
| `SakuraPetalShapeTests.swift` | phase 변화 테스트 추가 | 파형 애니메이션 회귀 방지 |
| `SakuraBranchShapeTests.swift` | 신규 Shape 기하/animatable/twig 테스트 추가 | branch shape 안정성 보장 |
| `Sakura* colorset` 4개 | saturation/contrast 상향 조정 | 테마 인지성/다크모드 시인성 강화 |

### Key Code

```swift
SakuraBranchShape(
    amplitude: 0.10 * scale,
    frequency: 1.1,
    phase: 0,
    verticalOffset: 0.76,
    twigDensity: 0.55
)
.stroke(theme.sakuraLeafColor.opacity(0.34 * opacityScale), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))
```

```swift
private func startDriftIfNeeded() {
    guard !reduceMotion else {
        driftPhase = 0
        return
    }
    driftPhase = 0
    withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
        driftPhase = 2 * .pi
    }
}
```

## Prevention

### Checklist Addition

- [ ] 신규 테마 배경은 색상 토큰만으로 끝내지 않고 silhouette 신호(예: branch, glyph) 1개 이상 포함
- [ ] 다크 모드에서 top gradient/crest opacity가 실제 기기에서 theme identity를 유지하는지 확인
- [ ] watch 테마 대응 시 `Reduce Motion` 및 저비용 애니메이션 경량화 확인
- [ ] xcodegen 후 `project.pbxproj`의 `objectVersion/compatibilityVersion` 드리프트 확인

### Rule Addition (if applicable)

- 현재 룰(`design-system`, `ui-testing`, `watch-navigation`) 범위에서 관리 가능하여 신규 룰 파일은 추가하지 않음.

## Lessons Learned

- 테마 차별성은 색상보다도 실루엣/움직임 언어가 더 크게 좌우한다.
- “프리미엄” 인상은 border보다 surface tint + depth layering 조합이 효과적이다.
- watch는 경량화 제약이 있어도 소형 identity cue를 넣으면 iOS와의 일관성을 유지할 수 있다.
