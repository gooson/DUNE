---
tags: [life-tab, habit, auto-achievement, auto-link, routing, ux]
date: 2026-03-22
category: plan
status: draft
---

# Plan: 운동 자동 입력 업적 → Auto Achievements 섹션 라우팅 + 삭제

## Problem Statement

현재 "Auto-complete from workouts" 토글을 켠 습관을 생성하면 "My Habits" 섹션에 추가된다.
사용자 기대: 이런 습관은 "Auto Workout Achievements" 섹션에 표시되어야 하고, 삭제도 가능해야 한다.

## Current Architecture

1. **My Habits** 섹션: `HabitDefinition` 모델 기반, `@Query`로 조회, 수동/자동 구분 없이 모두 표시
2. **Auto Workout Achievements** 섹션: `LifeAutoAchievementService`의 9개 하드코딩된 규칙 (Rule enum), 삭제 불가
3. `isAutoLinked` + `autoLinkSourceRaw == "exercise"` 습관은 `calculateProgresses()`에서 `todayExerciseExists` 기반 자동 완료 표시

## Design

### 접근법: Auto-linked 습관을 My Habits에서 숨기고, Auto Achievements 섹션의 "Custom Goals" 그룹으로 표시

#### LifeView 변경

1. **My Habits 필터링**: `filteredProgresses`에서 `isAutoLinked` 습관 제외
2. **Auto Achievements에 Custom Goals 그룹 추가**: auto-linked 습관을 별도 그룹으로 렌더링
3. **삭제 기능**: Custom Goals 그룹의 항목에 swipe-to-delete 또는 context menu 삭제 버튼

#### ViewModel 변경

1. `autoLinkedProgresses` computed property 추가 — `isAutoLinked == true`인 `HabitProgress` 필터
2. 삭제 시 `modelContext.delete(habit)` + `cancelPendingReminders` 호출 (View에서 처리)

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | `filteredProgresses`에서 auto-linked 제외, `autoAchievementsSection`에 Custom Goals 그룹 추가, 삭제 UI | 핵심 라우팅 변경 |
| `DUNE/Presentation/Life/LifeViewModel.swift` | `autoLinkedProgresses` computed property | Auto-linked 습관 분리 |
| `Shared/Resources/Localizable.xcstrings` | 새 문자열 번역 추가 | L10N |

## Implementation Steps

### Step 1: ViewModel — autoLinkedProgresses 추가

`LifeViewModel`에 `autoLinkedProgresses` computed property 추가:
```swift
var autoLinkedProgresses: [HabitProgress] {
    habitProgresses.filter(\.isAutoLinked)
}
```

### Step 2: LifeView — My Habits에서 auto-linked 제외

`filteredProgresses`에서 `isAutoLinked == false` 필터 추가:
```swift
private var filteredProgresses: [HabitProgress] {
    let base = viewModel.habitProgresses.filter { !$0.isAutoLinked }
    guard let filter = selectedCategoryFilter else { return base }
    return base.filter { $0.iconCategory == filter }
}
```

### Step 3: LifeView — Auto Achievements에 Custom Goals 그룹 추가

`autoAchievementsSection`에서 기존 하드코딩 그룹 뒤에 사용자 정의 auto-linked 습관을 custom 그룹으로 표시.
각 항목에 삭제 가능한 UI 제공 (context menu + confirmationDialog).

### Step 4: Localization

새 문자열을 `Localizable.xcstrings`에 en/ko/ja 추가.

## Test Strategy

- `LifeViewModelTests`: `autoLinkedProgresses` 필터링 검증
- 수동 확인: auto-linked 습관이 My Habits에서 사라지고 Auto Achievements에 나타나는지
- 삭제 후 해당 습관이 완전히 제거되는지

## Risks & Edge Cases

1. **기존 auto-linked 습관**: 이미 My Habits에 있던 auto-linked 습관들이 자동으로 Auto Achievements로 이동
2. **Hero section 진행률**: auto-linked 습관의 완료 상태가 hero ring에서 어떻게 카운트되는지 확인 필요
3. **빈 상태**: auto-linked 습관만 있고 일반 습관이 없는 경우 My Habits empty state 표시
