---
tags: [theme, arctic-dawn, aurora, performance, swiftui, animation, frame-stability, drawingGroup, canvas]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Arctic Theme 성능 개선 Phase 2

## Problem Statement

Arctic Dawn 테마에서 **탭 전환 시 끊김**과 **스크롤 시 버벅임**이 체감된다.
1차 최적화(LOD + 렌더 트림)로 저전력/Reduce Motion 경로는 개선되었으나,
**normal 모드**에서의 프레임 안정성은 여전히 부족하다.

핵심 목표: **현재 디자인/퀄리티 100% 유지, 오직 성능만 개선**

## Target Users

- Arctic Dawn 테마를 일상적으로 사용하는 사용자
- 탭 왕복, 리스트 스크롤을 빈번하게 수행하는 사용자
- 구형 기기(iPhone 15 이하)에서도 부드러운 체감을 기대하는 사용자

## Success Criteria

- **탭 전환 시 프레임 드랍 해소**: Arctic → 다른 탭 → Arctic 왕복 시 끊김 없음
- **리스트 스크롤 60fps 유지**: Arctic 배경 위에서 스크롤 시 jank 없음
- **비주얼 회귀 없음**: 오로라 커튼/리본/엣지 글로우/마이크로 디테일 모두 유지
- **빌드+테스트 통과**: 기존 WaveShapeTests 및 신규 테스트 통과

## 현재 병목 분석 (ArcticTabWaveBackground 기준)

### 병목 1: 독립 animation 9개 → 프레임당 9회 state mutation

| 뷰 | @State phase 개수 | animation 주기 |
|----|-------------------|---------------|
| ArcticRibbonOverlayView ×3 | 3 | 11s, 14s, 18s |
| ArcticAuroraCurtainOverlayView ×4 | 4 | 14s, 18s, 20s, 24s |
| ArcticAuroraMicroDetailOverlayView ×1 | 1 | 18s |
| ArcticAuroraEdgeTextureOverlayView ×1 | 1 | 16s |
| **합계** | **9** | |

SwiftUI는 각 `@State` 변경마다 해당 View의 `body`를 재평가한다.
9개 독립 animation이 60fps로 phase를 변경하면, **프레임당 최대 9회** body 재평가가 발생한다.
이것이 탭 전환과 스크롤 시 가장 큰 병목이다.

### 병목 2: per-element blur + blendMode ~225개

MicroDetailOverlayView에서만 127개 Shape에 개별 `.blur()` + `.blendMode()` 적용.
각 blur는 GPU에서 별도 렌더 패스를 생성한다. 컨테이너 단위로 통합하면 패스 수를 대폭 축소할 수 있다.

### 병목 3: 중첩 ForEach (Curtain × Filament)

```
ForEach(curtainSpecs) { spec →
    CurtainShape (fill)
    CurtainShape (stroke/highlight)
    ForEach(filamentLines) { strand →  ← 중첩
        CurtainShape (stroke)
    }
}
```

6커튼 × (fill + stroke + 11필라멘트) = **78개 ArcticAuroraCurtainShape** path 연산/frame.
각 Shape는 88 sample point의 path를 매 frame 재계산한다.

### 병목 4: ArcticRibbonOverlayView 이중 animation 시작

`.task` + `.onAppear` 양쪽에서 동일한 animation을 시작한다.
`.task`만 사용해야 한다 (swiftui-patterns.md 규칙: `.repeatForever` → `.task` 사용).

### 병목 5: GeometryReader 2개소

`ArcticAuroraMicroDetailOverlayView`와 `ArcticAuroraEdgeTextureOverlayView`에서
GeometryReader가 레이아웃 패스를 강제한다.

## Proposed Approach (중간 범위 — 구조 리팩토링)

### 전략 A: TimelineView 기반 animation 통합

**현재**: 9개 `@State phase` + 9개 `withAnimation(.linear.repeatForever)`
**개선**: 단일 `TimelineView(.animation)` → 시간값에서 각 레이어 phase를 파생

```
TimelineView(.animation) { context →
    let elapsed = context.date.timeIntervalSinceReferenceDate
    ArcticLayerStack(elapsed: elapsed)
}
```

- 각 레이어의 phase = `fmod(elapsed / driftDuration, 1.0) * 2π`
- **state mutation 0회/frame** (TimelineView가 body 재평가를 직접 트리거)
- 모든 phase 계산이 body 내에서 순수 함수로 수행되므로 SwiftUI diff 비용 최소화

**리스크**: TimelineView는 초당 120fps 렌더를 요청할 수 있어 ProMotion 디바이스에서
오히려 비용 증가 가능. `.animation` 대신 커스텀 cadence로 제한 필요.

### 전략 B: drawingGroup() 적용으로 GPU compositing 통합

**현재**: 각 Shape에 개별 blur + blendMode → 수백 개의 렌더 패스
**개선**: 고비용 오버레이 컨테이너에 `.drawingGroup()` 적용

적용 대상:
1. `ArcticAuroraCurtainOverlayView` body의 ZStack → `.drawingGroup()`
2. `ArcticAuroraMicroDetailOverlayView` body의 ZStack → `.drawingGroup()`
3. `ArcticAuroraEdgeTextureOverlayView` body의 ZStack → `.drawingGroup()`

