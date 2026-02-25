# iOS Navigation Ownership Rules

## Root NavigationStack 소유권

- iOS 탭 루트 `NavigationStack`은 `DUNE/App/ContentView.swift`에서만 생성합니다.
- 탭 루트 View(`DashboardView`, `ActivityView`, `WellnessView`) 내부에 추가 `NavigationStack`을 만들지 않습니다.

```swift
// GOOD: root only
Tab("Today", systemImage: "house") {
    NavigationStack { DashboardView() }
}

// BAD: nested root stack
struct DashboardView: View {
    var body: some View {
        NavigationStack { ... }
    }
}
```

## 허용 예외

다음 경우의 로컬 `NavigationStack`은 허용합니다.

- sheet/fullScreenCover 내부 독립 내비게이션 (예: FormSheet)
- 독립 preview/demo container (`#Preview`)에서만 필요한 래핑
- watchOS는 `watch-navigation.md` 규칙을 따름 (별도 정책)

## 리뷰 체크포인트

- 새 탭/섹션 추가 시 루트 stack은 `ContentView`에서만 추가되었는가
- Feature root view에 불필요한 `NavigationStack`이 추가되지 않았는가
- sheet 내부 stack은 dismiss/toolbar 동작을 위해 필요한 범위로 제한되었는가
