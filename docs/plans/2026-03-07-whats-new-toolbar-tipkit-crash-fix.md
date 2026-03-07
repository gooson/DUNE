---
topic: whats-new-toolbar-tipkit-crash-fix
date: 2026-03-07
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-whats-new-space.md
  - docs/brainstorms/2026-02-28-systematic-ui-test-design.md
---

# Implementation Plan: What's New Toolbar TipKit Crash Fix

## Context

Today 탭 우상단 `What's New` toolbar 아이콘에 `TipKit`의 `.popoverTip(...)`을 붙인 뒤, iOS 26 계열에서 Auto Layout 경고와 `_SwiftUILayerDelegate _screen` 예외가 이어지며 앱이 종료된다. 기능 목표는 `What's New` 진입점과 build 기반 badge는 유지하면서, toolbar popover 경로만 제거해 크래시를 막는 것이다.

리서치 근거:
- 프로젝트 내부 변경 이력상 문제는 `What's New` toolbar 진입점 복구 직후에 시작되었다.
- 기존 해결책 `dashboard-notification-badge-clipping`은 toolbar overlay를 명시적 frame + overlay로 제한하는 패턴을 사용한다.
- Apple 공식 문서상 `popoverTip`는 일반 API로 제공되지만, Apple Developer Forums에는 2025-11 기준 SwiftUI `ToolbarItem` 내부에서 `popoverTip` 동작 불안정 이슈가 보고되어 있다.

## Requirements

### Functional

- Today toolbar의 `What's New` 버튼이 계속 노출되어야 한다.
- 새 build에서 `new` 점 badge 표시 정책은 유지되어야 한다.
- `What's New` 화면을 열면 기존처럼 build open 상태가 기록되어야 한다.
- toolbar 렌더링 시 크래시를 유발하는 `TipKit` 경로는 제거되어야 한다.

### Non-functional

- 수정 범위는 crash hotfix 수준으로 제한한다.
- 기존 accessibility identifier와 smoke navigation 경로를 유지한다.
- 앱 빌드와 Today 관련 UI smoke, build-state unit test를 통과해야 한다.
- 관련 해결책 문서는 실제 구현과 일치하도록 갱신한다.

## Approach

`DashboardView`의 `What's New` toolbar `NavigationLink`에서 `.popoverTip(...)`을 제거하고, 더 이상 사용되지 않는 `WhatsNewToolbarTip` 타입도 삭제한다. `DUNEApp`의 `TipKit` 초기화 코드를 제거해 runtime이 `TipKit`을 전혀 건드리지 않게 만든다. `showWhatsNewBadge`와 `markWhatsNewOpened()`는 기존 `WhatsNewStore` build 상태에만 의존하도록 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `popoverTip` 유지 + `.buttonStyle(.plain)` 등 우회 적용 | UX 의도(1회 안내)를 유지할 수 있음 | Apple 포럼 기준 toolbar 내부 안정성이 낮고, 현재는 실제 크래시가 발생하므로 hotfix로는 위험 | Reject |
| tip anchor를 toolbar 밖 본문으로 이동 | crash path를 피하면서 안내 surface 유지 가능 | 새 anchor 설계, 추가 UI 검증, 범위 확대 필요 | Reject |
| toolbar 진입점은 유지하고 `TipKit`만 제거 | 최소 수정으로 크래시 경로 차단, badge와 navigation 유지 | 1회 popover 안내는 사라짐 | Accept |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | modify | `What's New` toolbar에서 `TipKit` popover 제거, badge/open 상태 유지 |
| `DUNE/App/DUNEApp.swift` | modify | `TipKit` import/configure 제거 |
| `docs/solutions/general/2026-03-07-whats-new-toolbar-tipkit-entrypoint.md` | modify | 해결책 문서를 crash workaround 기준으로 정정 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | verify | 기존 Today toolbar smoke를 회귀 gate로 사용 |
| `DUNETests/WhatsNewStoreTests.swift` | verify | build badge/open 상태 회귀 확인 |

## Implementation Steps

### Step 1: Remove the toolbar TipKit crash path

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`, `DUNE/App/DUNEApp.swift`
- **Changes**:
  - `DashboardView`의 `What's New` toolbar item에서 `.popoverTip(...)` 제거
  - `WhatsNewToolbarTip` type과 Tip invalidation 코드 삭제
  - `DUNEApp`의 `TipKit` import와 `Tips.configure()` 제거
- **Verification**:
  - `rg -n "TipKit|Tips\\.|popoverTip\\(" DUNE -S` 결과가 비어야 함
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -quiet`

### Step 2: Keep release discoverability and verify user flows

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`, `DUNEUITests/Smoke/DashboardSmokeTests.swift`, `DUNETests/WhatsNewStoreTests.swift`
- **Changes**:
  - badge 표시와 `markWhatsNewOpened()`의 build 기록 흐름이 그대로 유지되는지 확인
  - 기존 smoke/unit test를 회귀 gate로 실행
- **Verification**:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing DUNEUITests/Smoke/DashboardSmokeTests -quiet`
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.3.1' -only-testing DUNETests/WhatsNewStoreTests -quiet`

### Step 3: Document the stable pattern

- **Files**: `docs/solutions/general/2026-03-07-whats-new-toolbar-tipkit-entrypoint.md`
- **Changes**:
  - 원인, 수정, 예방 규칙을 “toolbar `popoverTip` crash 회피” 기준으로 재작성
  - 검증 명령과 통과 결과를 최신 상태로 반영
- **Verification**:
  - 문서의 Problem/Solution/Prevention/Lessons Learned가 현재 diff와 일치
  - 관련 파일/테스트 경로가 실제 저장소 상태와 맞음

## Edge Cases

| Case | Handling |
|------|----------|
| current build 문자열이 비어 있음 | 기존 guard 유지, badge open 기록 생략 |
| release catalog에 current build 대응 릴리스가 없음 | 기존 `reloadWhatsNewBadge()` 경로로 badge false 유지 |
| UI test 환경에서 Today toolbar가 늦게 렌더링됨 | 기존 smoke test의 `waitForExistence` 사용 |
| `TipKit` import 제거 후 다른 파일에서 참조가 남아 있음 | `rg` 검증으로 잔존 참조 차단 |

## Testing Strategy

- Unit tests: 기존 `WhatsNewStoreTests`로 build badge/open 정책 회귀 확인
- Integration tests: 없음
- UI tests: 기존 `DashboardSmokeTests` 전체 실행으로 launch + Today toolbar navigation 회귀 확인
- Manual verification: 크래시 로그 재현 경로(앱 실행 후 Today 탭 진입)에서 constraint warning/exception 미발생 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 1회 안내 popover가 사라져 discoverability가 약해짐 | medium | low | build badge와 Settings 재진입 경로 유지 |
| crash 원인이 `TipKit`이 아니라 다른 toolbar item일 가능성 | low | high | 관련 diff가 `What's New` item에 집중되어 있고, 제거 후 빌드/UI smoke로 최소 회귀 확인 |
| detached HEAD 상태에서 바로 ship 시 브랜치 정리가 꼬일 수 있음 | high | medium | Work 단계에서 `codex/` prefix feature branch 생성 후 진행 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 증상 발생 시점과 코드 변경 시점이 밀접하고, crash hotfix로 필요한 최소 범위가 명확하다. badge/open 상태는 기존 테스트로 검증 가능하며, toolbar popover만 제거하면 사용자 가치를 대부분 유지할 수 있다.
