---
topic: arctic-theme-max-performance
date: 2026-03-07
status: implemented
confidence: medium
related_solutions:
  - performance/2026-03-04-arctic-animation-consolidation.md
  - performance/2026-03-04-arctic-aurora-lod-frame-stability.md
  - performance/2026-03-04-artic-theme-compat-and-arctic-render-trim.md
  - performance/2026-03-06-arctic-background-playback-gating-and-sample-cache.md
related_brainstorms:
  - 2026-03-07-arctic-theme-max-performance.md
---

# Implementation Plan: Arctic Theme Max Performance

## Context

Arctic Dawn 배경은 이미 `TimelineView`, `drawingGroup`, playback gating, LOD, shared sample cache를 적용했다.
하지만 iPhone에서 Tab/Detail/Sheet 전환과 리스트 스크롤 중에는 여전히 체감 hitch가 남아 있다.
이번 변경은 benchmark 수치보다 **체감상 더 부드럽게 느껴지는 것**을 우선하고,
시각 디테일은 최대 5% 이내 감소만 허용한다.

## Requirements

### Functional

- Arctic Tab/Detail/Sheet background의 micro/edge 레이어 비용을 줄인다
- primary motion(ribbon/curtain)은 유지하고, secondary motion만 더 공격적으로 최적화한다
- Arctic 배경의 정적 레이어는 animation tick과 분리해 불필요한 재구성을 줄인다

### Non-functional

- iPhone 기준 체감 성능 개선이 우선이다
- 시각 회귀는 5% 이내로 제한한다
- 새 성능 정책은 테스트 가능한 helper로 분리한다
- 관련 unit test와 iOS build/test를 통과한다

## Approach

Arctic 최대 성능 개선은 아래 3축으로 진행한다.

1. **Canvas 전환**:
   `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView`를 `Canvas` 기반으로 옮겨
   SwiftUI primitive 수십~수백 개를 단일 렌더 경로로 축소한다.

2. **Performance profile 도입**:
   surface별(`tab/detail/sheet`)로 micro/edge 레이어의 normal-mode 반복 밀도와 phase update step을 분리한다.
   primary ribbon/curtain은 기존 cadence를 유지하고, secondary layer만 quantized phase를 사용한다.

3. **정적 레이어 분리**:
   gradient, sky glow, bloom처럼 animation에 직접 연결되지 않는 레이어를 `TimelineView` 밖으로 이동해
   매 tick마다 다시 계산되지 않도록 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 전체 Arctic를 Canvas 하나로 재작성 | 최대 성능 가능성 | 구조 변경이 과도하고 회귀 위험 큼 | 기각 |
| normal 모드 LOD만 더 낮춤 | 구현이 쉬움 | geometry/view tree 비용은 그대로 남음 | 부분 채택 |
| micro/edge만 Canvas + surface profile + 정적 레이어 분리 | hot path를 직접 줄이고 회귀 범위 관리 가능 | helper 설계와 시각 튜닝 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/brainstorms/2026-03-07-arctic-theme-max-performance.md` | Add | 요구사항/제약 정리 |
| `docs/plans/2026-03-07-arctic-theme-max-performance.md` | Add | 구현 계획 문서 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Modify | Arctic performance profile, Canvas overlay, static layer 분리 |
| `DUNETests/WaveShapeTests.swift` | Modify | quantized phase/profile regression tests 추가 |

## Implementation Steps

### Step 1: Arctic performance profile 도입

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - surface kind(`tab/detail/sheet`) 기반 `ArcticPerformanceProfile` 추가
  - secondary layer phase quantization helper 추가
  - normal mode에서도 surface별 micro/edge 밀도 감축값 정의
- **Verification**:
  - quantization helper 단위 테스트 추가
  - profile별 phase step / scale 값 테스트 가능

### Step 2: Micro/Edge overlay를 Canvas로 전환

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - `ArcticAuroraMicroDetailOverlayView`를 `Canvas` 기반 렌더로 전환
  - `ArcticAuroraEdgeTextureOverlayView`를 `Canvas` 기반 렌더로 전환
  - `GeometryReader` 제거, `context.size` 사용
- **Verification**:
  - build 성공
  - 기존 phase/opacity 입력으로도 렌더 가능한 구조 유지

### Step 3: Arctic background 3종에 profile 적용 + 정적 레이어 분리

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - Tab/Detail/Sheet에서 공통 `ArcticPerformanceProfile` 사용
  - static gradient/glow/bloom를 timeline 밖으로 이동
  - ribbon/curtain은 raw elapsed, micro/edge는 quantized elapsed 사용
- **Verification**:
  - Arctic Tab/Detail/Sheet 컴파일 및 렌더 경로 정합성 유지
  - 수동 확인 포인트가 명확히 정의됨

### Step 4: Regression test 보강

- **Files**: `DUNETests/WaveShapeTests.swift`
- **Changes**:
  - profile lookup tests
  - quantized elapsed tests
  - normal mode scale tests
- **Verification**:
  - 관련 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| phase step이 0 이하 | quantization helper가 elapsed를 그대로 반환 |
| conserve mode | 기존 LOD 축소가 우선 적용되고 profile normal-scale은 보수적으로만 반영 |
| scene inactive / reduce motion | 기존 playback pause 정책 유지 |
| sheet처럼 작은 viewport | 더 작은 normal-scale과 더 큰 quantization step 적용 |

## Testing Strategy

- Unit tests: `WaveShapeTests`에 Arctic profile/quantization regression 추가
- Integration tests: 없음
- Manual verification:
  - Arctic Theme에서 Tab/Detail/Sheet 전환 시 hitch 체감 확인
  - Arctic 리스트 스크롤 추적성 확인
  - Low Power Mode / Reduce Motion 경로 회귀 없음 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Canvas 렌더가 기존보다 색감이 달라질 수 있음 | Medium | Medium | micro/edge에만 적용하고 curtain/ribbon은 유지 |
| quantized phase가 shimmer를 끊겨 보이게 할 수 있음 | Medium | Medium | secondary layer에만 적용, step을 surface별로 보수적으로 설정 |
| static layer 분리 중 z-order가 달라질 수 있음 | Low | Medium | 기존 레이어 순서와 동일한 묶음으로 추출 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: hot path를 직접 줄이는 방향이라 성능 개선 가능성은 높지만, Canvas 전환은 시각적 미세 조정이 필요하다.
