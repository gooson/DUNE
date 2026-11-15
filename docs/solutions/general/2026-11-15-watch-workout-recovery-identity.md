---
tags: [watchos, healthkit, workout, recovery, save-error, session-identity]
category: general
date: 2026-11-15
status: implemented
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatchTests/WorkoutManagerSessionRecoveryTests.swift
related_solutions:
  - docs/solutions/general/2026-10-06-watch-workout-density-and-autosave.md
---

# Watch 운동 복구 시 운동 종류와 시작 시간 보존

## Problem

사용자 사진에서 Watch는 `0분`과 운동 데이터를 복구하지 못해 세트를 저장할 수 없다는 오류를 표시했지만 iPhone에는 계단 운동이 표시됐다. 후속 설명에서 사용자는 **운동 시간·기록이 보이는 최종 요약 화면의 완료**를 한 번 누른 뒤 앱이 백그라운드로 갔다가 다시 열렸다고 확인했다. 운동 강도 시트의 완료는 아니며, 실제 HealthKit 복구 응답은 미확인이다.

코드에서는 별도의 복구 결함을 확인했다. 로컬 복구 JSON이 없거나 디코딩되지 않으면 `workoutMode`가 기본값 `.strength`에 머물렀다. 실제 HealthKit 세션이 계단 운동이어도 요약 저장은 `templateSnapshot == nil`을 근력 세트 복구 실패로 처리했다. 종료 delegate도 같은 모드로 분기하므로 단일 운동 builder를 근력 운동의 병합 builder처럼 discard할 위험이 있었다.

`0분`은 이번 원인으로 확정하지 않았다. 실제 복구 함수에는 builder의 elapsed time을 이용한 별도 pause 보정이 있으며, 이 경로의 실기기 동작은 이번 테스트 범위 밖이다.

최종 요약의 완료 버튼은 `reset()`으로 운동 상태와 로컬 복구 snapshot을 지운다. 기존 generation 검사는 reset **이전**에 시작된 복구 요청을 차단하지만, reset **이후**에 시작된 요청은 같은 운동을 반환받아도 닫은 운동인지 구분하지 못했다. 실제로 HealthKit이 그 응답을 반환했는지는 관측하지 않았으며, 이 재채택 허점을 추가로 막았다. 운동 강도 시트의 완료는 시트만 닫으므로 최종 요약 완료와 구분한다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| `WorkoutManager.swift` | HealthKit configuration과 시작 시간을 pause 복원 전에 적용 | 로컬 JSON 유실 시에도 실제 운동 종류로 저장 경로 선택 |
| 같은 파일 | 세션 시작 시간이 다른 로컬 snapshot 거부 | 다른 운동의 템플릿·세트·일시 정지 시간 혼입 방지 |
| 같은 파일 | 시작·reset 시 generation 갱신, 비동기 복구 전후 세션 상태 확인 | 늦게 도착한 복구 응답이 새 운동을 덮어쓰는 상황 방지 |
| 같은 파일 | 종료된 운동 reset 전에 시작 시간을 영속 보존하고, 복구 응답 채택 전에 대조 | 완료로 닫은 운동의 재등장 방지 |
| `WorkoutManagerSessionRecoveryTests.swift` | 누락·손상·legacy·다른 운동 snapshot, 종목 분류, 근력 템플릿, 일시 정지 복원 검사 | 잘못된 세트 저장 오류 회귀 방지 |
| `WatchWorkoutFlowSmokeTests.swift` | 유산소 저장 → 최종 완료 → 백그라운드·복귀 → 앱 재실행 검사 | 완료한 요약과 오류 화면 재등장 검증 |

이 앱의 템플릿 기반 운동은 `.traditionalStrengthTraining` configuration을 사용한다. 나머지는 `startCardioSession`과 동일한 단일 builder 저장 모드로 복원한다. 따라서 유산소 category만 허용하는 방식으로 유연성·수영·기능성 근력 등의 단일 운동을 누락하지 않는다. 실제 근력 템플릿이 유실된 경우의 오류는 유지한다.

닫은 운동 표식은 복구 snapshot과 별도 UserDefaults 키에 저장하고 새 운동을 시작해도 지우지 않는다. 응답의 시작 시간이 같은 운동만 제외하며, 아직 완료로 닫지 않은 종료 세션을 일괄 거부하지 않는다. 거부한 HealthKit 세션을 새로 종료하거나 discard하지도 않는다.

