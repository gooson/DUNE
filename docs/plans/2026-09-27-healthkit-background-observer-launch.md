---
tags: [healthkit, background-delivery, launch, notifications]
date: 2026-09-27
category: plan
status: implemented
confidence: high
related_solutions:
  - ../solutions/general/2026-09-19-healthkit-launch-authorization-revalidation.md
  - ../solutions/healthkit/background-notification-system.md
---

# HealthKit 백그라운드 감시 복구

## Context / Requirements

현재 observer는 이번 실행의 권한 요청 완료 후에만 시작한다. 요청 함수는 active scene을 요구하므로 백그라운드 cold launch에서 감시가 복구되지 않는다. 체성분 전달도 hourly여서 지연된다.

## Approach

기존 권한 요청 이력이 있는 설치에서는 runtime 생성 시 observer를 동기 등록한다. 이 이력은 읽기 권한 증명이 아니며 foreground 권한 재확인과 Today 조회 gate는 유지한다. 첫 설치와 XCTest에서는 조기 등록하지 않는다. MainActor에서 등록/중지/보관을 직렬화하여 기존 Task의 check/set 및 query 보관 경쟁을 없앤다. 체중/체지방/BMI는 함께 immediate로 요청하고 기존 병합·하루 1회 정책은 유지한다.

대안: scene active에서만 등록하면 cold launch 문제가 남는다. 모든 설치에서 무조건 등록하면 최초 권한 요청 전 쿼리가 발생한다. 별도 AppDelegate/runtime 이중 구성은 현재 범위에 불필요하다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/App/DUNEApp.swift | modify | runtime 생성 시 조기 감시 복구 |
| DUNE/App/LaunchExperiencePlanner.swift | modify | 복구 가능 조건 |
| DUNE/Data/HealthKit/HealthKitObserverManager.swift | modify | 동기 등록/직렬화 및 체성분 immediate |
| DUNETests/LaunchExperiencePlannerTests.swift | modify | 최초 설치/재실행/테스트/미지원 분기 |
| DUNETests/HealthKitObserverManagerTests.swift | modify | 체성분 전달 정책 회귀 |
| DUNETests/CardioSessionViewModelTests.swift | modify | 전체 단위 테스트에서 발견한 live HealthKit 의존을 기존 mock으로 격리 |
| DUNEUITests/Helpers/UITestHelpers.swift | modify | 입력 전 포커스를 확인하고 제한적으로 재탭하여 UI 회귀의 입력 실패 방지 |

## Implementation Steps

1. runtime 생성 경로와 planner gate를 연결하고 분기 테스트를 추가한다.
2. observer 수명 관리를 MainActor로 통합하고 체성분 전달 주기를 변경한다. completion은 비동기 평가 완료 후 호출하는 계약을 유지한다.
3. 빌드, iOS 단위 테스트, 전체 기존 UI 회귀를 실행한다. diff 기반 5관점 리뷰와 품질/PR 리뷰 후 문서화한다.

## Testing Strategy

- 단위: 저장된 요청 이력 true/false, HealthKit 미지원, XCTest bypass; foreground 재확인 유지; 세 체성분 타입 immediate, steps/workout hourly; 기존 completion 테스트.
- 자동: scripts/build-ios.sh, scripts/test-unit.sh --ios-only, scripts/test-ui.sh.
- 실기기: HealthKit/알림 허용 후 앱을 백그라운드로 보내고 Health에 오늘 체중 추가. 프로세스 종료 후 OS가 백그라운드 실행한 상황에서 observer 등록 로그와 알림 확인. 잠금/잠금 해제 및 동일 날짜 재측정도 별도 확인.

## Risks / Edge Cases

- OS 전달 시점과 강제 종료 후 재실행은 앱이 보장하지 못한다. 시뮬레이터는 HealthKit background delivery 재현 근거가 아니다.
- 권한 철회/잠금 상태에서는 HealthKit이 접근을 제한한다. 저장 플래그로 이를 우회하지 않는다.
- CloudKit 설정 변경 runtime 교체 시 이전 query를 먼저 중지하고 새 runtime에서도 복구한다.
- 하루 1회/일일 예산에 따른 의도적 억제는 유지한다. 오늘 이전 샘플 및 전송 실패 복구 정책은 별도 범위다.

## Research / Confidence

기존 solutions, brainstorm, todos를 검색했다. 해당 미완료 TODO는 없다. Apple HKUpdateFrequency 문서상 hourly는 시간당 최대 1회이며 immediate는 변경 감지를 요청한다. 감시 등록 복구는 코드로 검증 가능하나 OS 백그라운드 깨우기는 실기기 확인이 필요하다.

## Execution Notes

- 앱 빌드 통과. Work 품질 점검에서 발견한 delivery 설정 실패 후 재시도 누락은 수정하고 테스트했다.
- iOS 27.0: Swift Testing 2,241개/244 suite 및 XCTest 9개 통과. Observer/LaunchExperience/CardioSession suite 모두 통과했다.
- 최초 전체 단위 실행은 CardioSession 테스트가 실제 HealthKit VO₂ Max 쿼리를 호출하며 정체됐다. 기존 mock을 helper 기본값으로 연결한 뒤 통과했다.
- 전체 UI 실행은 12개 통과, 기존 picker 테스트의 180초 제한 초과 1건을 확인한 후 다른 Health 작업의 단독 검증 조정으로 중단됐다. 전체 UI gate는 아직 미완료다.
- 테스트 조정 중에는 새 시뮬레이터 실행을 보류하고, 재개 후 timeout 케이스와 전체 회귀를 확인한다. 실기기 background delivery는 아직 미검증이다.

- 재개한 전체 UI에서 cardio 검색창 키보드 포커스 누락을 확인했다. 해당 케이스 단독 재실행은 97초에 통과했다. UI helper에 입력 전 포커스 확인과 최대 1회 재탭을 추가하여 검증한다.
- 사용자가 원격 CI 대신 로컬 테스트만 계속하도록 명시했다. 기존 다른 작업의 짧은 검증 이후 로컬 전체 UI를 재개한다.

- 사용자의 최종 지시로 전체 UI gate를 관련 테스트 통과로 축소했다. 전체 UI 실행은 중단했고 통과로 기록하지 않는다. 포커스 속성의 거짓 음성을 키보드 표시 확인으로 보완한 후 cardio 및 quick-start 검색 시나리오 2개가 모두 통과했다 (`ui-focus-fallback-targeted.log`).

- 5관점 리뷰 P1/P2/P3=0. 최종 품질 리뷰의 P3(포커스 확인 최대 2초)는 우선 필드 포커스를 확인하는 trade-off로 기록하고 유지했다. 해결책은 `docs/solutions/general/2026-09-27-healthkit-background-observer-launch.md`에 저장했다.
