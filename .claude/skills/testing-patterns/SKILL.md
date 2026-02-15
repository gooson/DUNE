---
name: testing-patterns
description: "테스트 작성 패턴과 커버리지 기대치. 테스트 관련 작업 시 자동으로 참조됩니다."
---

# Testing Patterns

## Test Structure

- Pattern: Arrange / Act / Assert (AAA)
- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- Location: `DailveTests/` (unit), `DailveUITests/` (UI)
- File naming: `{TargetType}Tests.swift` (예: `CalculateConditionScoreUseCaseTests.swift`)

## Required Imports

```swift
import Foundation
import Testing
@testable import Dailve
```

ViewModel 테스트는 `@MainActor` 추가:
```swift
@Suite("SomeViewModel")
@MainActor
struct SomeViewModelTests { ... }
```

## Test Types

### Unit Tests
- **Framework**: Swift Testing
- **Coverage target**: Domain UseCases 100%, ViewModel validation 100%
- **Run command**: `xcodebuild test -project Dailve.xcodeproj -scheme DailveTests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DailveTests -quiet`

### UI Tests
- **Framework**: XCTest
- **Coverage target**: Critical user flows (launch, navigation)
- **Run command**: `xcodebuild test -project Dailve.xcodeproj -scheme DailveUITests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DailveUITests -quiet`

## Mocking Strategy

- **Protocol-based DI**: 모든 서비스는 프로토콜로 추상화 (`HRVQuerying`, `SleepQuerying` 등)
- **Mock 구현**: 테스트 파일 내 `struct Mock{Service}: {Protocol}` 패턴

```swift
struct MockHRVService: HRVQuerying {
    var samplesResult: [HRVSample] = []
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samplesResult }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
}
```

- **UseCase mocking**: `ConditionScoreCalculating`, `SleepScoreCalculating` 프로토콜 사용

## What to Test

### Always Test (필수)
- **Domain UseCase**: 모든 분기, 경계값, 에러 케이스
- **ViewModel validation**: `createValidatedRecord()`, `validateInputs()` 전체 분기
- **Model init**: 클램핑, 상태 매핑
- **수학 방어**: log(0), division by zero, NaN/Infinity 처리

### Test per Category

| 카테고리 | 테스트 대상 | 예시 |
|----------|------------|------|
| UseCase | execute() 전체 분기 | 충분한 데이터, 불충분, 빈 배열, 0값 |
| ViewModel | 유효성 검증 | 범위 초과, 빈 입력, 정상 입력, isSaving 가드 |
| Model | init 로직 | score 클램핑, status 매핑, 경계값 |
| Extension | 포맷팅 | formattedValue, formattedChange |

### Don't Test (불필요)
- SwiftUI View body (UI 테스트로 대체)
- HealthKit 실제 쿼리 (시뮬레이터 제한)
- SwiftData CRUD (integration test 영역)
- 단순 저장 프로퍼티 getter/setter

## Naming Convention

```swift
@Suite("CalculateConditionScoreUseCase")
struct CalculateConditionScoreUseCaseTests {
    @Test("Returns nil score when insufficient days")
    func insufficientDays() { ... }

    @Test("Score is clamped to 0-100")
    func scoreClamped() { ... }
}
```

- `@Suite`: 테스트 대상 타입명
- `@Test`: 자연어로 기대 동작 설명
- func 이름: camelCase 축약

## Parameterized Tests

```swift
@Test("Score is clamped between 0 and 100", arguments: [-10, 0, 50, 100, 150])
func scoreClamping(input: Int) {
    let score = ConditionScore(score: input)
    #expect(score.score >= 0 && score.score <= 100)
}
```

## New Code Checklist

코드 작성 시 다음 테스트를 함께 작성:

1. **새 UseCase** → `{UseCase}Tests.swift` (모든 분기)
2. **새 ViewModel** → `{ViewModel}Tests.swift` (validation, state transitions)
3. **새 Model** → 기존 `{Model}Tests.swift`에 추가 (init, computed properties)
4. **기존 로직 변경** → 해당 테스트 파일에 변경 사항 반영
