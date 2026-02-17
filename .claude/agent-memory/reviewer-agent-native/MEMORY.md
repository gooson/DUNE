# Agent-Native Reviewer Memory

## Project: Health/Dailve iOS App

### Architecture Patterns
- Swift 6 / SwiftUI / HealthKit / SwiftData
- Clean architecture: Domain → Data ← Presentation
- ViewModels use `@Observable` + `@MainActor`
- Protocol-based service injection (all protocols marked `Sendable`)
- ModelContext operations performed in View layer only

### Validation Patterns
- ViewModels expose `createValidatedRecord() -> Record?`
- Validation errors stored in `validationError: String?`
- `isSaving` flag prevents duplicate operations
- Input validation uses domain-specific ranges

### Error Handling
- Service protocols return throwing functions
- ViewModels catch errors and expose `errorMessage: String?`
- Parallel HealthKit queries use `async let` (2-3 queries) or `withThrowingTaskGroup` (4+)
- Task cancellation checked via `guard !Task.isCancelled`

### Common Issues to Watch
1. Missing Task cancellation before spawning new Task
2. State updates after Task.isCancelled (breaks loading indicators)
3. JSON decoding without fallback (crashes on malformed data)
4. Protocol dependency injection missing in ViewModels
5. SwiftData migration failures without recovery strategy
