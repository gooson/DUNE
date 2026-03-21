---
topic: bedtime-notification-section-regroup
date: 2026-03-22
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-22-watch-bedtime-reminder-restoration.md
  - docs/solutions/general/2026-03-09-bedtime-reminder-lead-time-setting.md
  - docs/solutions/general/2026-03-08-general-bedtime-reminder.md
related_brainstorms: []
---

# Implementation Plan: Bedtime Notification Section Regroup

## Context

Settings 화면에서 일반 취침 미리 알림과 워치 취침 미리 알림이 서로 다른 섹션에 흩어져 있고,
자세 리마인더도 일반 알림과 섞여 있어 사용자가 의도한 정보 구조와 어긋난다.
또한 워치 관련 라벨이 길어 UI 줄바꿈을 유발할 수 있으므로, 섹션 맥락을 활용해 라벨을 짧게 정리해야 한다.

## Requirements

### Functional

- 일반 취침 미리 알림 2개 row와 워치 취침 미리 알림 2개 row를 같은 별도 섹션으로 이동한다.
- 자세 리마인더를 별도 섹션으로 분리한다.
- 설정 UI 문구에서 `Apple`을 제거한다.
- 기존 접근성 식별자와 재스케줄 동작은 유지한다.

### Non-functional

- iPhone/iPad에서 row 라벨이 과도하게 줄바꿈되지 않도록 한다.
- 기존 로컬라이제이션 규칙(en/ko/ja)을 유지한다.
- UI 구조 변경에 맞춰 smoke test를 같이 유지한다.

## Approach

`NotificationSettingsSection` 내부 `Section` 구성을 세 갈래로 재배치한다.
기존 `Notifications` 섹션에는 건강 알림과 운동 기록만 남기고,
새 `Bedtime` 섹션에 일반/워치 취침 미리 알림 row를 함께 둔다.
워치 row는 section context가 이미 `Bedtime`이므로 `Watch Reminder` 계열의 짧은 라벨을 사용한다.
`Posture` 섹션을 별도 추가해 자세 리마인더를 분리한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 알림 섹션 내부에서 순서만 조정 | 최소 수정 | 정보 구조 요구사항을 만족하지 못함 | 기각 |
| 취침/워치를 각각 별도 섹션 유지 | 의미 구분 명확 | 사용자가 요청한 “취침 두개 같이”와 불일치 | 기각 |
| 취침 섹션 하나로 통합 + 워치 라벨 축약 | 구조와 레이아웃 요구를 동시에 만족 | 신규 문자열 2~3개 추가 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | modify | 알림/취침/자세 섹션 재구성 및 워치 row 라벨 축약 |
| `Shared/Resources/Localizable.xcstrings` | modify | `Bedtime`, `Watch Reminder`, `Watch Reminder Lead Time` 문자열 추가 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | modify | 재구성된 설정 화면 smoke assertion 갱신 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | modify | 필요 시 자세 row AXID 추가 |

## Implementation Steps

### Step 1: Settings 섹션 구조 재배치

- **Files**: `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift`
- **Changes**:
  - `Notifications` 섹션에서 취침/자세 row 제거
  - `Bedtime` 섹션 추가 후 일반/워치 row 통합
  - `Posture` 섹션 추가
- **Verification**: 코드 diff에서 세 개 섹션 구조와 기존 스케줄 `onChange` 유지 확인

### Step 2: 문자열과 접근성 정리

- **Files**: `Shared/Resources/Localizable.xcstrings`, `DUNEUITests/Helpers/UITestHelpers.swift`
- **Changes**:
  - `Bedtime`, `Watch Reminder`, `Watch Reminder Lead Time` 번역 추가
  - 자세 row 식별자 추가 여부 반영
- **Verification**: 새 문자열이 en/ko/ja로 모두 존재하고 AXID 상수가 코드와 일치하는지 확인

### Step 3: UI smoke 검증

- **Files**: `DUNEUITests/Smoke/SettingsSmokeTests.swift`
- **Changes**:
  - 취침/워치/자세 row 존재 검증 유지 및 스크린샷 확보
- **Verification**: 대상 UI test 통과 및 최신 스크린샷에서 섹션 분리 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 워치 토글이 꺼져 있을 때 footer가 비는 경우 | footer는 enabled일 때만 표시하는 기존 조건 유지 |
| 짧은 라벨이 문맥 없이 모호해지는 경우 | `Bedtime` 섹션 헤더로 문맥 제공 |
| 기존 AXID를 참조하는 테스트 회귀 | 기존 bedtime/watch AXID는 유지하고 posture만 필요 시 추가 |

## Testing Strategy

- Unit tests: 없음. 스케줄링 로직은 그대로라 이번 변경 범위는 UI 구조/문구에 한정된다.
- Integration tests: `scripts/build-ios.sh`
- UI tests: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests -destination 'platform=iOS Simulator,id=CA0C55C7-DDE7-4BBF-9DC0-7B710DBCA046' -only-testing:DUNEUITests/SettingsSmokeTests/testBedtimeReminderSettingsExist`
- Manual verification: UI test 스크린샷에서 `Notifications`, `Bedtime`, `Posture` 섹션 순서와 row 줄바꿈 여부 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 문자열 추가 시 xcstrings 구조 오타 | medium | medium | 최소 범위 patch 후 `build-ios`로 컴파일 검증 |
| UI smoke가 row reorder로 스크롤 실패 | medium | low | 기존 AXID 유지 + posture row assertion만 추가 |
| footer 위치 변경으로 레이아웃이 어색해짐 | low | low | screenshot 확인 후 필요 시 footer를 bedtime section에만 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 영향 범위가 Settings UI와 xcstrings/UI smoke에 집중되어 있고, 기존 scheduler/logic은 그대로 재사용한다.
