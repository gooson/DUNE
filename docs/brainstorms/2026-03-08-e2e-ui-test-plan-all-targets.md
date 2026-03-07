---
tags: [ui-test, e2e, regression, xcuitest, watchos, visionos, widget, accessibility, mock-data]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 전체 화면 / 전체 타겟 E2E UI 테스트 플랜

## Problem Statement

현재 UI 테스트는 회귀 방지용 gate로 쓰기에는 범위가 좁다.

- iOS는 `DUNEUITests/Smoke/` 중심의 smoke 검증만 존재한다.
- watchOS는 `DUNEWatchUITests/Smoke/` 2개 시나리오만 있다.
- `DUNEVision`, `DUNEWidget`은 UI 자동화 하네스가 없다.
- 일부 접근성 식별자만 실제 화면에 연결되어 있고, `AXID`에 정의만 된 planned identifier가 남아 있다.
- iPhone, iPad, Watch, visionOS, widget을 하나의 회귀 전략으로 묶은 문서가 없다.

결과적으로 새 화면 추가, 네비게이션 변경, sheet/detail flow 수정, launch argument 분기 변경이 들어와도 전체 제품 표면에 대한 회귀 신호가 늦게 온다.

## Target Users

- iOS / watchOS / visionOS 개발자

핵심 니즈:

- PR 단계에서 핵심 회귀를 빠르게 막고 싶다.
- nightly에서는 가능한 한 전체 화면과 핵심 흐름을 자동 검증하고 싶다.
- 지금 당장 자동화하기 어려운 타겟도 TODO로 구조화해서 이후 `/plan`과 `/work`로 이어가고 싶다.

## Success Criteria

1. `DUNE` iPhone + iPad에서 모든 내비게이션 가능한 주요 화면과 sheet/detail flow가 회귀 대상에 포함된다.
2. `DUNEWatch`의 홈, 탐색, 운동 시작, 세션 진행, 종료 요약이 회귀 대상에 포함된다.
3. PR gate와 nightly full regression의 범위가 분리되어, 빠른 신호와 넓은 커버리지를 동시에 확보한다.
4. 테스트가 텍스트/레이아웃보다 `.accessibilityIdentifier()`와 launch argument 기반 상태 주입에 의존한다.
5. `DUNEVision`, `DUNEWidget`, HealthKit 권한, Cloud sync, offline, notification/deeplink는 즉시 구현 범위에서 분리하되 TODO로 명시된다.
6. flaky test를 줄이고, 실패 시 어떤 화면/흐름이 깨졌는지 바로 추적할 수 있다.

## Current State

### Existing Automated Coverage

- iOS:
  - `DUNEUITests/Launch/LaunchScreenTests.swift`
  - `DUNEUITests/Smoke/DashboardSmokeTests.swift`
  - `DUNEUITests/Smoke/ActivitySmokeTests.swift`
  - `DUNEUITests/Smoke/WellnessSmokeTests.swift`
  - `DUNEUITests/Smoke/LifeSmokeTests.swift`
  - `DUNEUITests/Smoke/SettingsSmokeTests.swift`
  - `DUNEUITests/Manual/HealthKitPermissionUITests.swift`
- watchOS:
  - `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift`
  - `DUNEWatchUITests/Smoke/WatchWorkoutStartSmokeTests.swift`

### Known Gaps

- iPad 전용 레이아웃은 헬퍼가 있으나 전체 화면 커버리지가 없다.
- seeded 상태와 empty 상태를 분리한 전체 회귀 세트가 없다.
- CRUD 기준의 full E2E test가 거의 없다.
- `DUNEVision`에는 accessibility identifier와 UI test target이 없다.
- `DUNEWidget`에는 widget family별 회귀 전략이 없다.
- `DUNEUITests/Helpers/UITestHelpers.swift`에 선언된 planned identifier 중 실제 view에 아직 연결되지 않은 항목이 있다.

## Product Surface Inventory

### Target: DUNE (iOS)

#### Today / Dashboard

- `DashboardView`
- `ConditionScoreDetailView`
- `MetricDetailView`
- `AllDataView`
- `WeatherDetailView`
- `NotificationHubView`
- `SettingsView`
- `WhatsNewView`
- `PinnedMetricsEditorView`
- `CloudSyncConsentView`
- Settings 하위 화면:
  - `ExerciseDefaultsListView`
  - `ExerciseDefaultEditView`
  - `PreferredExercisesListView`

#### Activity / Exercise

