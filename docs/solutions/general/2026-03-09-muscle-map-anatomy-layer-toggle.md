---
tags: [swiftui, realitykit, muscle-map, anatomy-layer, localization]
category: general
date: 2026-03-09
severity: minor
related_files:
  - DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift
  - DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift
  - DUNETests/MuscleMapDetailViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions: []
---

# Solution: Muscle Map Anatomy Layer Toggle

## Problem

3D 근육맵에 해부학 레이어 전환이 필요했지만, 현재 번들된 `muscle_body.usdz`는 실제 스켈레톤 메시 없이 `body_shell`과 근육 메시만 포함하고 있었다.

### Symptoms

- 사용자가 피부 레이어와 근육 레이어를 분리해서 볼 수 없었다.
- 선택한 근육만 더 강하게 읽히는 집중 모드가 없었다.
- 검증 중에는 stale test 하나가 현재 `ConditionScore` 생성자 시그니처와 맞지 않아 targeted test가 막혔다.

### Root Cause

자산 구조상 구현 가능한 레이어는 `Skin / Muscles / Focus`였는데, 뷰 상태와 RealityKit material 업데이트 경로에 그 개념이 없었다. 또한 기존 테스트 하나가 도메인 모델 API 변경을 따라가지 못했다.

## Solution

`MuscleMap3DAnatomyLayer`를 도입하고, UI 상태와 RealityKit scene 업데이트에 레이어 개념을 연결했다. `Focus`에서는 비선택 근육의 alpha만 낮추고, `Skin`이 아닐 때는 shell opacity를 0으로 강제해 현재 자산 범위 안에서 해부학 레이어 전환을 구현했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | 레이어 picker와 `@AppStorage` 상태 추가 | 사용자가 레이어를 전환하고 마지막 선택을 유지하도록 하기 위해 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | 레이어별 shell opacity / muscle alpha 계산 추가 | Scene material 업데이트를 레이어 상태와 연결하기 위해 |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | 레이어별 shell/muscle alpha 테스트 추가 | 상태 계산 회귀를 막기 위해 |
| `DUNETests/AICoachingMessageServiceTests.swift` | obsolete `status:` 인자 제거 | 현재 `ConditionScore` 생성자와 테스트를 다시 맞추기 위해 |
| `Shared/Resources/Localizable.xcstrings` | `Layer`, `Focus` 문자열 추가 | 새 UI 라벨을 지역화하기 위해 |

### Key Code

```swift
static func effectiveShellOpacity(
    for anatomyLayer: MuscleMap3DAnatomyLayer,
    configuredShellOpacity: Float
) -> Float {
    switch anatomyLayer {
    case .skin:
        configuredShellOpacity
    case .muscles, .focus:
        0
    }
}
```

## Prevention

### Checklist Addition

- [ ] USDZ 자산 구조를 먼저 확인하고 UI scope를 자산이 실제 지원하는 범위로 고정한다.
- [ ] 도메인 모델 생성자 변경 후 관련 테스트 호출부를 함께 점검한다.
- [ ] simulator 특정 디바이스에서 test runner가 멈추면 다른 가용 simulator UDID로도 확인한다.

### Rule Addition (if applicable)

새 규칙 추가는 필요하지 않았다.

## Lessons Learned

자산 한계가 명확할 때는 없는 개념을 억지로 노출하기보다, 현재 메시 구조에 맞는 제품 용어로 범위를 다시 정의하는 편이 빠르고 안전하다. 또한 Xcode simulator 환경 이슈와 실제 코드 오류를 빨리 분리하려면 `scripts/build-ios.sh`와 `xcodebuild test-without-building`를 다른 destination에서 각각 확인하는 것이 유효했다.
