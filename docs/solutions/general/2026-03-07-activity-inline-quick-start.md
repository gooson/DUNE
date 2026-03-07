---
tags: [ios, activity-tab, quick-start, templates, search, swiftui, localization]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/Components/ActivityQuickStartSection.swift
  - DUNE/Presentation/Exercise/Components/ExercisePickerView.swift
  - DUNE/Presentation/Exercise/Components/QuickStartSupport.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - 2026-02-26-quickstart-ia-usage-tracking-consistency.md
  - 2026-03-07-exercise-variant-canonical-dedup.md
---

# Solution: Activity 탭 인라인 Quick Start 노출

## Problem

Activity 탭에서 Quick Start를 시작하려면 항상 toolbar의 `+`를 눌러 sheet로 진입해야 했고, 템플릿 운동은 첫 화면에 보이지 않았습니다. 검색도 picker 내부에서만 사용할 수 있어서, Activity 탭에서 바로 운동을 시작하는 흐름이 끊겼습니다.

### Symptoms

- Activity 탭에서 템플릿 운동을 바로 시작할 수 없음
- Quick Start 검색창이 Activity 탭 landing 화면에 없어서 `+` 탭이 추가로 필요함
- Quick Start 검색/정렬/canonical dedup 로직이 picker 내부에만 있어 다른 진입점으로 재사용하기 어려움

### Root Cause

- iPhone Quick Start IA가 sheet 기반 picker에 묶여 있었고 Activity 본문에는 인라인 진입면이 없었음
- 템플릿 노출이 `WorkoutTemplateListView` 네비게이션에만 존재했음
- 검색 helper와 canonical dedup 로직이 `ExercisePickerView`에만 들어 있어 Activity 본문과 공유되지 않았음
- `"Search exercises"` 키가 `Localizable.xcstrings`에 없어 새 인라인 검색 UI에 그대로 쓰면 번역 누출이 발생함

## Solution

Activity 탭 최상단에 인라인 Quick Start 섹션을 추가하고, 기존 picker도 동일한 정보구조로 정렬했습니다. 검색/canonical dedup helper는 공용 파일로 추출해 Activity와 picker가 같은 우선순위와 검색 결과를 사용하도록 맞췄습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | Activity 최상단에 Quick Start 섹션 추가, 템플릿 시작 경로 연결 | `+` 없이 템플릿/검색/운동 시작 가능하게 하기 위해 |
| `DUNE/Presentation/Activity/Components/ActivityQuickStartSection.swift` | 인라인 검색창, 템플릿 strip, Popular/Recent, 검색 결과 UI 추가 | Activity landing에서 바로 Quick Start를 제공하기 위해 |
| `DUNE/Presentation/Exercise/Components/ExercisePickerView.swift` | Quick Start 모드에서 검색창 상시 노출, 템플릿 섹션 추가, 공용 helper 사용 | sheet 진입 시에도 동일한 IA를 유지하기 위해 |
| `DUNE/Presentation/Exercise/Components/QuickStartSupport.swift` | 검색/초성 매칭/canonical dedup/우선순위 정렬 helper 추출 | Activity와 picker의 결과 일관성을 보장하기 위해 |
| `Shared/Resources/Localizable.xcstrings` | `"Search exercises"` 번역 추가 | 인라인/picker 검색 placeholder의 localization leak 방지 |

### Key Code

```swift
SectionGroup(title: "Quick Start", icon: "bolt.fill", iconColor: DS.Color.activity) {
    ActivityQuickStartSection(
        library: library,
        recentExerciseIDs: recentExerciseIDs,
        popularExerciseIDs: popularExerciseIDs,
        onStartExercise: { exercise in selectedExercise = exercise },
        onStartTemplate: { template in startFromTemplate(template) },
        onBrowseAll: { showingExercisePicker = true }
    )
}
```

```swift
private var filteredExercises: [ExerciseDefinition] {
    let sorted = QuickStartSupport.sortQuickStartExercises(
        QuickStartSupport.uniqueByID(definitions),
        priorityIDs: popularExerciseIDs + recentExerciseIDs
    )
    return QuickStartSupport.uniqueByCanonical(sorted)
}
```

## Prevention

### Checklist Addition

- [ ] landing 화면에 검색 진입면을 추가할 때 unrelated loading state 뒤에 숨지지 않는지 확인
- [ ] Quick Start 노출면이 2개 이상이면 search/canonical dedup helper를 공용화했는지 확인
- [ ] 새 placeholder/section label 추가 시 `Localizable.xcstrings` 번역을 함께 추가했는지 확인

### Rule Addition (if applicable)

신규 rule 추가는 보류. 이번 건은 Quick Start IA/Localization 체크리스트로 관리합니다.

## Lessons Learned

- Quick Start처럼 행동 전환이 빠른 UI는 sheet 내부보다 landing 화면에 직접 노출될 때 체감 마찰이 크게 줄어든다.
- 검색과 dedup 기준이 picker 내부 로컬 구현에 머물면 새 진입면을 추가할 때 결과 불일치가 쉽게 생긴다.
- SwiftUI 문자열 리터럴은 key 존재 여부까지 같이 점검해야 실제 localization 품질이 확보된다.
