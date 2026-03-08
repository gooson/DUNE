---
topic: vision-pro-settings-entry
date: 2026-03-08
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-multi-window-dashboard.md
  - docs/solutions/architecture/2026-03-08-visionos-window-placement-planner.md
related_brainstorms:
  - docs/brainstorms/2026-02-28-settings-hub.md
---

# Implementation Plan: Vision Pro Settings Entry

## Context

Vision Pro 앱의 메인 dashboard에는 multi-window / immersive / chart 진입점만 있고, 설정으로 들어가는 명시적 버튼이 없다. iOS의 `SettingsView`는 존재하지만 `DUNEVision` target은 그 화면 전체를 포함하지 않기 때문에, Vision Pro 사용자는 설정 진입점을 찾을 수 없고 실제로 접근도 불가능하다.

## Requirements

### Functional

- Vision Pro Today surface에서 설정 진입 버튼이 명확히 보여야 한다.
- 설정 버튼을 누르면 visionOS에서 동작하는 설정 화면이 열려야 한다.
- 설정 화면은 최소한 Vision Pro에서 의미 있는 항목(iCloud sync 상태, simulator mock controls, app info)을 제공해야 한다.

### Non-functional

- 기존 visionOS multi-window 패턴(`openWindow`, `WindowGroup`, placement planner`)과 충돌하지 않아야 한다.
- iOS 전용 `SettingsView`/UIKit 의존을 억지로 DUNEVision target에 끌어오지 않는다.
- 새 사용자 대면 문자열은 가능하면 기존 string catalog key를 재사용하고, 필요한 경우 localization 규칙을 따른다.

## Approach

Vision dashboard toolbar에 별도 settings 버튼을 추가하고, 버튼은 dedicated visionOS settings utility window를 연다. 설정 UI는 `DUNEVision/` 하위에 전용 `VisionSettingsView`로 만들고, shared target에는 window placement planner와 해당 테스트만 최소 보강한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| iOS `SettingsView`를 DUNEVision target에 그대로 포함 | 기존 기능 재사용 가능 | UIKit/Location/openSettings 등 iOS 전용 의존이 많아 target 확장이 커짐 | 기각 |
| Today `NavigationStack` 안으로 push | 구현량이 가장 적음 | visionOS multi-window 흐름과 덜 맞고, utility panel 패턴을 재사용하지 못함 | 보류 |
| 전용 settings utility window + toolbar button | 현재 visionOS scene 구조와 일관, 발견성과 spatial UX 모두 확보 | 새 view와 scene wiring이 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-08-vision-pro-settings-entry.md` | add | 이번 작업 계획서 |
| `DUNEVision/Presentation/Settings/VisionSettingsView.swift` | add | visionOS 전용 settings 화면 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | modify | settings toolbar button 추가 |
| `DUNEVision/App/VisionContentView.swift` | modify | settings open action 및 single-window fallback 연결 |
| `DUNEVision/App/DUNEVisionApp.swift` | modify | settings `WindowGroup` 추가 |
| `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift` | modify | settings window placement intent 명시 |
| `DUNETests/VisionWindowPlacementPlannerTests.swift` | modify | settings placement regression test 추가 |

## Implementation Steps

### Step 1: Add a visionOS-native settings surface

- **Files**: `DUNEVision/Presentation/Settings/VisionSettingsView.swift`
- **Changes**:
  - lightweight settings form/card UI 작성
  - `CloudSyncPreferenceStore` toggle
  - simulator-only mock data controls/status
  - version/build info 노출
- **Verification**: 파일이 DUNEVision target source 범위(`../DUNEVision`) 안에 있고, 기존 xcstrings 키만으로 컴파일 가능해야 한다.

### Step 2: Wire the entry point from Vision dashboard

- **Files**: `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`, `DUNEVision/App/VisionContentView.swift`, `DUNEVision/App/DUNEVisionApp.swift`
- **Changes**:
  - toolbar settings button 추가
  - `supportsMultipleWindows`이면 utility window open, 아니면 current stack push fallback
  - `WindowGroup(id: settings)` 추가
- **Verification**: Vision Pro Today toolbar에서 버튼이 보이고, action이 settings surface로 이어져야 한다.

### Step 3: Lock down placement behavior and run platform validation

- **Files**: `DUNE/Presentation/Vision/VisionWindowPlacementPlanner.swift`, `DUNETests/VisionWindowPlacementPlannerTests.swift`
- **Changes**:
  - settings window placement를 utility panel로 명시
  - planner test 추가
- **Verification**:
  - `swift test` 또는 targeted DUNETests에서 planner test 통과
  - `scripts/build-ios.sh`
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' build`

## Edge Cases

| Case | Handling |
|------|----------|
| multi-window가 현재 context에서 비활성 | `VisionContentView`에서 stack push fallback 제공 |
| simulator mock controls가 비시뮬레이터 환경 | 기존 availability gate를 그대로 사용해 section 숨김 |
| iCloud sync toggle 변경 즉시 scene rebuild가 없더라도 | 현재 앱 정책과 동일하게 preference 저장만 수행하고, 상태 혼선이 없도록 단순 toggle로 제한 |

## Testing Strategy

- Unit tests: `VisionWindowPlacementPlannerTests`에 settings window case 추가
- Integration tests: `DUNEVision` generic build로 scene wiring 컴파일 검증
- Manual verification:
  - Vision Pro Today toolbar에서 gear 버튼 노출 확인
  - 버튼 탭 시 settings utility window 또는 fallback push 진입 확인
  - simulator 환경이면 mock seed/reset 동작 및 상태 문구 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| settings를 별도 window로 열 때 placement가 의도와 다르게 보임 | medium | medium | planner에 explicit settings case 추가 및 test 고정 |
| DUNEVision에서 shared setting dependency가 부족해 compile error 발생 | low | high | iOS `SettingsView` 재사용 대신 DUNEVision 전용 view로 제한 |
| toolbar 아이템이 다른 primary action과 충돌해 가시성이 떨어짐 | low | medium | settings를 별도 trailing item으로 분리해 icon affordance를 고정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 현재 visionOS app은 이미 `openWindow`/`WindowGroup` 기반 multi-window 구조를 사용 중이라 진입점 추가 자체는 명확하다. 핵심은 iOS 설정 화면을 재사용하지 않고 target-safe한 최소 settings surface를 만드는 것이다.
