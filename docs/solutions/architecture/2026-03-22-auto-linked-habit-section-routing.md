---
tags: [life-tab, habit, auto-linked, auto-achievement, section-routing, ux]
date: 2026-03-22
category: architecture
status: implemented
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNETests/LifeViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-healthkit-auto-achievements.md
---

# Solution: Auto-linked 습관을 Auto Workout Achievements 섹션으로 라우팅

## Problem

"Auto-complete from workouts" 토글을 켠 습관이 "My Habits" 섹션에 일반 습관과 함께 표시됨.
사용자 기대: 운동 자동 입력 업적은 "Auto Workout Achievements" 섹션에 표시되고 삭제 가능해야 함.

### Root Cause

- `filteredProgresses`가 `isAutoLinked` 여부와 관계없이 모든 `habitProgresses`를 표시
- Auto Achievements 섹션은 `LifeAutoAchievementService`의 하드코딩된 9개 규칙만 표시
- 사용자 정의 auto-linked 습관을 위한 UI 영역이 부재

## Solution

### 핵심 변경

1. **ViewModel**: `autoLinkedProgresses`를 stored property로 추가, `calculateProgresses()` 내에서 일괄 파티션
2. **Hero 카운트 분리**: `completedCount`/`totalActiveCount`에서 auto-linked 습관 제외 (hero ring은 My Habits만 반영)
3. **View 라우팅**: `filteredProgresses`에서 `isAutoLinked` 제외 → "My Habits"에 안 보임
4. **Custom Goals 그룹**: Auto Achievements 섹션 내 "Custom Goals" 카드로 auto-linked 습관 표시
5. **삭제 UX**: context menu + confirmationDialog로 archive (확인 필요)

### Key Code

```swift
// ViewModel: 파티션 후 hero 카운트에서 제외
autoLinkedProgresses = progresses.filter(\.isAutoLinked)
let manualProgresses = progresses.filter { !$0.isAutoLinked }
completedCount = manualProgresses.filter(\.isCompleted).count
totalActiveCount = manualProgresses.count
```

```swift
// View: My Habits 필터링
private var filteredProgresses: [HabitProgress] {
    let base = viewModel.habitProgresses.filter { !$0.isAutoLinked }
    ...
}
```

## Prevention

### Checklist

- [ ] 새로운 습관 유형 추가 시 hero ring에 포함될지 명시적으로 결정
- [ ] 섹션 간 라우팅 변경 시 완료 카운트 정합성 확인
- [ ] destructive action은 confirmationDialog 필수

## Lessons Learned

- computed property로 body에서 filter를 호출하면 매 렌더마다 O(N) 반복. stored property + `calculateProgresses()` 내 일괄 계산이 프로젝트 패턴
- hero ring 카운트와 실제 표시 섹션의 정합성이 어긋나면 사용자 혼란 유발
- `.contextMenu` 내 `Button(role: .destructive)` 금지 — `.tint(.red)` 사용 (프로젝트 규칙)
- VStack 내에서는 `.swipeActions` 불가 → `.contextMenu` + `.confirmationDialog` 패턴 사용
