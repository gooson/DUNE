---
topic: e2e widget surface contracts
date: 2026-03-16
status: approved
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-07-widget-visual-refresh.md
  - docs/solutions/architecture/widget-extension-data-sharing.md
  - docs/solutions/testing/2026-03-08-e2e-phase0-page-backlog-split.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-e2e-ui-test-plan-all-targets.md
---

# Implementation Plan: E2E Widget Surface Contracts

## Context

`DUNEWidget`의 phase 0 E2E surface TODO 4건(`SmallWidgetView`, `MediumWidgetView`, `LargeWidgetView`, `PlaceholderStates`)은 아직 `ready` 상태로 남아 있다. 현재 위젯은 visual/layout 구현과 shared data path는 갖췄지만, family별 stable selector contract와 테스트 가능한 고정 지점이 없어 후속 snapshot/preview lane으로 이어지기 어렵다.

## Requirements

### Functional

- `DUNEWidget`의 small/medium/large/placeholder surface에 대해 stable entry route와 selector contract를 고정한다.
- widget view 코드에 contract를 실제로 연결해 후속 회귀 lane에서 재사용 가능하게 만든다.
- contract 값이 바뀌면 unit test가 바로 깨지도록 한다.
- 관련 TODO 4건을 `done`으로 전환하고 backlog/completed index를 갱신한다.

### Non-functional

- 기존 widget layout과 copy는 바꾸지 않는다.
- `DUNEWidget` 전용 UI test target을 새로 도입하지 않는다.
- TODO/documentation 규칙과 naming convention을 유지한다.

## Approach

`Shared/`에 widget surface contract를 추가하고, `DUNE`와 `DUNEWidget` 양쪽 target에서 이 파일을 공유한다. 위젯 root/state/metric anchor에 contract를 연결하고, `DUNETests`에서 안정성 테스트를 추가한다. 마지막으로 TODO 문서를 contract 기준으로 채운 뒤 open/done index와 solution 문서를 갱신한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 문서만 `done`으로 전환 | 가장 빠름 | 코드와 분리돼 drift를 막지 못함 | Rejected |
| `DUNEWidgetTests` 타깃 신설 후 widget view 직접 테스트 | 가장 강한 회귀 신호 | target 추가와 test harness 리스크가 큼 | Rejected |
| shared contract + app unit test + TODO 문서 동기화 | 현재 인프라에서 가장 낮은 리스크로 drift 방지 가능 | 실제 snapshot lane은 후속 작업이 필요 | Accepted |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-16-e2e-widget-surface-contracts.md` | add | 이번 작업 계획서 |
| `DUNE/project.yml` | modify | shared contract 파일을 app/widget target에 포함 |
| `Shared/WidgetSurfaceAccessibility.swift` | add | widget surface contract와 stable identifiers 정의 |
| `DUNEWidget/Views/SmallWidgetView.swift` | modify | small family root/state anchor 연결 |
| `DUNEWidget/Views/MediumWidgetView.swift` | modify | medium family root/state anchor 연결 |
| `DUNEWidget/Views/LargeWidgetView.swift` | modify | large family root/state anchor 연결 |
| `DUNEWidget/Views/WidgetPlaceholderView.swift` | modify | placeholder anchor 연결 |
| `DUNEWidget/Views/WidgetScoreComponents.swift` | modify | metric anchor 연결 |
| `DUNEWidget/WellnessDashboardWidget.swift` | modify | family contract와 supported families 고정 |
| `DUNETests/WidgetSurfaceAccessibilityTests.swift` | add | contract stability/unit coverage |
| `todos/092-ready-p3-e2e-dunewidget-small-widget-view.md` | move+modify | `done` 전환 및 surface contract 기입 |
| `todos/093-ready-p3-e2e-dunewidget-medium-widget-view.md` | move+modify | `done` 전환 및 surface contract 기입 |
| `todos/094-ready-p3-e2e-dunewidget-large-widget-view.md` | move+modify | `done` 전환 및 surface contract 기입 |
| `todos/095-ready-p3-e2e-dunewidget-placeholder-states.md` | move+modify | `done` 전환 및 placeholder matrix 기입 |
| `todos/101-ready-p2-e2e-phase0-page-backlog-index.md` | modify | open widget backlog 제거 |
| `todos/107-done-p2-e2e-phase0-completed-surface-index.md` | modify | completed widget surface 추가 |
| `docs/solutions/testing/2026-03-16-widget-surface-contracts.md` | add | contract pattern 문서화 |

## Implementation Steps

### Step 1: Shared widget contract 정의

- **Files**: `Shared/WidgetSurfaceAccessibility.swift`, `DUNE/project.yml`, `DUNEWidget/WellnessDashboardWidget.swift`
- **Changes**:
  - family enum, root/state/metric identifier, supported families contract를 추가한다.
  - app/widget target에서 모두 compile되도록 shared source membership를 맞춘다.
- **Verification**: `rg -n "WidgetSurfaceAccessibility|supportedFamilies" Shared DUNEWidget DUNE/project.yml`

### Step 2: Widget views에 contract 연결

- **Files**: `DUNEWidget/Views/SmallWidgetView.swift`, `DUNEWidget/Views/MediumWidgetView.swift`, `DUNEWidget/Views/LargeWidgetView.swift`, `DUNEWidget/Views/WidgetPlaceholderView.swift`, `DUNEWidget/Views/WidgetScoreComponents.swift`
- **Changes**:
  - family별 root/state anchor를 추가한다.
  - metric component에 family-aware identifier를 연결한다.
  - placeholder surface에 dedicated state identifiers를 부여한다.
- **Verification**: `rg -n "accessibilityIdentifier|WidgetSurfaceAccessibility" DUNEWidget/Views`

### Step 3: Unit test와 surface TODO 문서 정리

- **Files**: `DUNETests/WidgetSurfaceAccessibilityTests.swift`, `todos/092-*.md`, `todos/093-*.md`, `todos/094-*.md`, `todos/095-*.md`, `todos/101-ready-p2-e2e-phase0-page-backlog-index.md`, `todos/107-done-p2-e2e-phase0-completed-surface-index.md`, `docs/solutions/testing/2026-03-16-widget-surface-contracts.md`
- **Changes**:
  - contract 값의 안정성/유일성/unit coverage를 추가한다.
  - widget surface TODO를 `done`으로 rename하고, entry route / selector inventory / assertion scope / deferred lane을 채운다.
  - open/completed index와 solution 문서를 동기화한다.
- **Verification**:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/WidgetSurfaceAccessibilityTests -quiet`
  - `rg -n "092-|093-|094-|095-" todos/101-ready-p2-e2e-phase0-page-backlog-index.md todos/107-done-p2-e2e-phase0-completed-surface-index.md`

