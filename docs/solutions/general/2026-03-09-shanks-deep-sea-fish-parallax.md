---
tags: [swiftui, theme, shanks, parallax, animation]
category: general
date: 2026-03-09
severity: minor
related_files:
  [
    DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift,
    DUNETests/ShanksThemeEnhancementTests.swift,
    docs/plans/2026-03-09-shanks-deep-sea-fish-parallax.md,
    todos/096-pending-p3-shanks-cinematic-theme-future-expansions.md,
  ]
related_solutions:
  [
    docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md,
    docs/solutions/design/2026-03-09-shanks-ocean-startline-reframe.md,
  ]
---

# Solution: Shanks scene engine에 deep-sea fish parallax를 안전하게 추가하기

## Problem

샹크스 시네마틱 오션 테마는 MVP 단계에서 `water mass / caustic / flag / ship / foam` 조합까지는 완성됐지만, 심해 원근감을 주는 후방 silhouette 레이어는 없었다. 브레인스토밍에서는 이를 future item으로 따로 빼 두었고, 실제 후속 확장을 시작할 때도 기존 장면 엔진을 깨지 않고 개별 효과만 얹는 방식이 필요했다.

### Symptoms

- 샹크스 바다가 hero ship과 foam은 강하지만, 후방 심도가 부족해 장면이 다소 평평하게 읽혔다.
- future expansion을 추가하는 순간 scene composer 바깥으로 설정/상태를 새로 만들 가능성이 있었다.
- 첫 구현안에서 fish tint alpha와 outer opacity를 둘 다 `style.fishOpacity`로 감쇠해 detail/sheet에서 silhouette가 거의 보이지 않을 위험이 있었다.

### Root Cause

기존 `ShanksSceneStyle`은 ship, foam, kamusari만 presentation-depth 차등 토큰을 갖고 있었고, 심해 레이어는 고려하지 않았다. 또한 시각 효과를 preset별로 약하게 만들려는 과정에서 `gradient color alpha`와 view-level `.opacity`를 동시에 줄여, 레이어가 이중 감쇠되는 문제가 생겼다.

## Solution

`ShanksSceneStyle`에 fish 전용 preset 토큰(`fishCount`, `fishOpacity`, `fishScale`)을 추가하고, `ShanksCinematicSceneBackground`의 water mass와 caustic 사이에 `ShanksDeepSeaFishOverlay`를 삽입했다. fish silhouette는 별도 `Shape`로 정의해 path smoke test를 붙였고, final visibility는 view-level opacity에서 한 번만 조절하도록 정리했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | fish preset, silhouette shape, parallax overlay 추가 | 기존 scene engine 안에서 후방 심도 레이어를 재사용 가능하게 만들기 위해 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | fish path 및 preset tiering 테스트 추가 | 새 shape와 presentation-depth 규칙 회귀를 막기 위해 |
| `docs/plans/2026-03-09-shanks-deep-sea-fish-parallax.md` | 구현 계획 기록 | future expansion을 한 단위로 좁힌 근거와 검증 전략을 남기기 위해 |
| `todos/096-pending-p3-shanks-cinematic-theme-future-expansions.md` | 구현된 아이템 체크 및 backlog 정리 | 남은 future items를 계속 추적 가능하게 유지하기 위해 |

### Key Code

```swift
ShanksDeepSeaFishSilhouetteShape()
    .fill(
        LinearGradient(
            colors: [
                theme.shanksCurrentColor.opacity(spec.opacity * 0.14 * darkBoost),
                theme.shanksDeepColor.opacity(spec.opacity * 0.72 * darkBoost),
                theme.shanksAbyssColor.opacity(spec.opacity * 0.94),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .opacity(style.fishOpacity)
```

## Prevention

scene engine 위에 새 장식 레이어를 얹을 때는 `preset token`과 `overlay implementation`을 한 파일 안에서 같이 추가하고, 시각 강도는 가능한 한 한 레벨에서만 감쇠한다. path shape는 0-size smoke test를 붙이고, presentation-depth 규칙은 숫자 비교 테스트로 고정해 두면 later tweak 시 회귀를 빨리 잡을 수 있다.

### Checklist Addition

- [ ] 새 scene overlay가 들어가면 preset tiering(tab/detail/sheet) 값이 테스트로 고정되어 있는지 확인
- [ ] gradient alpha와 outer `.opacity`가 같은 강도 토큰을 이중 적용하지 않는지 확인
- [ ] future-effect backlog를 구현했으면 원래 TODO에 남은 아이템 수를 같이 갱신

### Rule Addition (if applicable)

없음. 기존 theme scene pattern과 testing 규칙 안에서 처리 가능하다.

## Lessons Learned

- future expansion도 scene engine 내부 확장으로 닫히면 범위를 작게 유지하면서도 세계관 밀도를 높일 수 있다.
- 시각 효과 품질 문제는 코드가 "맞게 동작"하는 것과 별개로 alpha 조합처럼 작은 수식 하나에서 발생할 수 있다.
- custom shape를 테스트 가능 단위로 분리해 두면 시각 회귀 검증 비용이 크게 낮아진다.
