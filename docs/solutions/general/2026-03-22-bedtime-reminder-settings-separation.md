---
tags: [sleep, notification, reminder, settings, apple-watch, posture, ui-test]
category: general
date: 2026-03-22
severity: important
related_files: [DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/Domain/Models/BedtimeReminderLeadTime.swift, DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift, DUNETests/BedtimeReminderSchedulerTests.swift, DUNEUITests/Smoke/SettingsSmokeTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions: [docs/solutions/general/2026-03-22-watch-bedtime-reminder-restoration.md, docs/solutions/general/2026-03-09-bedtime-reminder-lead-time-setting.md, docs/solutions/general/2026-03-08-general-bedtime-reminder.md]
---

# Solution: 일반 취침 미리 알림과 워치 취침 미리 알림 설정 분리

## Problem

취침 관련 설정이 일반 취침 미리 알림, 워치 취침 미리 알림, 자세 리마인더를 한 덩어리로 섞어 노출하면서 실제 기능 의미와 UI 구조가 어긋났다.
이 과정에서 일반 취침 미리 알림의 2시간 기본값과 워치 취침 미리 알림의 1시간 기본값이 분리되어야 한다는 요구도 함께 보호해야 했다.

### Symptoms

- 일반 취침 미리 알림과 워치 취침 미리 알림이 서로 다른 섹션에 있거나 같은 의미로 덮여 보였다.
- 설정 라벨에 `Apple Watch`가 그대로 드러나 row가 길어지고 줄바꿈이 생길 수 있었다.
- 자세 리마인더가 일반 알림과 섞여 있어, 사용자가 “취침 설정”과 “자세 설정”을 별개로 이해하기 어려웠다.

### Root Cause

- 취침 알림 기능이 일반용/워치용으로 다시 갈라졌지만, Settings 표면은 이전 단일 구조를 기준으로 계속 누적 수정되었다.
- 일반 취침 알림과 워치 취침 알림이 같은 설정 surface에 기대면서 storage key, 기본값, 라벨 문맥이 섞일 여지가 있었다.
- UI 변경 이후 실제 설정 화면을 자동으로 확인하는 smoke coverage가 부족해, 레이아웃 붕괴나 섹션 구조 회귀가 바로 드러나지 않았다.

## Solution

일반 취침 미리 알림과 워치 취침 미리 알림을 스케줄러/저장 키/기본값 기준으로 분리하고,
Settings에서는 `알림 / 취침 / 자세` 세 섹션으로 구조를 재정리했다.
취침 섹션 안에서는 워치 row를 `Watch Reminder` 계열의 짧은 라벨로 줄여 `Apple` 문구를 제거했고,
UI smoke 테스트로 일반/워치/자세 row 존재와 실제 화면 스크린샷을 함께 고정했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | 일반 취침 스케줄러와 `AppleWatchBedtimeReminderScheduler`를 분리하고 공통 helper를 추출 | 기능 책임과 조건을 분리하면서 계산 로직 중복을 줄임 |
| `DUNE/Domain/Models/BedtimeReminderLeadTime.swift` | 일반/워치 storage key 및 기본값을 분리 | 일반 2시간, 워치 1시간 요구사항을 독립적으로 보존 |
| `DUNE/App/DUNEApp.swift`, `DUNE/App/ContentView.swift`, `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | 앱 시작/복귀/수면 observer 시 일반/워치 스케줄러를 모두 refresh | one-shot reminder가 최신 수면 데이터 기준으로 재무장되도록 보장 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | `Notifications`, `Bedtime`, `Posture` 섹션으로 재구성하고 워치 row 라벨 축약 | 사용자 관점의 정보 구조와 레이아웃 안정성 확보 |
| `Shared/Resources/Localizable.xcstrings` | `Bedtime`, `Watch Reminder`, `Watch Reminder Lead Time` 등 새 문자열 추가 | 설정 UI 문구를 짧게 유지하면서 en/ko/ja 로컬라이즈 보장 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | 일반/워치 스케줄러를 각각 회귀 테스트로 분리 | 기본값, skip 조건, authorization 회복 경로 보호 |
| `DUNEUITests/Helpers/UITestHelpers.swift`, `DUNEUITests/Smoke/SettingsSmokeTests.swift` | 새 AXID와 설정 smoke test 추가 | 섹션 구조/row 노출/UI 회귀를 자동 검증 |

### Key Code

```swift
private var bedtimeReminderSection: some View {
    Section {
        Toggle(isOn: $isBedtimeReminderEnabled) {
            Label("Bedtime Reminder", systemImage: "moon.stars.fill")
        }

        Picker(selection: $bedtimeReminderLeadTime) { ... } label: {
            Label("Reminder Lead Time", systemImage: "timer")
        }

        Toggle(isOn: $isAppleWatchBedtimeReminderEnabled) {
            Label("Watch Reminder", systemImage: "applewatch")
        }

        Picker(selection: $appleWatchBedtimeReminderLeadTime) { ... } label: {
            Label("Watch Reminder Lead Time", systemImage: "timer")
        }
    } header: {
        Text("Bedtime")
    }
}
```

## Prevention

기능이 다시 분리되면 설정 표면도 같은 기준으로 함께 재설계해야 한다.
특히 시간 기반 알림 기능은 스케줄러 분리만으로 끝나지 않고, storage key, 기본값, 설정 문맥, UI smoke를 하나의 계약으로 묶어야 회귀를 막을 수 있다.

### Checklist Addition

- [ ] 알림 기능을 일반용/디바이스용으로 분리할 때 storage key와 기본값을 공유하지 않는지 확인한다.
- [ ] Settings에서 긴 디바이스 명칭이 row wrap를 만들면 섹션 문맥을 활용해 라벨을 줄일 수 있는지 먼저 검토한다.
- [ ] 설정 구조 변경 시 UI smoke와 스크린샷 증빙을 함께 갱신한다.

### Rule Addition (if applicable)

현재는 기존 `localization`, `testing-required`, `ui-testing` 규칙 범위에서 관리 가능하므로 신규 rule 추가는 보류한다.

## Lessons Learned

- 설정 surface는 실제 feature boundary를 그대로 반영해야 사용자 기대와 코드 구조가 같이 안정된다.
- 일반 알림과 워치 알림처럼 비슷해 보이는 기능도 storage key와 default를 공유하면 요구사항이 쉽게 섞인다.
- UI 텍스트 수정만큼이나 “실제 스크린샷 확인”이 중요하며, smoke test에 attachment를 남기면 이후 회귀를 훨씬 빨리 잡을 수 있다.
