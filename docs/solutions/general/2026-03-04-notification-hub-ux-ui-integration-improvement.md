---
tags: [notification, swiftui, ux, ui, design-system, inbox, read-unread, delete]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Data/Persistence/NotificationInboxStore.swift
  - DUNE/Data/Persistence/NotificationInboxManager.swift
  - DUNETests/NotificationInboxStoreTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
---

# Solution: Notification Hub UX/UI 통합 개선 + 항상 이동 가능한 탭 정책

## Problem

Notification hub가 기본 `List + ContentUnavailableView` 형태로 남아 있어 Today 탭의 디자인 시스템(배경 wave, glass card, 카드 간 시각 계층)과 통일감이 낮았다.
또한 `route == nil` 알림은 탭해도 이동이 없어 사용자 입장에서 무반응처럼 보일 수 있었다.

### Symptoms

- 알림 화면이 다른 탭 UI 톤과 일관되지 않음
- 알림 타입 구분 아이콘이 없어 정보 인지 속도가 낮음
- read-all 외에 read/unread 전환, 삭제 관리 액션이 부족함
- 일부 알림 탭 시 상세 화면 이동이 발생하지 않음

### Root Cause

- 허브 UI가 초기 MVP 구현에 머물러 디자인 시스템 컴포넌트(`TabWaveBackground`, `InlineCard`, `StandardCard`) 적용이 미흡했다.
- 탭 동작이 `NotificationRoute` 존재 여부에만 의존해 `route == nil`인 알림의 default destination 규칙이 없었다.

## Solution

허브를 디자인 시스템 기반으로 재구성하고, 저장소/매니저에 read-unread-delete 액션을 확장했다.
탭 동작은 `route`가 있으면 기존 전역 라우팅을 유지하고, `route`가 없으면 인사이트 타입별 상세(AllDataView category)로 이동하도록 정책을 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | 요약 카드/빈 상태 CTA/카드형 row/아이콘/애니메이션/항상 이동 정책 추가 |
| `DUNE/Data/Persistence/NotificationInboxStore.swift` | update | `markUnread`, `delete`, `deleteAll` API 추가 |
| `DUNE/Data/Persistence/NotificationInboxManager.swift` | update | read-unread-delete facade 및 변경 notification 연결 |
| `DUNETests/NotificationInboxStoreTests.swift` | update | unread/delete/deleteAll 동작 회귀 테스트 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 허브 delete/settings 관련 AXID 상수 추가 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | update | 알림 허브 진입 후 Delete All 버튼 존재 검증 추가 |

### Key Code

```swift
// route가 없더라도 타입 기반 상세 화면으로 이동해 무반응 탭을 제거
private func handleTap(on item: NotificationInboxItem) {
    guard let opened = inboxManager.open(itemID: item.id) else {
        destination = .unavailable(itemID: item.id)
        return
    }

    guard opened.route == nil else { return }

    if let category = detailCategory(for: opened.insightType) {
        destination = .metric(category, itemID: opened.id)
    } else {
        destination = .unavailable(itemID: opened.id)
    }
}
```

## Prevention

### Checklist Addition

- [ ] 알림 허브/피드 화면은 디자인 시스템 배경 + 카드 패턴을 우선 적용했는가?
- [ ] 알림 탭 동작에 `route == nil` 기본 destination 규칙이 정의되어 있는가?
- [ ] read/unread + delete 관리 액션과 저장소 API가 함께 확장되었는가?
- [ ] 저장소 상태 변경 로직은 단위 테스트로 회귀를 막고 있는가?

### Rule Addition (if applicable)

기존 규칙(`testing-required`, `documentation-standards`) 범위 내에서 해결 가능하여 신규 rule은 추가하지 않았다.

## Lessons Learned

- 알림 UX는 “발송/수신”보다 “탭 후 행동 보장”이 체감 품질에 더 큰 영향을 준다.
- 허브 UI 리디자인 시 저장소 액션(read/unread/delete) 확장을 같이 처리해야 실제 사용성이 완성된다.
- `route` 기반 전역 라우팅을 유지하면서도 로컬 default destination을 병행하면 리스크를 낮추고 개선 속도를 높일 수 있다.
