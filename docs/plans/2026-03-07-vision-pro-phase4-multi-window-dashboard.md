---
topic: vision-pro-phase4-multi-window-dashboard
date: 2026-03-07
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-volumetric-phase2.md
  - docs/solutions/general/2026-03-07-visionos-app-icon-wiring.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro Phase 4 Multi-Window Dashboard

## Context

`todos/020-ready-p3-vision-pro-phase4-social-advanced.md`는 SharePlay, voice input, body tracking, multi-window를 한 파일에 묶고 있다. 현재 코드베이스에는 `openWindow(id:)`와 `WindowGroup` 기반 visionOS scene 확장 지점이 이미 있고, Phase 2/3에서 volumetric/immersive 경험까지 연결되어 있다. 반면 SharePlay와 speech pipeline은 capability, session sync, 오디오 입력 흐름이 아직 전혀 스캐폴드되지 않았다.

이번 `/run`에서는 과장 없이 **E1 Multi-Window Dashboard**를 먼저 제품화한다. 즉, 컨디션/운동/수면/바디 컴포지션을 각각 독립 윈도우로 열 수 있게 하고, 이후 G1/F3/C5는 후속 TODO로 남긴다.

## Requirements

### Functional

- Vision Pro 메인 대시보드에서 condition/activity/sleep/body 전용 윈도우를 각각 열 수 있어야 한다.
- 각 윈도우는 현재 HealthKit/Shared snapshot 기반 요약을 자체적으로 로드해서 표시해야 한다.
- 기존 `chart3d`, `spatial-volume`, `immersive-recovery` 진입점과 충돌 없이 공존해야 한다.
- shared 데이터 로직은 테스트 가능한 형태로 분리해야 한다.
- 기존 TODO 문맥에는 이번 배치가 E1 범위만 완료했다는 사실이 남아야 한다.

### Non-functional

- `openWindow`/`WindowGroup`는 Apple 공식 문서의 id 기반 패턴을 따른다.
- 새 사용자 노출 문자열은 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja로 등록한다.
- HealthKit 실패는 window 전체 crash 대신 unavailable/message 상태로 처리한다.
- 새 shared ViewModel은 `Observation` 기반, protocol DI, Swift Testing으로 검증한다.

## Approach

visionOS 전용 scene 렌더링은 `DUNEVision`에 두고, 데이터 로딩/상태 조합 로직은 `DUNE/Presentation/Vision/`의 shared ViewModel로 둔다. 이렇게 하면 iOS target에도 안전하게 컴파일되면서 `DUNETests/`에서 mock 기반 단위 테스트를 추가할 수 있다.

Window는 `WindowGroup(id:)` 네 개를 추가하고, 메인 dashboard quick action과 toolbar에서 각각 `openWindow(id:)`를 호출한다. 각 window view는 shared ViewModel을 사용해 summary를 렌더링한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TODO 020 전체(SharePlay + voice + form guide + windows) 일괄 구현 | TODO 파일을 한 번에 닫을 수 있음 | capability/API/testing 범위가 과도하고 검증 불가 리스크 큼 | 기각 |
| DUNEVision 전용 ViewModel만 추가 | 구현이 빠름 | DUNETests에서 검증하기 어려움 | 기각 |
| shared ViewModel + DUNEVision scene wiring | 테스트 가능, 기존 구조 재사용, 다음 phase 확장에 유리 | `project.yml`과 window wiring 수정 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-vision-pro-phase4-multi-window-dashboard.md` | create | 이번 구현 계획서 |
| `DUNE/Presentation/Vision/VisionDashboardWorkspaceViewModel.swift` | create | shared summary 로딩/상태 조합 |
| `DUNETests/VisionDashboardWorkspaceViewModelTests.swift` | create | shared ViewModel 테스트 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift` | create | 전용 visionOS metric window UI |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | modify | 새 window 액션 연결 |
| `DUNEVision/App/VisionContentView.swift` | modify | window open closure wiring |
| `DUNEVision/App/DUNEVisionApp.swift` | modify | condition/activity/sleep/body WindowGroup 추가 |
| `DUNE/project.yml` | modify | shared vision presentation 파일을 DUNEVision target에 포함 |
| `Shared/Resources/Localizable.xcstrings` | modify | 신규 Vision Pro window copy |
| `todos/020-ready-p3-vision-pro-phase4-social-advanced.md` | modify | E1 진행 현황 반영 / 후속 scope 명시 |

