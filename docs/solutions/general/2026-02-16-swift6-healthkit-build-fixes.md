---
tags: [swift-6, healthkit, concurrency, sending, HKSampleQueryDescriptor, HKUnit, build-error]
category: general
date: 2026-02-16
severity: critical
related_files: [Dailve/Data/HealthKit/HealthKitManager.swift, Dailve/Data/HealthKit/HRVQueryService.swift, Dailve/Data/HealthKit/WorkoutQueryService.swift]
related_solutions: []
---

# Solution: Swift 6 + HealthKit 빌드 에러 해결

## Problem

### Symptoms

- `HKSampleQueryDescriptor` generic constraint 컴파일 에러
- `HKUnit` 타입 추론 실패 에러
- Swift 6 `sending` 요구로 인한 data race 경고
- 테스트 파일에서 `Cannot find 'Date' in scope` 에러

### Root Cause

1. `HKSampleQueryDescriptor`는 프로토콜이 아닌 generic struct이므로 `where T: HKSampleQueryDescriptor` 제약이 불가
2. Swift 6의 엄격한 타입 추론으로 `.secondUnit(with:)` 등에서 base type을 추론하지 못함
3. Swift 6 strict concurrency에서 `HKStatisticsQueryDescriptor`가 `Sendable`하지 않아 `sending` 필요
4. Swift Testing은 `Foundation`을 자동 import하지 않음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HealthKitManager.swift` | `func execute<S: HKSample>(_ query: HKSampleQueryDescriptor<S>)` | Generic struct에 맞는 시그니처 |
| `HealthKitManager.swift` | `_ query: sending HKStatisticsQueryDescriptor` | Swift 6 data race 방지 |
| `HRVQueryService.swift` | `HKUnit.secondUnit(with: .milli)` | 명시적 타입 prefix |
| `WorkoutQueryService.swift` | `HKUnit.kilocalorie()`, `HKUnit.meter()` | 명시적 타입 prefix |
| `DailveTests/*.swift` | `import Foundation` 추가 | Date, Calendar 스코프 해결 |

### Key Code

```swift
// BEFORE: 컴파일 에러 — HKSampleQueryDescriptor는 프로토콜이 아님
func execute<T>(_ query: T) async throws -> [HKQuantitySample] where T: HKSampleQueryDescriptor

// AFTER: generic struct의 type parameter를 사용
func execute<S: HKSample>(_ query: HKSampleQueryDescriptor<S>) async throws -> [S]
```

```swift
// BEFORE: Swift 6 sending 에러
func executeStatistics(_ query: HKStatisticsQueryDescriptor) async throws -> HKStatistics?

// AFTER: sending 어노테이션 추가
func executeStatistics(_ query: sending HKStatisticsQueryDescriptor) async throws -> HKStatistics?
```

```swift
// BEFORE: 타입 추론 실패
sample.quantity.doubleValue(for: .secondUnit(with: .milli))

// AFTER: 명시적 HKUnit prefix
sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
```

## Prevention

### Checklist Addition

- [ ] HealthKit API 사용 시 `HKUnit.` prefix를 항상 명시
- [ ] Generic 함수 작성 시 대상이 protocol인지 struct인지 확인
- [ ] Swift 6에서 비-Sendable 타입 전달 시 `sending` 어노테이션 검토
- [ ] 테스트 파일 생성 시 `import Foundation` 포함 확인

### Rule Addition

`.claude/rules/healthkit-patterns.md`에 이미 포함된 패턴과 일관됨.

## Lessons Learned

1. **`HKSampleQueryDescriptor`는 generic struct이다**: Apple 프레임워크에서 `Descriptor` 접미사는 보통 struct. 프로토콜처럼 제약을 걸 수 없음
2. **Swift 6는 타입 추론이 엄격하다**: static method call에서 contextual base type을 추론하지 못하는 경우가 많음. `HKUnit.`, `CGFloat.` 등 명시적 prefix 습관화
3. **`sending`은 Swift 6의 새 키워드**: 비-Sendable 타입을 async 경계로 전달할 때 소유권 이전을 명시
4. **Swift Testing ≠ XCTest**: `Foundation` 자동 import가 없으므로 `Date`, `Calendar` 사용 시 명시적 import 필요
