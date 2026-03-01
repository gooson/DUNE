# Testing Required

## 필수 테스트 작성 규칙

코드 변경 시 다음 조건에 해당하면 **반드시** 유닛 테스트를 함께 작성합니다.

### 테스트 필수 대상

| 변경 유형 | 테스트 요구사항 |
|-----------|----------------|
| 새 UseCase 추가 | `{UseCase}Tests.swift` 생성 (모든 분기) |
| 새 ViewModel 추가 | `{ViewModel}Tests.swift` 생성 (validation, state) |
| 새 Model 추가 | `{Model}Tests.swift` 생성 (init, computed properties) |
| 기존 로직 변경 | 해당 테스트 파일에 변경 사항 반영 |
| 수학/통계 로직 | 경계값, 0, 음수, NaN 케이스 포함 |

### 테스트 면제 대상

- SwiftUI View body (UI 테스트로 대체)
- 단순 저장 프로퍼티 getter/setter
- HealthKit 실제 쿼리 (시뮬레이터 제한)
- SwiftData CRUD (integration test 영역)

### 테스트 작성 기준

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`)
- Pattern: Arrange / Act / Assert
- Location: `DUNE/DUNETests/`
- Naming: `{TargetType}Tests.swift`
- 상세 패턴: `.claude/skills/testing-patterns/SKILL.md` 참조

### 검증 명령

```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing DUNETests -quiet
```
