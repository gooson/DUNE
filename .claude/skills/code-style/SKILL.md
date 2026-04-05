---
name: code-style
description: "코딩 컨벤션과 스타일 가이드. 네이밍, 파일 구조, 에러 처리 패턴. 코드 작성 시 자동으로 참조됩니다."
---

# Code Style Guide — Swift 6 / SwiftUI / iOS 26+

## Naming Conventions

- **Files**: PascalCase (e.g., `ConditionScoreUseCase.swift`, `HRVChartView.swift`)
- **Extension files**: `{Type}+{Context}.swift` (e.g., `HealthMetric+View.swift`)
- **Variables/Functions**: camelCase
- **Types/Protocols**: PascalCase
- **Constants**: camelCase in code, UPPER_SNAKE_CASE only for global build flags
- **Enums**: PascalCase type, camelCase cases
- **Acronyms**: 2글자 대문자 유지(`HRV`, `UI`), 3글자+ camelCase(`Hrv` 금지, `HRV` 유지)

## File Organization

```
DUNE/
├── App/              # @main, ContentView, ModelContainer setup
├── Domain/           # Models, UseCases, Services (Foundation + HealthKit only)
├── Data/             # HealthKit queries, SwiftData extensions
└── Presentation/
    ├── Shared/       # Extensions, Components, Models(DTO)
    ├── Today/        # Dashboard tab
    ├── Train/        # Activity/Exercise tab
    ├── Wellness/     # Wellness tab
    └── Settings/     # Settings tab
```

- Feature별 그룹핑 (by feature, not by type)
- View + ViewModel은 같은 feature 폴더에 배치
- 공유 컴포넌트는 `Presentation/Shared/`

## Import Order

1. `Foundation` / `SwiftUI` / `HealthKit` (Apple frameworks)
2. `SwiftData` / `Observation` (Apple frameworks, secondary)
3. Internal modules (같은 타겟 내 파일은 import 불필요)

**Layer import 규칙**: `.claude/rules/swift-layer-boundaries.md` 참조

## Error Handling

- Domain/Service: `throws` + typed error enum. Silent `guard...return` 금지
- ViewModel: `validationError: String?` 프로퍼티로 UI에 전달
- View: `@State private var errorMessage: String?` + `.alert()`
- HealthKit: `do/catch` + partial failure 보고 ("N of M sources")
- `try?` 사용 시 주석으로 왜 에러를 무시하는지 명시

## Async Patterns

- 독립 쿼리 2-3개: `async let`
- 독립 쿼리 4개+: `withThrowingTaskGroup`
- Cancel-before-spawn: `reloadTask?.cancel()` → 새 Task 할당
- `guard !Task.isCancelled` 후 state 업데이트
- Void async: `defer { isLoading = false }` 허용
- Returning func: `defer` 금지, 명시적 리셋

## Swift 6 Concurrency

- Strict concurrency checking enabled — `Sendable` 준수 필수
- `@MainActor` class: 모든 프로퍼티/메서드가 자동으로 MainActor isolated
- `nonisolated` 명시: MainActor class에서 non-isolated 접근이 필요한 computed property에 사용
- `@Sendable` closure: `Task { }` 내부에서 캡처하는 값은 Sendable이어야 함
- `withThrowingTaskGroup` 내 `addTask`에서 actor-isolated 프로퍼티 직접 접근 금지 → capture list 사용

## #Preview Patterns

```swift
// Basic view preview with NavigationStack wrapper
#Preview {
    NavigationStack {
        SettingsView()
    }
}

// Named preview for component variants
#Preview("50%") {
    ActivityRingView(progress: 0.5, ringColor: DS.Color.activity, size: 100)
}

// Preview with SwiftData model container
#Preview {
    ActivityView()
        .modelContainer(for: [ExerciseRecord.self, WorkoutSet.self], inMemory: true)
}

// Component preview in parent context
#Preview {
    Form {
        NotificationSettingsSection()
    }
}
```

- View마다 최소 1개 `#Preview` 필수
- 복수 상태(empty, loaded, error)는 named preview로 분리: `#Preview("Empty") { ... }`
- SwiftData 의존 View는 `inMemory: true` container 제공
- 독립 component는 부모 context(Form, List, NavigationStack) 래핑

## SwiftUI Patterns

- 상세 패턴: `.claude/rules/swiftui-patterns.md` 참조
- 성능 패턴: `.claude/rules/performance-patterns.md` 참조

## Comments

- 코드 주석은 영어로 작성
- 로직이 self-evident하면 주석 불필요
- **필수 주석 대상**: 정렬 방향 명시 (`// oldest-first`), CloudKit 스키마 계약, rawValue rename 위험 경고
- TODO format: `// TODO: {description} — {context}`

## Function/Method Design

- ViewModel public API: `loadData()`, `createValidatedRecord() -> Record?`
- View에서 호출하는 computed property: service 호출 금지, stored property 사용
- 동일 로직 3곳 이상 중복 시 즉시 추출 (같은 파일 내 2개 struct도 추출)
