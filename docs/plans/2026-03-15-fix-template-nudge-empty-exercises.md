---
tags: [template, nudge, recommendation, prefill, bug-fix]
date: 2026-03-15
category: plan
status: approved
---

# Fix: 템플릿 넛지 → 저장 시 운동 목록 비어있는 버그

## Problem

"나의 루틴" 넛지 카드 또는 Activity 탭 추천 루틴에서 "템플릿으로 저장"을 선택하면
`TemplateFormView`가 열리지만 운동 목록이 비어있음 (`Exercises (0)`).

## Root Cause

`DashboardView.swift:306`과 `ActivityView.swift:350`에서 `TemplateFormView`의
pre-fill init을 호출할 때 `prefillEntries: []`를 하드코딩하고 있음.

`WorkoutTemplateRecommendation`의 `sequenceTypes`/`sequenceLabels`를
`[TemplateEntry]`로 변환하는 로직이 누락됨.

## Solution

`TemplateExerciseResolver.resolveExercises(from:library:)` → `defaultEntry(for:)` 체인을 사용하여
recommendation의 운동 시퀀스를 `[TemplateEntry]`로 변환 후 `prefillEntries`에 전달.

## Affected Files

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 수정 | library 참조 추가 + prefillEntries 변환 로직 |
| `DUNE/Presentation/Activity/ActivityView.swift` | 수정 | prefillEntries 변환 로직 |

## Implementation Steps

### Step 1: DashboardView 수정

1. `ExerciseLibraryService.shared` 참조 추가 (`private let library`)
2. `.sheet(item: $templateNudgeToSave)` 내부에서 `TemplateExerciseResolver.resolveExercises(from:library:)`로 운동 해석
3. 결과를 `.map { TemplateExerciseResolver.defaultEntry(for: $0) }`로 변환
4. `prefillEntries`에 변환된 entries 전달

### Step 2: ActivityView 수정

1. 이미 `library` 참조가 존재 (확인 필요)
2. 동일한 변환 로직 적용

## Test Strategy

- 기존 `TemplateExerciseResolverTests`에서 `resolveExercises` 커버리지 확인
- 수동 검증: 넛지 카드 → "템플릿으로 저장" → 운동 목록 확인

## Risks

- `resolveExercises`가 nil 반환 시 (운동 매칭 실패) → 빈 배열 fallback (현재와 동일 동작)
- DashboardView에 library 의존성 추가 → 최소 침습 (`private let` 1줄)

## Edge Cases

- 추천 운동이 library에서 찾을 수 없는 경우 → 빈 entries로 fallback (graceful degradation)
- 추천 운동이 1개인 경우 → 정상 동작 (1개 entry로 pre-fill)
