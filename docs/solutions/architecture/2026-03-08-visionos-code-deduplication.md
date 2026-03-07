---
tags: [visionos, deduplication, multi-target, muscle-group, extension, shared-code]
category: architecture
date: 2026-03-08
severity: important
related_files:
  - DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift
  - DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift
  - DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift
  - DUNEVision/Presentation/Immersive/VisionImmersiveSceneView.swift
  - DUNEVision/Presentation/Shared/Extensions/UIColor+Blended.swift
related_solutions: []
---

# Solution: visionOS 타겟 내 중복 코드 발산 해결

## Problem

### Symptoms

- `MuscleGroup.displayName`이 이미 Domain에 존재하는데 visionOS 뷰 4곳에서 로컬 헬퍼로 재구현
  - `localizedMuscleName(_:)`, `title(for:)`, `spatialDisplayName`
- `MuscleGroup.iconName`도 3곳에서 각각 구현 (`iconName(for:)`, `spatialIconName`)
- `UIColor.blended(with:ratio:)` 유틸이 2개 파일에 중복 정의
- 하나의 뷰에서 번역을 수정해도 다른 뷰에는 반영 안 됨

### Root Cause

visionOS 타겟이 초기 개발 시 iOS 코드를 복붙하면서 Domain의 공유 프로퍼티 대신 뷰 로컬 헬퍼를 만듦. 이후 각 뷰가 독립적으로 발전하면서 코드 발산 (divergence) 발생.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `VisionDashboardWindowScene.swift` | `localizedMuscleName` 삭제 → `$0.displayName` | Domain 프로퍼티 사용 |
| `VisionMuscleMapExperienceView.swift` | `title(for:)`, `iconName(for:)` 삭제 → `.displayName`, `.iconName` | Domain 프로퍼티 사용 |
| `VisionSpatialSceneSupport.swift` | `spatialDisplayName`, `spatialIconName`, `blended()` 삭제 | 공유 코드로 대체 |
| `VisionImmersiveSceneView.swift` | 로컬 `blended()` 삭제 → `base.blended(with:ratio:)` | 공유 extension 사용 |
| `UIColor+Blended.swift` | 신규 생성: 공유 `UIColor.blended(with:ratio:)` extension | 단일 소스 |
| `VisionVolumetricExperienceView.swift` | `spatialDisplayName` → `displayName` | 일관성 |

### Key Code

```swift
// BEFORE: 4곳에서 각각 구현
// VisionDashboardWindowScene.swift
private func localizedMuscleName(_ group: MuscleGroup) -> String {
    switch group {
    case .chest: return "가슴"  // 하드코딩!
    ...
    }
}

// VisionSpatialSceneSupport.swift
extension MuscleGroup {
    var spatialDisplayName: String { ... }  // 또 다른 구현
}

// AFTER: Domain의 단일 소스 사용
Text(muscleGroup.displayName)  // MuscleGroup에 이미 String(localized:) 패턴 존재
Image(muscleGroup.iconName)    // MuscleGroup에 이미 존재
```

### 공유 Extension 패턴

```swift
// DUNEVision/Presentation/Shared/Extensions/UIColor+Blended.swift
import UIKit

extension UIColor {
    func blended(with other: UIColor, ratio: CGFloat) -> UIColor {
        // 단일 구현
    }
}
```

## Prevention

### Checklist Addition

- [ ] visionOS 뷰에서 Domain 모델의 프로퍼티를 로컬 헬퍼로 재구현하고 있지 않은가
- [ ] 새 타겟 추가 시 기존 공유 extension/프로퍼티를 먼저 검색했는가
- [ ] 유틸리티 함수가 2개 이상 파일에 복붙되어 있지 않은가

### Rule Addition

`swift-layer-boundaries.md`에 다음 원칙을 고려:
> 새 타겟(visionOS 등)에서 Domain 모델의 프로퍼티를 사용할 때, 로컬 헬퍼를 만들기 전에 기존 Domain extension을 먼저 확인한다.

## Lessons Learned

1. **멀티타겟 코드 발산은 silent**: 컴파일 에러가 아니라 단순 "같은 기능의 다른 구현"이므로 CI에서 잡히지 않는다. 주기적 전수 리뷰 또는 lint 규칙이 필요
2. **Domain `displayName` 패턴의 가치**: `String(localized:)`로 구현된 Domain 프로퍼티가 있으면 모든 타겟이 같은 번역을 공유한다. 로컬 헬퍼는 번역 누락/불일치의 원인
3. **Shared Extension 디렉토리**: 타겟별 `Presentation/Shared/Extensions/`에 공유 유틸리티를 배치하면 중복을 방지하면서도 타겟 경계를 유지할 수 있다
