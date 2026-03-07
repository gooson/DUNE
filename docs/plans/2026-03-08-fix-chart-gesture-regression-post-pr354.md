---
tags: [chart, gesture, regression, NavigationStack, long-press, scroll, NavigationPath, Binding]
date: 2026-03-08
category: plan
status: implemented
---

# Plan: 차트 롱프레스/스크롤 제스처 회귀 수정 (PR #354 이후)

## Context

PR #354에서 알림 push 네비게이션 지원을 위해 ContentView의 NavigationStack 패턴을 변경.
이 변경이 모든 탭의 차트 제스처(롱프레스 선택, 수평 스크롤)를 전면 장애로 만듦.

## Root Cause

`NotificationPresentationPaths` struct + computed `Binding<NavigationPath>` 패턴이 원인:
1. `body` 평가마다 `notificationPathBinding(for:)` → 새 Binding 인스턴스 생성
2. 4개 탭 path가 하나의 struct → 어느 탭 변경이든 전체 struct @State 변경
3. NavigationStack이 Binding 변경 감지 → 내부 view hierarchy 재구성
4. 차트의 `@State` (selectionGestureState, selectedDate) 리셋
5. 제스처 인식 체인 단절

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/App/ContentView.swift` | 수정 | NavigationStack path 바인딩 패턴 변경 |

## Implementation Steps

### Step 1: 독립 @State NavigationPath 변수 선언

`NotificationPresentationPaths` struct를 제거하고, 탭별 독립 `@State var NavigationPath` 4개로 교체.

```swift
@State private var todayNavPath = NavigationPath()
@State private var trainNavPath = NavigationPath()
@State private var wellnessNavPath = NavigationPath()
@State private var lifeNavPath = NavigationPath()
```

### Step 2: NavigationStack 바인딩 직접 연결

각 탭의 `NavigationStack(path: notificationPathBinding(for: .today))` →
`NavigationStack(path: $todayNavPath)` 로 직접 바인딩.

### Step 3: 알림 라우팅 헬퍼 추가

4개 path를 개별 관리하는 헬퍼 메서드 추가:
- `clearAllNavPaths()`: 전체 path 초기화
- `setNavPath(_:for:)`: 특정 탭의 path 설정

### Step 4: handleNotificationNavigationRequest 업데이트

기존 `notificationPresentationPaths` 접근을 새 헬퍼로 교체.

### Step 5: Dead code 제거

- `NotificationPresentationPaths` struct 삭제
- `notificationPathBinding(for:)` 메서드 삭제

## Test Strategy

- 빌드 성공 확인 (scripts/build-ios.sh)
- 수동 검증: 각 탭 차트에서 롱프레스 → 선택 오버레이 표시
- 수동 검증: 수평 스크롤 → 과거 데이터 표시
- 알림 push 네비게이션 기능 유지 확인

## Risks

| 리스크 | 완화 |
|--------|------|
| 알림 라우팅 기능 퇴행 | handleNotificationNavigationRequest 로직 동일하게 유지 |
| 탭 전환 시 path 간섭 | 독립 @State로 완전 격리 |

## Alternatives Considered

| 옵션 | 장점 | 단점 | 선택 |
|------|------|------|------|
| A. 탭별 독립 @State NavigationPath | 직접 바인딩, SwiftUI 최적화 | 4개 변수 관리 | ✅ |
| B. Unmanaged NavigationStack + Bool binding | 가장 단순 | 프로그래매틱 push 제한 | |
| C. @Observable class로 전환 | 기존 구조 유지 | 전환 작업량 | |
