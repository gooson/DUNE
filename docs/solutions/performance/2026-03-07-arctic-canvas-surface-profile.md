---
tags: [arctic-dawn, performance, canvas, swiftui, timelineview, iphone, surface-profile]
category: performance
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNETests/WaveShapeTests.swift
related_solutions:
  - performance/2026-03-04-arctic-animation-consolidation.md
  - performance/2026-03-04-arctic-aurora-lod-frame-stability.md
  - performance/2026-03-06-arctic-background-playback-gating-and-sample-cache.md
---

# Solution: Arctic Canvas Overlays and Surface Performance Profile

## Problem

Arctic Dawn는 기존 최적화 이후에도 iPhone에서 `Tab`, `Detail`, `Sheet` 전환과 스크롤 중에 secondary layer 비용이 남아 있었다.

### Symptoms

- `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView`가 여전히 가장 비싼 장식 레이어였다
- Tab/Detail/Sheet가 모두 비슷한 밀도와 cadence로 보조 디테일을 갱신했다
- 정적인 glow/gradient 레이어도 `TimelineView` tick과 함께 다시 조합됐다

### Root Cause

- 고밀도 decorative layer가 SwiftUI view tree 중심으로 구성돼 diff/render 비용이 컸다
- 보조 레이어가 surface 크기와 중요도 차이 없이 같은 속도로 움직였다
- animation과 무관한 backdrop 레이어가 dynamic stack과 같이 묶여 있었다

## Solution

Arctic의 primary motion은 유지하고, secondary layer만 공격적으로 최적화했다.

1. `MicroDetail`, `EdgeTexture`를 `Canvas` 기반으로 전환
2. `ArcticPerformanceProfile`로 surface별 normal-mode density/cadence 분리
3. 정적 atmosphere layer를 `TimelineView` 바깥으로 이동

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticPerformanceProfile`, `ArcticPhaseQuantizer` 추가 | surface별 성능 정책과 secondary phase snapping 단일 소스화 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticAuroraMicroDetailOverlayView`를 Canvas 기반 path draw로 전환 | high-density decorative overlay의 view churn 제거 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticAuroraEdgeTextureOverlayView`를 Canvas 기반으로 전환 | edge texture sparkle 비용 절감 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Tab/Detail/Sheet가 각자 profile을 사용하도록 변경 | 작은 surface일수록 더 공격적으로 비용 절감 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | sky glow / bloom / tint gradient를 timeline 밖으로 분리 | 정적 레이어 재구성 비용 축소 |
| `DUNETests/WaveShapeTests.swift` | profile/quantizer/normalScale tests 추가 | 성능 정책 회귀 방지 |

### Key Code

```swift
struct ArcticPerformanceProfile: Sendable, Equatable {
    let microPhaseStep: Double
    let edgePhaseStep: Double
    let filamentNormalScale: Double
    let microStrandNormalScale: Double
    let microCrestNormalScale: Double
    let microSparkleNormalScale: Double
    let edgeSparkleNormalScale: Double
}

enum ArcticPhaseQuantizer {
    static func quantizedElapsed(_ elapsed: TimeInterval, step: Double) -> TimeInterval {
        guard step > 0 else { return elapsed }
        return (elapsed / step).rounded(.down) * step
    }
}
```

```swift
let profile = ArcticPerformanceProfile.profile(for: .detail)
let microElapsed = ArcticPhaseQuantizer.quantizedElapsed(elapsed, step: profile.microPhaseStep)

ArcticAuroraMicroDetailOverlayView(
    opacity: 0.15,
    phase: arcticPhase(elapsed: microElapsed, duration: 17),
    qualityMode: mode,
    performanceProfile: profile
)
```

## Prevention

### Checklist Addition

- [ ] 고밀도 decorative overlay는 먼저 `Canvas` 또는 path draw로 평탄화 가능한지 검토했는가?
- [ ] primary motion과 secondary motion을 같은 cadence로 묶지 않았는가?
- [ ] surface 크기(`tab/detail/sheet`)에 따라 normal-mode density를 분리했는가?
- [ ] animation과 무관한 gradient/glow layer를 dynamic timeline에 같이 두지 않았는가?

## Lessons Learned

- 테마 최적화에서 가장 안전한 공격 지점은 primary motif가 아니라 `secondary decorative layer`다.
- `Canvas` 전환만으로 끝나지 않고, surface별 density/cadence 정책이 같이 있어야 체감 차이가 커진다.
- `TimelineView`를 유지하더라도 정적 레이어를 밖으로 빼면 프레임마다 재조합되는 비용을 확실히 줄일 수 있다.
