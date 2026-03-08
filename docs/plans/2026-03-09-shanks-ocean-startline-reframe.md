---
topic: shanks-ocean-startline-reframe
date: 2026-03-09
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md
  - docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-shanks-cinematic-ocean-theme.md
---

# Implementation Plan: Shanks Ocean Startline Reframe

## Context

샹크스 시네마틱 오션 테마는 scene engine 기준으로는 완성되어 있지만, 현재 바다 레이어가 화면 상단에서 바로 시작되어 히어로 카드와 장면이 겹쳐 읽힌다. 이번 변경은 샹크스 테마의 바다 표현 시작선을 히어로 카드 하단 1/4 지점 근처로 내리고, 탭/상세/시트 전 경로에서 같은 startline 규칙을 유지하는 것이 목적이다.

## Requirements

### Functional

- 샹크스 테마에서 바다 질감, 거품, 배, 카무사리 등 핵심 ocean scene 요소가 기존보다 더 낮은 지점에서 시작되어야 한다.
- `Tab / Detail / Sheet` 경로가 모두 같은 startline 개념을 공유해야 한다.
- 상단 영역에는 완전한 공백이 아니라 atmospheric gradient는 남기되, 명시적인 ocean mass는 뒤로 물러나야 한다.

### Non-functional

- 다른 테마 dispatch에는 영향이 없어야 한다.
- geometry 0-size 방어와 기존 shape 안정성은 유지되어야 한다.
- startline 조정은 preset token 중심으로 구현해 이후 추가 테마 튜닝 시 재사용 가능해야 한다.

## Approach

`ShanksSceneStyle`에 ocean scene의 top inset token을 추가하고, `ShanksCinematicSceneBackground`에서 water mass / caustic / texture / flag / ship / foam 레이어 전체를 같은 inset 아래로 이동시킨다. 동시에 foam/wave의 내부 vertical offset을 약간 내려, 실제 표면 crest가 frame 상단에 다시 붙지 않도록 조정한다.

상단 전체 배경색은 기존 gradient가 유지하므로 화면 첫 인상과 가독성은 보존하고, 실제 바다 표현만 히어로 카드 아래쪽으로 물러난다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| wave/foam `verticalOffset`만 하향 | 수정 범위 작음 | texture/ship/flag가 여전히 상단에 남아 scene이 분리됨 | 기각 |
| 화면별 hero geometry를 background에 전달 | 가장 정확한 정렬 가능 | root view 전반 수정 필요, 결합도 증가 | 기각 |
| scene preset에 top inset 추가 | 공통 규칙 적용 가능, 구조 단순 | exact pixel-perfect hero sync는 아님 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | Modify | scene preset에 ocean start inset 추가, scene layer frame/offset 재배치 |
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | Modify | tab/detail/sheet wrapper가 새 startline preset을 사용하도록 정리 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | Modify | style preset smoke test 추가 |

## Implementation Steps

### Step 1: Shanks scene startline token 추가

- **Files**: `ShanksSceneEffects.swift`
- **Changes**:
  - `ShanksSceneStyle`에 `sceneTopInset` 추가
  - `tab/detail/sheet` preset별 inset 값을 정의
  - 필요 시 `sceneHeight`를 소폭 조정해 shifted scene이 답답해지지 않도록 보정
- **Verification**:
  - preset 값이 음수가 아니고 `tab > detail > sheet` 또는 의도한 순서로 구분되는지 테스트 가능 상태 확인

### Step 2: Scene composer 전체 레이어 하향

- **Files**: `ShanksSceneEffects.swift`
- **Changes**:
  - water mass, underwater caustic, texture, flag, ship, foam을 동일한 container로 묶고 top inset 적용
  - foam/wave vertical offset을 낮춰 시각적인 바다 시작선이 명확히 내려가도록 조정
- **Verification**:
  - 상단 gradient는 유지되고, ocean scene 요소는 inset 아래에서 시작하는 구조가 코드상 일관되게 반영됨

### Step 3: Regression guard 추가

- **Files**: `DUNETests/ShanksThemeEnhancementTests.swift`
- **Changes**:
  - `ShanksSceneStyle.tab/detail/sheet`의 inset/height smoke test 추가
  - 기존 shape 0-size 테스트는 유지
- **Verification**:
  - `ShanksThemeEnhancementTests`가 새 preset 규칙까지 검증

## Edge Cases

| Case | Handling |
|------|----------|
| inset이 너무 커서 ship/foam이 잘림 | `sceneHeight`를 같이 조정하고 ship 위치는 scene frame 내부 clamp 유지 |
| detail/sheet에서 장면이 너무 약해짐 | preset별 inset만 분리하고 opacity는 기존 톤 최대한 유지 |
| Today weather tint와 섞이며 상단이 심심해짐 | gradient layer는 유지하고 ocean mass만 이동 |

## Testing Strategy

- Unit tests: `ShanksThemeEnhancementTests`에 startline preset smoke test 추가
- Integration tests: `scripts/build-ios.sh`, 필요 시 `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/ShanksThemeEnhancementTests -quiet`
- Manual verification:
  - 샹크스 테마에서 `Dashboard / Activity / Wellness / Life` 탭의 hero 상단이 덜 붐비는지 확인
  - hero card 하단 1/4 부근부터 바다 mass가 시작되는지 확인
  - 샹크스 detail/sheet 1개 이상 열어 동일한 startline 감성이 유지되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| startline을 너무 낮게 내려 장면 존재감 약화 | Medium | Medium | tab/detail/sheet preset을 분리하고 foam opacity는 유지 |
| ship/foam 위치가 frame 하단에서 잘림 | Low | Medium | frame 높이와 ship clamp를 함께 점검 |
| 탭별 hero 높이 차이로 완벽한 3/4 정렬이 어렵다 | Medium | Low | 공통 inset token으로 먼저 통일하고 필요 시 preset별 세부 조정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: scene engine 구조가 이미 분리돼 있어 수정 지점은 좁지만, 최종 만족도는 실제 화면 밸런스에 민감하므로 inset과 wave offset 값을 함께 조정해야 한다.
