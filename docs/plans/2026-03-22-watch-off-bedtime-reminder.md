---
topic: watch-off-bedtime-reminder
date: 2026-03-22
status: approved
confidence: medium
related_solutions:
  - docs/solutions/performance/2026-02-15-healthkit-query-parallelization.md
  - docs/solutions/healthkit/2026-02-24-sleep-dedup-watch-detection.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-watch-off-before-bedtime-alert.md
  - docs/brainstorms/2026-03-08-general-bedtime-reminder.md
---

# Implementation Plan: Watch-Off Bedtime Reminder

## Context

현재 취침 알림은 최근 평균 취침 시간을 기준으로 일반적인 "취침 준비" 알림을 반복 스케줄한다. 이번 변경은 이 동작을 다시 Apple Watch 착용 리마인더로 되돌리고, 사용자가 선택한 리드타임 중 기본 1시간 전 시점에 "Apple Watch를 아직 안 찼을 때만" 알림이 유지되도록 만드는 작업이다.

현재 코드베이스에는 iPhone에서 Apple Watch의 실시간 착용 상태를 직접 조회하는 경로가 없다. 따라서 MVP는 HealthKit의 최근 watch-origin heart rate 샘플을 착용 근사치로 사용하고, 관련 HealthKit 업데이트나 foreground refresh 때마다 다음 알림을 재계산하는 방식으로 구현한다.

## Requirements

### Functional

- 평균 취침 시간 기반 취침 리마인더를 Apple Watch 미착용 리마인더로 전환한다.
- 기본 리드타임을 1시간으로 변경한다.
- Settings에서 리마인더 토글과 리드타임 선택은 계속 제공한다.
- 사용자가 Apple Watch를 착용 중으로 추정되면 예정된 알림을 스킵하거나 취소한다.
- Apple Watch가 없거나 알림/HealthKit 조건이 충족되지 않으면 리마인더를 스케줄하지 않는다.

### Non-functional

- 기존 debounce 계약을 유지해 foreground 진입마다 과도한 7일 수면 쿼리가 반복되지 않게 한다.
- Domain/Data/Presentation 레이어 경계를 지킨다.
- 새 로직은 Swift Testing 기반 유닛 테스트로 고정한다.
- 사용자 노출 문자열은 localization 규칙에 맞춰 `String(localized:)` 또는 `LocalizedStringKey`를 사용한다.

## Approach

`BedtimeReminderScheduler`를 반복 알림 스케줄러에서 "다음 1회 알림" 스케줄러로 바꾼다. 스케줄 계산 시 최근 수면 데이터로 평균 취침 시각을 구하고, 선택한 리드타임만큼 뺀 다음 upcoming trigger date를 만든다. 그 직전에 HealthKit의 최근 watch-origin heart-rate sample이 있으면 "이미 착용 중"으로 간주해 pending reminder를 제거하고, 없으면 오늘/내일 1회 알림을 등록한다.

watch 착용 판정은 별도 Data-layer 서비스로 분리한다. 이 서비스는 최근 몇 시간 내 heart rate 샘플 중 `sourceRevision.productType.hasPrefix("Watch")` 또는 bundle ID fallback이 watch로 판정되는 샘플 존재 여부를 반환한다. 심박 observer가 들어오면 scheduler를 강제 재평가해, 취침 전 watch를 다시 차는 경우 당일 예정 알림을 취소할 수 있게 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 반복 로컬 알림 유지 + 현재처럼 일반 카피만 수정 | 변경량이 가장 작음 | 발송 시점 조건 평가가 불가능해 "미착용일 때만" 요구를 만족하지 못함 | 기각 |
| WatchConnectivity reachability / pairing 상태로 미착용 판정 | 구현이 쉬움 | reachability는 착용 여부와 무관하고 오탐이 큼 | 기각 |
| 최근 watch-origin heart rate 샘플 기반 착용 근사치 + one-shot 재스케줄 | 현재 권한/데이터 경로로 구현 가능, 요구에 가장 근접 | 완전한 실시간 착용 판정은 아니며 heuristic임 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | modify | one-shot scheduling, watch-wear gating, 카피 업데이트 |
| `DUNE/Data/HealthKit/HeartRateQueryService.swift` | modify | watch-origin 최근 heart rate 조회 API 추가 |
| `DUNE/Data/HealthKit/HealthKitObserverManager.swift` | modify | heart rate observer 추가 및 bedtime scheduler 재평가 트리거 |
| `DUNE/Domain/Models/BedtimeReminderLeadTime.swift` | modify | 기본 리드타임을 1시간으로 조정 |
| `DUNE/Presentation/Shared/Extensions/BedtimeReminderLeadTime+View.swift` | verify/modify | 설정 라벨 유지 여부 확인 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | modify | 설정 라벨/설명문을 Apple Watch 미착용 리마인더로 조정 |
| `Shared/Resources/Localizable.xcstrings` | modify | 새 설정/알림 문구 번역 추가 |
| `DUNETests/BedtimeReminderSchedulerTests.swift` | modify | one-shot scheduling, watch-wear skip, 기본 리드타임 테스트 추가 |
| `DUNETests/HeartRateQueryServiceTests.swift` or 신규 테스트 | add/modify | watch-origin 판정 로직 테스트 추가 |

