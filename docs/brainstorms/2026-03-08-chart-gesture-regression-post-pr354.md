---
tags: [chart, gesture, regression, NavigationStack, long-press, scroll]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 차트 롱프레스/스크롤 전면 장애 (PR #354 이후)

## Problem Statement

PR #350에서 수정된 차트 롱프레스 선택 + 수평 스크롤이 PR #354 머지 후 다시 전면 장애.
모든 탭(Dashboard, Activity, Wellness)의 모든 차트에서 동일 증상.

### 증상
- 롱프레스 무반응 (선택 오버레이 미표시)
- 과거 데이터 수평 스크롤 불가
- 차트 터치 자체 미인식

## Root Cause Analysis

### 확인된 사실
1. PR #350 이후 **차트 코드 변경 없음** (DotLine, AreaLine, Bar, RangeBar, SleepStage, HeartRate, ChartSelectionInteraction 모두 동일)
2. 차트 소비자 View도 동일 (DailyVolumeChartView에 UI test probe 추가만 — benign)
3. **유일한 구조 변경**: `ContentView.swift`의 NavigationStack 패턴 변경 (PR #354)

### 원인: NavigationStack(path:) 커스텀 Binding

PR #354에서 알림 push 네비게이션 지원을 위해 ContentView 구조를 변경:

| 항목 | Before (PR #350) | After (PR #354) |
|------|------------------|-----------------|
| 외부 Stack | `NavigationStack(path: $notificationPresentationPath)` wrapping TabView | 없음 |
| 탭별 Stack | `NavigationStack` (unmanaged) | `NavigationStack(path: notificationPathBinding(for:))` |
| Path 관리 | `@State var notificationPresentationPath: [Destination]` (직접 바인딩) | `@State var notificationPresentationPaths = NotificationPresentationPaths()` (struct → computed binding) |
| navigationDestination | TabView 레벨 (외부 stack) | 각 탭 content 내부 |

**왜 문제인가:**

```swift
// 매 body 평가마다 새 Binding 인스턴스 생성
private func notificationPathBinding(for section: AppSection) -> Binding<NavigationPath> {
    Binding(
        get: { notificationPresentationPaths.path(for: section) },  // 값 복사 반환
        set: { notificationPresentationPaths.updatePath($0, for: section) }
    )
}
```

1. `body` 평가 시 `notificationPathBinding(for:)` 호출 → 새 `Binding` struct 생성
2. `NotificationPresentationPaths.path(for:)`는 NavigationPath **값 복사** 반환 (not a reference)
3. SwiftUI NavigationStack이 Binding 변경 감지 → 내부 view hierarchy 재구성 가능
4. 재구성 시 차트의 `@State` (selectionGestureState, selectedDate) 리셋
5. 제스처 인식 체인 단절 → 모든 터치/롱프레스/스크롤 무반응

추가 가능성: 4개 탭의 `notificationPresentationPaths`가 하나의 struct이므로, 어느 탭의 path가 변경되면 전체 struct의 `@State` 변경으로 인식 → 모든 탭의 NavigationStack Binding getter 재평가 → 불필요한 재렌더.

## Proposed Fixes

### Option A: 탭별 독립 @State NavigationPath (권장)

```swift
@State private var todayNavPath = NavigationPath()
@State private var trainNavPath = NavigationPath()
@State private var wellnessNavPath = NavigationPath()
@State private var lifeNavPath = NavigationPath()

// 사용
NavigationStack(path: $todayNavPath) { ... }
NavigationStack(path: $trainNavPath) { ... }
```

장점: 직접 `@State` 바인딩 → SwiftUI 최적화, 탭 간 불필요한 재렌더 없음
단점: 알림 라우팅에서 4개 path를 개별 관리해야 함

### Option B: NavigationPath → unmanaged + @State destination

```swift
NavigationStack {
    DashboardView(...)
    .navigationDestination(isPresented: $showPersonalRecords) { ... }
}
```

장점: path 관리 불필요, 가장 단순
단점: 프로그래매틱 push가 Bool binding으로 제한

### Option C: 커스텀 Binding 안정화

```swift
// notificationPresentationPaths를 class(@Observable)로 변경하여 참조 안정성 확보
@Observable
final class NotificationPresentationPaths { ... }
```

장점: 기존 구조 유지
단점: Observable 전환 작업량

## Constraints
- 알림 push 네비게이션 기능은 유지해야 함 (PR #354 목적)
- 차트 제스처 코드 자체는 건드리지 않음 (이미 정상)
- 모든 탭에서 동일하게 작동해야 함

## Scope

### MVP (Must-have)
- 모든 차트 롱프레스 선택 복구
- 과거 데이터 수평 스크롤 복구
- 알림 push 네비게이션 기능 유지

### Nice-to-have (Future)
- 차트 제스처 UITest 자동화
- NavigationStack 패턴 가이드 rules 추가

## Verification Plan

1. 수정 후 각 탭의 차트에서 롱프레스 → 선택 오버레이 표시 확인
2. 수정 후 각 차트에서 수평 스크롤 → 과거 데이터 표시 확인
3. 알림 수신 → 해당 탭 push 네비게이션 동작 확인
4. 기존 ChartSelectionInteractionTests 통과 확인

## Next Steps

- [ ] /plan 으로 Option A 구현 계획 생성
- [ ] 빌드 후 시뮬레이터에서 차트 제스처 수동 검증
