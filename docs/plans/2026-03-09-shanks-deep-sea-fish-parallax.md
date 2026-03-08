---
topic: shanks-deep-sea-fish-parallax
date: 2026-03-09
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-shanks-cinematic-ocean-scene.md
  - docs/solutions/design/2026-03-09-shanks-ocean-startline-reframe.md
  - docs/solutions/design/2026-03-05-shanks-theme-motif-enhancement.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-shanks-cinematic-ocean-theme.md
---

# Implementation Plan: Shanks Deep Sea Fish Parallax

## Context

`todos/096-pending-p3-shanks-cinematic-theme-future-expansions.md`는 샹크스 시네마틱 오션 테마에서 MVP 이후로 미뤄 둔 확장 아이디어 묶음이다. 이 중 `심해 거대 물고기 패럴랙스`는 기존 scene engine 안에서 독립 레이어 하나로 추가할 수 있어, 설정 저장/날씨 연동/멀티플랫폼 파생보다 범위가 가장 좁고 재사용성도 높다.

현재 `ShanksCinematicSceneBackground`는 `water mass / caustic / texture / flag / ship / foam` 구조까지는 갖췄지만, 심해의 깊이감을 전달하는 대형 silhouette 레이어는 없다. 이번 변경은 scene composer를 유지한 채 수중 후방 레이어에 느린 parallax fish silhouette를 더해 바다 장면의 원근감을 높이는 데 집중한다.

## Requirements

### Functional

- 샹크스 테마의 `Tab / Detail / Sheet` 배경이 동일한 deep-sea fish parallax 언어를 공유해야 한다.
- 새 fish silhouette는 기존 ship/foam/caustic보다 뒤에 배치되어 텍스트와 hero readability를 해치지 않아야 한다.
- `Reduce Motion`이 켜지면 기존 scene과 동일하게 animation이 정지한 상태로 안전하게 렌더링되어야 한다.
- `ShanksSceneStyle` preset에 따라 fish 레이어의 강도와 개수가 presentation depth에 맞게 조절되어야 한다.

### Non-functional

- 변경 범위는 Shanks 전용 scene 파일과 해당 테스트로 제한한다.
- 0-size rect에서도 custom path가 안전하게 비어 있어야 한다.
- 다른 테마 dispatch와 settings/domain 레이어에는 영향이 없어야 한다.
- 렌더 비용은 느린 drift와 제한된 silhouette 수로 관리한다.

## Approach

`ShanksSceneStyle`에 fish layer 강도 토큰을 추가하고, `ShanksCinematicSceneBackground` 안에 ship보다 뒤쪽에 위치하는 `ShanksDeepSeaFishOverlay`를 삽입한다. overlay는 큰 silhouette 몇 개를 서로 다른 depth, speed, opacity로 렌더링해 원근감만 제공하고, 기존 `TimelineView`의 elapsed 값을 그대로 재사용한다.

silhouette 자체는 새 `Shape`로 정의해 geometry smoke test를 붙인다. parallax는 개별 fish spec 배열과 `sin`/선형 drift 조합으로 처리해 상태 저장 없이 deterministic하게 움직이게 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| theme 첫 적용 cinematic intro 구현 | 체감 변화가 큼 | theme persistence, one-shot state, UX 조율까지 필요해 범위가 커짐 | 기각 |
| weather/time adaptive tint 구현 | 장면 다양성이 큼 | weather pipeline과 색상 정책 결합이 필요해 현재 TODO 묶음 범위를 벗어남 | 기각 |
| deep-sea fish silhouette overlay | scene engine 내부 확장으로 끝남 | 시각 효과 품질 튜닝이 필요함 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift` | Modify | fish layer preset, silhouette shape, parallax overlay 추가 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | Modify | fish silhouette path 및 preset smoke test 추가 |
| `todos/096-pending-p3-shanks-cinematic-theme-future-expansions.md` | Modify | 구현된 후속 확장과 남은 backlog를 반영 |

## Implementation Steps

### Step 1: Fish silhouette primitive와 preset 토큰 추가

- **Files**: `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift`
- **Changes**:
  - `ShanksSceneStyle`에 fish layer 개수/opacity/scale에 필요한 preset 값을 추가
  - `ShanksDeepSeaFishSilhouetteShape`와 내부 spec 모델 정의
  - zero-size rect에서 빈 path를 반환하도록 방어
- **Verification**:
  - `ShanksThemeEnhancementTests`에서 wide rect와 zero rect path 결과를 검증

### Step 2: Scene composer에 fish parallax overlay 통합

- **Files**: `DUNE/Presentation/Shared/Components/ShanksSceneEffects.swift`
- **Changes**:
  - `ShanksDeepSeaFishOverlay`를 `ShanksWaterMassScene` 뒤, `ShanksShipHeroOverlay` 앞에 배치
  - elapsed 기반 drift와 미세한 bobbing을 적용하되 `Reduce Motion` 시 정지 경로 유지
  - tab/detail/sheet preset별로 opacity와 density를 차등 적용
- **Verification**:
  - 코드상 레이어 순서가 fish → caustic/texture → ship/foam로 유지되는지 확인
  - preset별 강도가 tab > detail > sheet 관계를 유지하는지 테스트 추가

### Step 3: Tests 및 backlog 상태 반영

- **Files**: `DUNETests/ShanksThemeEnhancementTests.swift`, `todos/096-pending-p3-shanks-cinematic-theme-future-expansions.md`
- **Changes**:
  - fish path smoke test와 preset tiering assertion 추가
  - TODO 문서에서 구현된 확장을 표시하고 남은 future items를 명시
- **Verification**:
  - `scripts/build-ios.sh`
  - 필요 시 `swift test` 대신 iOS unit test target을 직접 실행해 Shanks 테스트 회귀 확인

## Edge Cases

| Case | Handling |
|------|----------|
| fish shape rect가 0-size | `Path()` 즉시 반환 |
| sheet에서 silhouette가 텍스트와 충돌 | sheet preset opacity/density를 가장 낮게 유지 |
| animation이 과하게 눈에 띔 | drift 속도와 bob amplitude를 ship/foam보다 더 느리게 제한 |
| fish가 ship hero와 겹쳐 foreground처럼 보임 | depth별 blur/opacity와 y-position clamp로 후방 레이어 유지 |

## Testing Strategy

- Unit tests: `DUNETests/ShanksThemeEnhancementTests.swift`에 fish silhouette path 및 preset tiering 추가
- Integration tests: `scripts/build-ios.sh`
- Manual verification:
  - Settings에서 `Shanks Red` 선택 후 `Dashboard / Activity / Wellness / Life` 탭 확인
  - detail/sheet 한 화면 이상 열어 fish layer가 더 약하게 보이는지 확인
  - `Reduce Motion` 환경에서 fish drift가 정지한 상태로도 장면이 자연스러운지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| fish silhouette가 코믹하게 보여 장면 톤을 해침 | Medium | Medium | 세부 묘사보다 추상 silhouette와 낮은 opacity 유지 |
| layer 추가로 overdraw가 증가 | Low | Medium | silhouette 수를 소수로 제한하고 blur를 최소화 |
| tab/detail/sheet preset 차등이 약해 회귀 검증이 모호함 | Medium | Medium | preset tiering을 테스트에서 숫자로 고정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 Shanks scene composer가 이미 공통 엔진으로 정리돼 있어, 후방 레이어 하나를 추가하는 구조적 여지가 충분하다. 설정/도메인 확장 없이 Presentation + test 범위에서 닫히므로 검증과 회귀 관리도 비교적 단순하다.
