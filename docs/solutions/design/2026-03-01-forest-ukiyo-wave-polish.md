---
tags: [theme, forest, ukiyo-e, desert, ocean, wave, dark-mode, animation, crest]
date: 2026-03-01
category: solution
status: implemented
related_files:
  - DUNE/Presentation/Shared/Components/DesertDuneShape.swift
  - DUNE/Presentation/Shared/Components/DesertWaveBackground.swift
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNE/Presentation/Shared/Components/ForestSilhouetteShape.swift
  - DUNE/Presentation/Shared/Components/ForestWaveBackground.swift
  - DUNE/Presentation/Shared/DesignSystem.swift
  - DUNEWatch/DesignSystem.swift
---

# Solution: Forest Ukiyo Wave Polish (Desert/Ocean/Forest)

## Problem

Desert/Ocean/Forest 배경 웨이브가 테마 정체성을 충분히 전달하지 못했다.

### Symptoms

- Desert 사구 가장자리가 거칠고, 매끈한 사구 질감이 약했다.
- Ocean의 최고 파도(컬 강조 레이어)에서 위상 이동 시 시각적 튐이 체감됐다.
- Forest 다크모드에서 실루엣/질감이 쉽게 뭉개졌고, 우키요 숲 무드가 약했다.
- 전체 배경 드리프트 속도가 상대적으로 빠르게 느껴졌다.

### Root Cause

- 테마별 레이어 파라미터(amplitude/frequency/opacity/drift)와 질감 수식이 초기에 보수적으로 설정되어 있었다.
- Ocean surface에 dramatic curl을 켠 상태에서 강한 steepness/crest 조합이 중첩됐다.
- Forest는 색/불투명도 대비 보정과 크레스트 계층 표현이 부족했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DesertDuneShape.swift` | edge noise 0, ripple 기여 축소 | 사구 표면을 매끈하게 정리 |
| `DesertWaveBackground.swift` | 반투명 crest 2-layer(밴드+코어) 추가, 파라미터 재조정 | 모래 능선 강조 및 화이트 레이어 도입 |
| `OceanWaveBackground.swift` | highest wave curl 사용 제거, 고저/크레스트 수치 재튜닝 | 최고 파도 애니메이션 안정화 |
| `ForestSilhouetteShape.swift` | canopy swell/rounded pulse 수식 강화, noise 스케일 확대 | "몽글몽글" 질감을 노이즈 중심으로 강화 |
| `ForestWaveBackground.swift` | crest 2-layer, dark mode visibility boost, grain 강도 제어 | 우키요 무드 강화 + 다크모드 가시성 확보 |
| `DesignSystem.swift` / `DUNEWatch/DesignSystem.swift` | `waveDrift` 12s로 완화 | 전체 모션 안정감 향상 |

### Key Code

```swift
// Ocean surface layer: curl 파라미터 전달 제거로 최고 파도 튐 완화
OceanWaveOverlayView(
    color: theme.oceanSurfaceColor,
    steepness: 0.44,
    crestHeight: 0.38 * scale,
    crestSharpness: 0.12 * scale,
    driftDuration: 12
)
```

## Prevention

- 테마 배경 튜닝 시 다음 순서를 고정한다:
  1. Shape 수식(기본 질감) 조정
  2. Layer 파라미터 조정
  3. Crest/Grain 오버레이 조정
- 극단 표현(curl/steepness)은 다크모드 대비와 함께 페어로 검증한다.
- 공통 애니메이션 토큰(`waveDrift`)은 테마별 개별 상수 대신 DS 토큰으로 관리한다.

## Lessons Learned

- "몽글함"은 파형 진폭보다 edge/noise 스케일과 pulse 곡선 형태가 체감 품질에 더 크게 작용한다.
- crest는 단일 stroke보다 "넓은 반투명 밴드 + 내부 선" 2계층이 테마 무드를 안정적으로 전달한다.
- 배경 애니메이션은 속도 증가보다 위상 안정성과 대비 유지가 체감 품질에 더 중요하다.
