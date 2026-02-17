---
tags: [tab-consolidation, swiftui-tabview, dual-viewmodel, navigation-destination, sheet-state, delete-confirmation, dead-code-cleanup, single-scroll-layout]
category: architecture
date: 2026-02-17
severity: important
related_files:
  - Dailve/Presentation/Wellness/WellnessView.swift
  - Dailve/Presentation/Wellness/BodyHistoryDetailView.swift
  - Dailve/Presentation/Wellness/Components/SleepHeroCard.swift
  - Dailve/Presentation/Wellness/Components/BodySnapshotCard.swift
  - Dailve/Presentation/BodyComposition/BodyCompositionFormSheet.swift
  - Dailve/App/AppSection.swift
  - Dailve/App/ContentView.swift
related_solutions:
  - architecture/2026-02-16-viewmodel-cached-filtering.md
  - architecture/2026-02-17-cloudkit-optional-relationship.md
  - general/2026-02-17-chart-ux-layout-stability.md
---

# Solution: 4탭→3탭 구조 전환 + Wellness 탭 통합

## Problem

### Symptoms

- Sleep 탭과 Body 탭이 각각 카드 3개씩만 표시하여 콘텐츠가 빈약
- 4개 탭 중 2개가 단순 정보 표시 전용이라 탭 전환 비용 대비 가치 낮음
- Oura Ring, WHOOP 등 경쟁 앱 대비 정보 밀도 부족

### Root Cause

초기 MVP에서 도메인별 1:1 탭 매핑(Condition/Activity/Sleep/Body)을 적용했으나, Sleep과 Body는 "Wellness" 관점에서 하나의 맥락으로 묶이는 데이터이며 개별 탭으로 분리할 정도의 콘텐츠 볼륨이 없었음.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `AppSection.swift` | 4 case → 3 case (today/train/wellness) | 탭 구조 정의 |
| `ContentView.swift` | 4 Tab → 3 Tab | 탭 렌더링 |
| `WellnessView.swift` | 신규 (351줄) | Sleep+Body 통합 Single Scroll |
| `SleepHeroCard.swift` | 신규 | Score Ring + Duration + Efficiency + Stage Bar |
| `BodySnapshotCard.swift` | 신규 | 최신값 + 7일 변화 비교 |
| `BodyHistoryDetailView.swift` | 신규 | Push destination for history |
| `BodyCompositionFormSheet.swift` | 분리 | 재사용을 위해 별도 파일로 |
| `SleepView.swift` | 삭제 | Dead code (WellnessView로 대체) |
| `BodyCompositionView.swift` | 삭제 | Dead code (WellnessView로 대체) |

### Key Code

**Dual ViewModel 패턴** — 한 뷰가 2개의 독립 ViewModel을 소유:

```swift
struct WellnessView: View {
    @State private var sleepViewModel = SleepViewModel()
    @State private var bodyViewModel = BodyCompositionViewModel()
    @Query(...) private var records: [BodyCompositionRecord]
    @State private var cachedBodyItems: [BodyCompositionListItem] = []

    .task {
        async let sleepLoad: () = sleepViewModel.loadData()
        async let bodyLoad: () = bodyViewModel.loadHealthKitData()
        _ = await (sleepLoad, bodyLoad)
        refreshBodyItemsCache()
    }
    .onChange(of: records.count) { _, _ in refreshBodyItemsCache() }
}
```

**Sheet State Race Condition 해결** — Push된 자식 뷰에서 별도 @State 사용:

```swift
// BodyHistoryDetailView — 자체 sheet state 관리
@State private var isShowingEditSheet = false  // VM의 isShowingEditSheet와 독립

// WellnessView — VM의 isShowingEditSheet 사용 (root level)
.sheet(isPresented: $bodyViewModel.isShowingEditSheet) { ... }
```

**NavigationDestination은 조건 밖에 배치**:

```swift
// BAD: if hasBodyData { ... .navigationDestination(for:) }
// GOOD: body 레벨에서 항상 등록
var body: some View {
    Group { ... }
    .navigationDestination(for: BodyHistoryDestination.self) { _ in ... }
}
```

**비교 데이터 범위 제한**:

```swift
private static let comparisonWindowDays = 10

private func findItemNearSevenDaysAgo(...) -> BodyCompositionListItem? {
    let threshold = Calendar.current.date(byAdding: .day, value: -Self.comparisonWindowDays, to: latest.date) ?? latest.date
    return items.dropFirst()
        .filter { $0.date >= threshold }  // 10일 이내만 허용
        .min(by: { ... })
}
```

## Prevention

### Checklist Addition

- [ ] `.navigationDestination(for:)`은 조건 블록(`if/else`) 외부에 배치했는가?
- [ ] Push된 자식 뷰에서 부모 ViewModel의 sheet state를 직접 바인딩하지 않는가?
- [ ] CloudKit 환경에서 삭제 동작에 confirmationDialog/alert가 있는가?
- [ ] 비교 데이터(change indicator)에 유효 기간 threshold가 있는가?
- [ ] 탭 통합 후 dead code가 완전히 제거되었는가?

### Rule Addition

`.claude/rules/swiftui-navigation.md` 신규 규칙 후보:

1. **NavigationDestination은 body 최상위에 배치**: 조건 블록 안에 넣으면 해당 조건이 false일 때 routing 불가
2. **Push 자식 뷰의 sheet은 자체 @State 사용**: 부모의 @Bindable ViewModel과 자식이 같은 sheet flag를 공유하면 back navigation 시 race condition
3. **Delete는 반드시 확인 다이얼로그**: CloudKit 환경에서 삭제는 전 디바이스 전파

## Lessons Learned

1. **Thin 탭은 통합 대상**: 카드 3개 이하의 탭은 다른 탭과 통합을 검토. Single Scroll이 탭 전환보다 사용자 경험 우수
2. **Dual ViewModel은 coordinator 없이 가능**: 두 VM이 독립적이면(서로 의존 없음) View에서 직접 @State로 소유하면 충분. 불필요한 coordinator ViewModel 추가 금지
3. **bodyItems 캐싱은 @State + onChange**: computed property가 merge 로직 포함 시 매 렌더마다 재계산 비용 발생. `onChange(of: records.count)`로 invalidation
4. **FormSheet 분리는 재사용 전제**: `private struct` → `struct` 변경만으로는 부족. 별도 파일로 분리해야 의존 관계 명확
5. **Dead code는 리뷰 시점에 삭제**: 구 View 파일(SleepView, BodyCompositionView)을 "나중에" 삭제하면 유지보수 비용만 증가. 리뷰 수정과 동시에 삭제
