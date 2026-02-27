---
tags: [watchos, carousel, scrollview-paging, fullscreen-card, scroll-transition, pre-compute, dry-extraction]
category: architecture
date: 2026-02-28
severity: important
related_files:
  - DUNEWatch/Views/CarouselHomeView.swift
  - DUNEWatch/Views/Components/ExerciseCardView.swift
  - DUNEWatch/Views/Components/CarouselRoutineCardView.swift
  - DUNEWatch/Helpers/WatchExerciseHelpers.swift
  - DUNEWatch/Views/QuickStartAllExercisesView.swift
  - DUNEWatch/ContentView.swift
related_solutions:
  - architecture/2026-02-18-watch-navigation-state-management.md
  - architecture/2026-02-28-watch-ux-enhancement-patterns.md
  - architecture/2026-02-27-watch-equipment-icon-patterns.md
---

# Solution: Watch Fullscreen Carousel Home (ScrollView Paging)

## Problem

### Symptoms

- Watch 홈 화면이 작은 리스트 행으로 구성되어 운동 선택 시 시각적 임팩트 부족
- RoutineListView와 QuickStartPickerView가 분리되어 두 곳을 왔다갔다 해야 하는 UX
- Popular/Recent 운동이 작은 타일로만 표시되어 한 눈에 파악하기 어려움

### Root Cause

기존 구조가 iOS List 패턴을 그대로 Watch에 적용. Watch의 작은 화면에서는 한 화면에 하나의 운동을 크게 보여주는 fullscreen card 패턴이 더 효과적.

## Solution

### Approach: ScrollView + scrollTargetBehavior(.paging)

`TabView(.verticalPage)` 대신 `ScrollView` + `.scrollTargetBehavior(.paging)` 선택:
- `.scrollTransition` modifier로 비활성 카드에 scale(0.85)/opacity(0.6) 효과 가능
- `TabView`는 `.scrollTransition`을 지원하지 않음
- `containerRelativeFrame(.vertical)`로 각 카드가 화면 전체를 차지

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| CarouselHomeView.swift (NEW) | 통합 캐러셀 홈 구현 | Routine + Popular + Recent + Browse 통합 |
| ExerciseCardView.swift (NEW) | 풀스크린 운동 카드 | 60pt 아이콘 + 이름 + 서브타이틀 |
| CarouselRoutineCardView.swift (NEW) | 풀스크린 루틴 카드 | 아이콘 스트립 + 메타 정보 |
| WatchExerciseHelpers.swift (NEW) | 4개 공유 헬퍼 추출 | DRY — carousel과 browse list 공용 |
| QuickStartAllExercisesView.swift (NEW) | 카테고리별 운동 리스트 분리 | 기존 QuickStartPickerView에서 추출 |
| ContentView.swift | CarouselHomeView를 root로 교체 | 라우팅 단순화 |
| RoutineListView.swift (DELETED) | CarouselHomeView로 흡수 | |
| QuickStartPickerView.swift (DELETED) | 분리됨 | |

### Key Code

```swift
// ScrollView paging carousel with scroll transitions
ScrollView(.vertical) {
    LazyVStack(spacing: 0) {
        ForEach(cards) { card in
            cardContent(for: card)
                .containerRelativeFrame(.vertical)
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                        .opacity(phase.isIdentity ? 1.0 : 0.6)
                }
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
```

### Key Pattern: Pre-compute in rebuildCards()

리뷰에서 발견된 핵심 성능 문제 — body/init에서 UserDefaults 접근 금지:

```swift
// BAD: body 또는 View init에서 UserDefaults 호출
NavigationLink(value: WatchRoute.workoutPreview(snapshotFromExercise(exercise))) { ... }
// ↑ snapshotFromExercise → resolvedDefaults → RecentExerciseTracker.latestSet (UserDefaults)
//   매 스크롤 프레임마다 실행

// GOOD: rebuildCards()에서 1회 pre-compute
private func rebuildCards() {
    // ...
    for exercise in popular {
        let snapshot = snapshotFromExercise(exercise)  // 여기서 1회만
        let daysAgo = daysAgoLabel(for: exercise)      // 여기서 1회만
        result.append(CarouselCard(
            id: "popular-\(exercise.id)",
            section: .popular,
            content: .exercise(exercise, snapshot: snapshot, daysAgo: daysAgo)
        ))
    }
}
```

### Key Pattern: Content-aware onChange invalidation

```swift
// BAD: count만 감시 — 같은 수의 루틴 수정 시 미갱신
.onChange(of: templates.count) { rebuildCards() }

// GOOD: content-aware hash key
@State private var templateContentKey: Int = 0

private func updateTemplateContentKey() {
    var hasher = Hasher()
    for t in templates {
        hasher.combine(t.id)
        hasher.combine(t.name)
        hasher.combine(t.updatedAt)
    }
    let newKey = hasher.finalize()
    if newKey != templateContentKey { templateContentKey = newKey }
}

.onChange(of: templateContentKey) { rebuildCards() }
.onChange(of: templates.count) { updateTemplateContentKey() }
```

## Prevention

### Checklist Addition

- [ ] Watch ScrollView 카드에서 body/init 내 UserDefaults 접근이 없는가?
- [ ] `CarouselCard.Content` Hashable이 모든 의미 있는 필드를 포함하는가?
- [ ] `onChange(of:)` 감시 대상이 content-aware한가? (count만으로 부족한지 확인)
- [ ] 두 파일 이상에서 사용되는 헬퍼가 공유 파일에 있는가?

### Card Ordering Algorithm

```
Routines (SwiftData @Query, updatedAt desc)
  → Popular (personalizedPopular, limit=5)
    → Recent (lastUsedTimestamps, excluding Popular, limit=5)
      → All Exercises (always last)
```

## Lessons Learned

1. **ScrollView paging > TabView for animated transitions**: watchOS에서 scroll transition 효과가 필요하면 `ScrollView + .scrollTargetBehavior(.paging)` 조합 사용. `TabView(.verticalPage)`는 `.scrollTransition`을 지원하지 않음.

2. **Pre-compute at data layer, not view layer**: carousel처럼 스크롤 중 모든 카드의 body가 재평가되는 UI에서는 UserDefaults, Calendar, Service 호출을 반드시 데이터 빌드 시점(`rebuildCards()`)에 pre-compute.

3. **DRY threshold for same-target files**: 같은 빌드 타겟의 두 파일에 동일 함수가 있으면 즉시 공유 파일로 추출. `private` file-scope는 같은 파일 내에서만 공유 가능하므로 파일 분리 시 자동으로 DRY 위반 발생.

4. **Hashable for enum with associated values**: `entries.count`만 hash/==에 사용하면 같은 수의 다른 항목이 동일 취급됨. entry ID를 포함해야 SwiftUI diffing이 올바르게 작동.
