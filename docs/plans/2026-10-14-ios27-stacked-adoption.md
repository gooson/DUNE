---
tags: [ios27, wwdc26, stacked-pr, healthkit, foundation-models, app-intents, widgetkit]
date: 2026-10-14
category: plan
status: approved
topic: iOS 27 adoption in stacked PRs
confidence: medium
related_solutions:
  - docs/solutions/testing/2026-02-16-xcodegen-test-infrastructure.md
  - docs/solutions/general/2026-02-25-condition-score-zero-fix.md
  - docs/solutions/general/2026-03-14-condition-score-intraday-stability.md
  - docs/solutions/general/2026-03-08-widget-app-group-file-storage.md
related_brainstorms:
  - docs/brainstorms/2026-03-15-reorder-workout-exercises.md
  - docs/brainstorms/2026-03-07-widget-visual-refresh.md
---

# Implementation Plan: iOS 27 adoption in stacked PRs

## Context

WWDC26에서 확인한 DUNE 적용 후보를 우선순위 순으로 제공한다. 사용자의 최신 지시에 따라 iOS·watchOS·visionOS 최소 지원 버전을 27.0으로 높이는 PR을 스택 맨 아래에 둔다. 현재 채팅의 원래 작업트리는 분리된 HEAD와 다수의 선행 미커밋 변경을 포함하므로, 이 계획은 `origin/main`에서 만든 깨끗한 별도 작업트리에서 실행한다.

## Requirements

### Functional

- 모든 앱 및 확장 타깃의 최소 배포 버전을 27.0으로 맞추고 생성된 Xcode 프로젝트와 기본 테스트 시뮬레이터를 동기화한다.
- HealthKit의 기간 제한 읽기 권한을 타입별로 인식하고, 권한 범위 밖의 과거를 결측이 아닌 미확인으로 취급한다.
- 고빈도 HRV 표본으로 인한 컨디션 점수 변화를 테스트 데이터로 검증하고 필요한 계산 수정만 적용한다.
- HealthKit 운동 구간을 운동 후 요약과 Watch 실시간 표시에서 사용한다.
- 기존 Foundation Models 기능에 실제 출력 품질 평가를 추가한다.
- 운동 템플릿과 습관의 안전한 동작을 App Intents·단축어로 제공한다.
- 휴식 타이머 Live Activity의 iOS 27 가로 Dynamic Island와 작은 화면을 지원한다.
- Watch 운동 순서 변경, 위젯 구성, 성능 계측을 각기 독립된 후속 PR로 제공한다.

### Non-functional

- 각 PR은 직전 PR 브랜치를 base로 하는 독립 diff를 가진다. 스택을 아래부터 검증·머지한다.
- 빌드·단위·UI CI는 `main`과 `codex/ios27-*` 대상 PR에서 모두 실행한다.
- `.claude/**` 원본과 원래 작업트리의 미커밋 파일을 수정·커밋하지 않는다.
- 건강 데이터는 기존 온디바이스 처리 원칙과 HealthKit 개인정보 보호 계약을 유지한다.
- 화면 변경 PR은 영향받는 기기의 UI 테스트와 실제 화면 디자인맵 캡처를 동기화한다.
- 각 PR의 `/run` Plan → Work → UI Test → Review → Quality → Resolve → Compound → Pre-Ship → Ship 증거를 남긴다.

## Approach

`origin/main`에서 `codex/ios27-deployment`를 만들고, 이후 브랜치를 직전 브랜치 HEAD에서 생성한다. PR은 검증된 브랜치 순서대로 생성하며 base를 직전 PR head로 지정한다. 마지막 PR까지 준비되면 아래부터 순차적으로 merge하고 후속 PR의 base·diff를 확인한다. API 전환은 검증 가능한 작은 데이터/UI 경계에서 진행한다.

