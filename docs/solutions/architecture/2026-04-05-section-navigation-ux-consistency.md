---
tags: [navigation, sectiongroup, ux-consistency, chevron, detail-view]
category: architecture
date: 2026-04-05
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/SectionGroup.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Life/LifeView.swift
related_solutions:
  - docs/solutions/architecture/2026-02-23-activity-detail-navigation-pattern.md
  - docs/solutions/architecture/2026-03-04-life-tab-ux-consistency-sectiongroup-refresh.md
  - docs/solutions/architecture/2026-03-29-sleep-detail-ux-sectiongroup-consistency.md
---

# Solution: Section Navigation UX Consistency (SectionGroup Header Chevron)

## Problem

### Symptoms

- 탭 섹션 UI에서 상세 전환 UX가 3+ 패턴으로 혼재:
  - 하단 "View Details >" 텍스트 버튼 (Dashboard, Activity Muscle Map)
  - 하단 "View All >" 텍스트 버튼 (Wellness Injury/Posture/Body History)
  - SectionGroup 내부 NavigationLink (Activity 일부)
  - 카드 전체 탭 (히어로 카드)
  - 네비게이션 없음 (Training Volume)
  - 독립 버튼 (Life Weekly Report)

### Root Cause

기능 추가 위주로 확장되면서 각 탭이 독립적으로 네비게이션 패턴을 선택, 통일 기준이 없었음.

## Solution

### Core Change: SectionGroup `showChevron` 파라미터

```swift
struct SectionGroup<Content: View>: View {
    var showChevron: Bool = false  // backward compatible
    // ...
    if showChevron {
        if infoAction == nil { Spacer() }
        Image(systemName: "chevron.right")
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(.tertiary)
    }
}
```

### 패턴별 적용 방법

| 섹션 유형 | NavigationLink 위치 | showChevron |
|----------|-------------------|-------------|
| 단일 액션 (카드 전체 탭) | SectionGroup 내부, content 래핑 | `true` |
| 히어로 카드 | SectionGroup 내부, content 래핑 | `true` |
| 혼합 액션 (개별 편집 + 전체 보기) | 개별 row에 NavigationLink + "View All" 링크 | 조건부 (`!records.isEmpty`) |
| 상세 뷰 없음 | NavigationLink 없음 | `false` (default) |

### 주의사항: NavigationLink 내부의 버튼/제스처 충돌

**SectionGroup 전체를 NavigationLink로 감싸면 내부 버튼 액션이 삼킴됨**. 리뷰에서 발견:
- Injury 카드의 `onEdit` 콜백이 NavigationLink에 의해 무시됨
- MuscleMap의 `onMuscleSelected` 콜백이 NavigationLink에 의해 무시됨

**해결 방법**: 내부에 독립적인 버튼 액션이 필요한 섹션은 전체를 NavigationLink로 감싸지 말고, 개별 액션 영역만 NavigationLink 적용.

## Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SectionGroup.swift` | `showChevron: Bool = false` 추가 | 통일 chevron 어포던스 |
| `ActivityView.swift` | 10개 SectionGroup에 showChevron + 히어로 래핑 | Activity 탭 통일 |
| `DashboardView.swift` | Condition/Stress/Sleep에 SectionGroup 래핑 | Dashboard 탭 통일 |
| `WellnessView.swift` | Hero/Sleep/Injury/Posture/Body에 SectionGroup 적용 | Wellness 탭 통일 |
| `LifeView.swift` | Heatmap/Weekly Report에 SectionGroup 적용 | Life 탭 통일 |
| `RecoverySleepCard.swift` | 하단 "Sleep Details" 링크 삭제 | SectionGroup chevron으로 대체 |
| `Localizable.xcstrings` | "Wellness Score", "Habit Heatmap" 3개 언어 추가 | 새 SectionGroup 타이틀 |

## Prevention

### Checklist

- [ ] 새 섹션 추가 시 상세 뷰가 있으면 `SectionGroup(showChevron: true)` 사용
- [ ] NavigationLink 내부에 버튼/제스처가 필요한 섹션은 전체 래핑 금지
- [ ] 히어로 카드도 SectionGroup으로 래핑하여 일관된 헤더 패턴 유지
- [ ] 혼합 액션 섹션은 개별 NavigationLink + showChevron 조건부 조합

## Lessons Learned

1. **NavigationLink + 내부 Button 충돌**: SwiftUI에서 NavigationLink는 내부의 Button tap을 삼킴. 혼합 액션 섹션은 전체 래핑 대신 개별 래핑 필요.
2. **조건부 showChevron**: `showChevron: !records.isEmpty`는 navigation 가용성을 UI 파라미터로 노출하는 패턴. 가능하면 NavigationLink 존재 여부와 동기화 유지.
3. **히어로 카드 + SectionGroup**: 히어로 카드를 SectionGroup으로 감싸면 이중 배경(material + card)이 발생할 수 있음. 현재는 허용 — 향후 히어로 카드 내부 배경을 조정하여 시각적 충돌 해소 가능.
