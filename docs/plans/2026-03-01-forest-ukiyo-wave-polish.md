---
topic: forest-ukiyo-wave-polish
date: 2026-03-01
status: draft
confidence: high
related_solutions:
  - design/2026-03-01-forest-green-theme
  - design/theme-wave-visual-upgrade
  - architecture/ocean-wave-curl-integration
related_brainstorms:
  - 2026-03-01-forest-ukiyo-style
---

# Implementation Plan: Forest Ukiyo Wave Polish

## Context

Forest 테마를 우키요 스타일로 강화하면서, Desert/Ocean/Forest 웨이브 배경의 시각적 일관성과 안정감을 높인다.
핵심은 다음 네 가지다.
- Desert: 거친 노이즈 제거 + 매끄러운 사구
- Ocean: 최고 파도 레이어 애니메이션 안정화
- Forest: 다크모드 가시성 유지 + 우키요 무드(몽글 노이즈/크레스트) 강화
- 전체: 과도한 속도감을 낮춘 안정적인 드리프트

## Requirements

### Functional

- Desert 사구 실루엣을 매끄럽게 만든다.
- Ocean 최고 파도 레이어의 불안정한 움직임을 제거한다.
- Forest 배경을 우키요 분위기로 강화한다.
- Forest는 다크모드에서도 충분히 식별 가능해야 한다.
- Forest/Desert에 반투명 크레스트 레이어를 적용한다.

### Non-functional

- 기존 테마 시스템(AppTheme 분기, Environment 기반)을 유지한다.
- SwiftUI 렌더 비용을 불필요하게 증가시키지 않는다.
- 접근성 Reduce Motion 동작을 유지한다.

## Approach

테마별 배경 컴포넌트 파라미터를 조정하고, Forest/Desert overlay에 크레스트 스트로크 레이어를 추가한다.
Shape 레벨에서는 DesertDuneShape/ForestSilhouetteShape 수식을 조정해 질감을 제어한다.
Ocean은 Surface layer의 curl 사용을 제한해 위상 전환 시 불안정함을 줄인다.
공통 애니메이션 토큰(DS.Animation.waveDrift)은 완만한 값으로 통일한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 자산 기반 텍스처 PNG/SVG 추가 | 원하는 질감 고정 표현 용이 | 에셋 관리 비용 증가, 다크모드 튜닝 중복 | 미채택 |
| Shape 수식 + 파라미터 튜닝 | 기존 구조 재사용, 테마별 미세조정 유연 | 수치 조절 반복 필요 | 채택 |
| Ocean big-wave 별도 shape 재도입 | 시각적으로 극적 | 기존 통합 구조 재복잡화, 안정성 저하 가능 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/DesertDuneShape.swift` | modify | edge/ripple 노이즈 제어 |
| `DUNE/Presentation/Shared/Components/DesertWaveBackground.swift` | modify | 사구 파라미터 + 크레스트 레이어 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | modify | Surface 안정화 및 속도 조정 |
| `DUNE/Presentation/Shared/Components/ForestSilhouetteShape.swift` | modify | 우키요형 몽글 노이즈 수식 조정 |
| `DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | modify | Forest 레이어 튜닝 + 크레스트 |
| `DUNE/Presentation/Shared/DesignSystem.swift` | modify | iOS waveDrift 완화 |
| `DUNEWatch/DesignSystem.swift` | modify | watchOS waveDrift 완화 |
| `DUNETests/DesertDuneShapeTests.swift` | add | Desert shape 기하/클램프 검증 |
| `DUNETests/ForestSilhouetteShapeTests.swift` | add | Forest shape 기하/변형 검증 |
| `docs/brainstorms/2026-03-01-forest-ukiyo-style.md` | add | 디자인 방향 브레인스토밍 |

## Implementation Steps

### Step 1: Theme Wave Parameter Tuning

- **Files**: `DesertWaveBackground.swift`, `OceanWaveBackground.swift`, `ForestWaveBackground.swift`
- **Changes**: 테마별 amplitude/frequency/opacity/driftDuration 및 layer composition 조정
- **Verification**: 각 배경 struct에서 파라미터 범위 및 일관성 점검

### Step 2: Shape Formula Refinement

- **Files**: `DesertDuneShape.swift`, `ForestSilhouetteShape.swift`
- **Changes**: Desert 노이즈 억제, Forest 노이즈/canopy 펄스 조정
- **Verification**: boundingRect/animatableData 테스트 추가

### Step 3: Crest Overlay Integration

- **Files**: `DesertWaveBackground.swift`, `ForestWaveBackground.swift`
- **Changes**: 반투명 밴드 + 코어 라인 2중 크레스트 적용
- **Verification**: OverlayView 파라미터와 mask/blend 적용 검토

### Step 4: Motion Stabilization

- **Files**: `DesignSystem.swift`, `DUNEWatch/DesignSystem.swift`
- **Changes**: waveDrift duration 상향(완만한 motion)
- **Verification**: 토큰 참조 파일(`WaveShape`, `WatchWaveBackground`) 경유 동작 확인

### Step 5: Test & Review

- **Files**: `DUNETests/*`, changed SwiftUI components
- **Changes**: 테스트 실행, 리뷰 관점(Security/Performance/Architecture/Data/Simplicity/Agent-Native) 점검
- **Verification**: xcodebuild test/build, review findings 정리

## Edge Cases

| Case | Handling |
|------|----------|
| 다크모드에서 Forest 레이어 저대비 | visibilityBoost/gradient 상단 보정 |
| Reduce Motion 활성화 | 기존 `guard !reduceMotion` 흐름 유지 |
| Theme 전환 직후 애니메이션 불안정 | 안정형 driftDuration/curl 축소로 완화 |
| 과도한 크레스트 폭으로 텍스트 가독성 저하 | mask/end point 및 opacity/width 파라미터로 제어 |

## Testing Strategy

- Unit tests: `DesertDuneShapeTests`, `ForestSilhouetteShapeTests`, 기존 `OceanWaveShapeTests`
- Integration tests: `xcodebuild test -scheme DUNETests` (가능 환경)
- Manual verification: ThemePicker에서 Desert/Ocean/Forest, Light/Dark 전환 관찰

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시뮬레이터 런타임 불가로 테스트 미실행 | High | Medium | 로그 보존 + 로컬 복구 후 재실행 |
| 파라미터 변경으로 기존 무드 이탈 | Medium | Medium | 레이어별 수치 조정 히스토리 유지 |
| 크레스트 레이어 과표현 | Medium | Low | width/opacity를 테마별로 분리 조정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 구조를 유지하면서 파라미터/수식/오버레이를 국소적으로 수정했고, 영향 파일이 명확하며 회귀 범위가 제한적이다.
