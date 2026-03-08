---
topic: bedtime-reminder-lead-time-setting
date: 2026-03-09
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
  - docs/solutions/performance/2026-03-08-review-triage-debounce-and-caching.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: Bedtime Reminder Lead Time Setting

## Context

일반 취침 알림은 최근 평균 취침 시간 기준으로 동작하지만, 현재 리드 타임이 2시간으로 고정되어 있다.
사용자가 30분, 1시간, 2시간 중 하나를 직접 선택할 수 있어야 하며, 선택값은 persistence되어야 한다.
또한 기존 scheduler에는 foreground 진입 과호출을 막기 위한 30분 debounce가 있어서, 설정 변경 시에는 별도의 즉시 재스케줄 경로가 필요하다.

## Requirements

### Functional

- Settings의 Notification 섹션에서 bedtime reminder 리드 타임을 선택할 수 있다.
- 선택값은 앱 재실행 후에도 유지된다.
- 선택값 변경 직후 pending bedtime reminder가 새 리드 타임으로 다시 예약된다.
- 기본값은 기존과 동일하게 2시간이다.
- 선택값별 trigger time 계산이 단위 테스트로 검증된다.

### Non-functional

- 기존 foreground debounce는 유지하여 불필요한 HealthKit 재조회 폭증을 막는다.
- 새 사용자 대면 문자열은 `Localizable.xcstrings`의 en/ko/ja 3개 언어를 모두 채운다.
- Presentation에서 사용하는 enum 라벨은 `displayName` 패턴으로 localized string을 제공한다.

## Approach

`BedtimeReminderLeadTime` enum을 공용 모델로 도입하고, UI와 scheduler가 같은 storage key를 공유하도록 만든다.
Scheduler는 `refreshSchedule(force:)` 경로를 추가해 명시적 설정 변경에서는 debounce를 우회하고, foreground/launch refresh는 기존 throttle을 그대로 사용한다.
Settings UI는 bedtime reminder toggle 아래에 lead time picker를 추가하고, toggle/lead time 변경 모두에서 `force: true`로 재스케줄한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| UI에서만 lead time을 들고 scheduler에는 분 단위만 직접 전달 | 변경 범위가 작아 보임 | launch/foreground refresh와 source of truth가 분리되고 persistence/read path가 중복됨 | 미채택 |
| UserDefaults store 클래스를 새로 만들기 | persistence 캡슐화가 명확함 | 단순 enum 설정 1개에 비해 구조가 과함 | 미채택 |
| 공용 enum + scheduler force refresh | 저장/표시/테스트 기준이 하나로 통일되고 debounce 우회가 명시적임 | enum/extension 파일이 추가됨 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/BedtimeReminderLeadTime.swift` | Add | 리드 타임 enum과 storage key/default/minutes 정의 |
| `DUNE/Presentation/Shared/Extensions/BedtimeReminderLeadTime+View.swift` | Add | Settings UI용 localized `displayName` 제공 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | Edit | lead time persistence 반영, `refreshSchedule(force:)` 추가, trigger 계산 변경 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | Edit | lead time 선택 UI 추가 및 즉시 재스케줄 연결 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | Edit | 리드 타임별 trigger time 및 force refresh 회귀 테스트 추가 |
| `Shared/Resources/Localizable.xcstrings` | Edit | picker label/option 문자열 번역 추가 |
| `todos/103-ready-p3-bedtime-reminder-lead-time-setting.md` | Edit | 최종 완료 시 status 갱신 |

## Implementation Steps

### Step 1: Introduce shared lead-time model

- **Files**: `DUNE/Domain/Models/BedtimeReminderLeadTime.swift`, `DUNE/Presentation/Shared/Extensions/BedtimeReminderLeadTime+View.swift`
- **Changes**: `30m / 1h / 2h` 옵션을 enum으로 정의하고, UI에서 바로 쓸 localized `displayName` extension을 추가한다.
- **Verification**: enum raw value가 persistence에 적합하고 default가 2시간인지 확인한다.

### Step 2: Update scheduler for persisted lead time and forced refresh

- **Files**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
- **Changes**: UserDefaults에서 lead time을 읽어 trigger minutes를 계산하고, explicit settings change용 `force` 파라미터로 debounce를 우회한다.
- **Verification**: 기존 launch/foreground 호출은 `force: false`로 유지되고, explicit 변경 경로는 `force: true`로 재스케줄 가능한지 확인한다.

### Step 3: Add settings UI and immediate reschedule wiring

- **Files**: `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**: bedtime reminder toggle 아래에 picker를 추가하고, toggle/lead time 변경 시 `Task { await BedtimeReminderScheduler.shared.refreshSchedule(force: true) }`를 호출한다.
- **Verification**: UI 문자열이 모두 localization rule을 따르고, disabled 상태에서도 lead time 값은 유지되는지 확인한다.

### Step 4: Extend regression tests

- **Files**: `DUNETests/BedtimeReminderSchedulerTests.swift`
- **Changes**: parameterized test로 30/60/120분 옵션별 trigger 시간을 검증하고, 최근 refresh 이후 설정이 바뀌어도 `force: true`에서 새 요청이 다시 생성되는지 검증한다.
- **Verification**: Swift Testing 기준으로 모든 새 분기와 엣지 케이스를 커버한다.

## Edge Cases

| Case | Handling |
|------|----------|
| lead time key가 없거나 손상됨 | enum decode 실패 시 `.twoHours` 기본값으로 fallback |
| 사용자가 알림을 끈 상태에서 lead time만 바꿈 | `force: true` 경로에서도 disabled guard가 우선 적용되어 pending reminder만 제거 |
| 앱이 방금 foreground refresh를 수행한 직후 설정을 바꿈 | explicit settings change는 `force: true`로 debounce 우회 |
| 최근 수면 데이터가 없음 | 새 lead time과 무관하게 pending reminder 제거 후 미예약 |

## Testing Strategy

- Unit tests: `BedtimeReminderSchedulerTests`에 리드 타임별 trigger time, disabled/no-data, force refresh bypass를 추가한다.
- Integration tests: `scripts/build-ios.sh`와 가능하면 대상 테스트 실행으로 회귀를 확인한다.
- Manual verification: Settings > Notifications에서 Bedtime Reminder lead time을 바꾼 뒤 pending request가 즉시 다시 예약되는 흐름을 확인한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| force refresh가 foreground debounce 보호를 깨뜨림 | Low | Medium | `force` 기본값을 `false`로 두고 settings change에서만 사용 |
| enum/string localization 누락 | Medium | Medium | 새 문자열을 xcstrings en/ko/ja에 동시 추가하고 review에서 localization 체크 |
| AppStorage enum raw value 변경 시 기존 값 호환성 깨짐 | Low | Medium | raw value를 minutes로 고정하고 fallback default 제공 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 scheduler/test 구조가 이미 갖춰져 있어, 공용 enum과 force-refresh 경로를 추가하는 수술적 변경으로 요구사항을 충족할 수 있다.