## Edge Cases

| Case | Handling |
|------|----------|
| WidgetKit에서 `accessibilityIdentifier`가 실제 host automation까지 직접 연결되지 않을 수 있음 | 이번 phase는 stable contract와 source-level hook까지만 보장하고, snapshot/preview lane은 deferred로 명시한다 |
| medium family에는 footer timestamp가 없음 | medium TODO에는 tile metric anchors와 scored/placeholder state만 contract로 고정한다 |
| placeholder는 family별로 같은 `WidgetPlaceholderView`를 재사용함 | family root/state ID와 공통 placeholder subview ID를 분리해 matrix를 기록한다 |
| project.yml 변경 후 xcodeproj가 stale일 수 있음 | `regen-project.sh`로 재생성 후 테스트한다 |

## Testing Strategy

- Unit tests: `DUNETests/WidgetSurfaceAccessibilityTests.swift`에서 family/state/metric contract와 supported families를 검증한다.
- Integration tests:
  - `scripts/lib/regen-project.sh`
  - `scripts/build-ios.sh`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/WidgetSurfaceAccessibilityTests -quiet`
- Manual verification: TODO 4건과 backlog indexes가 open/done 상태에 맞게 이동했는지 문서 확인.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| shared contract file membership 누락으로 target build 실패 | Medium | Medium | `DUNE/project.yml` 양쪽 source 목록에 명시하고 regen/build로 확인한다 |
| identifier 설계가 향후 snapshot lane에서 부족할 수 있음 | Medium | Low | family/state/metric 3계층으로 먼저 고정하고 deferred lane에 host-specific selector를 남긴다 |
| detached HEAD 상태에서 커밋이 분기 없이 쌓일 수 있음 | High | Medium | Work setup에서 `codex/` prefix 브랜치를 먼저 생성한다 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 문서/contract 작업은 명확하지만, widget extension에 shared source를 추가하고 xcodeproj를 재생성하는 경로는 실제 빌드 검증이 필요하다.
