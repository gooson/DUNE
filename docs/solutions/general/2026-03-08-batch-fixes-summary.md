---
tags: [branch-summary, sync, notifications, watchos, widget, consistency, keyboard, theme]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/App/ContentView.swift
  - DUNE/App/DUNEApp.swift
  - DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift
  - DUNE/Data/Services/WidgetDataWriter.swift
  - DUNE/Data/WatchConnectivity/WatchSessionManager.swift
  - DUNE/Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Presentation/Exercise/Components/WorkoutShareService.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Life/LifeView.swift
  - DUNE/Presentation/WhatsNew/WhatsNewView.swift
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatch/WatchConnectivityManager.swift
  - DUNEWidget/WidgetScoreProvider.swift
  - Shared/WidgetScoreData.swift
related_solutions:
  - docs/solutions/general/2026-03-08-consistency-detail-healthkit-history-parity.md
  - docs/solutions/general/2026-03-08-consistency-weekday-duplicate-foreach-id.md
  - docs/solutions/general/2026-03-08-invalid-sf-symbol-figure-rowing.md
  - docs/solutions/general/2026-03-08-life-context-menu-deferred-actions.md
  - docs/solutions/general/2026-03-08-notification-hub-summary-inline-navigation-link-wrap.md
  - docs/solutions/general/2026-03-08-sakura-suggested-exercise-title-contrast.md
  - docs/solutions/general/2026-03-08-share-image-renderer-proposed-size.md
  - docs/solutions/general/2026-03-08-watch-crown-focus-host-without-scrollview.md
  - docs/solutions/general/2026-03-08-watch-summary-effort-button-hit-area.md
  - docs/solutions/general/2026-03-08-watch-template-sync-background-request.md
  - docs/solutions/general/2026-03-08-whatsnew-sheet-list-blank-simulator.md
  - docs/solutions/general/2026-03-08-widget-app-group-file-storage.md
  - docs/solutions/general/2026-03-08-workout-keyboard-toolbar-constraint-warning.md
  - docs/solutions/general/2026-03-08-review-followup-state-and-migration-fixes.md
  - docs/solutions/testing/2026-03-08-actions-unit-test-timeout-and-locale-drift.md
---

# Solution: 2026-03-08 Batch Fixes Summary

## Problem

동기화, 알림 라우팅, watch 요약 입력, widget 공유 저장소, 테마 가독성, simulator-specific UI warning이 여러 화면에서 동시에 드러났다.

### Symptoms

- watch 운동 시작/종료 및 template sync가 `WatchConnectivity` 타임아웃 또는 session unavailable 로그를 남김
- Mac 앱이 iPhone에서 켠 cloud sync 상태를 읽지 못해 빈 화면을 표시함
- Notifications에서 탭 전환/다중 frame update/summary 줄바꿈 같은 라우팅 및 레이아웃 문제가 발생함
- Consistency 상세가 실제 연속 기록이 있어도 0일, 기록 없음으로 표시됨
- Workout share 렌더링에서 `1320x0 image slot` 로그가 발생함
- Watch crown/effort sheet, Life context menu, What’s New 시트, keyboard accessory 등에서 simulator-visible warning이 반복됨
- Sakura theme에서 추천 운동 카드 제목이 배경과 섞여 보이지 않음

### Root Cause

단일 원인이 아니라, 다음 성격의 독립 이슈가 누적돼 있었다.

- **Transport 선택 불일치**: 즉시성/백그라운드 성격이 다른 watch sync 요청이 같은 `sendMessage` 경로를 사용함
- **설정 해석 불일치**: iOS와 Mac이 cloud sync preference를 같은 소스에서 읽지 않음
- **화면별 계산 드리프트**: Activity 카드와 상세 화면이 다른 입력 소스를 기준으로 streak를 계산함
- **Simulator/runtime 민감 구현**: keyboard accessory toolbar, inline `NavigationLink`, `List`-based sheet, App Group defaults blob 등이 simulator에서 warning/noise를 유발함
- **Theme token 오용**: decorative text token이 밝은 card surface의 핵심 제목에 사용됨

## Solution

브랜치 범위 `c6ffc864` → `b4003f29` 에서 문제를 다음 묶음으로 정리했다.

### Changes Made

