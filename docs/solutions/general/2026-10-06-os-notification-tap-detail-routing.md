---
tags: [notification, inbox, os-response, navigation-path, swiftui, cold-start]
date: 2026-10-06
category: general
status: implemented
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNETests/NotificationInboxManagerTests.swift
  - DUNETests/NotificationPresentationPlannerTests.swift
  - DUNEUITests/Full/NotificationRoutingRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-10-05-notification-landing-route-audit.md
---

# OS 알림 탭에서 알림함 상세까지 진입

## Problem

### Symptoms

- 경로가 없는 OS 알림을 탭하면 Today의 알림함까지만 열리고 원래 알림의 상세는 열리지 않았다.
- 오래된 알림 payload에 항목 ID와 route가 모두 없으면 알림함 항목만 읽음으로 표시되고 화면 이동 요청은 발생하지 않았다.

### Root Cause

`NotificationInboxManager`는 무경로 알림의 항목 ID를 담은 `.notificationHub` 요청을 보냈지만, 앱 라우터는 알림함 표시 신호만 사용했다. 알림함 행이 가진 유형별 상세 선택 로직에는 OS 탭의 항목 ID가 전달되지 않았다. 수동 알림함과 OS 알림함에 별도 Boolean/경로를 쓰면 연속 탭 시 경로가 충돌할 수 있었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `ContentView.swift` | Today `NavigationPath`에 항목 ID와 고유 요청 번호를 가진 알림함 목적지를 설정하고 수동 벨 버튼에도 같은 경로 사용 | cold start, 재탭, 수동 진입에서 하나의 내비게이션 소스 유지 |
| `NotificationHubView.swift` | 표시된 후 저장 항목을 ID로 조회하고 기존 행 탭 처리로 상세 push | 메시지·수치 상세 결정 로직 재사용 |
| `NotificationInboxManager.swift` | 단건 조회 API와 오래된 무경로 응답의 허브 fallback 추가 | 재정렬 비용과 무이동 응답 제거 |
| `DashboardView.swift` | 알림 상세 진입 중 자동 Morning Briefing 억제 | 브리핑 sheet가 상세의 뒤로 버튼을 가리지 않도록 처리 |
| 테스트 | 상태 전환·legacy fallback 단위 테스트와 seeded 응답 UI 테스트 추가 | 항목 ID 전달, 메시지·수면 상세, 뒤로 가기 회귀 확인 |

### Key Code

`NotificationPresentationState.apply`는 `.notificationHub` 요청 때 기존 Today 경로를 고유 `.notificationHub(itemID:requestID:)` 경로로 교체한다. Hub의 task는 저장 항목이 있는 경우에만 `handleTap(on:)`을 호출한다. 취소된 task는 처리 완료로 표시하지 않는다.

## Prevention

- 새 OS 알림 유형에는 항목 ID가 있는 경로와 없는 legacy 경로를 모두 검토한다.
- 수동 알림함과 시스템 알림함이 같은 `NavigationPath`를 사용하도록 유지한다.
- 연속 알림 탭은 이미 열린 상세 화면에서 새 항목으로 이동하는지 확인한다.
- seeded UI 테스트는 알림 응답 핸들러 진입 이후의 화면 이동을 검증한다. 실제 OS 알림 배너 탭은 별도 실기기 확인 대상이다.

## Lessons Learned

알림함으로 이동하는 요청에 항목 ID를 보존하지 않으면 알림함 내부의 상세 선택 로직을 실행할 수 없다. 경로를 하나로 통일하면 두 번째 알림 탭과 수동 진입이 같은 뒤로 가기 계약을 따른다.
