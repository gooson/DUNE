---
tags: [swift, testing, memberwise-init, template-workout, argument-order]
category: testing
date: 2026-03-04
severity: important
related_files:
  - DUNETests/TemplateWorkoutTests.swift
  - DUNE/Domain/Models/TemplateWorkoutConfig.swift
related_solutions:
  - docs/solutions/testing/2026-03-01-memberwise-init-test-sync.md
---

# Solution: TemplateWorkoutConfig memberwise init 변경으로 깨진 테스트 동기화

## Problem

`TemplateWorkoutConfig` 모델의 저장 프로퍼티명이 `entries`에서 `templateEntries`로 정리된 뒤, 테스트 호출부가 이전 인자명을 계속 사용해 iOS 테스트 빌드가 실패했다.

### Symptoms

- `DUNETests/TemplateWorkoutTests.swift` 컴파일 에러:
  - `extra argument 'entries' in call`
  - `missing argument for parameter 'templateEntries' in call`
  - `argument 'exercises' must precede argument 'templateEntries'`
- `config.entries` 접근 에러:
  - `value of type 'TemplateWorkoutConfig' has no member 'entries'`

### Root Cause

`TemplateWorkoutConfig`는 커스텀 이니셜라이저 없이 Swift memberwise initializer를 사용한다.  
테스트가 다음 두 조건을 동시에 놓쳤다:

1. 프로퍼티명 변경(`entries` -> `templateEntries`)
2. memberwise init 파라미터 순서(`templateName`, `exercises`, `templateEntries`)

## Solution

테스트 호출부와 assertion을 현재 모델 정의와 동일하게 맞췄다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNETests/TemplateWorkoutTests.swift` | `entries:` -> `templateEntries:` 치환 | 모델 인자명 변경 반영 |
| `DUNETests/TemplateWorkoutTests.swift` | 이니셜라이저 인자 순서 조정 | memberwise init 순서 요구사항 충족 |
| `DUNETests/TemplateWorkoutTests.swift` | `config.entries` -> `config.templateEntries` | 프로퍼티명 변경 반영 |

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

테스트에서 memberwise init을 직접 호출하는 경우, 모델 stored property 변경 시 테스트를 같은 커밋에서 동기화한다.

### Checklist Addition

- [ ] Struct stored property rename/add/remove 시 해당 모델의 테스트 호출부 인자명/순서를 함께 점검한다.

### Rule Addition (if applicable)

기존 교정 패턴(`memberwise-init test sync`)과 동일한 유형이므로 신규 rule 추가 없이 기존 solution 재참조로 충분하다.

## Lessons Learned

모델 리팩터링에서 컴파일 에러는 빠르게 잡히지만, 인자 순서까지 포함한 memberwise init 계약은 테스트가 먼저 깨지기 쉽다.  
모델 변경 PR에서는 “모델 선언 + 테스트 호출부”를 항상 쌍으로 검토해야 회귀를 줄일 수 있다.
