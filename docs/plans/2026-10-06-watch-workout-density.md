---
topic: watch-workout-density
date: 2026-10-06
status: approved
confidence: medium
related_solutions:
  - design/2026-03-12-watch-set-input-rpe-visibility.md
related_brainstorms:
  - 2026-03-12-watch-rpe-auto-estimation.md
  - 2026-02-27-watch-ux-renewal.md
---

# Implementation Plan: 워치 운동 화면 밀도와 휴식 조작 개선

## Context

실기기 사진의 휴식 화면에서는 작은 카운트다운, 큰 RPE 버튼, 세 개의 가로 텍스트 버튼이 시각적으로 경쟁한다. `RestTimerView`는 종료 확인 전에 countdown task를 취소해 확인을 취소하면 완료 이벤트가 오지 않을 수 있다. 근력 세트 화면은 진행 막대·세트 문구·점 표시를 중복 노출하고, 완료 요약은 긴 통계와 세부 내역 다음에 저장 버튼이 있다.

## Requirements

### Functional

- 휴식 중 남은 시간을 최우선으로 보여주고 RPE 입력은 발견 가능하게 유지한다.
- 휴식 동작은 큰 `Skip`과 `+30s`를 중심으로 배치한다. 운동 종료는 기존 Controls 페이지에 남긴다.
- `End` 확인을 취소해도 countdown, 경고 햅틱, 자동 완료가 유지된다.
- 근력 세트 화면의 중복 진행 표현을 줄이고 완료 버튼을 유지한다.
- 완료 요약에서 핵심 통계와 저장 동작을 상세 내역보다 먼저 보여준다.

### Non-functional

- watchOS 작은 화면, 한국어·일본어, 큰 글씨에서 조작 가능해야 한다. 44pt 이상 터치 영역을 목표로 한다.
- HealthKit 저장, RPE 추정/기록, 타이머 duration 전달, 운동 종료 흐름을 바꾸지 않는다.
- `.claude/**`와 기존 다른 브랜치 변경은 수정하지 않는다.

## Approach

