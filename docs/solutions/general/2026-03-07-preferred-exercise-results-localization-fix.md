---
tags: [localization, xcstrings, quick-start, preferred-exercises, LocalizedStringKey, settings]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift
  - DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-07-preferred-exercise-quick-start-parity.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
  - docs/solutions/general/localization-gap-audit.md
---

# Solution: Preferred Exercise Results Header Localization Fix

## Problem

선호 운동 기능을 추가한 뒤, 검색 상태에서 보이는 `"Results"` 헤더가 다국어 경로를 우회하고 있었다.

### Symptoms

- iPhone Quick Start의 전체 운동 화면에서 검색 시 `"Results"`가 영어로 고정될 수 있었다.
- `Preferred Exercises` 화면 검색 결과 섹션도 같은 방식으로 영어가 노출될 수 있었다.
- 같은 패턴이 `Exercise Defaults` 화면에도 남아 있어 동일 누출이 반복될 수 있었다.

### Root Cause

- `Text(searchText.isEmpty ? "All Exercises" : "Results")` 와 `Section(searchText.isEmpty ? "All Exercises" : "Results")` 는 ternary 결과가 `String` 으로 평가되어 `LocalizedStringKey` lookup을 타지 않았다.
- `"Results"` 키가 `Shared/Resources/Localizable.xcstrings`에 등록되지 않아, 코드 경로를 바로잡더라도 번역 데이터는 여전히 비어 있는 상태였다.

## Solution

동적 헤더를 `LocalizedStringKey` 기반 computed property로 분리하고, 누락된 string catalog 키를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | `quickStartAllSectionTitle: LocalizedStringKey` 추가 후 header에서 사용 | Quick Start 검색 결과 헤더가 localization key 경로를 타도록 수정 |
| `DUNE/Presentation/Settings/Components/PreferredExercisesListView.swift` | `allExercisesSectionTitle: LocalizedStringKey` 추가 | 선호 운동 화면의 검색 결과 섹션 누출 제거 |
| `DUNE/Presentation/Settings/Components/ExerciseDefaultsListView.swift` | 동일한 `LocalizedStringKey` 패턴 적용 | 같은 anti-pattern의 재발 제거 |
| `Shared/Resources/Localizable.xcstrings` | `"Results"` 키의 ko/ja 번역 추가 | 새 헤더 문자열의 번역 완결성 확보 |

### Key Code

```swift
private var allExercisesSectionTitle: LocalizedStringKey {
    searchText.isEmpty ? "All Exercises" : "Results"
}

Section(allExercisesSectionTitle) {
    ...
}
```

## Prevention

상태에 따라 바뀌는 SwiftUI 헤더/레이블은 ternary `String` 표현식으로 직접 넘기지 않는다. `LocalizedStringKey` 타입 프로퍼티 또는 명시적 분기문으로 분리하고, 동시에 `.xcstrings` 키 존재 여부를 확인한다.

### Checklist Addition

- [ ] `Text(...)` / `Section(...)` 의 인자가 ternary/보간 결과 `String` 으로 내려가지 않는지 확인
- [ ] 상태 기반 헤더는 `LocalizedStringKey` computed property 또는 explicit localized branch로 분리
- [ ] 새 화면 문자열 추가 시 code path와 `Localizable.xcstrings`를 한 쌍으로 검증
- [ ] 리뷰에서 localization leak를 잡으면 같은 feature 범위의 인접 화면도 grep으로 같이 점검

### Rule Addition (if applicable)

신규 rule 추가는 불필요했다. 기존 `.claude/rules/localization.md` 와 기존 localization solution 문서가 이미 이 패턴을 설명하고 있었고, 이번 문서는 해당 규칙의 실제 재발 사례를 보강하는 역할로 충분하다.

## Lessons Learned

SwiftUI 문자열 리터럴은 안전하지만, 상태 분기식이 끼는 순간 쉽게 `StringProtocol` 경로로 떨어진다. 새 기능 화면 하나에서 발견된 localization leak는 인접 화면에도 같은 형태로 복제돼 있을 가능성이 높아서, 리뷰에서 발견하면 같은 패턴을 바로 grep으로 확장 점검하는 편이 효율적이다.
