---
tags: [navigation, detail-view, info-sheet, SectionGroup, NavigationLink, chevron, DRY, SwiftUI]
date: 2026-02-23
category: solution
status: implemented
---

# Activity 탭 상세 뷰 Navigation 패턴

## Problem

Activity 탭의 3개 섹션(Personal Records, Consistency, Exercise Mix)이 요약 카드만 표시하고 상세 화면으로 드릴다운할 수 없었음. 또한 각 섹션에 대한 설명(info) 접근 방법도 없었음.

추가로 Training Volume 섹션에서 SectionGroup 타이틀과 카드 내부 타이틀이 중복 표시되는 UX 문제가 있었음.

### 근본 원인
- SectionGroup 컴포넌트에 info 버튼 슬롯이 없었음
- 섹션→상세 뷰 navigation 인프라(destination enum, NavigationLink)가 없었음
- 상세 뷰와 ViewModel이 구현되지 않았음

## Solution

### 1. SectionGroup 확장 — optional infoAction 슬롯

```swift
struct SectionGroup<Content: View>: View {
    var infoAction: (() -> Void)? = nil  // 기본 nil = 기존 호출 전부 호환
    // ...
    if let infoAction {
        Spacer()
        Button(action: infoAction) {
            Image(systemName: "info.circle")
        }
    }
}
```

**핵심**: 기존 호출 사이트 수정 없이 선택적 기능 추가. nil 기본값으로 backward compatible.

### 2. 타입 안전 Navigation — ActivityDetailDestination enum

```swift
enum ActivityDetailDestination: Hashable {
    case personalRecords
    case consistency
    case exerciseMix
}

// ActivityView에서:
NavigationLink(value: ActivityDetailDestination.personalRecords) {
    PersonalRecordsSection(records: viewModel.personalRecords)
}
.buttonStyle(.plain)
```

**핵심**: Correction #61에 따라 String이 아닌 enum으로 type-safe routing.

### 3. 카드 내부 chevron 힌트

탭 가능한 카드에 `chevron.right` 아이콘을 trailing에 배치하여 drill-down affordance 제공.

### 4. Info Sheet 공통 헬퍼 추출

3개 info sheet에서 동일한 `sectionHeader`/`bulletPoint` 헬퍼가 중복되어 `InfoSheetHelpers` enum으로 추출.

```swift
enum InfoSheetHelpers {
    struct SectionHeader: View { ... }
    struct BulletPoint: View { ... }
}
```

### 5. PR 무게 계산 수정

weight가 nil인 세트(bodyweight 운동)가 분모에 포함되어 PR이 실제보다 낮게 계산되는 버그 수정.

```swift
// Before (buggy): completedSets.count가 분모
bestWeight: totalWeight / Double(completedSets.count)

// After (fixed): weight가 있는 세트만 분모
let weights = record.completedSets.compactMap(\.weight).filter { $0 > 0 }
let avgWeight = weights.reduce(0, +) / Double(weights.count)
```

### 6. ViewModel 렌더 성능 최적화

`calendarDays()`, `firstWeekdayOffset()` 같은 Calendar 연산을 body에서 매 렌더마다 호출하는 대신 `loadData`에서 1회 계산 후 캐시.

## Affected Files

| 파일 | 변경 |
|------|------|
| SectionGroup.swift | infoAction 슬롯 추가 |
| ActivityView.swift | NavigationLink + info sheet 연결 |
| ActivityDetailDestination.swift | 새 enum |
| PersonalRecordsDetailView/ViewModel | 새 상세 뷰 (PointMark chart) |
| ConsistencyDetailView/ViewModel | 새 상세 뷰 (calendar grid) |
| ExerciseMixDetailView/ViewModel | 새 상세 뷰 (SectorMark donut) |
| InfoSheetHelpers.swift | 공통 헬퍼 추출 |
| 3개 InfoSheet | 공통 헬퍼 사용으로 리팩토링 |

## Prevention

1. **SectionGroup에 새 기능 추가 시 nil 기본값 패턴 유지**: 기존 호출 사이트 수정 없이 확장 가능
2. **compactMap 후 분모는 결과 count 사용**: `compactMap(\.property)`로 nil 필터링했으면 원본 count가 아닌 필터링 후 count를 분모로
3. **body 내 Calendar/Date 연산은 캐싱**: `calendarDays()` 같은 computed function은 ViewModel 프로퍼티로 캐시
4. **3곳 이상 동일 View 헬퍼는 즉시 추출** (Correction #37)

## Lessons Learned

1. `compactMap` + `reduce` 패턴에서 분모/분자의 모수가 일치하는지 항상 확인
2. 선택적 슬롯 추가는 optional closure + nil 기본값이 가장 안전
3. Info sheet 같은 정보 표시 UI는 일찍 공통 헬퍼를 추출하면 새 sheet 추가 비용이 크게 줄어듦
4. SwiftUI body에서 호출되는 함수가 pure computation(부수 효과 없이 매번 같은 결과)이면 캐싱 후보