`RestTimerView`에서 3열 텍스트 버튼과 중복 종료 동작을 제거하고, 타이머 중심의 세로 위계로 재배치한다. RPE는 작은 명시적 입력 행으로 둔다. 종료는 기존 `ControlsView`의 확인 동작을 사용한다. `MetricsView`는 막대/점 중 하나만 남겨 현재 세트를 더 명확히 하고, `SessionSummaryView`는 저장 버튼을 핵심 통계 직후로 이동한다. 전역 DS 간격을 일괄 확대하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 모든 Watch 간격 토큰 확대 | 변경량 적음 | 작은 화면 overflow 및 다른 화면 회귀 | 선택 안 함 |
| RPE를 별도 페이지에 숨김 | 휴식 화면이 단순해짐 | 이전 RPE 가시성 회귀 | 선택 안 함 |
| 휴식 종료 버튼 유지·크기만 축소 | 기능 위치 유지 | 3열 조작과 오터치 문제 지속 | 선택 안 함 |
| 휴식 종료를 Controls에서만 제공 | 휴식 화면의 동작 수 감소 | Crown으로 한 페이지 이동 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Views/RestTimerView.swift` | Modify | 타이머/RPE/동작 위계와 종료 취소 버그 수정 |
| `DUNEWatch/Views/MetricsView.swift` | Modify | 중복 세트 진행 표현 정리, rest 종료 콜백 제거 |
| `DUNEWatch/Views/SessionSummaryView.swift` | Modify | 저장 동작을 핵심 통계 뒤로 이동 |
| `DUNEWatch/Resources/Localizable.xcstrings` | If needed | 새/변경 라벨 3개 언어 번역 |
| `DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift` | Modify | 휴식 CTA, 큰 글씨, Controls 종료 흐름 검증 |
| `DUNEWatchUITests/Smoke/WatchResponsiveWorkoutLayoutTests.swift` | Modify | 휴식 화면 핵심 조작 viewport 검증 |
| `DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift` | If needed | stable selector 및 viewport helper 재사용 |

## Implementation Steps

### Step 1: 휴식 화면과 종료 흐름

- **Files**: `RestTimerView.swift`, `MetricsView.swift`, Watch strings if needed
- **Changes**: 타이머를 시각적 중심으로 확대, RPE를 보조 행으로 유지, 3열 버튼을 분리하고 End를 Controls로 이동. 종료 취소에 앞선 countdown cancel을 제거한다.
- **Verification**: RPE 입력/건너뛰기/+30초가 남고, Controls에서 종료 확인을 취소하면 타이머가 계속 진행한다.

### Step 2: 세트/요약 정보 위계

- **Files**: `MetricsView.swift`, `SessionSummaryView.swift`
- **Changes**: 중복 진행 표시를 하나로 줄이고 완료 저장을 상세 내역 위로 이동.
- **Verification**: 현재 세트·완료 CTA 및 요약 핵심 통계·저장 CTA가 최초 화면에 접근 가능하다.

### Step 3: 화면 검증

- **Files**: Watch UI tests and selectors as necessary
- **Changes**: seeded strength flow에서 휴식 레이아웃·RPE·Skip, 큰 글씨 접근, Controls 종료 확인 취소를 고정한다.
- **Verification**: `scripts/build-ios.sh`, 변경 범위 판정 결과가 요구하는 Watch UI suite, 관련 unit tests 통과. 시뮬레이터 접근 실패 시 로그와 미검증 범위를 명확히 기록한다.

## Edge Cases

| Case | Handling |
|------|----------|
| RPE 추정 없음/있음 | 둘 다 짧은 진입점 유지, 확정 후 상태 반영 |
| 남은 시간 1분 미만 | `9` 대신 단위가 분명한 형태로 표기 |
| +30초 총 600초 제한 | 한도에서 비활성 상태를 표시 |
| 확인창 취소/타이머 만료 경합 | 확인 전 countdown을 멈추지 않으며, 확정 종료만 task 취소 |
| 작은 화면/큰 글씨/긴 번역 | ViewThatFits/ScrollView fallback 및 터치 영역 확인 |
| 화면 전환 중 countdown | 기존 onDisappear 취소·완료 콜백 유지 |

## Testing Strategy

- Unit tests: 새 순수 로직이 생기면 Watch Swift Testing으로 경계값 검증. SwiftUI body만 변경하면 UI 테스트로 대체.
- UI tests: `ui-testing` 패턴으로 `DUNEWatchUITests`의 fixture strength flow를 확장. 존재뿐 아니라 tappability/viewport와 종료 취소 후 진행을 확인.
- Build: `scripts/build-ios.sh`.
- Final UI scope: `python3 scripts/plan-ui-tests.py --base main` 재판정 후 필요한 Watch runner 실행. iOS 영향이 없음을 소비자 검색으로 확인.
- Manual: 실기기에서 사진과 같은 한국어 휴식 상태, 작은/큰 화면, 땀 묻은 손 조작, VoiceOver 순서 확인.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Crown 세로 페이지 이동과 휴식 조작 충돌 | Medium | Medium | Controls 이동을 기존 vertical TabView에서 테스트 |
| 새 위계가 작은 Watch에서 overflow | Medium | High | 최소 크기/큰 글씨 viewport 테스트 |
| RPE 진입점이 숨겨짐 | Medium | Medium | 버튼을 최초 화면에 유지하고 UI selector로 고정 |
| CoreSimulator 서비스 접근 실패 | Medium | High | 한 번 원인 확인 후 권한 경로로 복구, 동일 실패 무의미 재시도 금지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 실기기 사진과 SwiftUI 구조가 문제를 직접 보여준다. 레이아웃의 최종 크기와 크라운 조작은 Watch 시뮬레이터/기기 검증이 필요하다.
