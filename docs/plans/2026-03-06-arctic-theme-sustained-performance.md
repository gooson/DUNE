---
topic: arctic-theme-sustained-performance
date: 2026-03-06
status: draft
confidence: high
related_solutions:
  - performance/2026-03-04-arctic-animation-consolidation.md
  - performance/2026-03-04-arctic-aurora-lod-frame-stability.md
  - performance/2026-03-04-artic-theme-compat-and-arctic-render-trim.md
related_brainstorms:
  - 2026-03-06-arctic-theme-sustained-performance.md
---

# Implementation Plan: Arctic Theme Sustained Performance

## Context

Arctic Dawn는 이미 frame-stability 중심 최적화를 반영했지만, 지속 사용 시 발열/배터리/메모리 비용과 스크롤 체감 비용을 더 줄일 여지가 남아 있다.
이번 변경은 비주얼을 유지한 채, hot render path의 반복 할당과 불필요한 타임라인 tick을 줄이는 데 초점을 맞춘다.

## Requirements

### Functional

- Arctic Tab/Detail/Sheet background가 app inactive 상태에서 불필요하게 재생성/재생산되지 않아야 한다
- Arctic shape sampling이 shared cache를 사용해 동일 샘플 세트를 반복 생성하지 않아야 한다
- 기존 Arctic 배경 시각 인상과 motion direction은 유지되어야 한다

### Non-functional

- 디자인 100% 유지
- 공통화 가능한 성능 패턴을 Arctic 내부 helper로 먼저 정리
- 새 로직은 Swift Testing으로 회귀 방지
- build + 관련 unit tests 통과

## Approach

Arctic 전용 배경에 두 축의 최적화를 적용한다.

1. **Playback gating**: `TimelineView` pause 조건을 `reduceMotion`뿐 아니라 app `scenePhase`까지 확장해 비활성 상태에서 animation tick을 멈춘다.
2. **Sampling cache**: Ribbon/Curtain/Edge glow shape가 shared normalized sample cache를 사용하도록 바꿔 hot path의 반복 샘플 생성과 division 비용을 줄인다.

이 접근은 렌더 구조를 크게 바꾸지 않으므로 visual regression risk가 낮고, battery/thermal/CPU allocation을 동시에 줄일 수 있다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| GeometryReader -> Canvas 전면 전환 | 큰 구조적 성능 개선 가능 | 렌더 구조 변경이 커서 unattended run에 위험 | 미선택 |
| Curtain path에서 left/right edge 배열 제거 | allocation 감소 가능 | trig 재계산 증가로 CPU trade-off 불명확 | 미선택 |
| scenePhase pause + shared sample cache | 낮은 리스크, 공통 패턴화 가능, 테스트 용이 | 극단적 병목을 모두 제거하진 않음 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/brainstorms/2026-03-06-arctic-theme-sustained-performance.md` | Add | run 파이프라인 기준 brainstorm 문서 반영 |
| `docs/plans/2026-03-06-arctic-theme-sustained-performance.md` | Add | 구현 계획 문서 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Modify | Arctic playback gate + shared sample cache 추가 |
| `DUNETests/WaveShapeTests.swift` | Modify | playback policy / sample cache regression tests 추가 |

## Implementation Steps

### Step 1: Arctic playback policy 추가

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - Arctic 전용 playback helper 추가
  - `OceanLegacyArcticTabWaveBackground`, `OceanLegacyArcticDetailWaveBackground`, `OceanLegacyArcticSheetWaveBackground`에 `scenePhase` 기반 pause 조건 적용
- **Verification**:
  - build 성공
  - reduce motion + background state 조합에서 pause policy 테스트 가능

### Step 2: Shared sample cache로 hot path allocation 절감

- **Files**: `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift`
- **Changes**:
  - shared normalized sample cache helper 추가
  - `ArcticRibbonShape`, `ArcticAuroraCurtainShape`, `ArcticAuroraEdgeGlowShape`가 cache를 사용하도록 리팩터링
  - per-instance ribbon sample array 제거
- **Verification**:
  - 기존 path output이 비어 있지 않고 phase-driven 동작 유지
  - cache count/monotonic sequence 테스트 추가

### Step 3: Regression tests 추가

- **Files**: `DUNETests/WaveShapeTests.swift`
- **Changes**:
  - playback policy tests
  - normalized sample cache tests
- **Verification**:
  - `scripts/test-unit.sh --ios-only` 통과

## Edge Cases

| Case | Handling |
|------|----------|
| `scenePhase != .active` | Timeline pause 처리 |
| `reduceMotion == true` | 기존과 동일하게 pause 유지 |
| sample count 0 or 1 | helper가 안전한 최소 샘플 반환 |
| app foreground 재진입 | TimelineView가 기존 elapsed 기반 motion으로 재개 |

## Testing Strategy

- Unit tests: `WaveShapeTests`에 playback policy / sampling cache 테스트 추가
- Integration tests: 없음
- Manual verification:
  - Arctic Tab/Detail/Sheet 렌더 확인
  - app background -> active 복귀 후 animation 재개 확인
  - Arctic theme 스크롤 시 비주얼 회귀 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| scenePhase pause가 foreground 복귀 시 animation을 멈춘 채 둘 수 있음 | Low | Medium | helper를 순수 함수로 테스트하고 Timeline elapsed 기반 재개 유지 |
| sample cache refactor가 path 모양을 바꿀 수 있음 | Low | Medium | 기존 path tests 유지 + cache tests 추가 |
| 개선 폭이 제한적일 수 있음 | Medium | Low | 이후 Instruments 기반 Canvas/Geometry follow-up 여지 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 구현 구조를 크게 흔들지 않고 hot path allocation과 inactive animation tick을 줄이는 변경이라 회귀 리스크가 낮다.