## Implementation Steps

### Step 1: Reminder semantics를 watch-off 조건부 스케줄로 복원

- **Files**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`, `DUNE/Domain/Models/BedtimeReminderLeadTime.swift`
- **Changes**:
  - 기본 리드타임을 `.oneHour`로 변경
  - 반복 알림 대신 다음 1회 알림만 예약
  - 다음 알림 시각을 현재 시각 기준 오늘/내일 upcoming trigger로 계산
  - watch 착용 추정 결과가 true면 pending reminder 제거
- **Verification**:
  - scheduler unit test로 기본 trigger가 평균 취침 1시간 전으로 계산되는지 확인
  - 이미 착용 중일 때 request가 생성되지 않는지 확인

### Step 2: watch-origin heart rate 기반 착용 추정 경로 추가

- **Files**: `DUNE/Data/HealthKit/HeartRateQueryService.swift`, 관련 테스트 파일
- **Changes**:
  - 최근 heart rate sample 중 watch-origin 샘플 존재 여부를 반환하는 API 추가
  - sleep dedup과 동일한 watch source 판정 규칙 재사용 또는 동등 구현
- **Verification**:
  - watch productType / bundle ID fallback 케이스가 올바르게 판정되는 단위 테스트 추가

### Step 3: refresh trigger와 Settings copy를 새 기능 의미에 맞춤

- **Files**: `DUNE/Data/HealthKit/HealthKitObserverManager.swift`, `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift`, `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - heart rate observer를 추가하고 relevant update 시 bedtime scheduler 재평가
  - Settings 토글/설명/lead-time label을 Apple Watch bedtime reminder 의미에 맞게 수정
  - 새 알림 title/body 문구 localization 추가
- **Verification**:
  - 설정 문자열이 localization 규칙을 지키는지 확인
  - 리드타임 변경 즉시 재스케줄 호출이 유지되는지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 최근 수면 데이터 부족 | pending reminder 제거 후 미예약 |
| Apple Watch 미페어링 또는 앱 미설치 | reminder 미예약 |
| 최근 watch heart rate가 없지만 실제 착용 중 | heuristic 한계로 알림 가능, Settings copy/문서에 direct wrist-state API 부재를 전제로 둠 |
| foreground/observer 갱신이 취침 직전 없을 때 | 마지막 계산 기준 one-shot 알림 유지 |
| 자정 전후 평균 취침 시각 | 기존 average bedtime wrap 계산 재사용 |

## Testing Strategy

- Unit tests: `BedtimeReminderSchedulerTests`에 기본 1시간, watch-wear skip, next-day one-shot scheduling, pairing/app-installed gating 추가
- Unit tests: heart-rate watch-source detection helper 또는 service 테스트 추가
- Integration tests: 없음. HealthKit 실제 observer/background delivery는 시뮬레이터에서 결정적이지 않아 유닛 범위로 고정
- Manual verification: Settings에서 토글/리드타임 변경 후 pending notification이 재계산되는지, paired state 없는 환경에서 reminder가 제거되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 최근 heart rate 기반 착용 추정이 오탐/미탐을 낼 수 있음 | medium | medium | heuristic을 service로 분리하고 observer 재평가로 오탐 기간을 줄임 |
| heart rate observer 추가로 background refresh가 늘 수 있음 | medium | medium | observer frequency를 보수적으로 선택하고 scheduler debounce 유지 |
| one-shot 전환 후 다음날 알림이 안 이어질 수 있음 | medium | high | foreground + authorization grant + HK observer refresh 경로에서 재계산되도록 유지, next-day scheduling 테스트 추가 |
| 새 문자열 번역 누락 | low | medium | xcstrings 동시 수정 및 localization 체크 수행 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 평균 취침 시각 계산과 설정 UI는 기존 경로를 재사용할 수 있어 구현 난이도는 높지 않다. 다만 iPhone에서 실시간 wrist-state API가 없으므로 미착용 판정은 최근 watch-origin heart rate 기반 heuristic에 의존한다.
