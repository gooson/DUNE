---
tags: [notification, routing, navigation, posture, bedtime, inbox, regression]
date: 2026-10-05
category: general
status: implemented
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNE/Data/Services/DailyDigestScheduler.swift
  - DUNE/Data/Services/PostureReminderScheduler.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Presentation/Posture/PostureHistoryView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-08-tab-scoped-notification-push-preserves-navigation-bar.md
  - docs/solutions/general/2026-10-06-os-notification-tap-detail-routing.md
---

# 알림별 랜딩 경로와 알림함 푸시 일치

## Problem

### Symptoms

- 알림함의 취침 전 Apple Watch 알림을 누르면 현재 알림함 위로 상세가 쌓이지 않고 Wellness 탭으로 이동했다.
- 주간 자세 점검 알림은 시스템 알림을 누르면 이동이 없고, 알림함 행을 누르면 `Destination Unavailable`이 표시됐다.
- 일일 요약 알림은 시스템 탭에서 이동이 없었고, Life 체크리스트 알림은 알림함에서 목적지를 찾지 못했다.
- 합쳐진 체성분 알림은 여러 측정치를 담아도 하나의 수치 상세로 열릴 수 있었다.

### Root Cause

알림 발송 payload, 저장된 `NotificationRoute`, 시스템 알림 응답, 알림함 행의 목적지 선택이 서로 다른 규칙을 사용했다. 취침 알림의 `sleepDetail`은 앱 전체 라우터에서 Wellness 탭 전환으로 처리했으며, 자세 알림에는 routeKind가 없었다. 자세·일일 요약·체크리스트는 수치 상세로 변환할 수 없는 유형인데 알림함에 별도 화면이 없었다.

## Solution

- `postureAssessment` 경로를 예약 payload부터 앱 라우터까지 연결했다. 저장된 무경로 자세 알림도 유형을 통해 같은 경로로 해석한다.
- 알림함 안에서는 취침 상세, 자세 기록, 보상 상세를 현재 `NavigationStack`에 로컬 푸시한다. 자세 기록 화면에서 촬영을 시작할 수 있다.
- 수치 상세가 없는 일일 요약·체크리스트 알림은 알림 내용을 보여 주는 상세 화면으로 연결한다. 새 일일 요약 payload에는 알림함 경로를 명시하고, 이전 무경로 payload도 같은 경로로 해석한다.
- 여러 줄로 합쳐진 체성분 알림은 첫 수치만 뽑아 잘못된 수치 상세를 만들지 않고 전체 알림 내용을 보여 준다.
- 항목별 경로 결정은 `NotificationInboxManager.resolvedRoute(for:)`에 모아 시스템 탭과 알림함의 해석이 어긋나지 않게 했다.
- 이후 OS 탭의 `.notificationHub` 경로는 항목 ID를 보존해 알림함을 표시한 뒤 해당 행의 상세까지 자동으로 연다. 수동 알림함과 같은 Today 경로를 사용한다.

## Prevention

- 새 예약 알림 유형을 추가할 때 payload, `resolvedRoute`, 앱 라우터, 알림함 로컬 목적지, 기존 무경로 항목을 한 표로 검토한다.
- 시스템 알림 응답의 `itemID` 유무 두 경로와 알림함 행 탭을 각각 테스트한다.
- 목적지가 없는 정상 알림 유형을 오류 화면으로 보내지 않고, 사용자가 읽을 수 있는 상세 또는 기능 화면을 제공한다.
- iPhone의 seeded UI 테스트로 알림함 → 상세 → 뒤로 가기와 탭 선택 상태를 확인한다.

## Lessons Learned

알림 payload가 유효해도 시스템 알림과 앱 안의 알림함은 서로 다른 내비게이션 진입점을 사용한다. 두 진입점의 경로 계약과 오래된 저장 항목을 함께 검증해야 사용자가 보는 랜딩이 일치한다.
