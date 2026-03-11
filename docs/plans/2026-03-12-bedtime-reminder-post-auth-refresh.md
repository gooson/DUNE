---
topic: bedtime-reminder-post-auth-refresh
date: 2026-03-12
status: draft
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-09-bedtime-reminder-lead-time-setting.md
  - docs/solutions/architecture/2026-03-11-launch-permission-deferral-stability.md
  - docs/solutions/performance/2026-03-08-review-triage-debounce-and-caching.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-watch-off-before-bedtime-alert.md
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: Bedtime Reminder Post-Authorization Refresh

## Context

사용자 제보는 "평균 취침 시간 30분 전 워치를 안 차고 있으면 알려주는 기능이 동작하지 않는다"는 내용이다.
현재 코드베이스를 확인한 결과, 2026-03-08 이후 bedtime reminder는 watch-specific reminder가 아니라 일반 취침 알림으로 단순화되었고,
실제 재현 가능한 결함은 첫 권한 획득 세션에서 bedtime scheduler가 재실행되지 않아 알림이 예약되지 않는 점이다.

## Requirements

### Functional

- 앱이 notification permission을 새로 승인받은 직후 같은 세션에서 bedtime reminder를 즉시 다시 스케줄해야 한다.
- 기존 debounce 정책은 유지하되, 권한 승인 직후에는 강제 refresh가 가능해야 한다.
- 기존 bedtime reminder 설정이 꺼져 있거나 수면 데이터가 부족한 경우에는 기존과 동일하게 pending reminder를 제거해야 한다.

### Non-functional

- 기존 launch permission deferral 구조를 깨지 않는다.
- 변경은 최소 범위로 유지한다.
- 회귀를 막는 단위 테스트를 추가한다.

## Approach

`DUNEApp.requestDeferredAuthorizationsIfNeeded()`에서 notification authorization 성공 직후
`BedtimeReminderScheduler.shared.refreshSchedule(force: true)`를 호출한다.
이렇게 하면 launch 시 초기 scheduler 실행이 authorization 부재로 실패해도, 사용자가 권한을 허용한 동일 세션 안에서 즉시 pending reminder가 다시 계산된다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `DUNEApp`에서 authorization 성공 직후 scheduler 강제 refresh | 최소 변경, 실제 결함 지점 직접 해결 | app orchestration에 scheduler 호출이 하나 더 생김 | 선택 |
| `NotificationServiceImpl` 내부에서 authorization 성공 시 scheduler 호출 | 호출 지점이 한곳으로 모임 | 서비스 계층이 feature-specific scheduler를 알게 되어 레이어 경계 악화 | 기각 |
| watch-specific 30분 reminder를 다시 복원 | 사용자 표현과 가장 가까움 | 현재 제품 스펙과 다르고 실제 wear-state 판별 모델이 없음 | 이번 범위 제외 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | notification authorization 성공 직후 bedtime reminder 강제 refresh 추가 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | update | unauthorized -> authorized 전환 후 force refresh로 예약되는 회귀 테스트 추가 |
| `docs/plans/2026-03-12-bedtime-reminder-post-auth-refresh.md` | add | 구현 계획 문서 |

## Implementation Steps

### Step 1: Authorization 후 scheduler 재실행 연결

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: `notificationService.requestAuthorization()` 결과를 받아, 승인된 경우 bedtime scheduler를 `force: true`로 재실행한다.
- **Verification**: notification permission 승인 경로에서 bedtime scheduler 호출이 추가되었는지 코드 검토.

### Step 2: Scheduler 회귀 테스트 보강

- **Files**: `DUNETests/BedtimeReminderSchedulerTests.swift`
- **Changes**: 처음에는 authorization이 없어 미예약, 이후 authorization이 생긴 뒤 `force` refresh에서 정상 예약되는 시나리오 테스트를 추가한다.
- **Verification**: 새 테스트가 현재 버그 경로를 보호하는지 확인.

### Step 3: Focused build/test 실행

- **Files**: 없음
- **Changes**: 관련 테스트와 앱 빌드를 실행해 변경이 실제로 통과하는지 검증한다.
- **Verification**: `swift test` 또는 `xcodebuild test` 계열 명령 성공, app build 성공.

## Edge Cases

| Case | Handling |
|------|----------|
| 사용자가 알림 권한을 거부함 | scheduler 재실행 없이 기존 pending 제거 상태 유지 |
| bedtime reminder 토글이 꺼져 있음 | 강제 refresh가 호출되어도 scheduler 내부 guard가 제거 경로로 처리 |
| 최근 수면 데이터가 없음 | scheduler 내부에서 pending reminder 제거 후 미예약 |
| 사용자가 이미 권한을 가진 상태에서 foreground 진입 | 기존 debounce/force 정책 유지, 동작 변화 없음 |
| 사용자 기대가 여전히 watch-specific reminder임 | 이번 수정은 scheduling bug만 해결하고, wear-state semantics 불일치는 별도 후속 범위로 남김 |

## Testing Strategy

- Unit tests: `BedtimeReminderSchedulerTests`에 unauthorized -> authorized 전환 회귀 테스트 추가
- Integration tests: launch orchestration 전체를 직접 테스트하지는 않지만, 실제 app wiring은 `DUNEApp` 단일 변경으로 제한
- Manual verification: notification permission fresh state에서 앱 실행 후 bedtime reminder pending request가 생기는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 권한 승인 직후 중복 refresh로 불필요한 HealthKit 쿼리 발생 | 낮음 | 낮음 | `force`는 permission grant 직후 1회만 호출되고 기존 debounce는 일반 foreground 경로에 유지 |
| 사용자가 기대한 "watch 미착용 조건"은 여전히 충족되지 않음 | 높음 | 중간 | 이번 수정 범위를 scheduling failure로 제한하고 최종 보고에 현재 스펙 차이를 명시 |
| app-level orchestration 테스트 부재 | 중간 | 중간 | scheduler 회귀 테스트 추가 + 변경 범위를 한 줄 호출로 최소화 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 코드상 재현 가능한 결함과 해결 경로는 명확하지만, 사용자 기대에는 watch-specific semantics 불일치가 남아 있다.
