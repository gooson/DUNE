---
tags: [muscle-map, interaction, bug-fix, activity-tab]
date: 2026-03-10
category: plan
status: approved
---

# Fix: Activity Tab Muscle Map Click Interactions

## Problem

Activity 탭의 근육지도(MuscleRecoveryMapView)에서:
1. Recovery/Volume 세그먼트 피커 클릭이 동작하지 않음
2. 개별 근육 부위 탭이 동작하지 않음

## Root Cause

`ActivityView.swift:526-538`의 `recoveryMapSection()`:
- 전체 `SectionGroup`이 `NavigationLink`로 래핑됨
- `MuscleRecoveryMapView`에 `.allowsHitTesting(false)` 적용
- 결과: 모든 내부 인터랙션(피커, 근육 버튼)이 차단됨

## Solution

1. 외부 `NavigationLink` 래핑 제거
2. `.allowsHitTesting(false)` 제거
3. 디테일 네비게이션을 위한 별도 `NavigationLink` 추가 (섹션 하단)

## Affected Files

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Presentation/Activity/ActivityView.swift` | 수정 | `recoveryMapSection()` 리팩터링 |

## Implementation Steps

### Step 1: `recoveryMapSection()` 수정

**Before**:
```swift
NavigationLink(value: ActivityDetailDestination.muscleMap) {
    SectionGroup(...) {
        MuscleRecoveryMapView(...)
            .allowsHitTesting(false)
    }
}
.buttonStyle(.plain)
```

**After**:
```swift
SectionGroup(...) {
    MuscleRecoveryMapView(...)
    // 하단에 디테일 네비게이션 링크
    NavigationLink(value: ActivityDetailDestination.muscleMap) {
        // 디테일 뷰 이동 버튼
    }
    .buttonStyle(.plain)
}
```

## Test Strategy

- 빌드 성공 확인: `scripts/build-ios.sh`
- 수동 검증: Recovery/Volume 피커 토글, 개별 근육 탭 → MuscleDetailPopover 표시

## Risk

- 낮음: 단일 함수 수정, 기존 `MuscleMapDetailView`에서 이미 동일한 인터랙션 패턴 검증됨
- `MuscleMapDetailView`는 `.allowsHitTesting(false)` 없이 동일한 `MuscleRecoveryMapView`를 사용하고 있어, 인터랙션이 정상 동작함을 확인 가능