- `ActivityView`
- `TrainingReadinessDetailView`
- `WeeklyStatsDetailView`
- `TrainingVolumeDetailView`
- `ExerciseTypeDetailView`
- `PersonalRecordsDetailView`
- `ConsistencyDetailView`
- `ExerciseMixDetailView`
- `MuscleMapDetailView`
- `MuscleMap3DView`
- `ExercisePickerView`
- `ExerciseDetailSheet`
- `CreateCustomExerciseView`
- `ExerciseStartView`
- `WorkoutSessionView`
- `WorkoutCompletionSheet`
- `ExerciseView`
- `ExerciseHistoryView`
- `WorkoutTemplateListView`
- `CreateTemplateView`
- `TemplateWorkoutContainerView`
- `TemplateWorkoutView`
- `CompoundWorkoutSetupView`
- `CompoundWorkoutView`
- `CardioStartSheet`
- `CardioSessionView`
- `CardioSessionSummaryView`
- `HealthKitWorkoutDetailView`
- `UserCategoryManagementView`
- `NotificationTargetNotFoundView`

#### Wellness

- `WellnessView`
- `WellnessScoreDetailView`
- `MetricDetailView`
- `AllDataView`
- `BodyHistoryDetailView`
- `InjuryHistoryView`
- `InjuryStatisticsView`
- `BodyCompositionFormSheet`
- `InjuryFormSheet`

#### Life

- `LifeView`
- `HabitFormSheet`
- `HabitHistorySheet`

### Target: DUNEWatch (watchOS)

- `CarouselHomeView`
- `QuickStartAllExercisesView`
- `WorkoutPreviewView`
- `SessionPagingView`
- `MetricsView`
- `ControlsView`
- `RestTimerView`
- `SetInputSheet`
- `SessionSummaryView`

### Target: DUNEVision (visionOS) TODO

- `VisionContentView`
- `VisionDashboardView`
- `VisionTrainView`
- `VisionDashboardWindowScene` variants
- `Chart3DContainerView`
- `VisionVolumetricExperienceView`
- `VisionImmersiveExperienceView`
- placeholder wellness/life surfaces

### Target: DUNEWidget (WidgetKit) TODO

- `SmallWidgetView`
- `MediumWidgetView`
- `LargeWidgetView`
- placeholder states for each family

## Proposed Approach

### 1. Three-Lane Regression Strategy

#### Lane A: PR Gate

빠른 신호용이다.

- iPhone smoke
- iPad navigation smoke
- watch 핵심 smoke
- 가장 자주 깨지는 root navigation, toolbar action, 핵심 sheet open/close, 주요 happy path만 포함

#### Lane B: Nightly Full Regression

넓은 커버리지용이다.

- iPhone + iPad full regression
- watch full regression
- seeded / empty 상태 둘 다 검증
- add / edit / delete / dismiss / notification target not found 같은 흐름 포함

#### Lane C: Specialized / Deferred

즉시 자동화는 어렵지만 반드시 backlog에 올려둘 항목이다.

- `DUNEVision`
- `DUNEWidget`
- HealthKit 권한
- Cloud sync consent / recovery
- offline / no-data / partial-failure scenarios
- notification / deeplink / external routing

### 2. Testability-First Architecture

회귀 방지 목적상 테스트 코드는 view text보다 상태와 식별자에 의존해야 한다.

- `.accessibilityIdentifier()`를 화면 루트, primary CTA, row, section, empty state, detail entry point에 일관되게 부여
- `--uitesting`, `--seed-mock`, `--ui-reset`, `--ui-scenario=<name>` 같은 launch argument 도입
- SwiftData / mock snapshot 기반 fixture seeding
- empty / seeded / error-like 시나리오를 같은 테스트 프레임워크에서 재현 가능하게 설계

### 3. Coverage by Navigable Surface, Not by File Count

파일 수가 아니라 실제 사용자가 이동 가능한 화면 기준으로 커버리지를 설계한다.

- root tab / sidebar 진입
- push destination
- sheet / fullScreenCover
- toolbar action
- state transition
- save / cancel / delete / close

## Constraints

### Technical Constraints

- HealthKit / system permission dialog는 완전 자동화에 취약하다.
- iPad는 `TabView(.sidebarAdaptable)` 기반이라 iPhone과 selector 전략이 다를 수 있다.
- watch 세션 테스트는 timing과 runtime state에 민감하다.
- `DUNEVision`의 window / volumetric / immersive surface는 일반적인 iOS-style XCUITest로 끝나지 않는다.
- `DUNEWidget`은 앱 내부 XCUITest보다 snapshot / preview / widget host 검증이 더 적합할 수 있다.

### Team Constraints

- 문서의 1차 독자는 개발자다.
- 지금 당장은 전체 타겟을 한 번에 구현하기보다, TODO를 포함한 실행 순서를 명확히 만드는 것이 우선이다.

## Edge Cases

### 이번 문서에서 TODO로 관리할 항목

- HealthKit permission flow
- Cloud sync enable / decline / recovery
- offline / no network / partial failure banner
- notification / deeplink / missing target
- first launch / empty state vs seeded state
- iPad sidebar vs iPhone tab differences
- watch recovery / resume / interrupted session
- visionOS multi-window / immersive open failure
- widget no-data / stale-data / update timestamp

