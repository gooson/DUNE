---
topic: watch-off-before-bedtime-alert
date: 2026-03-07
status: implemented
confidence: medium
related_solutions: [docs/solutions/healthkit/background-notification-system.md, docs/solutions/architecture/sleep-deficit-personal-average.md]
related_brainstorms: [docs/brainstorms/2026-03-07-watch-off-before-bedtime-alert.md]
---

# Implementation Plan: 평균 취침 시간 -30분 Apple Watch 취침 리마인더

## Context

기존 변경은 brainstorm 문서만 추가되어 기능 동작이 없었다. 사용자가 실제로 취침 전에 Apple Watch 착용을 상기받을 수 있도록, 최근 수면 데이터 기반 시각 계산과 로컬 알림 스케줄링을 구현한다.

## Requirements

### Functional

- 최근 수면 시작 시각(최근 7일)을 기반으로 대표 취침 시각을 추정한다.
- 추정 취침 시각 30분 전에 반복 로컬 알림을 스케줄한다.
- Watch가 페어링/앱 설치되지 않았거나 권한이 없으면 알림을 제거한다.
- 앱 실행/포그라운드 복귀 시 스케줄을 최신 데이터로 갱신한다.

### Non-functional

- 자정 경계(23:xx vs 00:xx)에서 평균 계산 왜곡이 없어야 한다.
- 기존 알림 시스템과 충돌하지 않도록 독립 identifier를 사용한다.
- 핵심 계산 로직은 유닛 테스트로 검증 가능해야 한다.

## Approach

- `CalculateAverageBedtimeUseCase`를 추가해 최근 수면 stage 배열을 입력받아 취침 시각을 계산한다.
- `BedtimeWatchReminderScheduler`를 추가해 알림 권한/Watch 상태 확인 후 반복 알림 1건을 관리한다.
- 앱 런타임 시작 및 활성화 전환 시 스케줄러를 호출한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| HealthKit Background Delivery 기반 조건부 발송 | 착용 상태 판별 확장 가능 | 구현 복잡도/백그라운드 제약 큼 | 보류 |
| 고정 시간(예: 22:30) 알림 | 구현 단순 | 개인화 부족, 요구사항 미충족 | 기각 |
| 최근 수면 데이터 기반 개인화 스케줄 | 요구사항 직접 충족, 구현 난이도 적절 | 착용 여부 실시간 판별은 후속 과제 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/CalculateAverageBedtimeUseCase.swift` | New | 자정 경계 보정 포함 평균 취침 시각 계산 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | New | 취침 리마인더 스케줄 등록/삭제 |
| `DUNE/App/DUNEApp.swift` | Update | 런타임 시작 시 스케줄 갱신 |
| `DUNE/App/ContentView.swift` | Update | active 전환 시 스케줄 갱신 |
| `DUNETests/CalculateAverageBedtimeUseCaseTests.swift` | New | 계산 로직 유닛 테스트 |

## Implementation Steps

### Step 1: 평균 취침 시각 계산 유스케이스 추가

- **Files**: `DUNE/Domain/UseCases/CalculateAverageBedtimeUseCase.swift`
- **Changes**: non-awake stage의 earliest start를 추출하고, 자정 이후(00:xx)를 +24h 보정해 평균 계산
- **Verification**: 자정 경계/데이터 없음/awake-only 케이스 테스트 통과

### Step 2: 리마인더 스케줄러 구현

- **Files**: `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift`
- **Changes**: 7일 데이터 조회 → 평균 계산 → -30분 반복 알림 생성, 불충족 조건에서 pending 알림 제거
- **Verification**: 빌드 성공, 스케줄러 호출 경로에서 컴파일 경고/오류 없음

### Step 3: 앱 라이프사이클 연결

- **Files**: `DUNE/App/DUNEApp.swift`, `DUNE/App/ContentView.swift`
- **Changes**: 앱 서비스 시작 시/active 전환 시 스케줄 refresh 호출
- **Verification**: 앱 시작/복귀 시 호출 코드 경로 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 최근 수면 데이터 없음 | pending 리마인더 제거 |
| Watch 미페어링 또는 앱 미설치 | pending 리마인더 제거 |
| 알림 권한 미허용 | pending 리마인더 제거 |
| 23:50/00:10 혼합 취침 | 자정 보정 평균으로 noon drift 방지 |

## Testing Strategy

- Unit tests: `CalculateAverageBedtimeUseCaseTests`
- Integration tests: 없음(로컬 알림 API 직접 mocking 미구현)
- Manual verification: 앱 활성화 시 scheduler refresh 경로 코드 검토

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 실제 "미착용" 여부를 실시간 판별하지 못함 | medium | medium | 후속 단계에서 Watch 신호 기반 조건부 발송 확장 |
| 수면 데이터 품질 편차로 시간 변동 | medium | low | 최근 7일 평균, 데이터 없으면 스케줄 제거 |
| 반복 알림이 사용자에게 과도할 수 있음 | low | medium | 기존 설정 토글 확장 시 제어권 제공 예정 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 개인화 스케줄 핵심 기능은 구현 가능하며 테스트로 계산 안정성을 확보했지만, "미착용" 판별은 플랫폼 제약으로 후속 확장이 필요하다.
