---
tags: [arctic-dawn, aurora, swiftui, lod, low-power-mode, frame-stability, performance]
category: performance
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNETests/WaveShapeTests.swift
related_solutions:
  - design/2026-03-03-arctic-dawn-theme.md
  - design/theme-wave-visual-upgrade.md
  - general/2026-03-02-forest-theme-today-animation-freeze-fix.md
---

# Solution: Arctic Aurora LOD for Frame Stability (Quality-Preserved)

## Problem

### Symptoms

- Arctic Dawn 배경에서 `ArcticAuroraCurtainOverlayView`, `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView`가
  동시에 다수의 shape/blur/blend 연산을 수행해 프레임 안정성 리스크가 있었다.
- 특히 저전력 상태에서도 일반 모드와 동일 밀도로 반복 렌더링되어 불필요한 비용이 발생했다.

### Root Cause

- 고비용 오버레이가 모두 고정 밀도(고정 seed 개수, 고정 filament 라인 수)로 렌더링됐다.
- 런타임 전력 상태를 반영하는 품질 단계(LOD)가 없어, 동일 시각 구조를 유지한 상태의 비용 절감 경로가 없었다.

## Solution

Arctic 전용 품질 모드(`normal`, `conserve`)를 도입하고, 핵심 레이어는 유지하면서 반복 밀도/블러 강도만 축소했다.
`conserve`는 저전력 모드 또는 Reduce Motion에서 자동 적용된다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticAuroraQualityMode`, `ArcticAuroraLOD.scaledCount` 추가 | 품질 모드 기반 반복 수 조절 단일 소스 제공 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Curtain/MicroDetail/EdgeTexture overlay에 `qualityMode` 파라미터 추가 | 고비용 오버레이를 모드별로 밀도 축소 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Tab/Detail/Sheet 배경에 저전력 상태 감지(`NSProcessInfoPowerStateDidChange`) 추가 | 런타임 전력 상태 변경 시 자동 LOD 전환 |
| `DUNETests/WaveShapeTests.swift` | Arctic LOD 계산 테스트 추가 | 품질 모드 분기와 최소 반복수 보장을 회귀 방지 |

### Key Code

```swift
enum ArcticAuroraQualityMode: Sendable {
    case normal
    case conserve
}

enum ArcticAuroraLOD {
    static func qualityMode(isLowPowerModeEnabled: Bool, reduceMotion: Bool) -> ArcticAuroraQualityMode {
        if reduceMotion || isLowPowerModeEnabled { return .conserve }
        return .normal
    }

    static func scaledCount(
        baseCount: Int,
        mode: ArcticAuroraQualityMode,
        normalScale: Double = 1.0,
        conserveScale: Double,
        minimum: Int = 1
    ) -> Int {
        guard baseCount > 0 else { return 0 }
        let rawScale = (mode == .normal) ? normalScale : conserveScale
        let scaled = Int((Double(baseCount) * rawScale).rounded(.down))
        return max(minimum, scaled)
    }
}
```

## Prevention

### Checklist Addition

- [ ] Arctic 배경 레이어 추가 시 `qualityMode`를 파라미터로 전달했는가?
- [ ] 반복 루프(ForEach seed/strand/filament)에 `ArcticAuroraLOD.scaledCount`를 적용했는가?
- [ ] 저전력 모드 전환(`NSProcessInfoPowerStateDidChange`) 시 품질 단계가 반영되는가?
- [ ] 핵심 레이어(커튼/리본/엣지 글로우)를 제거하지 않고 밀도만 조정했는가?

## Lessons Learned

- 시각 아이덴티티를 보존해야 하는 테마 최적화에서는 "레이어 제거"보다 "밀도 조절"이 회귀 리스크가 낮다.
- 저전력/접근성 신호를 통합한 2단계 LOD만으로도 반복 렌더링 비용을 안전하게 낮출 수 있다.
- 반복 수 계산 로직을 테스트 가능한 정적 유틸리티로 분리하면 성능 회귀를 빠르게 차단할 수 있다.