| Area | Files | Change | Reason |
|------|-------|--------|--------|
| Watch sync | `DUNEWatch/WatchConnectivityManager.swift`, `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | workout start/end는 `applicationContext`, template sync는 `transferUserInfo`로 분리 | interactive timeout/session unavailable 제거 |
| Mac sync | `DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift`, `DUNE/App/DUNEApp.swift`, `DUNE/Presentation/Shared/CloudSyncConsentView.swift`, `DUNE/Presentation/Settings/SettingsView.swift` | local defaults와 iCloud KVS를 함께 해석하도록 변경 | iPhone에서 켠 sync 상태를 Mac이 읽도록 보정 |
| Widget shared storage | `Shared/WidgetScoreData.swift`, `DUNE/Data/Services/WidgetDataWriter.swift`, `DUNEWidget/WidgetScoreProvider.swift` | App Group `UserDefaults` blob을 App Group file로 전환 | simulator CFPreferences noise 및 static suite access 회피 |
| Notification routing | `DUNE/App/ContentView.swift`, `DUNE/Presentation/Activity/ActivityView.swift`, `DUNE/Presentation/Dashboard/NotificationHubView.swift` | reward 알림은 current screen push, frame warning 제거, summary settings 라우팅 정리 | 탭 전환 제거, navigation warning 제거, compact 레이아웃 안정화 |
| Consistency detail | `DUNE/Presentation/Activity/Consistency/ConsistencyDetailView.swift`, `DUNE/Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift` | HealthKit workout history와 manual record를 병합해 streak/history 계산 | Activity 카드와 상세 화면 계산 parity 확보 |
| Workout share/input | `DUNE/Presentation/Exercise/Components/WorkoutShareService.swift`, `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | share renderer size 명시, keyboard toolbar를 bottom inset dismiss bar로 교체 | 0-height render 방지, accessory keyboard constraint warning 제거 |
| Watch summary UX | `DUNEWatch/Views/SetInputSheet.swift`, `DUNEWatch/Views/SessionSummaryView.swift` | crown host 재구성, effort card hit area 확대, 12초 규칙 유지한 sheet 안정화 | crown warning 제거, 마지막 세트 후 effort 입력 안정화 |
| UI polish | `DUNE/Presentation/Life/LifeView.swift`, `DUNE/Presentation/WhatsNew/WhatsNewView.swift`, `DUNE/Presentation/Shared/Extensions/BodyPart+View.swift`, `DUNE/Presentation/Shared/Extensions/MuscleGroup+View.swift`, `DUNE/Presentation/Activity/Components/SuggestedExerciseRow.swift` | context menu defer, What’s New `List` 제거, invalid SF Symbol 수정, Sakura title contrast 수정 | simulator white screen/warning/noise 제거 및 테마 가독성 개선 |
| Tests | `DUNETests/*`, `DUNEWatchTests/*`, `DUNEUITests/Smoke/DashboardSmokeTests.swift` | focused unit test와 smoke assertion 추가/수정 | transport policy, widget file path, consistency parity, share rendering, notification hub 구조 회귀 방지 |

### Covered Commits

- `c6ffc864` Stabilize sync, notification routing, and share rendering
- `e172cd3c` Fix consistency detail parity and UI warnings
- `381d554b` Defer Life context menu row mutations
- `ad440980` fix: stabilize whats new sheet and watch crown hosts
- `6c94cf50` fix: stabilize watch effort summary sheet
- `63dc3408` fix: stabilize connectivity, widget storage, and notification hub
- `b4003f29` fix: improve exercise card contrast and keyboard input UX

### Key Code

```swift
// Watch template sync: background-only transport
transferUserInfo(["kind": "workoutTemplateSyncRequest"])

// Workout keyboard dismiss: inset bar instead of keyboard accessory toolbar
.safeAreaInset(edge: .bottom, spacing: 0) {
    if isInputFieldFocused {
        keyboardDismissBar
    }
}

// Widget shared storage: App Group file instead of UserDefaults blob
let fileURL = WidgetScoreData.sharedFileURL()
try jsonData.write(to: fileURL, options: .atomic)
```

## Prevention

### Checklist Addition

- [ ] watch sync 요청은 interactive 성격과 background 성격을 먼저 구분했는가?
- [ ] Mac/iOS가 같은 preference를 같은 source set으로 해석하는가?
- [ ] 카드 요약과 상세 화면이 같은 입력 데이터 집합을 기준으로 계산하는가?
- [ ] light/material surface의 핵심 제목이 decorative theme token을 사용하고 있지 않은가?
- [ ] `ToolbarItemGroup(placement: .keyboard)` 없이 dismiss UX를 구현할 수 있는가?
- [ ] App Group 단일 blob 공유에 `UserDefaults(suiteName:)`가 정말 필요한가?

### Rule Addition (if applicable)

이번 배치에서 교정 규칙을 `docs/corrections-active.md`에 추가했다.

- 카드 내부 작은 설정 이동은 inline `NavigationLink`보다 명시적 버튼 라우팅 우선
- 밝은/반투명 카드의 핵심 제목에는 decorative theme text 사용 금지
- numeric input dismiss는 keyboard accessory toolbar보다 inset bar 우선

## Lessons Learned

- simulator 로그는 모두 무시할 수 있는 noise가 아니지만, 원인을 나눠 보면 실제 앱 수정 대상과 시스템 noise를 구분할 수 있다.
- 같은 기능이라도 카드/상세/플랫폼별로 계산 소스를 조금씩 다르게 두면 결국 parity bug로 드러난다.
- SwiftUI에서는 작은 구현 선택 하나(`NavigationLink` in card, keyboard toolbar, `List` in sheet)가 simulator 안정성과 레이아웃 품질에 큰 차이를 만든다.
- batch fix를 할 때는 개별 solution note를 남긴 뒤, 마지막에 branch-level summary를 한 번 더 두는 편이 검색성과 회고에 유리하다.