## Scope

### MVP (Must-have)

회귀 방지 목적상 현재 즉시 구현 범위는 `DUNE` + `DUNEWatch` 전체 화면 / 전체 핵심 흐름이다.

- `DUNE` iPhone 전체 화면
- `DUNE` iPad 전체 화면
- `DUNEWatch` 전체 화면
- add / edit / delete / close / back / cancel / save / empty / seeded
- PR gate와 nightly full regression 분리
- AXID 정비, fixture seeding, base test infrastructure 포함

### Nice-to-have (Future)

- `DUNEVision` 자동화 전략 수립 및 테스트 하네스 구축
- `DUNEWidget` family별 회귀 검증
- HealthKit / Cloud / offline / notification specialized lane
- visual snapshot, localization, dynamic type, performance lane

## Execution Plan

### Phase 0. 화면 인벤토리와 AXID 정리

- [ ] `DUNE` / `DUNEWatch`의 모든 navigable surface를 route 기준으로 inventory화
- [ ] root view, section entry, detail destination, sheet, fullScreenCover에 필요한 AXID 목록 확정
- [ ] `DUNEUITests/Helpers/UITestHelpers.swift`의 planned identifier와 실제 view 연결 상태를 맞춤
- [ ] iPhone / iPad / Watch에서 공통으로 사용할 selector naming 규칙 고정
- [ ] `DUNEVision` / `DUNEWidget`용 TODO inventory separate section 작성

### Phase 1. 테스트 인프라 구축

- [ ] `UITestBaseCase` 확장: reset, seed, scenario launch helper 추가
- [ ] `WatchUITestBaseCase` 확장: session launch / seed / interruption helper 추가
- [ ] `--seed-mock`, `--ui-reset`, `--ui-scenario` launch argument 도입
- [ ] SwiftData fixture seeder 추가
- [ ] reusable test helpers 추가:
- [ ] iPad sidebar navigation helper
- [ ] modal/sheet dismissal helper
- [ ] form fill helper
- [ ] scrolling to off-screen cell helper
- [ ] screenshot / failure artifact naming helper
- [ ] test plan 분리:
- [ ] `DUNEUITests-PR`
- [ ] `DUNEUITests-Full`
- [ ] `DUNEWatchUITests-PR`
- [ ] `DUNEWatchUITests-Full`

### Phase 2. DUNE Today / Settings 회귀 세트

- [ ] Dashboard root rendering smoke
- [ ] Today tab reselection / scroll-to-top behavior
- [ ] Condition hero -> `ConditionScoreDetailView`
- [ ] metric card -> `MetricDetailView`
- [ ] all-data route -> `AllDataView`
- [ ] weather card -> `WeatherDetailView`
- [ ] notification button -> `NotificationHubView`
- [ ] notification empty state / controls
- [ ] settings button -> `SettingsView`
- [ ] settings rows:
- [ ] rest time
- [ ] exercise defaults
- [ ] preferred exercises
- [ ] appearance
- [ ] iCloud sync
- [ ] location access
- [ ] What's New
- [ ] version / app info
- [ ] `PinnedMetricsEditorView` open / close
- [ ] `WhatsNewView` open / detail / close
- [ ] `CloudSyncConsentView` TODO hook point 정의

### Phase 3. DUNE Activity / Exercise 회귀 세트

- [ ] Activity root rendering smoke
- [ ] training readiness hero -> detail
- [ ] muscle recovery map / muscle detail
- [ ] weekly stats -> detail
- [ ] training volume -> overview -> exercise type detail
- [ ] recent workouts section
- [ ] personal records preview -> detail
- [ ] achievement history preview -> detail
- [ ] consistency -> detail
- [ ] exercise mix -> detail
- [ ] toolbar add -> `ExercisePickerView`
- [ ] picker search / recent / popular
- [ ] picker -> exercise detail sheet
- [ ] picker -> create custom exercise
- [ ] picker -> `ExerciseStartView`
- [ ] `ExerciseStartView` -> manual workout session
- [ ] `WorkoutSessionView` set input / complete / finish
- [ ] `WorkoutCompletionSheet` dismiss
- [ ] `ExerciseView` secondary surfaces
- [ ] `ExerciseHistoryView` open / close
- [ ] `WorkoutTemplateListView` open / create / edit
- [ ] `CreateTemplateView` create / validation
- [ ] `TemplateWorkoutContainerView` full-screen flow
- [ ] `CompoundWorkoutSetupView` -> `CompoundWorkoutView`
- [ ] `CardioStartSheet` -> `CardioSessionView` -> `CardioSessionSummaryView`
- [ ] `HealthKitWorkoutDetailView`
- [ ] `UserCategoryManagementView`
- [ ] notification route -> workout detail
- [ ] notification route -> target not found

