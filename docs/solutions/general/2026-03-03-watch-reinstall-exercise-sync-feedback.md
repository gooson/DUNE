---
tags: [watchos, watchconnectivity, sync, reinstall, exercise-library, status-feedback]
date: 2026-03-03
category: solution
status: implemented
related_plans:
  - docs/plans/2026-03-03-watch-reinstall-sync-feedback.md
related_reviews:
  - docs/reviews/2026-03-03-watch-reinstall-sync-feedback-review.md
---

# Solution: Watch 재설치 후 Exercise Sync 지연/가시성 개선

## Problem

Apple Watch 앱 삭제 후 재설치 시 `exerciseLibrary`가 비어 있는 초기 구간에서 동기화가 늦게 체감되거나, 실제로는 아직 데이터를 못 받은 상태인데도 watch가 `synced`로 표시되어 사용자가 진행 상태를 알기 어려웠다.

근본 원인은 두 가지였다.

1. watch가 라이브러리 미수신 상태에서 iPhone에 능동 재요청하는 경로가 없었다.
2. watch `handleParsedContext`가 `exerciseLibrary` key 부재 시에도 `syncStatus = .synced`로 처리했다.

## Solution

watch pull-request + iPhone re-push 구조를 추가하고, sync 상태 표시를 실제 데이터 상태에 맞게 보정했다.

### 1) Watch에서 라이브러리 재요청 경로 추가

- `WatchConnectivityManager.requestExerciseLibrarySync(force:)` 추가
- activation/context/reachability 이벤트에서 라이브러리가 비어 있으면 재요청 시도
- 재요청 폭주 방지를 위해 8초 throttling 적용 (`WatchLibrarySyncRequestPolicy`)

### 2) iPhone에서 재요청 메시지 수신 처리

- `ParsedWatchIncomingMessage`를 도입해 `requestExerciseLibrarySync` bool key 파싱
- `didReceiveMessage` + `didReceiveUserInfo` 모두 동일 파싱 경로 사용
- 요청 수신 시 `syncExerciseLibraryToWatch()` 즉시 호출

### 3) sync 상태 가시성 보강

- watch 홈/퀵스타트 empty state 진입 시 `requestExerciseLibrarySync()` 호출
- `CarouselHomeView` empty 설명 문구를 `syncStatus` 기반으로 분기
  - `.syncing` → `"Syncing..."`
  - 그 외 → `"Open the DUNE app\non your iPhone to sync"`
- `exerciseLibrary` key가 없는 context를 빈 라이브러리 상태에서 `synced`로 표시하지 않도록 수정

## Changed Files

| File | Change |
|------|--------|
| `DUNEWatch/WatchConnectivityManager.swift` | 재요청 정책/상태 보정/자동 요청 트리거 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | request key 파싱 + userInfo 수신 + 즉시 re-sync |
| `DUNEWatch/Views/CarouselHomeView.swift` | empty 상태 설명 분기 + 재요청 트리거 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | empty 상태 재요청 트리거 |
| `DUNEWatchTests/WatchLibrarySyncRequestPolicyTests.swift` | 재요청 정책 유닛 테스트 추가 |
| `DUNETests/ParsedWatchIncomingMessageTests.swift` | iPhone 메시지 파싱 유닛 테스트 추가 |

## Verification

- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2' -only-testing:DUNEWatchTests/WatchLibrarySyncRequestPolicyTests -quiet` ✅
- `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DUNETests/ParsedWatchIncomingMessageTests -quiet` ✅
- `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -quiet` ✅

## Prevention

- WatchConnectivity context에 핵심 key(`exerciseLibrary`)가 없을 때는 상태를 `synced`로 간주하지 않는다.
- watch↔iPhone 신규 메시지 key 추가 시 `didReceiveMessage`와 `didReceiveUserInfo`를 동시에 반영한다.
- 재시도/재요청 경로에는 최소 간격(throttle)을 둬 전송 폭주를 방지한다.
