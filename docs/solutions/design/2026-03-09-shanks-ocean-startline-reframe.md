---
tags: [theme, shanks, hero-card, wave-background, swiftui, ipad]
category: general
date: 2026-03-09
severity: important
related_files:
  [
    DUNE/Presentation/Shared/Components/WaveShape.swift,
    DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift,
    DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift,
    DUNE/Presentation/Dashboard/DashboardView.swift,
    DUNE/Presentation/Activity/ActivityView.swift,
    DUNE/Presentation/Wellness/WellnessView.swift,
    DUNE/Presentation/Life/LifeView.swift,
    DUNETests/ShanksThemeEnhancementTests.swift,
    docs/plans/2026-03-09-shanks-ocean-startline-reframe.md,
  ]
related_solutions:
  [
    docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md,
    docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md,
  ]
---

# Solution: 샹크스 바다 장면 시작선을 히어로 카드 실제 3/4 지점에 맞추기

## Problem

샹크스 시네마틱 오션 테마는 장면 구성 자체는 완성되어 있었지만, 바다 mass와 거품, 배 레이어의 시작선이 hero card 실제 위치를 따라가지 못해 화면마다 체감 품질이 들쭉날쭉했다.

### Symptoms

- Today/Activity/Wellness/Life 탭에서 hero card 하단 1/4 지점보다 위에서 바다가 시작해 첫 화면이 답답하게 보였다.
- Wellness의 partial failure banner, Dashboard의 baseline progress 같은 hero 전후 분기에서 start line이 어긋났다.
- iPad regular width나 탭별 hero 높이 차이 때문에 고정 inset 숫자만으로는 “hero 3/4 지점부터 시작” 요구를 안정적으로 맞출 수 없었다.

### Root Cause

첫 구현은 `ShanksSceneStyle.sceneTopInset` preset과 size-class 보정만으로 ocean scene을 아래로 내렸다. 이 방식은 scene 자체를 늦게 시작시키는 데는 도움이 됐지만, 실제 hero card frame을 읽지 못해 탭별 hero 높이와 배너 유무를 반영하지 못했다.

## Solution

탭 루트가 실제 hero card frame을 preference로 올리고, `TabWaveBackground`가 그 값을 environment로 받아 샹크스 ocean scene의 start line override로 쓰도록 바꿨다. 계산식은 `hero.minY + hero.height * 0.75`로 고정해 바다가 hero 하단 1/4 지점에서 시작되게 맞췄고, detail/sheet처럼 hero anchor가 없는 경로만 기존 preset fallback을 유지했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | `TabHeroStartLine`, preference key, environment key, hero frame reporter 추가 | 탭 루트가 hero card 실제 frame을 배경으로 전달할 수 있게 하기 위해 |
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | tab 배경이 hero start line override를 읽도록 수정 | 샹크스 tab 배경이 preset 대신 실제 hero 기준선을 사용할 수 있게 하기 위해 |
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | `sceneTopInsetOverride` 지원 추가 | tab은 measured inset을 쓰고 detail/sheet는 preset fallback을 유지하기 위해 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | condition hero와 baseline progress 분기 모두 hero frame report 연결 | Today 탭의 대체 hero 상태에서도 바다 시작선이 어긋나지 않게 하기 위해 |
| `DUNE/Presentation/Activity/ActivityView.swift` | training readiness hero frame을 background에 전달 | Activity hero 높이에 맞춰 바다 시작선을 정렬하기 위해 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | hero card와 partial failure banner 이후 위치를 측정해 전달 | Wellness의 배너 유무에 따라 바다 시작선이 함께 이동하게 하기 위해 |
| `DUNE/Presentation/Life/LifeView.swift` | child hero section frame을 root background로 전달 | isolated query 구조를 유지하면서 Life hero 기준선을 공유하기 위해 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | hero frame 3/4 anchor test, zero-height clamp test 추가 | measured start line 계산이 경계값에서 회귀하지 않도록 하기 위해 |
| `docs/plans/2026-03-09-shanks-ocean-startline-reframe.md` | 구현 계획 기록 | 요청 배경, 검증 전략, 리스크를 재사용 가능하게 남기기 위해 |

### Key Code

```swift
static func inset(for frame: CGRect) -> CGFloat {
    guard frame.height > 0 else { return 0 }
    return max(frame.minY + frame.height * 0.75, 0)
}
```

```swift
NavigationLink(value: score) {
    ConditionHeroView(...)
}
.reportTabHeroFrame()

TabWaveBackground()
    .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
```

## Prevention

시각적으로 hero card에 고정되어 보여야 하는 scene background는 추정 inset 숫자보다 실제 hero frame 측정을 우선한다. preset은 detail/sheet처럼 anchor가 없는 경로의 fallback으로만 둔다.

### Checklist Addition

- [ ] hero card가 있는 tab root가 실제 hero frame을 preference로 보고하는가?
- [ ] 대체 hero 분기(loading, baseline, fallback card)도 같은 anchor 경로를 쓰는가?
- [ ] tab은 measured start line, detail/sheet는 fallback preset으로 책임이 분리돼 있는가?

### Rule Addition (if applicable)

즉시 `.claude/rules/`로 승격할 정도의 범용 규칙은 아니므로 추가 없음.

## Lessons Learned

- 시네마틱 테마의 과밀도 문제는 레이어 숫자보다 anchor 정렬 오차에서 더 자주 발생한다.
- hero-first 화면에서 배경 품질 요구가 높으면 preset 튜닝보다 geometry 전달이 결과가 안정적이다.
- isolated child view 구조여도 preference + environment 조합이면 hero 위치를 root background로 안전하게 올릴 수 있다.
