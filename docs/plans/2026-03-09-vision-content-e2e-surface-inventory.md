---
topic: vision-content-e2e-surface-inventory
date: 2026-03-09
status: implemented
confidence: high
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: VisionContent E2E Surface Inventory

## Context

Vision Pro backlog에서 `todos/022-in-progress-p2-vision-ux-polish.md`는 실기기 또는 시뮬레이터 기반 spatial placement 시각 검증만 남아 있다. 현재 로컬 환경에서 바로 닫을 수 있는 다음 Vision Pro TODO는 `todos/084-ready-p3-e2e-dunevision-content-view.md`이며, 같은 진입점 파일을 공유하는 `todos/091-ready-p3-e2e-dunevision-placeholder-surfaces.md`를 함께 정리하는 편이 가장 작은 배치다.

## Requirements

### Functional

- `VisionContentView`의 root lane과 section별 assertion anchor를 코드로 고정한다.
- Wellness/Life placeholder surface에서 회귀 검증에 필요한 selector를 고정한다.
- 관련 TODO 문서에 entry route, selector inventory, 주요 state, deferred lane 조건을 실제 코드 기준으로 기록한다.

### Non-functional

- visionOS 전용 XCUITest harness 구축은 이번 범위에서 제외한다.
- 기존 navigation/window wiring을 바꾸지 않고 E2E inventory만 보강한다.
- selector는 재사용 가능한 상수로 묶어 drift를 줄인다.

## Approach

공용 `VisionSurfaceAccessibility` helper를 추가하고, `VisionContentView`, `VisionWellnessView`, `VisionLifeView`에 필요한 accessibility identifier를 주입한다. 이후 TODO 문서를 코드와 동일한 inventory로 채워 문서와 구현을 함께 닫는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TODO 문서만 업데이트 | 구현 없이 빠름 | 실제 selector가 코드에 고정되지 않아 회귀에 취약 | 기각 |
| 각 View에 문자열을 직접 하드코딩 | 파일 수가 적고 단순함 | inventory drift와 중복 위험 | 기각 |
| 공용 helper + view wiring + TODO 업데이트 | 코드/문서/테스트가 같은 식별자를 공유 | 파일 수가 조금 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift` | add | visionOS root/placeholder selector inventory 상수화 |
| `DUNEVision/App/VisionContentView.swift` | modify | root lane 및 section screen identifier 연결 |
| `DUNEVision/Presentation/Wellness/VisionWellnessView.swift` | modify | placeholder/assertion anchor identifier 추가 |
| `DUNEVision/Presentation/Life/VisionLifeView.swift` | modify | placeholder/assertion anchor identifier 추가 |
| `DUNETests/VisionSurfaceAccessibilityTests.swift` | add | selector mapping과 uniqueness 회귀 고정 |
| `todos/084-ready-p3-e2e-dunevision-content-view.md` | modify | root surface inventory와 deferred lane 조건 기록 |
| `todos/091-ready-p3-e2e-dunevision-placeholder-surfaces.md` | modify | placeholder surface inventory와 deferred lane 조건 기록 |

## Implementation Steps

### Step 1: Root/placeholder selector inventory 정의

- **Files**: `DUNE/Presentation/Vision/VisionSurfaceAccessibility.swift`
- **Changes**: section screen ID, placeholder card ID, root view ID를 상수/함수로 정의
- **Verification**: 테스트에서 section별 ID가 유일하고 예상 값과 일치하는지 확인

### Step 2: visionOS surface에 identifier 연결

- **Files**: `DUNEVision/App/VisionContentView.swift`, `DUNEVision/Presentation/Wellness/VisionWellnessView.swift`, `DUNEVision/Presentation/Life/VisionLifeView.swift`
- **Changes**: root TabView, section별 screen anchor, placeholder card/empty state에 identifier 부여
- **Verification**: 빌드 성공, `rg "vision-" DUNEVision` 결과로 식별자 주입 위치 확인

### Step 3: TODO 문서와 테스트 정리

- **Files**: `DUNETests/VisionSurfaceAccessibilityTests.swift`, `todos/084-ready-p3-e2e-dunevision-content-view.md`, `todos/091-ready-p3-e2e-dunevision-placeholder-surfaces.md`
- **Changes**: selector inventory 테스트 추가, TODO 체크리스트를 코드 기준으로 채움
- **Verification**: 선택 테스트 통과, TODO 문서에 entry/state/deferred 조건이 채워져 있는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| visionOS `Tab` item 자체에 stable AXID를 부여하기 어려움 | 탭 선택 selector는 고정 영어 label(`Today`, `Activity`, `Wellness`, `Life`)을 사용하고, assertion은 section screen ID로 분리 |
| Wellness tab에 실제 sleep 데이터가 있거나 없을 수 있음 | 데이터 유무와 무관하게 root/sleep/body anchor를 공통 ID로 노출 |
| Life tab가 완전 placeholder 상태 | root screen ID와 placeholder card ID를 분리해 최소 회귀 범위를 보장 |

## Testing Strategy

- Unit tests: `VisionSurfaceAccessibilityTests`로 section ID 매핑/유일성 검증
- Integration tests: 없음. visionOS XCUITest harness는 deferred 유지
- Manual verification: `scripts/build-ios.sh`, 필요 시 `scripts/test-unit.sh --ios-only`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| TODO 문서와 실제 selector가 다시 어긋남 | medium | medium | selector를 helper 상수로 모으고 테스트로 고정 |
| 향후 visionOS root 구조가 바뀌며 ID가 stale됨 | medium | medium | section 단위 helper를 통해 rename 지점을 한 곳으로 제한 |
| placeholder 범위가 이후 실데이터 화면으로 대체됨 | high | low | TODO 문서에 deferred 조건과 현재 assertion scope를 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 파일 범위가 작고, 기존 visionOS 코드에 이미 일부 accessibility identifier 패턴이 있어 동일 방식으로 확장하면 된다. XCUITest harness 구축처럼 외부 제약이 큰 일은 이번 범위에서 제외했다.
