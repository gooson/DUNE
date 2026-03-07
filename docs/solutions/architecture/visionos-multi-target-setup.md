---
tags: [visionos, xcodegen, multi-target, platform, chart3d, widgetkit]
date: 2026-03-05
category: solution
status: implemented
---

# visionOS 멀티 타겟 설정 패턴

## Problem

iOS + watchOS 앱에 visionOS 타겟을 추가할 때:
1. Domain/Data 레이어 코드 중복을 피해야 함
2. UIKit 의존 코드가 visionOS에서 컴파일되지 않음
3. Widget Extension에서 앱 데이터 접근이 필요함
4. ModelContainer 초기화 코드가 타겟마다 복제됨

## Solution

### 1. project.yml 타겟 구조

```yaml
# 독립 visionOS 앱 타겟 + Widget Extension
DUNEVision:
  type: application
  platform: visionOS
  sources:
    - path: ../DUNEVision       # visionOS 전용 코드
    - path: Domain              # 100% 공유
    - path: Data/Persistence    # SwiftData 공유
    - path: Data/HealthKit      # HealthKit 공유
      excludes: ["CardioSessionManager.swift"]  # GPS 의존 제외
    - path: Data/Services       # CloudKit 등 공유

DUNEVisionWidgets:
  type: app-extension
  platform: visionOS
  sources:
    - path: ../DUNEVisionWidgets
    - path: Domain/Models/HealthMetric.swift  # 필요한 모델만 선택적 공유
```

### 2. UIKit 의존 가드 패턴

```swift
// Wave background, share image 등 UIKit 의존 파일
#if canImport(UIKit)
import UIKit
#endif
```

### 3. ModelContainer DRY 패턴

```swift
// 모델 목록을 한 곳에서 관리
private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
    try ModelContainer(
        for: ExerciseRecord.self, /* ... */,
        migrationPlan: AppMigrationPlan.self,
        configurations: configuration
    )
}

// 초기화 시 재사용
modelContainer = try Self.makeModelContainer(configuration: config)
```

### 4. Chart3D 데이터 파라미터화

```swift
// BAD: 파라미터 없이 고정 데이터
.onChange(of: period) { sampleData = Self.generate() }

// GOOD: 선택값을 반영
.onChange(of: period) { _, new in sampleData = Self.generate(days: new.dayCount) }
```

### 5. Widget WidgetFamily switch 패턴

```swift
// @unknown default 사용 (프로젝트 규칙: exhaustive case)
switch family {
case .systemSmall: smallView
case .systemMedium: mediumView
@unknown default: smallView
}
```

## Prevention

- 새 플랫폼 타겟 추가 시 `excludes`로 비호환 파일 제외
- UIKit import는 항상 `#if canImport(UIKit)` 가드
- ModelContainer 모델 목록은 `makeModelContainer()` 팩토리 단일 소스
- Chart 데이터 생성 함수는 UI 선택값을 파라미터로 반드시 전달
- Widget timeline 날짜 계산 시 과거 날짜 방어 필수
