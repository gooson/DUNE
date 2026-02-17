---
tags: [review, architecture, layer-boundary, viewmodifier, caching, swiftui, dedup]
date: 2026-02-18
category: solution
status: implemented
---

# 6-관점 리뷰 수정 패턴: Domain 레이어 정화 + ViewModifier 추출

## Problem

HealthKit dedup 구현 시 3가지 아키텍처 문제 발견:

1. **Domain 오염**: `sourceBundleIdentifier: String?`이 Domain 모델(`WorkoutSummary`)에 직접 노출. 인프라 상세(번들 ID 문자열)가 Domain에 유출.
2. **Presentation에 비즈니스 로직**: `Bundle.main.bundleIdentifier` 접근이 Presentation extension에 위치. Data 레이어에서 해소해야 할 책임.
3. **중복 alert 코드**: Delete 확인 다이얼로그가 2개 View에서 15+ lines 중복.

## Solution

### 1. Domain 정화: `sourceBundleIdentifier` → `isFromThisApp: Bool`

```swift
// Data layer: WorkoutQueryService.toSummary()
isFromThisApp: workout.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier

// Domain model: WorkoutSummary
let isFromThisApp: Bool  // infrastructure detail resolved at Data boundary
```

**원칙**: Domain 모델에는 의미(semantic) 필드만. 인프라 문자열은 Data 레이어에서 boolean으로 해소.

### 2. ViewModifier 추출: `ConfirmDeleteRecordModifier`

```swift
// Presentation/Shared/ViewModifiers/ConfirmDeleteRecordModifier.swift
.confirmDeleteRecord($recordToDelete, context: modelContext)
```

`modelContext.save()` 호출 + stale reference guard 포함.

### 3. SwiftUI 캐싱: `@State` + `onChange(of: .count)`

```swift
@State private var externalWorkouts: [WorkoutSummary] = []

.onAppear { externalWorkouts = workouts.filteringAppDuplicates(against: records) }
.onChange(of: workouts.count) { ... }
.onChange(of: exerciseRecords.count) { ... }
```

## Prevention

- Domain 모델에 새 필드 추가 시: "이 필드가 Foundation/HealthKit 타입인가?" 확인. 아니면 Data 레이어에서 해소.
- 동일 alert/sheet이 2곳 이상이면: 복잡도에 따라 ViewModifier 추출 고려.
- computed property가 filter/sort 포함 시: `@State` 캐싱 + `onChange(of: .count)` 패턴 적용.

## Lessons Learned

- `String` 타입 필드는 Domain에 들어가기 전에 의미 있는 타입(Bool, enum)으로 변환하면 테스트도 쉬워진다.
- ViewModifier 추출은 2곳 중복부터 해도 좋다 — 복잡도가 높으면 3곳 규칙 대기할 필요 없음.
