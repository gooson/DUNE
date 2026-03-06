---
tags: [arctic-dawn, performance, timelineview, scenephase, thermal, battery, memory, sample-cache]
category: performance
date: 2026-03-06
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/OceanWaveBackground.swift
  - DUNETests/WaveShapeTests.swift
related_solutions:
  - performance/2026-03-04-arctic-animation-consolidation.md
  - performance/2026-03-04-arctic-aurora-lod-frame-stability.md
  - performance/2026-03-04-artic-theme-compat-and-arctic-render-trim.md
---

# Solution: Arctic Background Playback Gating and Shared Sample Cache

## Problem

Arctic Dawn는 이미 `TimelineView` 통합과 `drawingGroup()` 최적화를 적용했지만,
배경이 비활성 상태일 때도 animation tick을 유지할 수 있고,
hot render path에서 동일한 normalized sample을 반복 생성하고 있었다.

### Symptoms

- app inactive/background 상태에서 Arctic background가 불필요한 animation tick을 유지할 수 있었다
- `ArcticRibbonShape`가 shape init마다 sample array를 새로 만들었다
- Arctic shape path 계산이 동일한 normalized sample set을 매번 다시 계산했다

### Root Cause

- playback pause 정책이 `reduceMotion`에만 연결되어 있어 app lifecycle과 분리되어 있었다
- Arctic shapes가 재사용 가능한 sampling table 대신 instance-local 계산에 의존했다

## Solution

Arctic 전용 playback helper를 추가해 `scenePhase != .active`에서도 `TimelineView`를 멈추도록 하고,
Ribbon/Curtain/EdgeGlow shape가 shared normalized sample cache를 사용하도록 리팩터링했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticPlaybackPolicy` 추가 | app inactive/background 상태에서 background animation tick 중단 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticNormalizedSamples` 추가 | hot render path에서 sample table 재사용 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | `ArcticRibbonShape`, `ArcticAuroraCurtainShape`, `ArcticAuroraEdgeGlowShape` refactor | per-instance sample 생성 제거 및 공통 cache 사용 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Arctic Tab/Detail/Sheet backgrounds에 `scenePhase` pause 적용 | battery/thermal 비용 절감 |
| `DUNETests/WaveShapeTests.swift` | playback policy / sample cache tests 추가 | lifecycle policy와 cache sequence 회귀 방지 |

### Key Code

```swift
enum ArcticPlaybackPolicy {
    static func isPaused(scenePhase: ScenePhase, reduceMotion: Bool) -> Bool {
        reduceMotion || scenePhase != .active
    }
}

enum ArcticNormalizedSamples {
    static let ribbon = build(count: 120)
    static let curtain = build(count: 88)
    static let edgeGlow = build(count: 84)

    static func values(count: Int) -> [CGFloat] {
        switch count {
        case 120: ribbon
        case 88: curtain
        case 84: edgeGlow
        default: build(count: count)
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] `TimelineView` 기반 background animation은 `reduceMotion`뿐 아니라 `scenePhase` pause 정책을 가지는가?
- [ ] hot path `Shape`가 동일 sample/lookup table을 instance마다 다시 만들지 않는가?
- [ ] sample cache는 path math를 바꾸지 않고 재사용만 도입했는가?
- [ ] full suite baseline failure가 있으면 변경 영향 범위 targeted test를 별도로 실행했는가?

### Rule Addition (if applicable)

이번에는 `.claude/rules/` 업데이트 대신 solution 문서로 패턴을 보존한다.
같은 최적화가 다른 wave 배경에도 반복되면 공통 performance rule로 승격한다.

## Lessons Learned

- 지속 성능 개선은 새로운 렌더 구조를 도입하기 전에 lifecycle pause와 shared cache 같은 무회귀 최적화부터 적용하는 편이 안전하다
- `TimelineView` 최적화는 frame cadence뿐 아니라 **언제 완전히 멈출 수 있는지**까지 같이 설계해야 battery/thermal 효과가 난다
- 전체 테스트 스위트 baseline이 깨져 있어도, 변경 영향 범위를 정확히 좁힌 targeted regression test는 여전히 유효한 안전장치다
