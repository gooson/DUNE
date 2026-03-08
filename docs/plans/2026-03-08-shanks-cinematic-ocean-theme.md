---
topic: shanks-cinematic-ocean-theme
date: 2026-03-08
status: approved
confidence: medium
related_solutions:
  - docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md
  - docs/solutions/design/2026-03-01-ocean-wave-visual-upgrade.md
  - docs/solutions/design/2026-03-07-hanok-theme-dalhangari-redesign.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-shanks-theme-enhancement.md
  - docs/brainstorms/2026-03-08-shanks-cinematic-ocean-theme.md
---

# Implementation Plan: Shanks Cinematic Ocean Theme

## Context

기존 `shanksRed` 배경은 이미 모티프 오버레이와 붉은 파형을 갖고 있지만, 장면 전체가 하나의 세계로 읽히기보다 장식 요소의 합처럼 보인다. 이번 변경은 샹크스 테마를 팬서비스형 시네마틱 바다 장면으로 재구성해, 표면 거품, 수중 빛무늬, 배와 카무사리, 전 화면 일관성을 우선 완성하는 것이 목표다.

## Requirements

### Functional

- `Tab / Detail / Sheet` 전 경로에서 샹크스 테마가 같은 장면 언어를 유지해야 한다.
- 표면 거품, 수중 빛무늬, 배 + 카무사리 4개 요소가 모두 실제 렌더링에 반영되어야 한다.
- 기존 theme dispatch (`WaveShape.swift`) 구조는 유지하고, 샹크스 분기만 고도화한다.
- Weather atmosphere 연동은 깨지지 않되 샹크스 정체성을 유지해야 한다.

### Non-functional

- 고급 렌더링(`Canvas`, SwiftUI shader/Metal)을 사용하되 crash-safe fallback이 있어야 한다.
- 기존 테마와 다른 화면에는 영향이 없어야 한다.
- `ShanksWaveBackground.swift`의 장식 합성 구조를 장면 중심 구조로 단순화해야 한다.
- 테스트/프리뷰에서 0-size, no-shader 상황을 방어해야 한다.

## Approach

샹크스 전용 장면 엔진을 도입한다. 구성은 `Canvas` 기반 scene overlays + Metal shader wrapper + theme-aware palette 확장으로 나눈다.

- `Canvas`: 표면 거품, 수중 빛무늬, 부유 질감, 실루엣을 immediate-mode로 그린다.
- `Metal shader`: 카무사리 필드와 수면 굴절/수중 shimmer를 연결하는 decorative effect로 제한한다.
- `SwiftUI` composition: `Tab / Detail / Sheet`별 intensity profile만 다르게 유지한다.

이 접근은 Apple이 SwiftUI에서 `Canvas`, `MeshGradient`, `layerEffect`/`distortionEffect`, Metal shader 조합을 공식적으로 권장하는 흐름과 맞다. 또한 GPU Gems 계열 water rendering 원칙처럼 "geometry-like macro motion"과 "fine surface detail / caustics"를 분리하는 편이 장면 품질과 조정 가능성을 높인다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 `Shape + blur + overlay`만 증설 | 구현이 빠름 | 이미 한계가 드러났고 여전히 장식 조합처럼 보일 가능성이 큼 | 기각 |
| `Canvas`만 사용 | Metal 없이도 꽤 풍부한 표현 가능 | 카무사리와 수면 굴절이 분리되어 보일 수 있음 | 보조 fallback로 유지 |
| `Canvas + Metal shader` 하이브리드 | 장면 일체감, 프리미엄 표현, 카무사리/굴절 연동에 유리 | 첫 `.metal` 도입 리스크가 있음 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | Modify | 샹크스 배경을 장면 엔진 기반 composition으로 재작성 |
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | New | scene overlay, shader wrapper, silhouette/foam helper 추가 |
| `DUNE/Resources/Shaders/ShanksSceneEffects.metal` | New | 카무사리 왜곡/수중 shimmer용 stitchable shaders 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | Modify | 샹크스 장면용 추가 palette accessor 정의 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | Modify | foam/ship/silhouette helper의 경로 및 0-size 방어 테스트 추가 |

## Implementation Steps

### Step 1: Shanks scene palette와 primitive 추가

