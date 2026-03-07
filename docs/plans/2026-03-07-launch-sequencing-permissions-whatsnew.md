---
topic: launch-sequencing-permissions-whatsnew
date: 2026-03-07
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/testing/2026-02-23-healthkit-permission-ui-test-gating.md
related_brainstorms: []
---

# Implementation Plan: Launch Sequencing For Permissions And What's New

## Context

첫 실행 시 `iCloud Sync` consent, HealthKit authorization, notification authorization, 그리고 `What's New` 진입이 서로 독립적으로 시작되어 사용자에게 여러 요청이 한꺼번에 겹쳐 보일 수 있다. 현재는 `DUNEApp`가 consent sheet를 띄우는 동시에 `DashboardViewModel`이 초기 데이터 로드에서 HealthKit 권한을 요청하고, 앱 시작 후 비동기 task가 notification 권한도 요청한다. `What's New`는 현재 수동 진입 중심이지만, launch-level surface로 확장될 경우 같은 충돌이 반복될 수 있다.

## Requirements

### Functional

- 첫 실행/미요청 상태에서 `iCloud consent -> HealthKit -> notifications -> What's New` 순서로 한 단계씩만 노출
- Dashboard 초기 HealthKit load가 launch permission flow와 경쟁하지 않을 것
- 이미 본 consent / 이미 시도한 permission / 이미 연 build의 `What's New`는 자동 노출 생략
- 수동 Settings/toolbar 진입은 기존대로 유지

### Non-functional

- XCTest/UI test 기본 경로에서는 launch extras를 건너뛰어 기존 smoke test 안정성 유지
- 순서 판정은 테스트 가능한 순수 로직으로 분리
- 기존 HealthKit/CloudKit/notification 코드 경계를 크게 흔들지 않을 것

## Approach

`DUNEApp`에 launch sequencing orchestrator를 추가하고, 다음 단계 결정은 작은 pure planner로 분리한다. 오케스트레이터는 현재 상태를 읽어 다음 step을 하나만 실행하고, custom sheet dismissal 이후 다음 step으로 이어진다. `ContentView`와 `DashboardView`는 `launchExperienceReady` 신호를 받아 초기 load를 늦춘다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Dashboard에서만 HealthKit prompt 지연 | 변경 범위 작음 | notification / consent / what's new 충돌 해결 불가 | 기각 |
| 앱 콘텐츠 전체를 launch flow 완료 전까지 숨김 | 경쟁 조건 제거가 쉬움 | 빈 화면/전환 품질 저하, 기존 탭 구조와 분리 | 보류 |
| `DUNEApp` 단일 오케스트레이션 + dashboard load gate | launch-level surface를 한곳에서 제어, 기존 구조와 정합성 높음 | 상태 전이 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | launch step orchestration, permission sequencing, auto `What's New` presentation |
| `DUNE/App/ContentView.swift` | update | launch readiness를 Today 탭으로 전달 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | launch readiness 전에는 초기 load 보류 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | update | 자동 HealthKit authorization 호출을 launch orchestration과 분리 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | update | launch consent test identifiers 추가 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | update | automatic mode dismiss 식별자 보강 |
| `DUNE/App/LaunchExperiencePlanner.swift` | add | 다음 launch step 판정 pure logic |
| `DUNETests/LaunchExperiencePlannerTests.swift` | add | sequencing order / skip 조건 unit tests |
| `DUNEUITests/Manual/HealthKitPermissionUITests.swift` | update | 새 launch 순서에 맞는 manual verification flow |

## Implementation Steps

### Step 1: Launch step planner 추가

- **Files**: `LaunchExperiencePlanner.swift`, `LaunchExperiencePlannerTests.swift`
- **Changes**:
  - consent, HealthKit, notifications, `What's New`, ready 단계 enum 정의
  - 현재 launch state에서 next step을 판정하는 pure function 추가
  - 대표 조합(첫 실행, 일부 완료, 테스트 환경, release 없음) 테스트 작성
- **Verification**:
  - 첫 실행은 consent부터 시작
  - consent 이후에는 HealthKit -> notifications -> `What's New` 순으로 진행
  - 이미 완료한 단계는 skip

### Step 2: `DUNEApp` orchestration 적용

- **Files**: `DUNEApp.swift`
- **Changes**:
  - persistent flags(`hasRequestedHealthKitAuthorization`, `hasRequestedNotificationAuthorization`) 추가
  - splash 이후 launch step을 하나씩 실행하는 async orchestration 추가
  - automatic `What's New` sheet와 dismiss 후 mark-opened 처리 추가
  - watch activation / observer start는 launch flow 완료 후 실행
- **Verification**:
  - consent sheet가 닫힌 뒤 다음 system prompt가 이어짐
  - notification prompt는 HealthKit flow 이후에만 뜸
  - current build의 `What's New`가 있으면 마지막에 한 번만 표시

### Step 3: Dashboard 초기 load 경쟁 제거

- **Files**: `ContentView.swift`, `DashboardView.swift`, `DashboardViewModel.swift`
- **Changes**:
  - `launchExperienceReady`를 Today 탭에 전달
  - ready 전에는 `.task` 기반 초기 `loadData()` 실행 보류
  - `DashboardViewModel`의 auto authorization을 선택적으로 비활성화
- **Verification**:
  - permission flow 중 Dashboard에서 HealthKit prompt를 다시 띄우지 않음
  - flow 완료 후 Today 데이터가 정상 로드됨

### Step 4: UX/test 보강

- **Files**: `CloudSyncConsentView.swift`, `WhatsNewView.swift`, `HealthKitPermissionUITests.swift`
- **Changes**:
  - launch consent 버튼, automatic `What's New` close 버튼에 AX identifier 추가
  - manual permission UI test가 consent -> HealthKit -> notifications 흐름을 따라가도록 조정
- **Verification**:
  - manual permission test가 새 순서에서도 시나리오를 설명 가능
  - smoke tests는 launch extras 없이 기존대로 유지

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit unavailable device | HealthKit step skip 후 다음 단계 진행 |
| 이미 current build의 `What's New`를 열어본 상태 | automatic `What's New` 생략, 수동 진입만 유지 |
| 사용자가 permission을 거절 | 다음 단계로 진행하고 dashboard는 empty/error state로 복귀 |
| XCTest / UI tests | consent, permission, auto `What's New` 자동 실행 생략 |

## Testing Strategy

- Unit tests: `LaunchExperiencePlanner` 순서/skip 판정
- Integration tests: targeted iOS unit tests + manual permission UI test 정합성 확인
- Manual verification: fresh launch에서 consent, HealthKit, notification, `What's New`가 한 번에 하나씩만 보이는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| launch step 전이 중복 호출 | Medium | Medium | single orchestrator + dismissal-triggered resume |
| permission 완료 플래그가 실제 OS 상태와 어긋남 | Medium | Medium | 의미를 “authorized”가 아니라 “launch auto-request attempted”로 제한 |
| auto `What's New`가 UI tests를 깨뜨림 | Medium | High | XCTest 환경에서는 automatic presentation skip |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 `DUNEApp`가 launch-level surface를 담당하는 방향과 일치하고, 핵심 순서 결정 로직을 pure planner로 분리하면 회귀 없이 검증 가능하다.
