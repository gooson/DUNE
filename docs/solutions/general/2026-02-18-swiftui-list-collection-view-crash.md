---
tags: [swiftui, list, crash, swiftdata, query, animation, collection-view]
date: 2026-02-18
category: general
status: implemented
---

# SwiftUI List + @Query NSInternalInconsistencyException Crash

## Problem

`@Query`로 관찰하는 SwiftData 배열이 변경될 때, SwiftUI `List`의 내부 `UICollectionView`가 item count 불일치로 크래시:

```
NSInternalInconsistencyException: Invalid update: invalid number of items in section 1.
The number of items contained in an existing section after the update (62)
must be equal to the number of items contained in that section before the update (61)...
```

### 원인

1. `modelContext.delete(record)` + `modelContext.save()`가 `@Query`를 **동기적으로** 업데이트
2. SwiftUI의 `UICollectionView`가 animation context 없이 데이터 변경을 받으면 batch update 실패
3. `Button(role: .destructive)` in `.swipeActions`는 SwiftUI가 자동으로 row 삭제 animation을 재생하여, 실제 삭제 전에 UI가 먼저 변경됨

## Solution

### 삭제 시 withAnimation 감싸기

```swift
// Before: crash
modelContext.delete(record)
try? modelContext.save()

// After: safe
withAnimation {
    modelContext.delete(record)
    recordToDelete = nil
}
// Note: explicit save() 제거 — SwiftUI가 적절한 타이밍에 auto-save
```

### Swipe-to-delete에서 role: .destructive 제거

```swift
// Before: alert 전에 row가 사라짐
Button(role: .destructive) { recordToDelete = record }

// After: confirm 후에만 삭제
Button { recordToDelete = record } label: {
    Label("Delete", systemImage: "trash")
}
.tint(.red)
```

### ConfirmDeleteRecordModifier에서 delete 순서

```swift
// 1. HK ID를 먼저 캡처 (delete 후 record 접근 불가)
let hkWorkoutID = record.healthKitWorkoutID

// 2. SwiftData delete first (authoritative)
withAnimation { modelContext.delete(record) }

// 3. HealthKit cleanup (fire-and-forget side-effect)
if let workoutID = hkWorkoutID, !workoutID.isEmpty {
    Task { try? await deleteService.deleteWorkout(uuid: workoutID) }
}
```

## Prevention

- SwiftData `modelContext.delete()` 호출은 항상 `withAnimation {}` 내부에서
- `.swipeActions`의 confirmation 패턴: `role: .destructive` 제거 → `@State var recordToDelete` → `.alert` → `withAnimation { delete }`
- `try? modelContext.save()` 명시 호출은 제거 — SwiftUI auto-save 활용
