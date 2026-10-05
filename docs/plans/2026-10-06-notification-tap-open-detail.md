---
tags: [notification, routing, navigation, regression]
date: 2026-10-06
category: plan
status: approved
---

# Implementation Plan: 시스템 알림에서 알림함 상세까지 열기

## Context

경로가 없는 OS 알림을 탭하면 `NotificationInboxManager`가 항목 ID와 `.notificationHub` 경로를 전달하지만 `ContentView`는 Today와 알림함 열기 신호만 저장한다. `NotificationHubView`는 항목 ID를 받지 않아 알림함에서 멈춘다. 기존 알림함 행 탭에는 이미 유형별 상세 선택 로직이 있다.

## Requirements

- 저장된 알림의 OS 탭으로 알림함에 들어오면 해당 항목 상세까지 자동 진입한다.
- 알림함의 기존 행 탭, 직접 상세로 가는 경로, 뒤로 가기를 유지한다.
- 항목이 삭제되었거나 route-only 요청이면 알림함에서 안전하게 끝낸다.

## Approach

`.notificationHub` 요청의 항목 ID와 요청 번호를 `ContentView` → `DashboardView` → `NotificationHubView`로 전달한다. 알림함이 나타난 뒤 해당 항목이 실제 저장소에 존재할 때만 기존 행 탭 처리와 같은 로컬 목적지 선택을 사용한다. 수동 알림함 열기는 자동 선택을 하지 않는다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/ContentView.swift` | 수정 | 알림함 요청 항목 ID 보존 및 전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 수정 | OS 탭 요청을 알림함에 전달 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | 수정 | 표시 후 해당 항목 상세 자동 선택 |
| `DUNETests/NotificationPresentationPlannerTests.swift` | 수정 | 요청 ID state 검증 |
| `DUNEUITests/Full/NotificationRoutingRegressionTests.swift` | 수정 | seeded 시스템 응답 경로 검증 |
| `DUNE/App/TestDataSeeder.swift` | 필요 시 | 테스트 전용 알림 응답 진입점 |

## Implementation Steps

1. 알림함 목적지 state에 항목 ID를 보존한다. 단위 테스트에서 `.notificationHub`만 ID를 보존하는지 확인한다.
2. Dashboard의 알림함 표시 경로에 항목 ID를 전달하고 Hub에서 한 요청을 한 번만 처리한다. 기존 `handleTap` 로직을 재사용한다.
3. seeded UI 테스트에서 알림 응답을 발생시켜 알림함 상세의 AXID와 뒤로 가기 화면을 확인한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 삭제된 ID / route-only UUID | 자동 상세 push 없이 알림함 유지 |
| 같은 알림 재탭 | 요청 번호 변경으로 새 탐색 처리 |
| 수동 알림함 재진입 | 이전 OS 요청을 재사용하지 않음 |
| 앱 cold start | 기존 pending 요청 소비 뒤 동일한 ID 전달 |

## Testing Strategy

- Unit: `NotificationPresentationState` hub 요청 ID와 요청 번호.
- UI: seeded notification response에서 알림함 상세와 back navigation.
- Build 및 변경 범위 UI 게이트: `scripts/build-ios.sh`, `scripts/plan-ui-tests.py --base main` 결과에 따른 `scripts/test-ui.sh`.

## Risks

| Risk | Mitigation |
|------|------------|
| SwiftUI navigation registration 전 상세 push | Hub 표시 이후 task에서 한 번 yield 후 목적지 설정 |
| 이전 요청 재사용 | 요청 번호와 수동 진입 상태를 분리 |
