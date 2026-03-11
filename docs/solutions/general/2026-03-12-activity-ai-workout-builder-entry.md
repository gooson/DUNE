---
tags: [activity-tab, ai-workout-builder, template-form, navigation, ui-test]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - docs/solutions/general/2026-03-07-activity-inline-quick-start.md
  - docs/solutions/architecture/2026-03-07-activity-section-consolidation.md
  - docs/solutions/architecture/2026-03-09-natural-language-workout-template-generation.md
---

# Solution: Restore Activity entry for AI Workout Builder

## Problem

Activity 탭에서 자연어 운동 생성 기능이 사라진 것처럼 보였다. 실제 생성 UI인 `TemplateFormView`는 살아 있었지만,
Activity 탭의 `Suggested Workout` 섹션에는 추천 운동, 추천 루틴, 저장된 템플릿만 남아 있고
AI builder 화면으로 이동하는 entry가 없어졌다.

### Symptoms

- Activity 탭에서 자연어로 운동을 만들 수 있는 화면을 찾을 수 없다.
- 0.3.0 What's New는 `AI Workout Builder`를 `activity` 기능으로 소개하지만 실제 Activity 화면에서는 해당 진입점이 보이지 않는다.
- Exercise 탭의 template list를 거치면 생성 화면에 갈 수 있지만, Activity landing에서는 기능이 사라진 것처럼 느껴진다.

### Root Cause

원인은 Activity IA 변경 과정에서 template strip과 검색 surface는 남았지만,
`TemplateFormView` create mode로 연결되는 CTA가 Activity 계층에 다시 연결되지 않은 데 있었다.
즉 자연어 생성 자체의 구현 문제나 Foundation Models 문제는 아니고,
Activity 탭에서의 navigation contract가 끊긴 UI wiring 회귀였다.

## Solution

Activity의 `Suggested Workout` 섹션 안에 `AI Workout Builder` CTA를 직접 복원하고,
`ActivityView`가 `TemplateFormView()`를 sheet로 띄우도록 연결했다.
또한 UI regression test로 Activity entry → template form opening을 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/Components/SuggestedWorkoutSection.swift` | `AI Workout Builder` inline CTA와 callback 추가 | Activity landing에서 자연어 생성 진입점을 다시 보이게 하기 위해 |
| `DUNE/Presentation/Activity/ActivityView.swift` | `showingAIWorkoutBuilder` state + `TemplateFormView()` sheet presentation 추가 | CTA를 실제 create-mode template form으로 연결하기 위해 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | Activity CTA / template AI prompt AXID 추가 | 회귀 테스트가 안정적으로 surface를 찾게 하기 위해 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Activity CTA 탭 후 template form + AI prompt field 확인 테스트 추가 | entry가 다시 빠지는 회귀를 UI 레벨에서 막기 위해 |

### Key Code

```swift
private var aiWorkoutBuilderEntry: some View {
    Button(action: onOpenAIWorkoutBuilder) {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(DS.Color.activity)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("AI Workout Builder")
                    Text("Describe your ideal workout in natural language and get a ready-to-use template instantly.")
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
            }
        }
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("activity-ai-workout-builder")
}
```

```swift
.sheet(isPresented: $showingAIWorkoutBuilder) {
    TemplateFormView()
}
```

핵심은 "템플릿 생성 기능이 존재한다"와 "Activity에서 그 기능에 도달할 수 있다"를 같은 계약으로 보지 말고,
landing IA에서 entry 자체를 테스트로 잠근 점이다.

## Prevention

### Checklist Addition

- [ ] What's New나 release surface에서 특정 탭 기능으로 소개한 항목은 해당 탭 landing에서 실제 entry가 존재하는지 확인한다.
- [ ] section consolidation 후에도 이전 CTA가 다른 surface로 대체됐는지, 아니면 단순 누락됐는지 UI flow 기준으로 재확인한다.
- [ ] Activity/Exercise처럼 entry surface가 자주 바뀌는 영역은 "버튼 존재"가 아니라 "탭 후 도착 화면"까지 UI 테스트로 고정한다.

### Rule Addition (if applicable)

이번 건은 범용 rule까지는 올리지 않았다. Activity IA 변경 시 entry surface를 regression test로 잠그는 쪽이 더 적절했다.

## Lessons Learned

- 기능 회귀는 구현 삭제보다 "도달 경로 단절" 형태로 더 자주 발생한다.
- 추천/검색/템플릿 strip만 남겨 두면 사용자는 자연어 생성 기능이 살아 있어도 사라진 것으로 인식한다.
- release note에 노출한 핵심 기능은 landing screen entry까지 함께 검증해야 실제 사용자 체감과 맞는다.
