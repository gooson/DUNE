---
source: review/data-integrity
priority: p1
status: ready
created: 2026-02-16
updated: 2026-02-16
---

# Edit 작업 transaction boundary 추가

## Problem

`BodyCompositionViewModel.applyUpdate(to:)`가 record의 5개 필드(date, weight, bodyFatPercentage, muscleMass, memo)를 개별 변경.
SwiftData auto-save가 중간 상태를 CloudKit으로 전파할 이론적 위험 존재.

## Location

- `Dailve/Presentation/BodyComposition/BodyCompositionView.swift:68` (호출부)
- `Dailve/Presentation/BodyComposition/BodyCompositionViewModel.swift:45` (applyUpdate)

## Solution

View의 onSave 클로저에서 `modelContext.transaction { }` 블록으로 감싸서 원자성 보장.

```swift
onSave: {
    modelContext.transaction {
        if viewModel.applyUpdate(to: record) {
            viewModel.isShowingEditSheet = false
            viewModel.editingRecord = nil
        }
    }
}
```

## Notes

- SwiftData는 같은 RunLoop tick 내 변경을 일괄 처리하므로 실제 위험은 낮음
- 하지만 명시적 transaction은 의도를 명확히 하고 향후 안전성 보장
