---
tags: [notification, swiftui, routing, metric-detail, charts]
category: general
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNETests/DomainModelCoverageTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/general/2026-03-04-notification-hub-ux-ui-integration-improvement.md
---

# Solution: Notification Hub 탭 시 차트 상세 라우팅

## Problem

Notification Hub에서 알림을 탭할 때 `route == nil` 항목은 `AllDataView`(데이터 리스트)로 이동했다.
요구사항은 리스트가 아니라 차트가 포함된 상세 화면으로 이동해 즉시 맥락을 확인하는 것이다.

### Symptoms

- 알림 탭 후 리스트 화면으로 이동해, 인사이트 확인에 한 단계가 더 필요함
- "해당 기록의 상세"를 기대한 사용자 흐름과 실제 이동 화면이 불일치

### Root Cause

`NotificationHubView`의 기본 destination 정책이 `HealthMetric.Category -> AllDataView`로 고정되어 있었고,
알림 본문을 상세 metric 초기값으로 변환하는 계층이 없었다.

## Solution

Notification Hub 내부에 `NotificationHubMetricResolver`를 도입해
알림 항목을 `HealthMetric`으로 변환한 뒤 `MetricDetailView`로 push하도록 변경했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | `HubDestination.metric` payload를 `HealthMetric`으로 확장하고 `MetricDetailView`로 라우팅 |
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | update | 알림 본문 숫자/수면 시간 파싱 기반 `NotificationHubMetricResolver` 추가 |
| `DUNETests/DomainModelCoverageTests.swift` | update | category 매핑, 숫자 파싱, 수면 파싱, fallback 동작 단위 테스트 추가 |

### Key Code

```swift
if let metric = NotificationHubMetricResolver.metric(for: opened) {
    destination = .metric(metric, itemID: opened.id)
}

.navigationDestination(item: $destination) { target in
    switch target {
    case .metric(let metric, _):
        MetricDetailView(metric: metric)
    ...
    }
}
```

## Prevention

알림 탭 destination 정책은 "리스트"와 "차트 상세"를 명시적으로 구분하고,
요구사항이 상세 맥락 중심일 때는 category-only 라우팅 대신 typed payload(`HealthMetric`)를 사용한다.

### Checklist Addition

- [ ] Notification Hub 탭 기본 destination이 최신 UX 정책(리스트 vs 차트 상세)과 일치하는가?
- [ ] `route == nil` 알림도 사용자 기대 동작(명시적 상세 또는 fallback)이 보장되는가?
- [ ] 알림 본문 파싱 실패 시에도 크래시 없이 fallback 값으로 진입 가능한가?

### Rule Addition (if applicable)

없음. 기존 navigation/testing 규칙 범위 내에서 해결 가능.

## Lessons Learned

- 알림 UX에서 중요한 것은 "탭 후 즉시 의미 있는 화면"이며, 기본 destination의 정보 밀도가 체감 품질을 좌우한다.
- 도메인 route를 확장하지 않더라도 Presentation 계층 변환기(`Notification -> HealthMetric`)로 요구사항을 빠르게 충족할 수 있다.
