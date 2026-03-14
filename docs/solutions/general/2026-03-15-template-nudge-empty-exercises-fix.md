---
tags: [template, nudge, recommendation, prefill, bug-fix, TemplateExerciseResolver]
date: 2026-03-15
category: general
status: implemented
---

# Fix: 템플릿 넛지 → 저장 시 운동 목록 비어있는 버그

## Problem

"나의 루틴" 넛지 카드(Dashboard) 또는 추천 루틴 bookmark(Activity)에서 "템플릿으로 저장"을 선택하면
`TemplateFormView`가 `Exercises (0)`으로 열림.

**근본 원인**: `DashboardView`와 `ActivityView`에서 `TemplateFormView(prefillName:prefillEntries:)` 호출 시
`prefillEntries: []`를 하드코딩. `WorkoutTemplateRecommendation`의 운동 시퀀스를 `[TemplateEntry]`로
변환하는 로직이 누락되어 있었음.

## Solution

기존 `TemplateExerciseResolver.resolveExercises(from:library:)` + `defaultEntry(for:)` 체인을
두 View의 `.sheet` closure에서 호출하여 recommendation → entries 변환 수행.

```swift
// Before
prefillEntries: []

// After
prefillEntries: TemplateExerciseResolver.resolveExercises(
    from: nudge,
    library: library
)?.map { TemplateExerciseResolver.defaultEntry(for: $0) } ?? []
```

`DashboardView`에는 `library` 참조가 없었으므로 `private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared` 추가. (`ActivityView`는 이미 보유.)

### 변경 파일

| 파일 | 변경 |
|------|------|
| `DUNE/Presentation/Dashboard/DashboardView.swift` | library 참조 추가 + prefillEntries 변환 |
| `DUNE/Presentation/Activity/ActivityView.swift` | prefillEntries 변환 |

## Prevention

- **pre-fill init을 사용하는 sheet 연결 시** 데이터 변환 로직이 실제로 호출되는지 확인
- `resolveExercises`가 nil을 반환할 수 있으므로 `?? []` fallback 필수
- 동일 패턴이 여러 View에 분산되면 ViewModel로 승격 고려 (현재 2곳)

## Lessons Learned

- UI에서 데이터 모델 간 변환 로직이 필요할 때 기존 Resolver/Builder를 먼저 검색할 것
- `TemplateExerciseResolver`에 이미 `resolveExercises(from:library:)` 메서드가 존재했지만 연결만 빠져있었음
- pre-fill init이 있는 View는 호출 측에서 실제 데이터를 전달하는지 검증 필요