- **Files**: `AppTheme+View.swift`, `ShanksSceneEffects.swift`
- **Changes**:
  - `foam`, `abyss`, `caustic`, `haze` 계열의 샹크스 전용 scene palette accessor 추가
  - 표면 거품, 배 실루엣, 생체/심해 silhouette, 부유 입자용 helper/shape 정의
  - 0-size rect에서 안전하게 빠지는 path helper 설계
- **Verification**:
  - 새 helper가 `ShanksThemeEnhancementTests`에서 empty/non-empty path 조건을 만족하는지 확인

### Step 2: Shader-backed caustic / Kamusari overlay 도입

- **Files**: `ShanksSceneEffects.swift`, `ShanksSceneEffects.metal`
- **Changes**:
  - `ShaderLibrary` 기반 `layerEffect` / `distortionEffect` wrapper 추가
  - 카무사리는 화면 전체가 아니라 배를 감싸는 focused field로 제한
  - Preview/테스트용 pure SwiftUI fallback 경로 유지
- **Verification**:
  - 빌드가 `.metal` 추가 후 정상 통과
  - SwiftUI preview/zero-size rendering 경로에서 컴파일 오류가 없는지 확인

### Step 3: Tab / Detail / Sheet 장면 composition 재작성

- **Files**: `ShanksWaveBackground.swift`
- **Changes**:
  - 기존 장식 중심 `ZStack`을 장면 중심 구조로 교체
  - `Tab`: 표면 거품 + 수중 빛무늬 + 배 + 카무사리 풀 버전
  - `Detail`: 같은 모티프를 낮은 강도/적은 레이어로 유지
  - `Sheet`: 텍스트 가독성을 우선하며 배 + 약한 카무사리만 유지
  - Weather atmosphere는 표면 tint 보정 수준으로 제한
- **Verification**:
  - `WaveShape.swift` dispatch 변경 없이 샹크스 테마 모든 루트 화면에 반영되는지 수동 확인

### Step 4: 테스트와 시각 회귀 검증

- **Files**: `DUNETests/ShanksThemeEnhancementTests.swift`
- **Changes**:
  - 새 scene helper에 대한 geometry smoke tests 추가
  - zero-size rect, wide rect, tall rect 방어 케이스 추가
- **Verification**:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/ShanksThemeEnhancementTests -quiet`

## Edge Cases

| Case | Handling |
|------|----------|
| `Canvas` size가 0 | 모든 helper/path는 early return |
| Shader가 preview/test에서 불안정 | pure SwiftUI fallback overlay 유지 |
| Today 탭 weather tint가 정체성 약화 | atmosphere 적용 범위를 surface highlight에만 제한 |
| Sheet에서 장식이 텍스트를 침범 | sheet profile은 배경 alpha와 shader intensity를 더 낮춤 |
| theme 전환 직후 animation freeze | 기존 wave 계열 해결책처럼 `.task` 기반 재시작 패턴 유지 |

## Testing Strategy

- Unit tests: `ShanksThemeEnhancementTests`에 foam/ship/silhouette helper smoke tests 추가
- Integration tests: `scripts/build-ios.sh`, 필요 시 `DUNETests/ShanksThemeEnhancementTests` 타깃 실행
- Manual verification:
  - Settings에서 `Shanks Red` 선택
  - `Dashboard`, `Activity`, `Wellness`, `Life` 탭 확인
  - 샹크스 테마가 적용된 detail/sheet 화면 1개 이상 열어 layer 강도 확인
  - theme 전환 직후 배경 animation 재시작 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 첫 `.metal` 도입으로 빌드 설정 이슈 | Medium | High | `DUNE` 타깃 source tree 구조를 유지하고 wrapper를 최소 범위로 한정 |
| 카무사리 효과가 과해져 유치해 보임 | Medium | High | 배 주변 focal field로 제한하고 전체 화면 번개 연출 금지 |
| overdraw/blur로 렌더 비용 증가 | Medium | Medium | `Canvas`/shader 레이어 수를 프로파일별로 분기하고 sheet/detail은 축소 |
| 가독성 회귀 | Medium | High | `Detail / Sheet`에서 veil과 opacity cap 유지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 theme dispatch와 Shanks 전용 파일 구조는 이미 있어 영향 범위는 비교적 좁다. 다만 `.metal` 도입과 장면 composition 재작성은 이번 브랜치에서 처음 시도하는 조합이라 구현 리스크가 남아 있다.
