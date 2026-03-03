---
tags: [theme, solar-pop, design-system, watch-parity, animation, xcassets]
date: 2026-03-04
category: solution
status: implemented
related_files:
  - DUNE/Domain/Models/AppTheme.swift
  - DUNE/Presentation/Shared/Extensions/AppTheme+View.swift
  - DUNE/Presentation/Shared/Components/WaveShape.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNE/Presentation/Shared/Components/SectionGroup.swift
  - DUNE/Presentation/Shared/Components/ProgressRingView.swift
  - DUNEWatch/Views/WatchWaveBackground.swift
  - Shared/Resources/Colors.xcassets
  - DUNETests/AppThemeTests.swift
  - DUNETests/WaveShapeTests.swift
related_solutions:
  - docs/solutions/design/2026-03-01-multi-theme-architecture.md
  - docs/solutions/design/2026-03-03-arctic-dawn-theme.md
---

# Solar Pop Theme (Warm Glow + Ember Motion)

## Problem

기존 5개 테마와 감성적으로 겹치지 않으면서도 전체 사용자에게 무난하게 선택 가능한 신규 테마가 필요했다.  
요구사항은 iOS + watchOS 동시 적용, 전면 색상 토큰 반영, 배경 애니메이션 필수였다.

### Symptoms

- 테마 선택 폭은 늘었지만 warm/high-energy 무드의 명확한 옵션이 부재
- 신규 테마를 추가할 때 iOS/watch 분기 누락 위험 존재
- 색상 토큰만 추가하면 배경/카드/링의 시각 정체성이 약해질 수 있음

### Root Cause

테마 구조는 이미 안정적이지만, 신규 컨셉을 “토큰 + 배경 + 공통 컴포넌트” 단위로 동시에 확장하지 않으면
테마 완성도가 낮아진다.

## Solution

`AppTheme + prefix resolver + shared colorset` 구조를 유지한 채 `solarPop`을 추가하고,
Solar 전용 wave shape/overlay를 도입해 시각 정체성을 완성했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/AppTheme.swift` | `solarPop` case 추가 | 저장/동기화 rawValue 확장 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | `assetPrefix`/`displayName`/Solar wave accessor 추가 | prefix 기반 토큰 해석 + 라벨 노출 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | Solar Tab/Detail/Sheet dispatch 추가 | 루트 배경 라우팅 연결 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `SolarFlareShape`, `SolarFlareOverlayView`, Solar backgrounds 구현 | Solar 전용 애니메이션 무드 구현 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | Solar border/surface/bloom gradient 추가 | 카드 계층 시각 일관성 확보 |
| `DUNE/Presentation/Shared/Components/SectionGroup.swift` | Solar section 분기 추가 | 섹션 카드 톤 정합 |
| `DUNE/Presentation/Shared/Components/ProgressRingView.swift` | Solar accent gradient 캐시 추가 | 링 gradient 테마 정합 |
| `DUNEWatch/Views/WatchWaveBackground.swift` | Solar flare band 오버레이 추가 | watch 경량 동시 적용 |
| `Shared/Resources/Colors.xcassets/Solar*.colorset` | Solar colorset 27종 추가 | iOS/watch 공용 토큰 소스 |
| `DUNETests/AppThemeTests.swift` | case/prefix/themed asset 기대값 업데이트 | 신규 테마 회귀 방지 |
| `DUNETests/WaveShapeTests.swift` | `SolarFlareShapeTests` 추가 | 신규 shape 동작 검증 |

## Prevention

- 신규 테마 추가 시 고정 체크리스트:
1. `AppTheme` case + `assetPrefix` + `displayName`
2. shared `Colors.xcassets`에 theme prefix 토큰 일괄 추가
3. `WaveShape` dispatch + watch 배경 분기 동시 반영
4. `GlassCard`/`SectionGroup`/`ProgressRing` 시각 분기 반영
5. `AppThemeTests` + theme-specific shape tests 업데이트

## Verification

- `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2'`
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/AppThemeTests -only-testing DUNETests/WaveShapeTests`
- 결과: 빌드 성공, 대상 테스트 12개 통과

## Lessons Learned

- prefix resolver 구조 덕분에 색상 토큰 확장은 매우 빠르게 확장 가능하다.
- 신규 테마의 체감 품질은 토큰보다 배경/카드/링 같은 공통 컴포넌트 분기에서 결정된다.
- watch parity를 같은 커밋에서 함께 처리해야 테마 경험이 분리되지 않는다.

## Follow-up Fix (2026-03-04): Sun Core Stabilization

### Problem

- Solar SunBurst 중심 코어가 다중 gradient로 구성되어 태양 중심이 "고정된 노란 원"으로 보이지 않았다.
- ray/ring 애니메이션과 합성될 때 중심 색이 프레임마다 흔들려 보였다.

### Solution

- `SolarSunBurstOverlay`(iOS)와 `WatchSolarSunBurst`(watch) 모두에서 중심 코어를
  `Color("SolarGlow")` 기반 단색 원으로 분리했다.
- 기존 다중 gradient는 중심 코어가 아닌 외곽 corona 역할로 축소해 유지했다.
- 회전/드리프트 애니메이션은 ray/ring 레이어에만 남겨 시각적 움직임은 유지하고,
  중심 원은 고정 상태를 보장했다.

### Verification

- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,id=F4DFCC0D-2430-411D-AF07-E50D8B8AD255' -derivedDataPath .deriveddata -only-testing DUNETests/WaveShapeTests CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
- `scripts/test-unit.sh --no-regen --watch-only`