| 순서 | 우선순위 | PR 브랜치 | 주요 결과 |
|---|---|---|---|
| 01 | 선행 조건 | `codex/ios27-deployment` | iOS/watchOS/visionOS와 테스트 기본 런타임 27.0 |
| 02 | P0 | `codex/ios27-healthkit-limited-access` | 타입별 읽기 시작일, 추세/기준선의 부분 데이터 표현 |
| 03 | P1 | `codex/ios27-hrv-density` | 새 Watch 수준 표본 밀도 회귀 테스트와 필요한 점수 안정화 |
| 04 | P1 | `codex/ios27-workout-zones` | HealthKit 개인화 구간, Watch 실시간 구간, 운동 후 분포 |
| 05 | P1 | `codex/ios27-ai-evaluations` | Q&A·운동 템플릿 생성 평가 세트와 실행 경로 |
| 06 | P1 | `codex/ios27-app-intents` | 템플릿 열기·습관 기록 단축어와 시스템 경로 테스트 |
| 07 | P2 | `codex/ios27-rest-live-activity` | 가로 Dynamic Island·작은 화면 휴식 타이머 |
| 08 | P2 | `codex/ios27-watch-reorder` | Watch 순서 변경 제스처와 접근성 조작 |
| 09 | P2 | `codex/ios27-widget-config` | 사용자가 표시 지표를 고르는 위젯 |
| 10 | P2 | `codex/ios27-metrickit` | 상태별 성능 계측과 개인 건강값 비포함 보고 |

