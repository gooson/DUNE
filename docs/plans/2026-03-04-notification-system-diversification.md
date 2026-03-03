---
topic: notification-system-diversification
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/healthkit/background-notification-system.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-notification-system-diversification.md
---

# Implementation Plan: Notification System Diversification (Push Optimization Only)

## Context

알림시스템 다각화 브레인스토밍 결과에서 MVP 범위를 "인앱 허브 확장"이 아닌 "푸시 최적화"로 확정했다.
현재 코드베이스는 HealthKit 기반 스마트 알림, 타입별 on/off, 일일 쓰로틀(건강형), 알림 인박스 저장/라우팅이 이미 구현되어 있다.
이번 변경의 목적은 리텐션 개선을 위해 **알림 피로/중복**을 우선적으로 줄이는 것이다.

## Requirements

### Functional

- 동일 이벤트의 반복 푸시를 일정 시간(예: 60분) 내 차단해야 한다.
- 일일 알림량 상한(알림 예산)을 적용해 과도한 전송을 방지해야 한다.
- 기존 타입별 설정(on/off), 건강형 일일 쓰로틀, 워크아웃 PR 흐름을 깨지 않아야 한다.
- Background evaluator에서 insight 생성 후 최종 전송 게이트를 통합 적용해야 한다.

### Non-functional

- 변경 범위를 알림 Data/Domain 경계 내로 제한한다.
- 기존 테스트 패턴(Swift Testing)을 유지하고 신규 정책 분기를 테스트로 보장한다.
- UserDefaults key는 bundle prefix 규칙을 준수한다.

## Approach

기존 `NotificationThrottleStore`를 확장해 "타입 단위 쓰로틀" + "insight 단위 dedup" + "일일 예산"을 하나의 최종 게이트로 구성한다.
`BackgroundNotificationEvaluator`에서 insight 평가 후 최종 게이트를 호출하여 실제 전송 직전에 중복/피로를 차단한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `NotificationServiceImpl`에서만 dedup/budget 처리 | 전송 직전 제어로 단순 | evaluator와 정책 분리되어 테스트/의도 추적 어려움 | ❌ |
| 별도 `NotificationPolicyStore` 신규 파일 추가 | 역할 분리 명확 | 파일/프로젝트 구성 변경 범위 증가 | ❌ |
| 기존 `NotificationThrottleStore` 확장 | 최소 변경으로 정책 통합, 기존 테스트 재사용 용이 | Store 책임 증가 | ✅ |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Persistence/NotificationThrottleStore.swift` | modify | dedup window + daily budget + insight-level gate 추가 |
| `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift` | modify | insight 생성 후 최종 게이트 호출로 전송 조건 강화 |
| `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift` | modify | 푸시 정책(중복 방지/빈도 제한) 문구 반영 |
| `DUNETests/NotificationThrottleStoreTests.swift` | modify | dedup/budget 정책 테스트 추가 |

## Implementation Steps

### Step 1: Throttle policy 확장

- **Files**: `DUNE/Data/Persistence/NotificationThrottleStore.swift`
- **Changes**:
  - dedup key 생성 로직 추가 (insight type + route + message 기반)
  - 최근 전송 시간 비교(기본 60분)로 중복 차단
  - 일일 예산 카운트/리셋 로직 추가
  - `canSend(insight:)`, `recordSent(insight:)` API 추가
- **Verification**:
  - 동일 insight 재전송 차단 여부 확인
  - 날짜 변경 시 예산 카운트 리셋 확인

### Step 2: Background evaluator 전송 게이트 연결

- **Files**: `DUNE/Data/HealthKit/BackgroundNotificationEvaluator.swift`
- **Changes**:
  - insight 계산 직후 `canSend(insight:)` 체크
  - 통과 시 `recordSent(insight:)` 후 `notificationService.send(...)` 실행
- **Verification**:
  - 기존 타입 매핑/평가 로직 동작 유지
  - 중복/예산 조건 미충족 시 전송되지 않음

### Step 3: UX 문구 + 테스트 보강

- **Files**: `DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift`, `DUNETests/NotificationThrottleStoreTests.swift`
- **Changes**:
  - Settings footer를 실제 정책(중복 방지 + 빈도 제한)에 맞게 수정
  - dedup window, 일일 예산, high-priority 예외 케이스 테스트 추가
- **Verification**:
  - 변경된 테스트 모두 통과
  - Settings 문구가 정책과 불일치하지 않음

## Edge Cases

| Case | Handling |
|------|----------|
| 동일 workoutID 알림이 observer 재호출로 반복 생성 | dedup key + 60분 윈도우로 차단 |
| 하루 예산 소진 후 정보성 알림 과다 발생 | 일일 카운트 기반 차단 |
| 날짜가 바뀌는 시점(자정) | 일일 카운트 리셋 후 재전송 허용 |
| route 없는 insight가 동일 title/body로 반복 | message 기반 dedup key로 차단 |

## Testing Strategy

- Unit tests:
  - `NotificationThrottleStoreTests` 확장 (dedup/budget/자정 리셋)
- Integration tests:
  - 기존 알림 파이프라인 테스트 스모크(빌드/기존 테스트)로 회귀 확인
- Manual verification:
  - 동일 이벤트 연속 발생 시 알림 1회만 발송되는지 확인
  - 일일 예산 초과 시 정보성 알림이 억제되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| dedup key가 과도하게 넓어 정상 알림까지 차단 | Medium | Medium | type+route+message 조합, 테스트 케이스로 검증 |
| 예산 정책이 공격적으로 동작해 engagement 저하 | Medium | Medium | 기본 예산 보수적으로 설정, attention/celebration 예외 |
| 기존 health/day throttle와 충돌 | Low | High | 기존 `canSend(for:)` 유지 + insight gate는 추가 보호층으로 적용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 알림 인프라를 그대로 활용하고, 핵심 변경이 `NotificationThrottleStore` 중심의 국소 수정이라 회귀 위험이 상대적으로 낮다. 또한 테스트로 정책 분기를 직접 검증할 수 있다.
