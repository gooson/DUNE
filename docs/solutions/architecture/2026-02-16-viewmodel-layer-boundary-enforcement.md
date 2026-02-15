---
tags: [viewmodel, import, observation, swiftui, layer-boundary, date-validation, DRY]
category: architecture
date: 2026-02-16
severity: important
related_files:
  - Dailve/Presentation/Exercise/ExerciseViewModel.swift
  - Dailve/Presentation/BodyComposition/BodyCompositionViewModel.swift
  - Dailve/Presentation/Shared/Extensions/Date+Validation.swift
  - Dailve/Presentation/Shared/Components/AdaptiveNavigation.swift
related_solutions:
  - architecture/2026-02-15-review-quality-patterns.md
---

# Solution: ViewModel Layer Boundary Enforcement & View Stability

## Problem

### Symptoms

1. ViewModel 파일에서 `import SwiftUI`를 사용하여 레이어 경계 규칙 위반
2. 날짜 검증 로직 `selectedDate > Date()`가 3곳에 중복
3. AdaptiveNavigation의 `sizeClass` 분기가 iPad multitasking 전환 시 NavigationStack 생성/소멸 유발
4. `validationError`가 날짜 변경 시 클리어되지 않아 stale error 표시
5. `applyUpdate(to:)`에 `isSaving` guard 누락으로 중복 수정 가능

### Root Cause

1. `@Observable`이 `Observation` 프레임워크 소속이지만, SwiftUI에서도 re-export되어 `import SwiftUI`로 컴파일 가능. 이로 인해 ViewModel이 SwiftUI에 의존하는 것처럼 보이며, 실제로 UI 타입 접근 가능.
2. 날짜 검증은 각 메서드(`createValidatedRecord`, `applyUpdate`) 시작부에 인라인으로 작성되어 DRY 원칙 위반.
3. SwiftUI의 `@Environment(\.horizontalSizeClass)`는 iPad Split View/Slide Over 전환 시 동적으로 변경됨. `if/else` 분기가 직접 sizeClass를 참조하면 View 트리가 교체되어 상태 손실.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ExerciseViewModel.swift:1` | `import SwiftUI` → `import Foundation` + `import Observation` | 레이어 경계 준수 |
| `BodyCompositionViewModel.swift:1` | 동일 | 레이어 경계 준수 |
| `Date+Validation.swift` | 신규 생성: `Date.isFuture` extension | 날짜 검증 중복 제거 |
| `ExerciseViewModel.swift` | `selectedDate > Date()` → `selectedDate.isFuture` | DRY |
| `BodyCompositionViewModel.swift` | 동일 (2곳) | DRY |
| `AdaptiveNavigation.swift` | `@State private var initialIsRegular: Bool?` 추가 | sizeClass 전환 안정성 |
| `*ViewModel.swift` | `selectedDate` didSet에 `validationError = nil` | Stale error 방지 |
| `BodyCompositionViewModel.swift` | `applyUpdate`에 `guard !isSaving` 추가 | Idempotency 보장 |

### Key Code

**Date.isFuture extension (중복 제거 + race condition 방어):**
```swift
extension Date {
    /// 60-second tolerance to avoid false positives from DatePicker minute-level precision.
    var isFuture: Bool { self > Date().addingTimeInterval(60) }
}
```

**AdaptiveNavigation sizeClass 안정화:**
```swift
struct AdaptiveNavigation: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var initialIsRegular: Bool?

    private var isRegular: Bool {
        initialIsRegular ?? (sizeClass == .regular)
    }

    func body(content: Content) -> some View {
        Group {
            if isRegular { /* no NavigationStack */ }
            else { NavigationStack { /* wrapped */ } }
        }
        .onAppear {
            if initialIsRegular == nil {
                initialIsRegular = (sizeClass == .regular)
            }
        }
    }
}
```

**ViewModel selectedDate didSet:**
```swift
var selectedDate: Date = Date() { didSet { validationError = nil } }
```

## Prevention

### Checklist Addition

- [ ] ViewModel에서 `import SwiftUI` 사용 여부 확인 → `import Observation` 사용
- [ ] 동일 검증 로직이 2곳 이상에서 반복되면 extension/helper로 추출
- [ ] `@Environment` 값 기반 View 분기 시 `@State`로 초기값 캡처하여 안정성 확보
- [ ] 모든 mutation 메서드에 `isSaving` guard 적용

### Rule Addition

`.claude/rules/swift-layer-boundaries.md`에 이미 ViewModel SwiftUI import 금지 규칙 존재.
추가 강화: `Date.isFuture`처럼 공통 검증 로직은 Presentation/Shared/Extensions/에 배치.

## Lessons Learned

1. **SwiftUI re-export 함정**: `@Observable`은 SwiftUI에서 접근 가능하지만, 명시적으로 `import Observation`을 사용해야 레이어 의도가 명확해진다.
2. **sizeClass 동적 변경**: iPad에서 sizeClass는 정적이 아니다. Slide Over 진입/이탈 시 `.regular` ↔ `.compact` 전환이 발생하므로, View 트리 구조를 결정하는 분기에는 초기값 캡처가 필수.
3. **60초 tolerance**: DatePicker는 분 단위 정밀도이므로, 현재 시각과의 비교에서 마이크로초 오차는 무의미. 적절한 tolerance가 UX를 개선한다.
4. **didSet 활용**: `@Observable`에서도 `didSet`은 동작하므로, 연관 상태 클리어에 활용 가능.
