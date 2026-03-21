---
tags: [mac, cloudkit, refresh, throttle, feedback-loop, flickering, swiftdata, sync]
date: 2026-03-21
category: solution
status: implemented
---

# Mac CloudKit Refresh Storm (UI Flickering)

## Problem

맥앱에서 모든 탭(특히 Activity)이 무한 리프레시되며 UI가 계속 깜빡임.

### 증상

```
[AppRefreshCoordinator] Refresh triggered by cloudKitRemoteChange  ← 초당 5-6회 반복
[CloudMirroredSnapshot] Loaded — steps: 16215, ...  ← 동일 데이터 반복 로드
[ScoreRefreshService] Saved hourly snapshot at ...  ← 매번 SwiftData write
```

### 근본 원인: Feedback Loop

```
NSPersistentStoreRemoteChange notification
  → requestRefresh(source: .cloudKitRemoteChange)  [throttle bypass]
  → invalidateCache + yield refreshNeededStream
  → ContentView refreshSignal++ → VMs reload data
  → VMs call ScoreRefreshService.recordSnapshot()
  → context.save() → SwiftData write → CloudKit sync
  → NSPersistentStoreRemoteChange  ← LOOP
```

commit `8f1503f3`에서 `cloudKitRemoteChange`가 60초 throttle을 완전히 bypass하도록 변경.
Mac에서 CloudKit이 주 데이터 경로이므로 지연을 없애려는 의도였으나,
ScoreRefreshService의 snapshot save → CloudKit sync → notification 피드백 루프를 유발.

## Solution

`cloudKitRemoteChange`에 전용 짧은 throttle (5초)을 적용.

### 핵심 변경

`AppRefreshCoordinatorImpl`에 `lastCloudKitRefreshDate` 별도 추적 + `cloudKitThrottleInterval` (기본 5초):

- CloudKit 소스 → 전용 5초 throttle 적용 (일반 60초 throttle과 독립)
- 비-CloudKit 소스 → 기존 60초 throttle 유지
- `lastRefreshDate`는 모든 소스에서 업데이트 (중복 refresh 방지)
- `lastCloudKitRefreshDate`는 `.distantPast`로 초기화 → 첫 CloudKit notification 즉시 통과

### 변경 파일

| 파일 | 변경 |
|------|------|
| `DUNE/Data/Services/AppRefreshCoordinatorImpl.swift` | 전용 CloudKit throttle 추가 |
| `DUNETests/AppRefreshCoordinatorTests.swift` | 5개 CloudKit throttle 테스트 추가/수정 |

## Prevention

### CloudKit + SwiftData 환경에서 refresh bypass 금지

`NSPersistentStoreRemoteChange`에 반응하는 refresh 경로에서:
1. **절대 throttle을 완전히 bypass하지 않는다** — SwiftData write가 CloudKit sync를 트리거하여 feedback loop 가능
2. **전용 짧은 throttle을 사용한다** — 일반 throttle보다 짧되, feedback loop 주기(~1초)보다 긴 간격
3. **동일 데이터 여부를 확인하여 불필요한 write를 방지한다** — ScoreRefreshService의 upsert가 이미 이를 부분적으로 수행

### 규칙 후보

> CloudKit + SwiftData 환경에서 `NSPersistentStoreRemoteChange` 기반 refresh는 반드시 throttle을 적용한다. bypass는 feedback loop를 유발하므로 금지.

## Lessons Learned

1. CloudKit sync는 **로컬 SwiftData write도 remote change로 돌아올 수 있다** — 다른 디바이스뿐 아니라 자기 자신의 write도 sync 경로를 통해 notification을 재발행
2. throttle bypass는 "이 소스는 중요하니까"라는 직관적 판단이 위험할 수 있음 — bypass의 부작용(feedback loop)이 원래 문제(지연)보다 심각
3. 전용 throttle 분리는 기존 throttle 인프라를 그대로 활용하면서 소스별 정책을 독립적으로 관리할 수 있는 좋은 패턴
