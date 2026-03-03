---
tags: [swift, memberwise-init, template-workout, unit-test, ci-build]
category: testing
date: 2026-03-03
severity: minor
related_files: [DUNETests/TemplateWorkoutTests.swift, DUNE/Domain/Models/TemplateWorkoutConfig.swift]
related_solutions: [docs/solutions/testing/2026-03-01-memberwise-init-test-sync.md]
---

# Solution: TemplateWorkoutConfig memberwise init 변경에 맞춘 테스트 동기화

## Problem

### Symptoms

- GitHub Actions `unit-tests` 잡에서 `TemplateWorkoutTests.swift` 컴파일 실패
- 에러:
  - `extra argument 'entries' in call`
  - `missing argument for parameter 'templateEntries' in call`
  - `argument 'exercises' must precede argument 'templateEntries'`

### Root Cause

`TemplateWorkoutConfig`의 stored property가 `entries`에서 `templateEntries`로 변경되었고,
memberwise initializer의 인자 순서가 `templateName, exercises, templateEntries`로 고정되어 있는데
테스트 코드가 이전 시그니처(`entries`)와 순서를 계속 사용하고 있었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/TemplateWorkoutTests.swift` | `entries:` -> `templateEntries:`로 변경 | 최신 memberwise initializer label 동기화 |
| `DUNETests/TemplateWorkoutTests.swift` | 인자 순서를 `exercises` 다음 `templateEntries`로 정렬 | Swift memberwise initializer 순서 요구사항 충족 |
| `DUNETests/TemplateWorkoutTests.swift` | `config.entries.count` -> `config.templateEntries.count`로 변경 | 모델 필드명과 테스트 assertion 동기화 |

### Key Code

```swift
let config = TemplateWorkoutConfig(
    templateName: "Push Day",
    exercises: exercises,
    templateEntries: entries
)
#expect(config.templateEntries.count == 2)
```

## Prevention

### Checklist Addition

- [ ] struct stored property rename/addition 시, 해당 타입의 테스트 생성 코드(memberwise init 호출)를 `label + argument order`까지 함께 점검
- [ ] CI 컴파일 에러가 `extra argument/missing argument` 조합이면, 모델 시그니처 변경 여부를 우선 확인

### Rule Addition (if applicable)

기존 Correction Log의 memberwise init/필드 동기화 관련 항목으로 커버 가능하여 신규 규칙 추가는 생략.

## Lessons Learned

- Swift memberwise initializer는 파라미터 이름뿐 아니라 선언 순서까지 컴파일에 영향을 준다.
- 테스트가 실행되기 전 컴파일 단계에서 실패하므로, 작은 모델 시그니처 변경도 CI 전체를 즉시 막을 수 있다.