### Phase 4. DUNE Wellness 회귀 세트

- [ ] Wellness root rendering smoke
- [ ] wellness hero -> `WellnessScoreDetailView`
- [ ] physical / active indicator card -> `MetricDetailView`
- [ ] all-data route
- [ ] body history link -> `BodyHistoryDetailView`
- [ ] injury history link -> `InjuryHistoryView`
- [ ] injury statistics route
- [ ] add menu -> body form
- [ ] body form validation
- [ ] body add save
- [ ] body edit save
- [ ] body delete TODO if supported
- [ ] add menu -> injury form
- [ ] injury form validation
- [ ] injury add save
- [ ] injury recovered toggle / end date
- [ ] injury edit save
- [ ] injury resolve / delete TODO if supported

### Phase 5. DUNE Life 회귀 세트

- [ ] Life root rendering smoke
- [ ] hero progress visibility
- [ ] habits list visibility
- [ ] add habit -> `HabitFormSheet`
- [ ] habit validation
- [ ] habit frequency mode changes
- [ ] habit create save
- [ ] habit edit save
- [ ] habit toggle completion
- [ ] habit history sheet open / close
- [ ] auto achievement section seeded verification
- [ ] archive / delete TODO if supported

### Phase 6. DUNEWatch 회귀 세트

- [ ] home renders with carousel or empty state
- [ ] all exercises navigation
- [ ] category filtering in quick start
- [ ] exercise preview
- [ ] strength workout start
- [ ] cardio workout preview path
- [ ] session paging root
- [ ] metrics screen
- [ ] controls screen
- [ ] set completion button
- [ ] set input sheet
- [ ] rest timer behavior
- [ ] workout end
- [ ] session summary
- [ ] interrupted session recovery TODO

### Phase 7. CI / Execution Lane 정착

- [ ] PR gate workflow:
- [ ] iPhone smoke
- [ ] iPad navigation smoke
- [ ] watch smoke
- [ ] test failure 시 merge-blocking
- [ ] Nightly full workflow:
- [ ] iPhone full
- [ ] iPad full
- [ ] watch full
- [ ] screenshot / xcresult artifact 업로드
- [ ] flaky test triage 규칙 정의
- [ ] 실패 분류 규칙:
- [ ] product regression
- [ ] selector debt
- [ ] seed/fixture issue
- [ ] simulator/environment instability

### Phase 8. Deferred Target TODO

- [ ] `DUNEVision` 접근성 식별자 설계
- [ ] `DUNEVision` dedicated test target 전략 수립
- [ ] window / immersive / volumetric 검증 방식 결정
- [ ] `DUNEWidget` snapshot / preview regression 전략 수립
- [ ] small / medium / large family별 expected state 정의
- [ ] widget stale / placeholder / scored state fixture 설계
- [ ] HealthKit permission manual lane 유지 또는 분리
- [ ] Cloud sync consent / recovery lane 추가
- [ ] offline / empty / partial failure lane 추가
- [ ] notification / deeplink / external route lane 추가
- [ ] visionOS simulator lane TODO

## Recommended Delivery Order

1. Phase 0-1로 AXID + seed + base infra를 먼저 고정한다.
2. Phase 2-5로 `DUNE` iPhone/iPad full coverage를 완성한다.
3. Phase 6으로 `DUNEWatch` full coverage를 확장한다.
4. Phase 7에서 PR gate / nightly lane을 분리해 운영한다.
5. Phase 8은 `DUNEVision`, `DUNEWidget`, specialized scenarios를 backlog로 넘긴다.

## Phase 0 Artifacts

- Page backlog index: `todos/021-ready-p2-e2e-phase0-page-backlog-index.md`
- Must-have surface TODOs: `todos/022-*.md` ~ `todos/083-*.md`
- Deferred surface TODOs: `todos/084-*.md` ~ `todos/095-*.md`
- Status: 화면 inventory를 page-level TODO로 분리 완료. AXID 정리와 harness 구현은 후속 `/plan` / `/work` 단계로 진행

## Open Questions

- watch full regression을 PR gate까지 올릴지, nightly부터 시작할지
- widget 회귀 검증을 snapshot 중심으로 갈지 preview host 기반으로 갈지
- visionOS 회귀를 XCUITest로 시도할지, surface-level smoke + snapshot 혼합으로 갈지
- seeded fixture 포맷을 JSON으로 관리할지 Swift fixture builder로 관리할지

## Next Steps

- [ ] `/plan e2e-ui-test-plan-all-targets` 로 구현 순서와 대상 파일을 확정
- [ ] Phase 0 inventory를 기준으로 AXID 누락 화면부터 먼저 정리
- [ ] PR gate 최소 세트와 nightly full 세트를 별도 문서 또는 test plan으로 분리
