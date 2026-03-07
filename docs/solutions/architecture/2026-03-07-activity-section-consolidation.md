---
tags: [activity-tab, layout, search-integration, section-consolidation, swiftui]
date: 2026-03-07
category: solution
status: implemented
---

# Activity 탭 섹션 통합 및 Hero-First 레이아웃

## Problem

Activity 탭에서 QuickStart 섹션(검색+템플릿+인기/최근 운동)이 최상단을 차지하여
Hero Card(Training Readiness)가 스크롤 아래로 밀림. QuickStart의 가치 대비 화면 점유가 과도.

## Solution

### 섹션 재배치

```
Before: QuickStart → Hero+CTA → Recovery → Suggestion+Volume → Recent...
After:  Hero → Recovery → Suggestion(검색+템플릿 통합) → Volume → Recent...
```

### 핵심 변경

1. **Hero Card 최상단 이동** + CTA 버튼 제거
2. **QuickStart 섹션 삭제** (`ActivityQuickStartSection.swift` 삭제)
3. **SuggestedWorkoutSection에 검색+템플릿 통합**:
   - 상단 검색바 추가 (검색 중이면 추천 운동 카드를 검색 결과로 대체)
   - 하단 템플릿 스트립 + "All Exercises" 링크 추가
4. **iPad side-by-side 해제**: Suggested Workout + Training Volume 각각 full-width

### 성능 최적화

검색 로직을 `@State` + `.onChange` 캐싱으로 전환:

```swift
// BAD: computed property → 매 render마다 O(N log N) 정렬+필터
private var filteredExercises: [ExerciseDefinition] {
    // library.allExercises() + sort + unique...
}

// GOOD: @State 캐싱 + onChange 무효화
@State private var cachedFilteredExercises: [ExerciseDefinition] = []

.onChange(of: searchText) { _, _ in rebuildFilteredExercises() }
.onChange(of: customExercises.count) { _, _ in rebuildFilteredExercises() }
```

정적 프로퍼티도 호이스트:
```swift
private static let columns: [GridItem] = [...]
private static let searchBorderColor = Color.secondary.opacity(0.15)
```

## Prevention

- 검색 결과처럼 sort/filter가 포함된 데이터는 computed property 대신 `@State` + `.onChange` 캐싱
- 섹션 통합 시 `@Query` 중복 여부를 부모-자식 hierarchy에서 확인
- `[GridItem]` 같은 상수 배열은 `static let`으로 선언

## Files Changed

| 파일 | 변경 |
|------|------|
| `ActivityView.swift` | 섹션 순서 재배치, QuickStart 제거, CTA 제거 |
| `SuggestedWorkoutSection.swift` | 검색+템플릿 통합, 캐싱 최적화 |
| `ActivityQuickStartSection.swift` | 삭제 |
