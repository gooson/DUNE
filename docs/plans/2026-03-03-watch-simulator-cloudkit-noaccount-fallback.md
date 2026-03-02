---
topic: Watch Simulator CloudKit No-Account Fallback
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-02-28-cloudkit-remote-notification-background-mode.md
  - docs/solutions/general/2026-03-02-run-review-fix-batch.md
related_brainstorms:
  - docs/brainstorms/2026-03-02-watch-workout-start-freeze.md
---

# Implementation Plan: Watch Simulator CloudKit No-Account Fallback

## Context

워치 시뮬레이터에서 CloudKit 설정이 활성화된 상태로 앱이 부팅되면 `CKAccountStatusNoAccount` 에러가 반복되고, 이후 운동 시작 경로까지 연쇄 실패한다. 현재 워치 타깃은 iPhone 앱과 달리 CloudKit을 항상 `.automatic`으로 강제하며, Info.plist에도 CloudKit push 관련 background mode 키가 누락되어 경고가 발생한다.

## Requirements

### Functional

- 시뮬레이터/무계정 환경에서 워치 앱이 CloudKit 없이 정상 부팅되어야 한다.
- 운동 시작 흐름(근력/카디오)이 CloudKit 상태와 무관하게 동작해야 한다.
- CloudKit 경고(`remote-notification`)를 제거해야 한다.

### Non-functional

- 실기기 iCloud 로그인 환경에서는 기존 CloudKit 동기화를 유지해야 한다.
- 변경 범위는 워치 시작 구성과 Info.plist에 한정한다.
- 기존 SwiftData fallback(in-memory) 전략과 충돌하지 않아야 한다.

## Approach

워치 앱 부팅 시점에 CloudKit 사용 여부를 환경 기반으로 결정한다.
- 시뮬레이터: CloudKit 비활성화
- 실기기: iCloud 계정 토큰 존재 시에만 활성화

추가로 워치 Info.plist에 CloudKit/Workout 관련 background mode를 명시해 런타임 경고와 시작 실패 가능성을 줄인다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| CloudKit 항상 활성화 유지 + in-memory fallback만 의존 | 코드 변경 최소 | 무계정 환경에서 경고/초기화 실패 반복, 부팅 안정성 저하 | 기각 |
| launch 후 비동기 CKAccountStatus 체크 후 재구성 | 계정 상태를 정확히 확인 가능 | ModelContainer 재구성 복잡도 높음 | 기각 |
| 부팅 전 환경 기반 CloudKit 게이팅 | 단순, 동기 결정 가능, 부작용 적음 | 계정 변경 즉시 반영은 재실행 시점 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/DUNEWatchApp.swift` | modify | CloudKit 사용 여부 결정 로직 추가 (`simulator`/`ubiquityIdentityToken`) |
| `DUNEWatch/Resources/Info.plist` | modify | `UIBackgroundModes: remote-notification`, `WKBackgroundModes: workout-processing` 추가 |
| `docs/plans/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md` | add | 구현 계획 문서 |

## Implementation Steps

### Step 1: CloudKit 게이팅 도입

- **Files**: `DUNEWatchApp.swift`
- **Changes**: `shouldEnableCloudKit` 계산 후 `ModelConfiguration.cloudKitDatabase`를 `.automatic/.none`으로 분기
- **Verification**: 시뮬레이터 로그에서 `CKAccountStatusNoAccount` 반복 여부 확인

### Step 2: Watch background mode 보강

- **Files**: `DUNEWatch/Resources/Info.plist`
- **Changes**: CloudKit push/Workout 처리용 background mode 키 추가
- **Verification**: `BUG IN CLIENT OF CLOUDKIT` 경고 재현 여부 확인

### Step 3: 회귀 검증

- **Files**: build/test commands
- **Changes**: watch 타깃 빌드 + watch 단위 테스트 실행
- **Verification**: 컴파일 성공, 테스트 통과, 설정 충돌 없음

## Edge Cases

| Case | Handling |
|------|----------|
| 실기기에서 iCloud 로그아웃 상태 | CloudKit 자동 비활성화로 로컬 모드 부팅 |
| 시뮬레이터에서 HealthKit 권한 지연 | 기존 timeout + 에러 알럿 경로 유지 |
| CloudKit 비활성화 상태에서 기존 로컬 store 존재 | SwiftData 로컬 store 그대로 사용 |

## Testing Strategy

- Unit tests: 기존 watch 단위 테스트 회귀 실행
- Integration tests: watch 시뮬레이터에서 Strength/Cardio 시작 수동 확인
- Manual verification:
  - 앱 실행 시 CloudKit no-account 에러 미출력
  - 운동 시작 버튼 탭 후 세션 진입 또는 원인 기반 오류 알럿

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ubiquityIdentityToken` 판단 오탐 | low | medium | 시뮬레이터는 컴파일 타임 분기로 강제 OFF |
| watchOS background mode 키 호환성 이슈 | low | medium | watch 타깃 빌드/테스트로 즉시 검증 |
| 실제 실기기 동기화 회귀 | low | high | 실기기 iCloud 로그인 상태에서 추가 수동 검증 안내 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 iOS 타깃의 CloudKit 게이팅 패턴과 동일하며, 워치 부팅 안정성 이슈를 최소 변경으로 직접 완화한다.
