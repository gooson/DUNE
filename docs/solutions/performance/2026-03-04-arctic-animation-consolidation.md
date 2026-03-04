---
tags: [arctic-dawn, animation, timelineview, drawingGroup, performance, frame-stability, swiftui, promotion]
date: 2026-03-04
category: solution
status: implemented
---

# Arctic Animation Consolidation via TimelineView + drawingGroup

## Problem

Arctic Dawn 배경에서 **탭 전환 시 끊김**과 **스크롤 시 버벅임** 발생.

### 근본 원인

1. **9개 독립 `@State phase` animation**: 각 오버레이(Ribbon, Curtain, EdgeTexture, MicroDetail)가 자체 `@State private var phase` + `withAnimation(.linear.repeatForever)` 보유. 배경 3종(Tab/Detail/Sheet) × 3-4 오버레이 = 프레임당 최대 9회 body 재평가
2. **per-element blur/blendMode ~225개**: `drawingGroup()` 없이 개별 GPU 렌더 패스
3. **ProMotion 120fps 과잉**: `minimumInterval: nil`은 120Hz 디바이스에서 불필요한 이중 렌더

## Solution

### 1. TimelineView 통합 (9 animations → 1 time source per background)

```swift
// BEFORE: 각 오버레이가 독립 animation
struct ArcticRibbonOverlayView: View {
    @State private var phase: CGFloat = 0
    .task { withAnimation(.linear(duration: 13).repeatForever) { phase = .pi * 2 } }
}

// AFTER: 외부에서 phase 주입
struct ArcticRibbonOverlayView: View {
    var phase: CGFloat = 0  // No @State, no .task
}

// 배경에서 단일 TimelineView로 모든 phase 파생
TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
    let elapsed = context.date.timeIntervalSinceReferenceDate
    ArcticRibbonOverlayView(
        phase: arcticPhase(elapsed: elapsed, duration: 13, reverse: true)
    )
    ArcticAuroraCurtainOverlayView(
        phase: arcticPhase(elapsed: elapsed, duration: 24)
    )
}
```

### 2. Phase 계산 유틸리티

```swift
enum ArcticAnimationPhase {
    static func phase(elapsed: TimeInterval, duration: Double, reverse: Bool = false) -> CGFloat {
        guard duration > 0 else { return 0 }
        let normalizedTime = elapsed.truncatingRemainder(dividingBy: duration) / duration
        let p = CGFloat(normalizedTime) * 2 * .pi
        return reverse ? -p : p
    }
}
```

- 순수 함수로 테스트 가능
- `truncatingRemainder`로 overflow-safe 주기 반복

### 3. drawingGroup() 배치

| 오버레이 | View 수 | drawingGroup | 이유 |
|----------|---------|--------------|------|
| Curtain | ~78 | Yes | blur + blendMode 집중 |
| MicroDetail | ~127 | Yes | 가장 많은 element |
| EdgeTexture | ~19 | Yes | blur 비용 높음 |
| Ribbon | 2 | No | 적은 view, 오버헤드 > 이득 |
| SkyGlow | 2 | No | 단순 gradient |

### 4. ProMotion 60fps Cap

```swift
// minimumInterval: nil → 120fps on ProMotion (불필요)
// minimumInterval: 1.0/60.0 → 60fps cap (11-24초 주기 animation에 120fps 불필요)
TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion))
```

### 5. Reduce Motion 처리

`AnimationTimelineSchedule(minimumInterval:paused:)`의 `paused` 파라미터 사용.
`paused: true`이면 TimelineView가 더 이상 업데이트하지 않아 정적 렌더 1회만 수행.

## Key Decisions

| 결정 | 이유 |
|------|------|
| `paused:` vs `.explicit([Date()])` | 동일 타입 보장 (ternary type mismatch 방지) |
| ForEach 평탄화 보류 | `drawingGroup()`이 composition collapse하므로 nested ForEach 병목 아님 |
| `arcticPhase()` wrapper 유지 | 20+ call site에서 가독성 향상 |
| animatableData 제거 | TimelineView 방식은 withAnimation을 사용하지 않음 |

## Prevention

- **새 Arctic 오버레이 추가 시**: `@State phase` + `.task`/`.onAppear` 패턴 금지. 외부 `phase: CGFloat` 파라미터 사용
- **새 배경 추가 시**: 반드시 단일 `TimelineView` 래핑 + `minimumInterval: 1.0/60.0`
- **고밀도 오버레이 (10+ views)**: `drawingGroup()` 필수
- **ProMotion 고려**: slow animation (>5초 주기)에 120fps 불필요 → 60fps cap

## Performance Impact

| 메트릭 | Before | After |
|--------|--------|-------|
| body 재평가 / frame | 최대 9회 | 1회 |
| GPU 렌더 패스 (Tab) | ~225+ | ~5 (drawingGroup 텍스처) |
| ProMotion 프레임 | 120fps | 60fps (동일 시각 품질) |
| animation 정확도 | SwiftUI interpolation | wall-clock elapsed (drift-free) |

## Related

- `docs/solutions/performance/2026-03-04-arctic-aurora-lod-frame-stability.md` — Phase 1 (LOD 시스템)
- `docs/solutions/performance/2026-03-04-artic-theme-compat-and-arctic-render-trim.md` — 호환성 + 렌더 트림