## Implementation Steps

### Step 1: shared workspace data loader 추가

- **Files**: `DUNE/Presentation/Vision/VisionDashboardWorkspaceViewModel.swift`, `DUNETests/VisionDashboardWorkspaceViewModelTests.swift`
- **Changes**:
  - `SharedHealthDataService`, `WorkoutQuerying`, `BodyCompositionQuerying`, `HealthKitManaging`를 주입받는 ViewModel 추가
  - condition/sleep/activity/body window 요약 모델 정의
  - HealthKit availability/authorization/message 조합 로직 구현
  - mock 기반 단위 테스트 작성
- **Verification**:
  - 요약 데이터가 snapshot/workouts/body 샘플에서 기대대로 조합된다
  - authorization 실패/partial fetch 실패 시 message 상태가 유지된다

### Step 2: DUNEVision window scene 추가

- **Files**: `DUNEVision/Presentation/Dashboard/VisionDashboardWindowScene.swift`, `DUNEVision/App/DUNEVisionApp.swift`, `DUNEVision/App/VisionContentView.swift`, `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`, `DUNE/project.yml`
- **Changes**:
  - condition/activity/sleep/body 전용 window scene UI 구현
  - 메인 dashboard quick action/toolbar에 새 window entry 추가
  - `WindowGroup(id:)` 4개 추가 및 `openWindow(id:)` 연결
  - shared ViewModel 파일이 DUNEVision target에도 포함되도록 `project.yml` 갱신
- **Verification**:
  - window ID와 `openWindow(id:)`가 일치한다
  - 새 window가 기존 chart3d/volumetric/immersive 흐름을 깨지 않는다

### Step 3: localization + TODO 문맥 정리

- **Files**: `Shared/Resources/Localizable.xcstrings`, `todos/020-ready-p3-vision-pro-phase4-social-advanced.md`
- **Changes**:
  - 새 사용자 문자열 en/ko/ja 추가
  - TODO 020에 이번 배치의 E1 완료 범위와 남은 G1/F3/C5를 명시
- **Verification**:
  - localization leak 없음
  - TODO 상태/updated 날짜가 현재 실행과 일치한다

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit unavailable | unavailable 상태 + fallback message 표시 |
| authorization 요청 실패 | log 후 가능한 범위의 cached/shared data로 계속 로드 |
| snapshot은 있으나 workout/body query 실패 | partial message를 유지하고 window는 가능한 카드만 렌더링 |
| body metric 일부만 존재 | 값이 있는 카드만 렌더링하고 empty copy 제공 |
| TODO 020 전체 미완료 | E1 완료 사실만 기록하고 나머지는 후속 scope로 명시 |

## Testing Strategy

- Unit tests: `VisionDashboardWorkspaceViewModel`의 ready/unavailable/partial-failure 조합을 Swift Testing으로 검증
- Integration tests: `scripts/test-unit.sh --ios-only`로 shared target 회귀 확인
- Manual verification: `scripts/lib/regen-project.sh` 후 `xcodebuild -scheme DUNEVision build`로 visionOS scene wiring 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| DUNEVision target에 shared file 미포함 | medium | high | `project.yml` 수정 후 regen-project + visionOS build 수행 |
| 신규 문자열 번역 누락 | medium | medium | xcstrings en/ko/ja 동시 추가 + review localization 체크 |
| HealthKit query 중 일부 empty/failure | medium | medium | ViewModel에서 partial message + card-by-card fallback 처리 |
| broad TODO를 너무 좁혀서 문맥 손실 | low | medium | TODO 파일에 완료/미완료 범위를 명시 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: `openWindow`/`WindowGroup` 패턴과 HealthKit query 서비스는 이미 존재해 구현 자체는 안정적이다. 다만 DUNEVision target source wiring과 visionOS build 검증은 실제 시뮬레이터/SDK 설정 영향을 받으므로 medium으로 둔다.
