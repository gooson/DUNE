---
tags: [ui-test, e2e, exercise-picker, accessibility-identifier, seeded-fixture, swiftui, selector-contract]
category: testing
date: 2026-03-09
severity: important
related_files:
  - DUNE/App/TestDataSeeder.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - docs/plans/2026-03-09-e2e-exercise-picker-view.md
  - todos/045-done-p2-e2e-dune-exercise-picker-view.md
related_solutions:
  - docs/solutions/testing/2026-03-08-e2e-phase1-test-infrastructure.md
  - docs/solutions/testing/2026-03-08-e2e-phase3-activity-exercise-regression-hardening.md
  - docs/solutions/testing/2026-03-09-e2e-musclemap-3d-simulator-safe-testing.md
---

# Solution: Exercise Picker Surface Contract for E2E

## Problem

`ExercisePickerView`는 Activity quick start와 template form full picker를 동시에 담당하지만, 기존 회귀 커버리지는 open/search smoke 수준에 머물러 있었다.
이 상태에서는 TODO 046 이후 exercise flow 작업이 picker surface를 간접 경로로만 검증하게 되고, section/filter/template lane이 깨져도 늦게 발견된다.

### Symptoms

- quick start hub의 recent/preferred/popular/templates/all lane을 직접 검증하는 full regression이 없었다.
- full picker의 category/user-category/muscle/equipment filter 조합을 deterministic하게 확인할 selector inventory가 부족했다.
- 템플릿/유저 카테고리 selector를 이름 기반으로 만들면 non-ASCII 이름이나 중복 이름에서 AXID 충돌 위험이 있었다.
- UI 런타임은 CoreSimulatorService 장애로 막혀 있었기 때문에, 최소한 build-for-testing 기준의 surface contract를 더 명확히 잡아둘 필요가 있었다.

### Root Cause

picker를 공용 component로 쓰고 있었지만, 테스트 관점에서는 surface contract가 명시적으로 정의되어 있지 않았다.
특히 quick start와 full 모드가 같은 뷰를 공유하는데도 mode별 section/action/filter anchor가 부족했고, seeded fixture와 selector 규약도 한 번에 고정되지 않았다.

## Solution

picker를 하나의 공용 E2E surface로 보고, quick start lane과 full lane을 각각 안정 selector와 dedicated regression으로 고정했다.
또한 mutable name 기반 token 대신 model UUID 기반 AXID를 사용하고, seeded scenario에는 고정 UUID를 주어 selector 충돌과 flakiness를 줄였다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | section/filter/template/action AXID 추가 | quick start/full picker state를 locale-safe selector로 검증하기 위해 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | template/user-category AXID를 UUID 기반으로 전환 | non-ASCII/중복 이름에서 identifier 충돌을 막기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | picker surface constants 확장 | 새 selector를 테스트 코드에서 중앙 관리하기 위해 |
| `DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift` | quick start hub/detail/template lane + full picker filter/select lane 추가 | TODO 045를 전용 regression으로 고정하기 위해 |
| `DUNE/App/TestDataSeeder.swift` | user category/template seeded fixture에 고정 UUID 부여 | UUID 기반 AXID를 UI 테스트에서 deterministic하게 참조하기 위해 |
| `todos/045-done-p2-e2e-dune-exercise-picker-view.md` | backlog item을 done으로 전환 | surface contract와 regression 추가를 backlog에 반영하기 위해 |

### Key Code

```swift
private func templateRowIdentifier(_ template: WorkoutTemplate) -> String {
    "picker-template-\(template.id.uuidString.lowercased())"
}

private func userCategoryChipIdentifier(_ userCategory: UserCategory) -> String {
    "picker-filter-user-category-\(userCategory.id.uuidString.lowercased())"
}
```

```swift
let category = UserCategory(
    name: "Codex Mobility",
    iconName: "figure.cooldown",
    colorHex: "34C759",
    defaultInputType: .durationIntensity,
    sortOrder: 0
)
category.id = UUID(uuidString: activityExerciseCategoryID) ?? category.id
```

## Prevention

picker처럼 재사용되는 selection surface는 화면이 아니라 contract로 관리해야 한다.
section/action/filter/template row마다 selector inventory를 먼저 고정하고, user-generated name을 AXID key로 재사용하지 않는 것이 중요하다.

### Checklist Addition

- [ ] 공용 picker/sheet surface에 quick start lane과 full lane이 섞여 있다면 mode별 anchor selector를 각각 고정했는가?
- [ ] user-generated name이나 localized copy를 AXID key로 직접 쓰지 않고, UUID 등 stable identifier를 사용했는가?
- [ ] seeded UI scenario가 stable selector 값을 직접 재현할 수 있도록 deterministic fixture ID를 부여했는가?
- [ ] smoke test와 deeper regression lane을 분리해 PR gate와 nightly 범위를 명확히 나눴는가?
- [ ] simulator runtime이 불안정할 때도 `build-for-testing`으로 test target compile 증빙을 남겼는가?

### Rule Addition (if applicable)

새 rules 파일 추가는 보류한다.
다만 이후 picker/selector 작업에서는 "이름 기반 token보다 model identifier를 우선한다"는 기준을 계속 적용한다.

## Lessons Learned

이번 작업의 핵심은 테스트 코드보다 surface contract를 먼저 명시하는 것이었다.
quick start와 full picker가 같은 뷰를 공유하더라도, E2E 관점에서는 lane별 anchor를 따로 잡아야 회귀가 읽기 쉬워진다.

또한 UI 테스트 selector는 사람이 읽기 쉬운 slug보다 충돌하지 않는 식별자가 더 중요했다.
이름 기반 AXID는 처음엔 편하지만, user-generated 데이터와 localization이 들어오는 순간 바로 불안정해진다.

마지막으로, CoreSimulatorService가 깨진 환경에서도 app build와 `build-for-testing`을 따로 확보해 두면 "테스트가 못 돌았다"가 아니라 "코드는 컴파일되고 런타임만 외부 환경에 막혔다"는 근거를 남길 수 있었다.
