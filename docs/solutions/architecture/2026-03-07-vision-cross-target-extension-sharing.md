---
tags: [visionos, cross-target, extension, dry, localization, fatigue-level]
date: 2026-03-07
category: solution
status: implemented
---

# visionOS 크로스타겟 Extension 공유 패턴

## Problem

DUNEVision 타겟에서 `FatigueLevel.displayName`이 필요하지만, 이 프로퍼티가 `FatigueLevel+View.swift`에 있어 `DS` (Design System) 의존성 때문에 공유 불가.

추가로 `fatigueLabel` 함수가 3곳에 중복 존재하며 `.fullyRecovered` 케이스에서 "Fully Recovered" vs "Recovered" 불일치 발생.

## Solution

### 1. Foundation-only Extension 분리

`FatigueLevel+DisplayName.swift` (Foundation만 import)를 별도 파일로 생성하여 iOS/visionOS 양쪽에서 공유:

```swift
// FatigueLevel+DisplayName.swift — Foundation only
import Foundation

extension FatigueLevel {
    var displayName: String {
        switch self {
        case .noData:           String(localized: "No Data")
        case .fullyRecovered:   String(localized: "Fully Recovered")
        // ... exhaustive cases
        }
    }
}
```

`FatigueLevel+View.swift`에서 `displayName` 제거 (SwiftUI/DS 의존 코드만 유지).

### 2. project.yml 공유 등록

```yaml
# DUNEVision target sources
- path: Presentation/Shared/Extensions/FatigueLevel+DisplayName.swift
  group: DUNEVision/Presentation/Shared/Extensions
```

### 3. 중복 제거

3곳의 fatigueLabel → `fatigueLevel.displayName` 단일 소스로 통합.

## Prevention

- **크로스타겟 공유 필요한 extension은 DS/SwiftUI 의존을 분리**
  - Foundation-only → 별도 파일 → 양쪽 타겟에 등록
  - SwiftUI/DS 의존 → 타겟별 유지
- **동일 enum label이 2곳+ 존재 시 즉시 추출** (DRY 규칙 #37)
- **exhaustive switch 필수** — `default:` 금지로 불일치 방지