HealthKit이 제공하는 [workoutConfiguration](https://developer.apple.com/documentation/healthkit/hkworkoutsession/workoutconfiguration)과 [startDate](https://developer.apple.com/documentation/healthkit/hkworkoutsession/startdate)를 세션 식별 기준으로 사용한다. 로컬 snapshot은 같은 세션의 추가 데이터로 취급한다.

## Validation

- 표준 `scripts/test-unit.sh --watch-only`에서 `DUNEWatchTests/WorkoutManagerSessionRecoveryTests`와 `DUNEWatchTests/WorkoutElapsedTimeTests`: 2 suites, 12 tests 통과. watchOS 27.2 전용 clone에서 실행했다.
- 최초 실행은 새 테스트 데이터의 필수 `duration` 인자 누락으로 컴파일 실패했다. `duration: nil` 보완 후 같은 selector를 1회 재실행해 통과했다. 실패 로그와 재실행 로그는 각각 `.xcodebuild/watch-session-recovery-unit.log`, `.xcodebuild/watch-session-recovery-unit-retry.log`에 보존한다.
- 사용자 후속 설명에 따른 완료 표식 보완 후 같은 2 suites를 실행해 **14 tests**가 통과했다. `.xcodebuild/watch-completed-recovery-unit.log`에 기록한다. 완료된 운동 reset 뒤 재채택 거부·다음 운동 허용과 active reset의 미완료 운동 보존을 추가로 검사했다.
- 전용 40mm Watch·watchOS 27.2에서 `DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testCardioSummaryDoneStaysDismissedAfterBackgroundAndRelaunch` **1/1 통과, exit 0**. `.xcodebuild/watch-summary-return-ui.log.result.json`의 정확한 selector 결과를 확인했다. 최종 완료 후 홈 복귀, Home 버튼으로 백그라운드 전환, 앱 복귀와 재실행 후 요약·오류 재등장 없음을 검사한다. 이 UI fixture는 모의 세션과 in-memory SwiftData를 사용하므로 영속 기록 보존·중복 제거의 검증으로 확장하지 않는다.
- 앱과 Watch test target 컴파일을 포함한다. 화면 배치·문구·String Catalog는 변경하지 않았다.
- 실제 HealthKit active-session 복구, 종료 callback 순서, builder elapsed-time 보정 및 사용자 사진의 `0분`은 실기기 미검증이다. 시뮬레이터의 운동 경로는 HealthKit session 대신 모의 세션을 사용한다.
- [실제 화면맵 F02](../../design/phone-design-map/actual/watch/index.html)는 위 UI 테스트에서 새로 캡처한 저장된 요약으로 갱신했다. 원본 `.xcresult`와 `.xcodebuild/watch-summary-return-attachments/manifest.json`을 보존한다. 복귀 후 홈 PNG도 직접 확인했다. 재실행 직후 PNG는 홈 제목만 뜬 부분 로딩 상태이므로 완성된 홈 화면맵 증거로 쓰지 않았다. F02의 기존 하단 지표 가림은 이번 수정 범위 밖의 관찰로 유지한다.
- F06(저장 오류)의 **실제 HealthKit 복구 상황** 새 캡처는 없다. 기존 PNG를 이번 수정의 증거로 재사용하거나 완료 표시하지 않았다. iPhone·iPad·Duo는 코드 변경 대상이 아니다.

## Prevention

출하 전 [5관점·최종 PR 리뷰](../../reviews/2026-11-15-watch-recovery/review-ship.md)에서 P1/P2는 없었고, 중복 대입 P3 두 건을 제거했다. 제거 후 관련 Watch unit 14개가 다시 통과했다. UI 1/1은 두 대입문 제거 전 실행이며, 최종 리뷰에서 결과 불변을 확인해 재사용했다.

- 복구용 JSON을 읽지 못해도 HealthKit의 세션 종류·시작 시간부터 복원한다.
- 세션 시간 일치 확인 전에 로컬 템플릿과 pause 데이터를 적용하지 않는다.
- pause 복원 중 snapshot을 다시 쓸 수 있으므로 운동 종류·시작 시간 설정을 먼저 수행한다.
- 완료로 닫은 운동의 식별 정보는 복구 snapshot과 수명을 분리한다. reset 이후 시작된 요청과 앱 재실행에도 같은 운동을 다시 채택하지 않아야 한다.
- 잘못된 저장 오류의 코드 수정과 실기기 저장 완료 검증을 구분해 보고한다.

## Lessons Learned

운동의 HealthKit 저장과 Watch의 추가 기록 저장은 서로 다른 경로다. iPhone의 운동 목록만으로 Watch 저장 오류 전체를 해결했다고 판단할 수 없고, 복구 JSON의 누락을 실제 근력 세트 데이터 유실과 구분해야 한다. 새 공통 규칙 추가는 제안하지 않았다.
