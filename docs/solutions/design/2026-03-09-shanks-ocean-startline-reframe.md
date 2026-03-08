---
tags: [theme, shanks, hero-card, wave-background, swiftui, ipad]
category: general
date: 2026-03-09
severity: important
related_files:
  [
    DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift,
    DUNETests/ShanksThemeEnhancementTests.swift,
    docs/plans/2026-03-09-shanks-ocean-startline-reframe.md,
  ]
related_solutions:
  [
    docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md,
    docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md,
  ]
---

# Solution: 샹크스 바다 장면 시작선을 히어로 카드 하단으로 내리기

## Problem

샹크스 시네마틱 오션 테마는 장면 구성 자체는 완성되어 있었지만, 바다 mass와 거품, 배, 카무사리 레이어가 화면 상단에서 너무 빨리 시작되어 hero card와 시각적으로 겹쳐 읽혔다.

### Symptoms

- Today/Activity/Wellness 탭에서 hero card 상단부가 바다 레이어와 경쟁해 화면 첫 인상이 복잡해 보였다.
- detail/sheet에서도 같은 scene engine을 쓰지만, start line 규칙이 명시적이지 않아 장면 시작 위치를 일관되게 조절하기 어려웠다.
- iPad regular width에서는 hero card가 더 커지는데, 고정 배경 시작점만으로는 “hero 3/4 지점부터 바다가 시작된다”는 요구를 맞추기 어려웠다.

### Root Cause

기존 `ShanksCinematicSceneBackground`는 gradient와 실제 ocean scene 레이어를 모두 화면 최상단에 정렬했다. 이 구조에서는 scene을 구성하는 모든 요소가 같은 top origin을 공유하므로, 상단에 atmospheric tint만 남기고 ocean scene만 늦게 시작시키는 제어점이 없었다.

## Solution

`ShanksSceneStyle`에 `sceneTopInset`을 추가하고, `ShanksCinematicSceneBackground`에서 water mass / caustic / texture / flag / ship / foam 레이어를 하나의 scene container로 묶어 공통 inset 아래로 내렸다. 상단 gradient는 그대로 유지해 화면 분위기는 보존하고, 실제 바다 장면만 hero card 하단부에서 시작하도록 분리했다. iPad regular width는 `horizontalSizeClass` 기반으로 inset을 추가 보정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | `sceneTopInset` token 추가, tab/detail/sheet preset별 값 정의, regular width 보정 추가 | hero card와 ocean scene의 시작선을 분리하고 presentation depth별로 일관되게 제어하기 위해 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | preset inset smoke test 추가 | startline token이 0 이하나 비정상 tiering으로 회귀하지 않도록 하기 위해 |
| `docs/plans/2026-03-09-shanks-ocean-startline-reframe.md` | 구현 계획 기록 | 요청 배경, 검증 전략, 리스크를 재사용 가능하게 남기기 위해 |

### Key Code

```swift
private var resolvedSceneTopInset: CGFloat {
    style.sceneTopInset + (sizeClass == .regular ? 20 : 0)
}
```

```swift
ZStack(alignment: .top) {
    ShanksWaterMassScene(style: style, accentTint: resolvedAccentTint)
    ShanksUnderwaterCausticOverlay(style: style, elapsed: elapsed)
    ShanksShipHeroOverlay(style: style, elapsed: elapsed)
    ShanksSurfaceFoamOverlay(style: style, elapsed: elapsed)
}
.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
.padding(.top, resolvedSceneTopInset)
```

## Prevention

scene-heavy 테마에서 “상단 분위기”와 “실제 장면 본체”를 같은 top origin으로 두지 않는다. 배경을 고도화할수록 gradient tint와 subject layers를 분리하고, 장면 시작점은 preset token으로 조절한다.

### Checklist Addition

- [ ] hero card가 있는 scene background는 gradient layer와 subject layer의 top origin을 분리했는가?
- [ ] tab/detail/sheet가 같은 startline token 체계를 공유하는가?
- [ ] regular width(iPad)에서 hero scale 증가를 반영한 inset 보정이 필요한가?

### Rule Addition (if applicable)

즉시 `.claude/rules/`로 승격할 정도의 범용 규칙은 아니므로 추가 없음.

## Lessons Learned

- 시네마틱 테마의 과밀도 문제는 레이어를 줄이는 것보다 “장면이 시작되는 높이”를 토큰화하는 편이 안전하다.
- 상단 gradient와 ocean scene 본체를 분리하면 감성은 유지하면서 가독성 문제를 훨씬 좁은 범위에서 조정할 수 있다.
- iPad처럼 hero card 스케일이 달라지는 화면에서는 absolute inset만 두지 말고 size-class 보정을 함께 고려해야 한다.
