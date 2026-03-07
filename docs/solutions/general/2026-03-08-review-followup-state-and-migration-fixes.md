---
tags: [review-followup, migration, app-group, cloud-sync, notification-routing, root-navigation]
date: 2026-03-08
category: general
severity: important
related_files:
  - Shared/WidgetScoreData.swift
  - DUNE/Data/Services/WidgetDataWriter.swift
  - DUNEWidget/WidgetScoreProvider.swift
  - DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift
  - DUNE/App/ContentView.swift
  - docs/corrections-active.md
related_solutions:
  - docs/solutions/general/2026-03-08-widget-app-group-file-storage.md
  - docs/solutions/general/2026-03-08-batch-fixes-summary.md
---

# Solution: Review Follow-up State and Migration Fixes

## Problem

배치 수정 리뷰에서, 기능은 동작하지만 배포 이후 상태 전이와 업그레이드 경로에서 회귀가 날 수 있는 세 가지 문제가 확인됐다.

### Symptoms

- widget shared storage를 file로 옮기면서 legacy App Group defaults를 읽지 않아 업데이트 직후 widget이 비어 보일 수 있었다.
- cloud sync opt-in bootstrap이 local `false`를 cloud에 seed해 다른 기기의 기존 opt-in 상태를 덮을 수 있었다.
- notification reward root push가 열린 상태에서 다른 알림 route가 오면 기존 root push가 남아 새 route를 가릴 수 있었다.

### Root Cause

- 저장소 전환을 "새 저장소 쓰기"만으로 처리하고 "기존 저장소 읽기"를 남기지 않았다.
- cross-device preference bootstrap에서 explicit user intent와 default false를 구분하지 않았다.
- 전역 `NavigationStack` path와 tab-based routing state를 별도 축으로 다루면서, non-push route 진입 시 root path reset 규칙이 없었다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Shared/WidgetScoreData.swift` | file-first load + legacy defaults fallback/migration helper 추가 | widget 데이터 업그레이드 경로 복구 |
| `DUNE/Data/Services/WidgetDataWriter.swift` | shared helper 기반 저장/로드로 정리 | 새 file storage와 migration 로직 재사용 |
| `DUNEWidget/WidgetScoreProvider.swift` | file miss 시 legacy payload 승격 경로 사용 | 앱 재실행 전에도 widget 데이터 유지 |
| `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift` | cloud seed를 explicit local opt-in(`true`)으로 제한 | 기본값 `false`의 cross-device overwrite 방지 |
| `DUNE/App/ContentView.swift` | notification plan별 root path policy 추가 | 기존 root push가 후속 알림 route를 가리지 않도록 정리 |
| `DUNETests/*` | migration/root-path/seed 정책 회귀 테스트 추가 | 같은 종류의 상태 회귀 재발 방지 |

### Key Code

```swift
static func cloudSeedValue(localValue: Bool?, cloudValue: Bool?) -> Bool? {
    guard cloudValue == nil else { return nil }
    guard localValue == true else { return nil }
    return true
}

static func rootPath(for plan: NotificationPresentationPlan) -> [NotificationPresentationDestination] {
    switch plan {
    case .push(let destination): [destination]
    case .openWorkoutInActivity, .openNotificationHub: []
    }
}
```

## Prevention

### Checklist Addition

- 저장소 backend를 바꿀 때는 "새 경로 write"와 함께 "legacy read + one-time migrate"를 같은 PR에서 처리한다.
- 기기 간 preference bootstrap에는 default state를 seed하지 말고, 명시적 opt-in/out 이벤트만 cloud state로 간주한다.
- root `NavigationStack`과 탭 라우팅을 같이 쓰는 화면은 non-push route에서 path reset policy를 pure helper로 고정한다.

### Rule Addition (if applicable)

`docs/corrections-active.md`에 다음 교정 규칙을 추가했다.

- storage backend 교체 시 legacy read/migration 경로를 남긴다.
- cross-device opt-in seed는 positive intent만 동기화한다.
- root push 라우터와 tab 라우터를 섞을 때 non-push 요청은 root path를 먼저 비운다.

## Lessons Learned

- 저장소 migration은 "새 구현이 동작한다" 수준으로 끝내면 안 되고, 업데이트 직후 기존 데이터가 살아남는지까지 봐야 한다.
- 기기 간 설정 bootstrap은 local default와 explicit user action을 분리하지 않으면 가장 늦게 업데이트된 기기가 정답을 덮어쓴다.
- SwiftUI 전역 path와 탭 라우팅을 같이 쓰는 구조는 pure helper로 path 정책을 못 박아야 후속 알림/딥링크 회귀를 막을 수 있다.