drawingGroup은 View 서브트리를 Metal 텍스처로 래스터라이즈하여 단일 이미지로 합성한다.
blur/blendMode가 많은 서브트리에서 효과가 크다.

**리스크**: drawingGroup 내부에서 `Color.opacity()` 정밀도가 미세하게 달라질 수 있다.
시각 검증 필수.

### 전략 C: Ribbon 이중 시작 제거

`.onAppear` 블록 제거, `.task`만 유지.
규칙 근거: `swiftui-patterns.md` — "`.repeatForever` 애니메이션 시작 → `.task` 사용"

### 전략 D: 중첩 ForEach 평탄화

Curtain × Filament 중첩을 사전 계산된 flat 배열로 변환:

```swift
private struct FlatFilamentSpec: Identifiable {
    let id: Int
    let curtainIndex: Int
    let strandIndex: Int
    let centerX: CGFloat
    let bandWidth: CGFloat
    // ... pre-computed values
}

// body에서:
ForEach(flatFilamentSpecs) { spec in
    // 단일 레벨 ForEach
}
```

중첩 해소로 SwiftUI diff 비용 감소 + 코드 가독성 향상.

### 전략 E: Shape sample count 조건부 축소

| Shape | 현재 sample | 개선안 |
|-------|------------|--------|
| ArcticRibbonShape | 120 | Tab: 120, Detail: 80, Sheet: 60 |
| ArcticAuroraCurtainShape | 88 | Tab: 88, Detail: 60, Sheet: 48 |
| ArcticAuroraEdgeGlowShape | 84 | 60 (모든 컨텍스트) |

화면 크기/레이어 높이가 작을수록 적은 sample로도 동일한 시각 인상 유지 가능.

### 전략 F: GeometryReader 제거 (overlay + relative 방식 전환)

MicroDetail과 EdgeTexture에서 `proxy.size` 대신 `.frame(height:)` + 비율 기반 레이아웃으로 전환.
또는 `Canvas` 내부에서 `context.size` 사용 (Canvas는 GeometryReader처럼 추가 레이아웃 패스를 유발하지 않음).

## 우선순위 제안

| 순서 | 전략 | 예상 효과 | 구현 난이도 | 회귀 위험 |
|------|------|----------|------------|----------|
| 1 | C: 이중 시작 제거 | 낮음 | 매우 쉬움 | 없음 |
| 2 | B: drawingGroup | 높음 | 쉬움 | 낮음 (시각 검증) |
| 3 | A: TimelineView 통합 | 매우 높음 | 중간 | 중간 (animation 정확도) |
| 4 | D: ForEach 평탄화 | 중간 | 쉬움 | 없음 |
| 5 | E: sample count 축소 | 중간 | 쉬움 | 낮음 |
| 6 | F: GeometryReader 제거 | 중간 | 중간 | 낮음 |

## Constraints

- **비주얼 100% 유지**: 레이어 제거 없음, 색/구도/모티프 변경 없음
- **구조 리팩토링 허용**: View 구조, animation 방식 변경 가능
- **Canvas 전면 재작성은 제외**: 부분적 Canvas 활용은 허용
- **Tab/Detail/Sheet 모두 적용**: 동일 전략을 3개 배경에 일관 적용
- **기존 LOD 시스템 유지**: conserve 모드와의 호환성 보장

## Edge Cases

- **TimelineView + Reduce Motion**: reduceMotion 시 TimelineView를 정지해야 함
- **drawingGroup + dark mode**: 텍스처 래스터화 시 color space 변환 주의
- **탭 전환 시 animation 재시작**: TimelineView는 elapsed 기반이므로 자연스럽게 재개
- **ProMotion 디바이스**: 120Hz에서 animation cadence 제한 필요할 수 있음
- **스크린샷/스냅샷 테스트**: drawingGroup 적용 시 렌더 타이밍 차이

## Scope

### MVP (Must-have)

- [x] Ribbon 이중 시작 제거 (전략 C)
- [ ] drawingGroup 적용 (전략 B) — 가장 효과 대비 비용 좋음
- [ ] TimelineView 통합 (전략 A) — 근본 원인 해결
- [ ] ForEach 평탄화 (전략 D)

### Nice-to-have (Follow-up)

- [ ] Shape sample count 컨텍스트별 분기 (전략 E)
- [ ] GeometryReader → Canvas/overlay 전환 (전략 F)
- [ ] ProMotion 디바이스 cadence 제한
- [ ] Instruments 기반 before/after 프레임 비교 문서화

## Open Questions

- TimelineView `.animation` cadence가 기기별로 다를 수 있는데, 60fps 상한이 필요한가?
- drawingGroup 적용 시 `.blendMode(.screen)`이 부모 컨텍스트와 정확히 동일하게 합성되는가?
- MicroDetail의 Capsule 127개를 Canvas draw로 전환하면 어떤 수준의 성능 이득이 있는가?

## Next Steps

- [ ] `/plan arctic theme perf phase2` 으로 구현 계획 생성
