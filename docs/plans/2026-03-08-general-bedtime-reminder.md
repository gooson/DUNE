---
topic: general-bedtime-reminder
date: 2026-03-08
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-bedtime-watch-reminder-implementation.md
  - docs/solutions/performance/2026-03-08-review-triage-debounce-and-caching.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-watch-off-before-bedtime-alert.md
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: General Bedtime Reminder

## Context

기존 구현은 평균 취침 시간 30분 전에 Apple Watch 미착용 사용자만 대상으로 리마인더를 보낸다.
이번 변경은 기능 의미를 일반 취침 알림으로 전환하고, 최근 7일 평균 취침 시간보다 2시간 먼저
건강/회복/운동 가치 중심의 알림을 보내도록 수정하는 것이다.

## Requirements

### Functional

- 최근 7일 평균 취침 시간을 기준으로 일반 취침 알림을 스케줄한다.
- 리드 타임을 30분에서 2시간으로 변경한다.
- Watch pairing, watch app 설치, wrist temperature 기반 skip 조건을 제거한다.
- 데이터 부족, 권한 미허용, 토글 off 상태에서는 pending reminder를 제거하고 미예약한다.
- Settings의 toggle label/icon과 알림 카피를 일반 취침 알림 의미에 맞게 갱신한다.
- 미래 작업으로 리드 타임 사용자 설정 TODO를 추가한다.

### Non-functional

- 기존 app lifecycle refresh 지점은 유지한다.
- 기존 평균 취침 시간 계산의 자정 wrap 처리와 debounce 동작은 유지한다.
- 신규 사용자 대면 문자열은 xcstrings에 en/ko/ja 번역을 추가한다.
- 기존 로직 변경에 맞춰 단위 테스트를 추가한다.

## Approach

watch-specific 판단을 담당하던 scheduler를 일반 bedtime reminder scheduler로 단순화한다.
평균 취침 시간 계산 use case는 그대로 재사용하고, scheduler 내부 의존성을 수면 조회와 알림 예약에만 한정한다.
알림 예약 권한과 데이터 유무만 gate로 사용하고, user-facing copy와 settings label을 일반 취침 습관 코칭 관점으로 교체한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 watch-specific scheduler를 최소 수정 | diff가 작음 | 내부 의미와 사용자 경험이 불일치 | 미선택 |
| scheduler를 일반 bedtime reminder로 단순화 | 요구사항과 코드 의미가 일치 | 테스트 보강 필요 | 선택 |
| 별도 신규 scheduler 추가 후 기존 watch scheduler 유지 | 레거시 보존 가능 | 중복 스케줄러/토글/알림 충돌 위험 | 미선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | modify | watch 조건 제거, 2시간 리드 타임, 일반 취침 알림 로직으로 전환 |
| `DUNE/App/DUNEApp.swift` | modify | scheduler 명칭 변경 시 runtime 호출 업데이트 |
| `DUNE/App/ContentView.swift` | modify | foreground refresh 호출 업데이트 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | modify | 일반 취침 알림 label/icon 반영 |
| `Shared/Resources/Localizable.xcstrings` | modify | 신규 알림 문구/설정 문자열 번역 추가 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | add | scheduler gating 및 trigger time 검증 |
| `todos/NNN-ready-p3-bedtime-reminder-lead-time-setting.md` | add | 후속 사용자 설정 작업 기록 |

## Implementation Steps

### Step 1: Generalize reminder scheduling logic

- **Files**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`, `DUNE/App/DUNEApp.swift`, `DUNE/App/ContentView.swift`
- **Changes**:
  - scheduler를 일반 bedtime reminder 의미로 전환
  - watch pairing / watch app / wrist temperature 조건 제거
  - lead time을 120분으로 변경
  - 기존 평균 취침 시간 계산 use case와 debounce/lifecycle wiring 유지
- **Verification**: scheduler unit test에서 평균 취침 시간 대비 2시간 전 trigger를 검증

### Step 2: Update user-facing copy and settings

- **Files**: `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - 설정 토글 라벨과 아이콘을 일반 취침 알림 의미로 수정
  - title/body 문구를 건강/회복/운동 가치 중심 메시지로 교체
  - en/ko/ja 번역 추가
- **Verification**: localization rule 기준으로 사용자 대면 문자열 누락이 없는지 diff 검토

### Step 3: Add regression tests and future TODO

- **Files**: `DUNETests/BedtimeReminderSchedulerTests.swift`, `todos/NNN-ready-p3-bedtime-reminder-lead-time-setting.md`
- **Changes**:
  - authorized + data available 시 schedule, disabled/no data 시 remove-only 동작 검증
  - 후속 리드 타임 사용자 설정 TODO 추가
- **Verification**: DUNETests 대상 테스트 실행 및 todo 파일 번호/형식 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 최근 수면 데이터 부족 | pending reminder 제거 후 미예약 |
| 평균 취침 시간이 자정 전후로 걸침 | 기존 CalculateAverageBedtimeUseCase wrap 처리 유지 |
| 알림 권한 미허용 | pending reminder 제거 후 미예약 |
| 사용자가 토글 off | pending reminder 제거 후 미예약 |
| foreground 진입이 잦음 | 기존 30분 debounce 유지 |

## Testing Strategy

- Unit tests: scheduler 전용 테스트 추가로 trigger hour/minute, disabled/no-data gating 검증
- Integration tests: 기존 `CalculateAverageBedtimeUseCaseTests`는 유지하여 평균 취침 계산 회귀 보호
- Manual verification: Settings에서 토글 노출/문구 확인, 앱 active 진입 후 pending notification 예약 시간 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 의미 변경 후 내부 watch 명칭 일부 잔존 | medium | low | diff 기준으로 문자열/타입명 사용처 재검색 |
| xcstrings 편집 실수 | medium | medium | 기존 키 블록 근처에만 국소 수정하고 review에서 L10N 점검 |
| scheduler 테스트용 알림 추상화가 과해질 위험 | low | medium | scheduler에 필요한 최소 인터페이스만 도입 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 평균 취침 계산과 lifecycle wiring은 이미 존재하고, 이번 변경은 gating/카피/리드 타임 전환이 중심이라 범위가 명확하다.