SwiftData `ResultsObserver`/`HistoryObserver`, 자세 이미지 AI, Private Cloud Compute는 측정된 문제 또는 개인정보·계정 자격 판단이 선행되지 않아 이번 적용 스택에서 제외한다. WWDC26 조사에서 보류 후보로 분류한 항목이다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 하나의 대형 PR | 한 번의 빌드와 머지 | 기능별 리뷰·롤백 불가 | 제외 |
| iOS 26 지원 유지 | 지원 기기 폭 유지 | 27 전용 기능마다 이중 경로 필요 | 사용자의 최신 지시에 따라 제외 |
| 우선순위별 stacked PR | 독립 검증, 순차 적용 | base 및 머지 후 재확인 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/project.yml`, `DUNE/DUNE.xcodeproj/project.pbxproj` | 수정 | 27.0 최소 배포 버전 동기화 |
| `scripts/test-unit.sh`, `scripts/test-ui.sh`, `scripts/test-watch-ui.sh`, `scripts/tests/test_ui_test_runner.py`, `.github/workflows/*.yml`, `CLAUDE.md` | 수정 | 테스트 런타임·CI Xcode 이미지와 프로젝트 목표 설명 동기화 |
| `DUNE/Data/HealthKit/HealthKitManager.swift`, 관련 QueryService·ViewModel·Tests | 수정 | 기간 제한 권한과 부분 데이터 처리 |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift`, 관련 Tests | 조건부 수정 | 고빈도 HRV 영향 검증과 필요한 안정화 |
| `DUNE/Domain/Models/HeartRateZone.swift`, `DUNE/Data/HealthKit/HeartRateQueryService.swift`, `DUNEWatch/Managers/WorkoutManager.swift`, 관련 View·Tests | 수정 | 개인화 구간 모델과 실시간/사후 표시 |
| `DUNE/Data/Services/HealthDataQAService.swift`, `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift`, 평가 파일 | 추가·수정 | Foundation Models 평가 |
| App Intents 추가 파일, 습관·운동 템플릿 저장 경로, 관련 Tests | 추가·수정 | 단축어 액션 |
| `DUNEWidget/WorkoutRestLiveActivity.swift`, `DUNEWatch/Views/WatchExerciseReorderView.swift`, `DUNEWidget/WellnessDashboardWidget.swift` | 수정 | UI 적용 후보 |
| 상태 보고 진입점, MetricKit 수집 코드, 관련 Tests | 추가·수정 | 성능 계측 |
| `docs/design/phone-design-map/actual/`, `docs/solutions/`, `docs/plans/` | 추가·수정 | 실제 화면 증거와 구현 문서 |

## Implementation Steps

### Step 1: Deployment baseline PR

- **Files**: `DUNE/project.yml`, 생성 프로젝트, `scripts/test-*.sh`, 테스트 실행기 계약, `.github/workflows/*.yml`, `CLAUDE.md`.
- **Changes**: 세 플랫폼 및 확장 타깃의 배포 버전을 27.0으로 맞추고, 26.x 시뮬레이터로 되돌아가는 기본값을 제거한다. CI를 iOS/watchOS/visionOS 27 SDK가 포함된 Xcode 27 이미지로 옮긴다.
- **Verification**: xcodegen 재생성, build, 프로젝트 build settings의 모든 target 확인, iOS/watchOS 27 시뮬레이터 대상 테스트 명령과 CI 계약 확인.

### Step 2: HealthKit limited read authorization PR

- **Files**: `HealthKitManager`, 데이터 기간이 노출되는 QueryService·점수 표시 경로, 관련 tests.
- **Changes**: `earliestAuthorizedSampleDate(for:)`를 권한 요청 후 호출하고 날짜를 데이터 종류별로 전달한다. 전체 허용과 거부의 구별 불가 계약을 유지한다.
- **Verification**: 제한된 시작일/전체 허용·거부와 14일 기준선 경계 테스트, 실제 기기 권한 화면 수동 확인 경로 기록.

### Step 3: HRV sample density PR

- **Files**: 컨디션 점수 계산기와 테스트, 필요할 경우 옵저버 갱신 경로.
- **Changes**: 시간별 표본 수가 크게 다른 동일 생리 신호 fixture를 비교한다. 결과가 부당하게 바뀌는 경우에만 집계 보정을 한다.
- **Verification**: 저빈도·고빈도·혼합 소스 3개 이상 시나리오, 기존 기준선 테스트 회귀.

### Step 4: HealthKit workout zones PR

- **Files**: 구간 Domain/Data, 운동 후 ViewModel/View, Watch WorkoutManager/View, Tests.
- **Changes**: 설정 출처와 가변 구간 수를 보존하고 HealthKit 구간을 사용한다. 구간 데이터가 없는 오래된 운동에는 기존 계산을 적용한다.
- **Verification**: 시스템/사용자/앱 정의 구간, 이전 운동, Watch 실시간 변경, iOS/Watch 화면 테스트.

### Step 5: Foundation Models Evaluations PR

- **Files**: 평가 데이터·실행 설정 및 기존 AI 서비스 테스트.
- **Changes**: 건강 단정 방지, 데이터 부족, 언어, 유효 운동 ID·세트 구성을 점수화한다.
- **Verification**: 기기/모델 가용성 별 평가 실행 및 결정적 결과 확인; 비가용 환경은 명시적으로 보고.

### Step 6: App Intents PR

- **Files**: 새 Intents/Entities, 운동 템플릿·습관 저장 경로, 관련 tests.
- **Changes**: 앱 소유 데이터만 노출하고 민감한 건강 값은 기본 응답에 담지 않는다.
- **Verification**: Shortcuts 실행, 엔티티 식별자 안정성, 중복 습관 완료, AppIntentsTesting 가능한 경로.

### Step 7: Rest Live Activity PR

- **Files**: 휴식 타이머 widget view와 tests/captures.
- **Changes**: 제한 폭에서는 간결한 표시를 사용하고 작은 family 레이아웃을 제공한다.
- **Verification**: 세로·가로 Dynamic Island, Watch Smart Stack 및 접근성.

### Step 8: Watch reorder PR

- **Files**: Watch 재정렬 view와 workout state, tests/captures.
- **Changes**: 완료 운동을 고정한 채 Watch 끌기 재정렬을 추가하고 접근성 조작을 유지한다.
- **Verification**: 제스처·완료 운동 경계·Watch 캡처.

### Step 9: Configurable widget PR

- **Files**: 위젯 구성과 App Intent, widget tests/captures.
- **Changes**: 사용자가 Condition/Readiness/Wellness 중 대표 지표를 고른다.
- **Verification**: 기본 설정 마이그레이션, 선택 변경, 잠금 화면 개인정보 노출 점검.

### Step 10: MetricKit PR

- **Files**: 앱 상태 보고·수집 코드와 tests.
- **Changes**: 자세 분석·AI·기록 화면 구간의 성능 상태를 기록하되 원시 건강값은 포함하지 않는다.
- **Verification**: 상태 전환과 비민감 필드 테스트, MetricKit 시스템 전달은 실제 기기 후속 확인.

## Edge Cases

| Case | Handling |
|---|---|
| 이미 iOS/watchOS/visionOS 26에 설치한 사용자 | 27 미만 기기는 업데이트할 수 없음을 릴리스 노트에 명시하고 27 업그레이드 후 기존 데이터 마이그레이션을 검증 |
| 권한 날짜가 타입별로 다름 | 각 타입의 쿼리 시작일과 표시 범위를 별도로 계산 |
| HealthKit 권한 결과에 타입이 없음 | 전체 허용 또는 거부 가능성을 유지하고 단정하지 않음 |
| 구간 없는 과거 운동 | 현재 추정 계산 또는 구간 없음 상태로 표시하고 출처 표기 |
| 구간 기준 변경 | 서로 다른 경계의 Zone 3을 동일 강도로 단순 비교하지 않음 |
| AI 사용 불가·할당량 | 기존 결정적 fallback을 유지 |
| App Intents 반복 호출 | stable ID와 멱등성 검증 |
| 디자인맵이 `main`에 아직 없음 | 원래 작업트리의 미커밋 PNG를 복사·커밋하지 않고 새 화면의 실제 캡처로 영향 화면을 생성; 막히면 미갱신 ID와 이유 보고 |

## Testing Strategy

- **Unit tests**: 새 로직과 경계/결측/NaN/중복 시나리오를 Swift Testing으로 검증한다.
- **Integration tests**: 빌드 설정, HealthKit 서비스 주입 경로, App Intents 시스템 실행을 검증한다.
- **UI tests**: `plan-ui-tests.py`를 각 PR의 실제 base에 실행하고 변경 범위에 맞는 iOS/Watch 테스트를 선택한다. 새 화면 동작은 테스트를 추가한다.
- **Manual verification**: HealthKit 실제 읽기 권한 선택, 운동 구간, Dynamic Island, 위젯과 Siri 언어별 동작은 기기·권한 전제를 기록한다.
- **Design map**: UI 변경 PR은 해당 상태·기기를 다시 캡처하고 원본 PNG와 출처를 갱신한다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 최소 27 전환으로 26 기기 지원 종료 | 확정 | 높음 | 첫 PR에서 명시, 타깃 전체 일치 검증 |
| 27 API 시뮬레이터와 실제 기기 차이 | 중간 | 높음 | 모델/서비스 단위 테스트 + 실기기 확인 항목 |
| 장기 스택에서 하위 PR merge 후 base 이동 | 중간 | 중간 | PR마다 base/diff 확인 후 순차 merge |
| 원래 작업트리 미커밋 변경 혼입 | 낮음 | 높음 | 별도 clean worktree에서만 구현·commit |
| 디자인맵이 baseline 미추적 | 높음 | 중간 | UI PR 진입 전 캡처 경로 확인, 선행 산출물 재사용 금지 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 배포 타깃·HealthKit·UI 코드의 변경 지점은 확인됐다. 후속 AI 평가와 시스템 통합은 SDK/실기기 제약에 따라 각 PR의 검증에서 확정한다.
