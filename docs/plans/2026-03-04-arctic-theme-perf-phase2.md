---
topic: arctic-theme-perf-phase2
date: 2026-03-04
status: approved
confidence: high
related_solutions:
  - docs/solutions/performance/2026-03-04-arctic-aurora-lod-frame-stability.md
  - docs/solutions/performance/2026-03-04-artic-theme-compat-and-arctic-render-trim.md
  - docs/solutions/design/2026-03-03-arctic-dawn-theme.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-arctic-theme-perf-phase2.md
---

# Implementation Plan: Arctic Theme Performance Phase 2

## Context

Arctic Dawn 배경에서 **탭 전환 시 끊김**과 **스크롤 시 버벅임**이 체감된다.
1차 최적화(LOD)로 저전력 경로는 개선되었으나 normal 모드에서 프레임 안정성이 부족하다.

근본 원인: 9개 독립 `@State phase` animation → 프레임당 다수 body 재평가 + per-element blur/blendMode ~225개

## Requirements

### Functional

- Arctic Dawn 배경의 핵심 레이어(커튼/리본/엣지 글로우/마이크로 디테일) 100% 유지
- 탭 전환 시 프레임 드랍 해소
- 리스트 스크롤 시 60fps 유지
- 저전력/Reduce Motion 경로 호환 유지

### Non-functional

- 기존 테마 정체성(색/구도/모티프) 회귀 없음
- Tab/Detail/Sheet 3개 배경 모두 동일 전략 적용
- 기존 LOD 시스템과의 호환성 보장

## Approach

3단계 최적화를 순차 적용한다:

1. **drawingGroup()**: 고비용 오버레이에 `.drawingGroup()` 적용하여 GPU 렌더 패스 통합
2. **TimelineView 통합**: 9개 독립 animation을 단일 TimelineView 시간 소스로 통합
3. **ForEach 평탄화**: Curtain × Filament 중첩 루프를 사전 계산 flat 배열로 변환

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Canvas 전면 재작성 | 최대 성능 | 구현 범위 거대, 회귀 위험 높음 | 보류 |
| 파라미터만 조정 (blur/sample 축소) | 안전 | 근본 원인(9개 animation) 미해결 | 보완적 활용 |
| TimelineView + drawingGroup + ForEach 평탄화 | 근본 원인 해결 + 렌더 패스 감소 | 새 패턴 도입 | **채택** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Modify | Arctic 배경 3종에 TimelineView + drawingGroup + ForEach 평탄화 적용 |
| `DUNETests/WaveShapeTests.swift` | Modify | Arctic ForEach 평탄화 로직 테스트 추가 |

## Implementation Steps

### Step 1: drawingGroup() 적용

- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `ArcticAuroraCurtainOverlayView` body ZStack에 `.drawingGroup()` 추가
  - `ArcticAuroraMicroDetailOverlayView` body ZStack에 `.drawingGroup()` 추가
  - `ArcticAuroraEdgeTextureOverlayView` body ZStack에 `.drawingGroup()` 추가
- **Rationale**: per-element blur/blendMode를 Metal 텍스처로 래스터화하여 렌더 패스 통합
- **Verification**: 빌드 성공 + 시각 회귀 없음

### Step 2: TimelineView 통합

- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `ArcticAnimationContext` 구조체 추가: elapsed → 각 레이어 phase 파생
  - `ArcticTabWaveBackground`, `ArcticDetailWaveBackground`, `ArcticSheetWaveBackground`를
    단일 `TimelineView(.animation)` 기반으로 전환
  - `ArcticRibbonOverlayView`, `ArcticAuroraCurtainOverlayView`,
    `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView`에서
    `@State phase` + `.task`/`.onAppear` 제거, 외부에서 `phase` 파라미터로 전달
  - Reduce Motion 시 TimelineView를 `TimelineSchedule.explicit([Date()])` (1회만)로 교체
- **Rationale**: 9개 독립 animation → 1개 시간 소스로 통합, body 재평가 1회/frame
- **Key Pattern**:
  ```swift
  TimelineView(reduceMotion ? .explicit([Date()]) : .animation) { context in
      let elapsed = context.date.timeIntervalSinceReferenceDate
      // Each layer derives its phase from elapsed / driftDuration
  }
  ```
- **Verification**: 빌드 성공 + animation이 이전과 동일 속도/방향으로 동작

### Step 3: Curtain ForEach 평탄화 *(Deferred)*

- **Status**: Deferred — perf-optimizer 분석 결과, `drawingGroup()`이 composition hierarchy를 이미 collapse하므로 nested ForEach는 유의미한 병목이 아님. 실측 프로파일에서 병목 재확인 시 별도 작업으로 진행.
- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `ArcticFlatCurtainElement` struct 추가: curtain + filament 정보를 사전 결합
  - `ArcticAuroraCurtainOverlayView`에서 `flatElements` computed property로
    curtain × filament을 단일 배열로 pre-compute
  - 중첩 ForEach를 단일 ForEach로 교체
- **Rationale**: SwiftUI diff 비용 감소 + 코드 가독성 향상
- **Verification**: 빌드 성공 + 필라멘트 위치/색상 동일

### Step 4: 테스트 보강

- **Files**: `DUNETests/WaveShapeTests.swift`
- **Changes**:
  - `ArcticAnimationContext` phase 파생 정확도 테스트
  - flat curtain element 수 = curtainCount × (1 fill + 1 highlight + filamentCount) 검증
  - 경계값: elapsed = 0, driftDuration = 0, reduceMotion
- **Verification**: 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| Reduce Motion 활성 | TimelineView schedule을 `.explicit([Date()])` (정적 1회 렌더) |
| 저전력 모드 | 기존 LOD 시스템 유지, TimelineView cadence는 영향 없음 |
| 탭 전환 시 animation 재시작 | TimelineView는 elapsed 기반이므로 자연스럽게 연속 |
| drawingGroup + blendMode | drawingGroup 내부 blendMode는 텍스처 내에서만 적용, 외부 blendMode는 별도 |
| ProMotion 120Hz | TimelineView `.animation`은 기본 디스플레이 cadence 준수 |

## Testing Strategy

- Unit tests: `WaveShapeTests`에 Arctic animation context + flat element 테스트 추가
- Integration: `scripts/build-ios.sh`로 빌드 검증
- Manual: Arctic Dawn 테마에서 탭 왕복, 리스트 스크롤, 저전력 모드 전환 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| drawingGroup 시각 차이 | Low | Medium | 적용 후 시각 비교, 차이 시 opacity 미세 조정 |
| TimelineView 프레임 소비 | Low | Medium | .animation schedule은 60Hz 기본, ProMotion 대응 |
| ForEach 평탄화 시 element 수 불일치 | Low | Low | 테스트로 curtain×filament 수 정확성 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: drawingGroup은 codebase에 선례 있고, TimelineView는 SwiftUI 공식 패턴이며,
  ForEach 평탄화는 순수 데이터 변환. 세 전략 모두 기존 시각 파라미터를 변경하지 않아 회귀 위험이 낮다.
