---
tags: [life-tab, ux-consistency, sectiongroup, pull-to-refresh, context-menu, ipad-layout]
category: architecture
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - docs/brainstorms/2026-03-04-life-tab-ux-improvement.md
  - docs/plans/2026-03-04-life-tab-ux-improvement.md
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-auto-workout-card-ux-ui.md
---

# Solution: Life 탭 UX 일관성 정렬 (SectionGroup + Refresh + Context Menu)

## Problem

Life 탭은 기능적으로는 충분했지만, 탭 간 시각/구조 일관성 관점에서 다음 문제가 있었다.

### Symptoms

- 섹션이 공통 `SectionGroup` 패턴과 다르게 보여 다른 탭 대비 이질감 발생
- 주기형 습관의 보조 액션이 행 아래에 직접 노출되어 화면 밀도가 높아짐
- Life 탭만 pull-to-refresh 일관 패턴이 없어 갱신 흐름이 다르게 느껴짐
- iPad에서 정보 배치가 단일 세로 흐름 중심이라 공간 활용이 부족함

### Root Cause

- Life 탭이 초기 구현 이후 기능 추가 위주로 확장되면서, 공통 UI 패턴(SectionGroup/refresh rhythm)으로 재정렬되지 않았다.
- 핵심 액션과 보조 액션의 정보 계층 분리가 약해 기본 화면에 액션이 과다 노출되었다.

## Solution

Life 탭을 `Hero → SectionGroup` 구조로 재정렬하고, 보조 액션은 context menu로 이동했으며, refresh signal 기반 pull-to-refresh를 연결했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | `HabitListQueryView`에 `My Habits`/`Auto Workout Achievements`를 `SectionGroup`으로 통일 | 탭 간 구조/스타일 일관성 확보 |
| `DUNE/Presentation/Life/LifeView.swift` | cycle 보조 액션(Snooze/Skip/History)을 `contextMenu`로 이동 | 기본 화면 정보 밀도 축소, 핵심 액션 집중 |
| `DUNE/Presentation/Life/LifeView.swift` | `waveRefreshable` + local refresh signal 추가, child `recalculate()` 연동 | Life 탭 refresh 경험을 다른 탭과 정렬 |
| `DUNE/Presentation/Life/LifeView.swift` | iPad에서 섹션 2열 배치, 자동 달성 카드는 split 레이아웃에서 1열 유지 | iPad 공간 활용 + 과밀 카드 방지 |

### Key Code

```swift
.waveRefreshable {
    await MainActor.run {
        localRefreshSignal += 1
    }
}
```

```swift
if isRegular {
    HStack(alignment: .top, spacing: DS.Spacing.md) {
        habitsSection(fillHeight: true)
        autoAchievementsSection(fillHeight: true)
    }
}
```

## Prevention

### Checklist Addition

- [ ] 탭 루트 UI 변경 시 `Hero → SectionGroup` 공통 구조와 정합성 먼저 확인
- [ ] 보조 액션은 기본 화면 노출 대신 context menu/sheet 우선 검토
- [ ] iPad 분할 레이아웃에서 내부 카드 그리드 중첩(2열 안의 2열) 여부 확인
- [ ] 새 탭/기존 탭 모두 pull-to-refresh 적용 정책 일관성 확인

### Rule Addition (if applicable)

- 현재는 기존 규칙으로 커버 가능하여 신규 rule 추가는 생략

## Lessons Learned

UI 기능 확장 이후에는 "동작 완성"만으로 충분하지 않고, 공통 구조로 재정렬하는 리듬이 필요하다.  
특히 iPad에서는 상위 레이아웃과 내부 카드 그리드가 동시에 다열화될 때 정보 과밀이 쉽게 발생하므로, 한 단계씩만 다열화해야 가독성과 일관성을 함께 유지할 수 있다.
