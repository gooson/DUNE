---
tags: [muscle-map, navigation-link, hit-testing, swiftui, activity-tab]
date: 2026-03-10
category: solution
status: implemented
---

# NavigationLink 래핑이 내부 인터랙션을 차단하는 문제

## Problem

Activity 탭의 근육지도(`MuscleRecoveryMapView`)에서:
1. Recovery/Volume 세그먼트 피커 클릭이 동작하지 않음
2. 개별 근육 부위 탭이 동작하지 않음

## Root Cause

`ActivityView.swift`의 `recoveryMapSection()`에서:
- 전체 `SectionGroup`이 `NavigationLink`로 래핑됨
- `MuscleRecoveryMapView`에 `.allowsHitTesting(false)` 적용
- 결과: 모든 내부 인터랙션(피커, 근육 버튼)이 차단됨

```swift
// BAD: 전체 섹션을 NavigationLink로 래핑 + hitTesting 비활성화
NavigationLink(value: ActivityDetailDestination.muscleMap) {
    SectionGroup(...) {
        MuscleRecoveryMapView(...)
            .allowsHitTesting(false)
    }
}
```

## Solution

1. 외부 `NavigationLink` 래핑 제거
2. `.allowsHitTesting(false)` 제거
3. 섹션 하단에 별도 "View Details" `NavigationLink` 추가

```swift
// GOOD: 내부 인터랙션 허용 + 별도 디테일 링크
SectionGroup(...) {
    MuscleRecoveryMapView(...)

    NavigationLink(value: ActivityDetailDestination.muscleMap) {
        HStack {
            Text("View Details")
            Image(systemName: "chevron.right")
        }
    }
    .buttonStyle(.plain)
}
```

## Prevention

인터랙티브 컴포넌트(Picker, Button 등)를 포함하는 View를 `NavigationLink`로 래핑할 때:
- `.allowsHitTesting(false)`는 내부 모든 인터랙션을 차단함
- 대신 별도 네비게이션 링크를 섹션 하단에 배치
- `MuscleMapDetailView`가 이미 동일한 패턴(`.allowsHitTesting(false)` 없이)으로 동작하고 있었으므로, 기존 동작하는 패턴을 참조할 것

## Affected Files

- `DUNE/Presentation/Activity/ActivityView.swift` — `recoveryMapSection()` 수정
- `Shared/Resources/Localizable.xcstrings` — "View Details" 번역 추가 (ko/ja)
