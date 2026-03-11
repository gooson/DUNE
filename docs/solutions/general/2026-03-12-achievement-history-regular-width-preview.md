---
tags: [activity-tab, achievement-history, regular-width, empty-state, swiftui-layout]
category: general
date: 2026-03-12
severity: minor
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-07-activity-section-consolidation.md
  - docs/solutions/testing/2026-03-03-ipad-activity-tab-ui-test-navigation-stability.md
---

# Solution: Achievement History preview regular-width expansion

## Problem

Activity 탭의 `Achievement History` preview card가 iPad/macOS의 regular width 레이아웃에서 지나치게 작게 보였다.

### Symptoms

- `Achievement History` 섹션 안에서 카드가 전체 폭을 쓰지 않고 작은 박스처럼 보였다.
- reward history가 비어 있을 때는 empty-state 문구 길이에 맞춰 카드 폭이 더 줄어들었다.
- `Personal Records`, `Consistency`, `Exercise Mix` 같은 인접 카드 대비 균형이 무너졌다.

### Root Cause

`AchievementHistoryPreview`가 `StandardCard` 내부 콘텐츠를 intrinsic content size에 맡기고 있었고, `NavigationLink` 래퍼도 full-width를 명시하지 않았다. 그래서 regular width 환경에서는 empty/populated state 모두 섹션 폭을 충분히 사용하지 못했다.

## Solution

`AchievementHistoryPreview`와 이를 감싸는 `NavigationLink`에 full-width alignment를 부여하고, regular size class에서만 preview 밀도와 최소 높이를 소폭 키웠다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/ActivityView.swift` | `Achievement History` `NavigationLink`에 `.frame(maxWidth: .infinity, alignment: .leading)` 추가 | 링크 래퍼가 섹션 폭을 채우도록 보장 |
| `DUNE/Presentation/Activity/ActivityView.swift` | `AchievementHistoryPreview`에 regular-width 전용 `previewLimit`, `minimumCardHeight`, full-width frame 추가 | iPad/macOS에서 카드가 작아 보이지 않도록 조정 |
| `DUNE/Presentation/Activity/ActivityView.swift` | empty/populated state를 분리하고 regular width typography/spacing 확장 | empty state와 populated state 모두 읽기성과 시각 균형 확보 |

### Key Code

```swift
NavigationLink(value: ActivityDetailDestination.personalRecords) {
    AchievementHistoryPreview(events: viewModel.workoutRewardHistory)
}
.frame(maxWidth: .infinity, alignment: .leading)

Group {
    if previewEvents.isEmpty {
        emptyState
    } else {
        populatedState
    }
}
.frame(maxWidth: .infinity, minHeight: minimumCardHeight, alignment: .leading)
```

## Prevention

regular width에서 보이는 카드형 preview는 empty state라도 intrinsic width에 맡기지 말고, 카드 내부 루트 컨테이너와 상위 interactive wrapper 둘 다 `maxWidth: .infinity`를 검토한다.

### Checklist Addition

- [ ] `SectionGroup` 안의 `NavigationLink`/`Button` 카드가 regular width에서 full width를 유지하는지 확인
- [ ] empty-state card가 문구 길이에 따라 폭이 줄어들지 않는지 확인
- [ ] compact와 regular에서 preview item count와 min-height가 균형적인지 비교

### Rule Addition (if applicable)

해당 없음. 현재는 Activity preview 카드에 국한된 패턴으로 solution 문서 축적만으로 충분하다.

## Lessons Learned

- `StandardCard` 자체는 배경만 제공하므로, 안쪽 콘텐츠가 폭을 채우도록 명시하지 않으면 wide layout에서 쉽게 축소된다.
- iPad/macOS에서 작은 empty-state 카드 문제는 대부분 컨테이너 intrinsic sizing과 interactive wrapper sizing을 함께 봐야 빠르게 해결된다.
- regular width에서는 item count와 typography를 소폭만 늘려도 별도 레이아웃 재구성 없이 체감 밀도를 크게 개선할 수 있다.
