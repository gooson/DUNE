---
topic: shanks-ocean-startline-reframe
date: 2026-03-09
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md
  - docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-shanks-cinematic-ocean-theme.md
---

# Implementation Plan: Shanks Ocean Startline Reframe

## Context

샹크스 시네마틱 오션 테마는 scene engine 기준으로는 완성되어 있지만, 현재 바다 레이어가 화면 상단에서 바로 시작되어 히어로 카드와 장면이 겹쳐 읽힌다. 초기 preset-only 보정만으로는 탭별 hero 높이와 배너 유무를 따라가지 못했기 때문에, 이번 구현은 샹크스 테마의 바다 표현 시작선을 hero card 실제 하단 1/4 지점에 맞추는 쪽으로 확정한다.

## Requirements

### Functional

- 샹크스 테마에서 바다 질감, 거품, 배, 카무사리 등 핵심 ocean scene 요소가 기존보다 더 낮은 지점에서 시작되어야 한다.
- `Tab / Detail / Sheet` 경로가 모두 같은 startline 개념을 공유하되, hero anchor가 있는 tab은 실제 frame 측정을 우선한다.
- 상단 영역에는 완전한 공백이 아니라 atmospheric gradient는 남기되, 명시적인 ocean mass는 뒤로 물러나야 한다.

### Non-functional

- 다른 테마 dispatch에는 영향이 없어야 한다.
- geometry 0-size 방어와 기존 shape 안정성은 유지되어야 한다.
- geometry 0-size 방어가 있어야 하고, hero anchor가 없는 detail/sheet는 fallback preset을 유지해야 한다.

## Approach

`ShanksSceneStyle`의 ocean scene inset token은 detail/sheet fallback으로 남기고, tab root는 hero card frame을 named coordinate space에서 측정해 `hero.minY + hero.height * 0.75` 값을 background environment로 전달한다. `ShanksCinematicSceneBackground`는 override가 있으면 그 값을 우선 사용해 water mass / caustic / texture / flag / ship / foam 레이어 전체를 같은 기준선 아래로 이동시킨다.

상단 전체 배경색은 기존 gradient가 유지하므로 화면 첫 인상과 가독성은 보존하고, 실제 바다 표현만 히어로 카드 아래쪽으로 물러난다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| wave/foam `verticalOffset`만 하향 | 수정 범위 작음 | texture/ship/flag가 여전히 상단에 남아 scene이 분리됨 | 기각 |
| 화면별 hero geometry를 background에 전달 | hero 하단 1/4 지점 요구를 가장 정확히 만족 | root view 전반 수정 필요, preference/env wiring 추가 | 채택 |
| scene preset에 top inset 추가 | 공통 규칙 적용 가능, 구조 단순 | 탭별 hero 높이와 배너 유무를 반영하지 못함 | 초기안 후 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | Modify | hero frame preference/environment helper 추가 |
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | Modify | scene preset에 ocean start inset 추가, scene layer frame/offset 재배치 |
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | Modify | tab 배경이 hero-derived startline override를 읽도록 정리 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | Modify | hero/baseline 분기 frame report 연결 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Modify | hero frame report 연결 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Modify | hero frame report 연결 |
| `DUNE/Presentation/Life/LifeView.swift` | Modify | child hero frame report를 root background에 전달 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | Modify | hero startline 계산 테스트 추가 |

## Implementation Steps

### Step 1: Hero startline geometry bridge 추가

- **Files**: `WaveShape.swift`, `DashboardView.swift`, `ActivityView.swift`, `WellnessView.swift`, `LifeView.swift`
- **Changes**:
  - `TabHeroStartLine`, preference key, environment key, hero frame reporter 추가
  - 각 tab root hero가 named coordinate space 기준 frame을 background로 전달
  - 대체 hero 분기까지 동일한 anchor 경로 사용
- **Verification**:
  - hero frame 계산이 0-size를 안전하게 처리하고, banner/alternate hero 상태에서도 값이 비지 않는지 코드상 확인

### Step 2: Scene composer가 measured inset 우선 사용

- **Files**: `ShanksSceneEffects.swift`, `ShanksWaveBackground.swift`
- **Changes**:
  - `ShanksCinematicSceneBackground`에 `sceneTopInsetOverride` 추가
  - tab은 measured inset을 override로 넘기고, detail/sheet는 preset fallback 유지
- **Verification**:
  - 상단 gradient는 유지되고, ocean scene 요소는 override 기준 아래에서 시작하는 구조가 코드상 일관되게 반영됨

### Step 3: Regression guard 추가

- **Files**: `DUNETests/ShanksThemeEnhancementTests.swift`
- **Changes**:
  - `ShanksSceneStyle.tab/detail/sheet`의 inset/height smoke test 유지
  - hero frame 3/4 anchor 계산과 zero-height clamp 테스트 추가
  - 기존 shape 0-size 테스트는 유지
- **Verification**:
  - `ShanksThemeEnhancementTests`가 measured startline 계산과 fallback preset 규칙을 함께 검증

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
| 대체 hero 분기가 frame report를 빼먹어 fallback으로 돌아감 | Medium | Medium | dashboard/wellness 등 alternate hero 경로까지 동일 modifier 적용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: scene engine 구조는 유지하면서 tab root에서 hero frame만 전달하는 방식이라 수정 지점이 명확하고, build/test로 회귀 범위도 좁게 검증 가능하다.
