---
topic: Watch Reinstall Exercise Sync Feedback and Recovery
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/watch-settings-sync-pattern.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
  - docs/solutions/architecture/2026-03-02-watch-navigation-request-observer-update-loop.md
related_brainstorms: []
---

# Implementation Plan: Watch Reinstall Exercise Sync Feedback and Recovery

## Context

Apple Watch 앱을 삭제 후 재설치하면 운동 목록(`exerciseLibrary`)이 비어 있는 시간이 길게 발생한다. 현재 watch 앱은 context에 운동 목록 키가 없어도 `synced` 상태로 표시하므로, 사용자는 “지금 가져오는 중인지 / 실패했는지”를 구분하기 어렵다.

## Requirements

### Functional

- 재설치 직후 watch가 운동 목록이 비어 있으면 iPhone에 재동기화를 능동적으로 요청해야 한다.
- iPhone은 watch의 재동기화 요청 메시지를 수신해 즉시 `exerciseLibrary`를 재전송해야 한다.
- watch 동기화 상태는 실제 데이터 유무에 맞게 표시되어야 한다(빈 데이터인데 `synced` 금지).

### Non-functional

- 기존 WatchConnectivity DTO/validation 규칙을 유지해야 한다.
- 기존 workoutComplete/setCompleted 수신 경로를 회귀 없이 보존해야 한다.
- 변경 범위는 watch sync 경로와 관련 UI 표시로 한정한다.

## Approach

watch 측에서 “운동 목록이 비어 있고 연결 상태가 확보된 경우” 재동기화 요청 메시지를 보내고, iPhone 측에서 해당 메시지를 처리하여 즉시 `syncExerciseLibraryToWatch()`를 호출한다. 동시에 watch의 상태 로직을 보강해 라이브러리 미수신 상태를 `syncing/notConnected`로 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| watch에서 iPhone app context를 수동 polling | 구현 단순해 보임 | WCSession polling API 부재, 효과 없음 | 기각 |
| iPhone 활성화 시점 push만 유지 | 코드 변경 최소 | 재설치/비활성 상황에서 지연 지속 | 기각 |
| watch pull-request + iPhone 즉시 push + 상태 보강 | 지연 복구 빠름, 사용자 피드백 명확 | 메시지 파싱 경로 확장 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/WatchConnectivityManager.swift` | modify | 재동기화 요청 API 추가, 라이브러리 미수신 상태 처리 보강 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | modify | watch의 `requestExerciseLibrarySync` 메시지/유저인포 수신 및 재전송 처리 |
| `DUNEWatch/Views/CarouselHomeView.swift` | modify | 빈 상태에서 수동 재동기화 액션 노출 |
| `DUNEWatch/Views/QuickStartAllExercisesView.swift` | modify | 빈 상태에서 수동 재동기화 액션 노출 |
| `DUNEWatch/Resources/Localizable.xcstrings` | modify | watch UI 신규 문자열 키(재동기화 액션) 추가 |
| `DUNEWatchTests/WatchConnectivityManagerTests.swift` | add | watch 상태/재요청 트리거 회귀 테스트 |
| `DUNETests/WatchSessionManagerTests.swift` | add | iPhone 메시지 파싱 및 sync 요청 처리 회귀 테스트 |

## Implementation Steps

### Step 1: Watch 재동기화 요청 경로 추가

- **Files**: `WatchConnectivityManager.swift`
- **Changes**:
  - 라이브러리 미수신 시 `syncStatus`를 `synced`로 오표시하지 않도록 수정
  - `requestExerciseLibrarySync(force:)` API 추가
  - activation/context 수신 시 empty library면 자동 재요청
- **Verification**: watch 단위 테스트에서 empty context 시 상태/요청 동작 검증

### Step 2: iPhone 요청 수신/재전송 처리

- **Files**: `WatchSessionManager.swift`
- **Changes**:
  - Data-only 파싱을 일반 메시지 파싱 구조로 확장
  - `requestExerciseLibrarySync` key 수신 시 `syncExerciseLibraryToWatch()` 호출
  - `didReceiveUserInfo` 경로도 동일 처리
- **Verification**: iOS 단위 테스트에서 request key 수신 시 sync 호출 검증

### Step 3: Empty state 재시도 UI + 문자열

- **Files**: `CarouselHomeView.swift`, `QuickStartAllExercisesView.swift`, `Localizable.xcstrings`
- **Changes**:
  - empty state에 `Retry Sync` 버튼 추가
  - 버튼 탭 시 `connectivity.requestExerciseLibrarySync(force: true)` 호출
- **Verification**: watch UI smoke 시 empty state에서 retry 버튼 노출 확인

### Step 4: 회귀 검증

- **Files**: tests + build commands
- **Changes**: 대상 테스트 실행
- **Verification**:
  - `DUNETests` 신규/기존 WatchSessionManager 관련 테스트 통과
  - `DUNEWatchTests` 신규/기존 WatchConnectivityManager 관련 테스트 통과
  - watch target build 성공

## Edge Cases

| Case | Handling |
|------|----------|
| watch 재설치 직후 iPhone 비연결 | `syncStatus = .notConnected` 유지 + Retry Sync로 재요청 가능 |
| iPhone 활성화 이전에 watch가 먼저 실행 | watch의 요청 메시지를 userInfo로 큐잉해 iPhone 활성화 후 처리 |
| context에 settings만 있고 library 없음 | `synced`로 오표시하지 않고 재요청 시도 |

## Testing Strategy

- Unit tests:
  - `WatchConnectivityManager` 상태 전이/재요청 로직
  - `WatchSessionManager` 요청 메시지 파싱/재전송 호출
- Integration tests:
  - watch target build
- Manual verification:
  - watch 앱 삭제→재설치 후 iPhone 앱 미오픈 상태에서 notConnected/syncing 상태 확인
  - iPhone 앱 실행 후 10초 내 운동 목록 수신 확인
  - Retry Sync 탭 시 목록 수신 가속 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 새 메시지 파싱으로 기존 workoutComplete 경로 회귀 | low | high | Data key별 분기 유지 + 기존 디코드 테스트 보강 |
| 재요청 과다 전송 | medium | low | watch 측 최소 간격(throttle) 적용 |
| 문자열 키 누락으로 watch 빌드 경고 | low | medium | xcstrings에 신규 키 추가 후 빌드 검증 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 watch settings sync pattern(dual delivery/applicationContext 재구성)과 일관되고, 문제의 직접 원인(요청 부재 + 상태 오표시)을 최소 변경으로 해소한다.
