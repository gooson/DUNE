---
source: brainstorm/end-to-end-review
priority: p1
status: done
created: 2026-03-08
updated: 2026-03-08
---

# End-to-End 전체 코드베이스 리뷰

## 목표

전체 코드베이스(~481 Swift files)를 기능/레이어별로 쪼개어 체계적으로 리뷰한다.
부족하거나, 끊겨있거나, 위험하거나, 낭비되는 코드를 식별하고 제거/수정한다.

## 리뷰 관점 (6-point inspection)

| # | 관점 | 검사 항목 |
|---|------|----------|
| 1 | **끊김 (Disconnected)** | 미사용 심볼, 호출되지 않는 함수, 도달 불가 코드 경로 |
| 2 | **부족 (Incomplete)** | 누락된 에러 핸들링, 빠진 validation, 미구현 분기 |
| 3 | **위험 (Risky)** | 데이터 손실 가능성, race condition, crash 경로 |
| 4 | **낭비 (Wasteful)** | 중복 코드, 과잉 추상화, 불필요한 계산 |
| 5 | **규칙 위반 (Rule Violation)** | `.claude/rules/` 패턴 위반 |
| 6 | **로컬라이제이션 (L10n)** | 미번역 문자열, xcstrings 누락 |

---

## Review Units

### R1: Domain Layer — Models, Protocols, Enums (67 files)
- **범위**: `DUNE/Domain/Models/`, `DUNE/Domain/Protocols/`, `DUNE/Domain/Services/`
- **핵심 검사**:
  - SwiftUI/UIKit/SwiftData import 금지 (swift-layer-boundaries.md)
  - Protocol이 실제 구현체를 가지는지 확인
  - enum exhaustive case 확인
  - Sendable 준수 여부
- **상태**: [ ] 미완료

### R2: Domain Layer — UseCases & Business Logic (27 files)
- **범위**: `DUNE/Domain/UseCases/`
- **핵심 검사**:
  - 미사용 UseCase 식별 (CalculateAverageBedtimeUseCase 등)
  - 수학 함수 방어 (log/sqrt/division by zero)
  - 입력 검증 패턴 준수
  - TaskGroup/async let 병렬화 패턴
- **상태**: [ ] 미완료

### R3: Data Layer — HealthKit Integration (19 files)
- **범위**: `DUNE/Data/HealthKit/`
- **핵심 검사**:
  - 쿼리 병렬화 (for-loop await 금지)
  - 값 범위 검증 (HR 20-300, Weight 0-500 등)
  - Watch 소스 감지 패턴
  - Cancel-before-spawn 패턴
- **상태**: [ ] 미완료

### R4: Data Layer — Persistence/SwiftData (24 files)
- **범위**: `DUNE/Data/Persistence/`
- **핵심 검사**:
  - @Relationship Optional 필수 (CloudKit)
  - VersionedSchema 동기화
  - ModelContainer recovery 패턴
  - auto-save 위임 (명시적 save 지양)
- **상태**: [ ] 미완료

### R5: Data Layer — External Services & WatchConnectivity (25 files)
- **범위**: `DUNE/Data/Services/`, `DUNE/Data/External/`, `DUNE/Data/WatchConnectivity/`
- **핵심 검사**:
  - API 에러 처리 completeness
  - DTO 양쪽 target 동기화
  - Weather/AirQuality fallback
  - Widget data writer 안전성
- **상태**: [ ] 미완료

### R6: Presentation — Dashboard Feature (15 files)
- **범위**: `DUNE/Presentation/Dashboard/`
- **핵심 검사**:
  - Score 계산 → UI 연결 완전성
  - Placeholder/skeleton 처리
  - body 내 금지 패턴 (Calendar 연산, Service 호출)
  - 로컬라이제이션 누락
- **상태**: [ ] 미완료

### R7: Presentation — Activity & Training Analytics (51 files)
- **범위**: `DUNE/Presentation/Activity/`
- **핵심 검사**:
  - NavigationDestination 완전성 (모든 enum case 매칭)
  - 차트 성능 (.clipped(), allocation 금지)
  - Computed property 캐싱
  - Period 전환 .id() + .transition()
- **상태**: [ ] 미완료

### R8: Presentation — Exercise Session & Workout Flow (34 files)
- **범위**: `DUNE/Presentation/Exercise/`
- **핵심 검사**:
  - 세션 lifecycle (시작→진행→완료→저장)
  - 데이터 유실 방어 (onDisappear 저장)
  - isSaving 중복 방지
  - Rest timer 정확성
  - Cardio session metric 전달 완전성
- **상태**: [ ] 미완료

### R9: Presentation — Wellness & Body Composition (9 files)
- **범위**: `DUNE/Presentation/Wellness/`
- **핵심 검사**:
  - 입력 validation (weight 0-500, bodyFat 0-100)
  - HealthKit 쓰기 안전성
  - Form sheet dismiss 후 데이터 갱신
- **상태**: [ ] 미완료

### R10: Presentation — Life/Habits & Injury Tracking (12 files)
- **범위**: `DUNE/Presentation/Life/`, `DUNE/Presentation/Injury/`
- **핵심 검사**:
  - Streak 계산 정확성
  - Injury 충돌 검사 (CheckInjuryConflictUseCase 연결)
  - Habit CRUD 완전성
  - 삭제 확인 (withAnimation + .tint(.red))
- **상태**: [ ] 미완료

### R11: Presentation — Shared Components & Design System (85+ files)
- **범위**: `DUNE/Presentation/Shared/`
- **핵심 검사**:
  - 디자인 토큰 일관성 (DS.Color, DS.Spacing)
  - 중복 컴포넌트 식별
  - Wave background 사용 패턴
  - Extension 레이어 경계 (Domain+View.swift 위치)
  - Color(red:green:blue:) 인라인 금지
- **상태**: [ ] 미완료

### R12: Presentation — Charts & Visualization Library
- **범위**: `DUNE/Presentation/Shared/Charts/`
- **핵심 검사**:
  - 대량 데이터 성능 (1000+ data points)
  - .clipped() 적용
  - Chart closure 내 allocation 금지
  - gradient/color static 호이스트
  - Selection overlay material 사용
- **상태**: [ ] 미완료

### R13: App Layer — Entry Points, Navigation, Settings (13 files)
- **범위**: `DUNE/App/`, `DUNE/Presentation/Settings/`
- **핵심 검사**:
  - 탭 라우팅 완전성 (ContentView)
  - NavigationStack 소유권 (ContentView만)
  - ModelContainer 초기화/복구
  - LaunchExperience 흐름
  - Settings 각 항목 연결
- **상태**: [ ] 미완료

### R14: watchOS App (34 files)
- **범위**: `DUNEWatch/`
- **핵심 검사**:
  - NavigationStack(path:) 사용 (watch-navigation.md)
  - WatchRoute enum type-safe routing
  - Sheet 내부 NavigationStack 금지
  - onChange 감시 범위 최소화
  - @State 데이터 보호 (onDisappear)
  - strength 템플릿 discardWorkout + 개별 HKWorkout
  - exerciseLibrary 미수신 상태 처리
- **상태**: [ ] 미완료

### R15: Widget & visionOS (27 files)
- **범위**: `DUNEWidget/`, `DUNEVision/`
- **핵심 검사**:
  - Widget 데이터 갱신 타이밍
  - Widget placeholder 적절성
  - visionOS 미완성 코드 정리 (Phase 4 TODO)
  - visionOS ViewModel without View 식별
- **상태**: [ ] 미완료

### R16: Cross-Cutting — Dead Code, Orphans, Localization Gaps
- **범위**: 전체 코드베이스
- **핵심 검사**:
  - 미사용 심볼 최종 확인
  - xcstrings orphan key 식별
  - 코드에서 삭제됐지만 xcstrings에 남은 키
  - xcstrings에 없지만 코드에서 참조하는 키
  - 중복 import 정리
  - .DS_Store 등 불필요 파일
- **상태**: [ ] 미완료

### Final: 종합 발견사항 정리 & 액션 아이템
- 리뷰 결과를 severity별로 분류
- P1 (Critical): 즉시 수정
- P2 (Important): 다음 스프린트
- P3 (Minor): 백로그
- **상태**: [ ] 미완료

---

## 초기 탐색에서 발견된 잠재 이슈

1. **`CalculateAverageBedtimeUseCase`** — 미사용 가능성 (R2에서 확인)
2. **visionOS ViewModels without Views** — Phase 4 대기 코드 (R15에서 확인)
3. **ExerciseView 접근 경로** — ActivityView에서 라우팅 명확화 필요 (R13에서 확인)
4. **Watch DesignSystem 수동 동기화** — iOS DS와 불일치 위험 (R14에서 확인)

## 진행 기록

| Review | 시작일 | 완료일 | 발견 수 | P1 | P2 | P3 |
|--------|--------|--------|---------|----|----|-----|
| R1 | 2026-03-08 | 2026-03-08 | 7 | 1 | 2 | 4 |
| R2 | 2026-03-08 | 2026-03-08 | 13 | 0 | 9 | 4 |
| R3 | 2026-03-08 | 2026-03-08 | 24 | 5 | 4 | 15 |
| R4 | 2026-03-08 | 2026-03-08 | 6 | 0 | 2 | 4 |
| R5 | 2026-03-08 | 2026-03-08 | 7 | 0 | 2 | 5 |
| R6+R7 | 2026-03-08 | 2026-03-08 | 15 | 0 | 6 | 9 |
| R8 | 2026-03-08 | 2026-03-08 | 9 | 2 | 4 | 3 |
| R9+R10 | 2026-03-08 | 2026-03-08 | 20 | 7 | 8 | 5 |
| R11+R12 | 2026-03-08 | 2026-03-08 | 26 | 2 | 19 | 5 |
| R13+R14 | 2026-03-08 | 2026-03-08 | 10 | 1 | 3 | 6 |
| R15 | 2026-03-08 | 2026-03-08 | 15 | 1 | 6 | 8 |
| R16 | 2026-03-08 | 2026-03-08 | 11 | 2 | 6 | 3 |
| **Total** | | | **163** | **21** | **71** | **71** |

---

## Completed Review Findings

### R1: Domain Models/Protocols/Enums — 7 findings (1 P1, 2 P2, 4 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R1-1 | P2 | rule-violation | `Domain/Protocols/AirQualityFetching.swift:1` | `import CoreLocation` forbidden in Domain — replace CLLocation with Coordinate struct |
| R1-2 | P2 | rule-violation | `Domain/Models/TemplateWorkoutConfig.swift:17` + 2 files | `TemplateEntry` defined in Data layer but used in Domain — move to Domain |
| R1-3 | P1 | l10n | `Domain/Models/ActiveRecoverySuggestion.swift:11-13` | Sendable struct의 title/duration이 `String(localized:)` 없이 하드코딩 |
| R1-4 | P3 | rule-violation | `Domain/Models/BodyPart.swift:70` | `isJoint`에서 `default:` 사용 — exhaustive case 필요 |
| R1-5 | P3 | disconnected | `Domain/Models/CompoundFatigueScore.swift:14` | `FatigueBreakdown` type name이 Presentation에서 직접 참조 안됨 (간접 사용 중, info only) |
| R1-6 | P3 | risky | `Domain/Models/WorkoutIntensity.swift:81` | `EffortCategory.init(effort:)` default가 unreachable dead code |
| R1-7 | P3 | risky | `Domain/Models/WorkoutIntensity.swift:19` | `WorkoutIntensityLevel.init(rawScore:)` NaN/Inf 입력 시 `.maxEffort` 할당 |

### R2: Domain UseCases — 13 findings (0 P1, 9 P2, 4 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R2-1 | P2 | disconnected | `Domain/UseCases/WorkoutTemplateRecommendationService.swift:22` | 전체 서비스 미사용 (production caller 없음) |
| R2-2 | P3 | disconnected | `Domain/UseCases/FatigueCalculationService.swift:147` | `sessionLoad` 불필요한 public 노출 |
| R2-3 | P2 | incomplete | `Domain/UseCases/HealthDataAggregator.swift:164` | `fillDateGaps` while 루프에 iteration guard 없음 (무한루프 위험) |
| R2-4 | P2 | l10n | `Domain/UseCases/ActivityPersonalRecordService.swift:30,167` | subtitle "Strength", "Manual Cardio" 하드코딩 |
| R2-5 | P2 | rule-violation | `Domain/UseCases/CalculateConditionScoreUseCase.swift:91-125` | 6x `String(format:)` 사용 — forbidden pattern |
| R2-6 | P3 | risky | `Domain/UseCases/CalculateConditionScoreUseCase.swift:160` | `computeDailyAverages` isFinite 필터 누락 |
| R2-7 | P2 | l10n | `Domain/UseCases/LifeAutoAchievementService.swift:39` | progressText fallback unlocalized |
| R2-8 | P2 | wasteful | ConditionScore + TrainingReadiness UseCases | `computeDailyAverages()` 중복 구현 |
| R2-9 | P2 | wasteful | WorkoutRecommendation + SpatialTraining | `computeFatigueStates()` 중복 구현 |
| R2-10 | P3 | rule-violation | `Domain/UseCases/LifeAutoAchievementService.swift:77` | `default:` in classification switch |
| R2-11 | P2 | l10n | `Domain/UseCases/OneRMEstimationService.swift:175-193` | 4x training zone name 하드코딩 |
| R2-12 | P2 | l10n | `Domain/UseCases/WorkoutRecommendationService.swift:134-292` | 8+ hardcoded English reason strings |
| R2-13 | P3 | l10n | `Domain/UseCases/CoachingEngine.swift:203,330,456` | rawValue 사용 — displayName 권장 |

### R3: HealthKit Integration — 24 findings (5 P1, 4 P2, 15 P3/Info)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R3-F3 | P2 | disconnected | `HealthKitManager.swift:16-40` | `.flightsClimbed` readTypes 누락 but queried |
| R3-F4 | Info | disconnected | `CardioSessionManager.swift` | Presentation caller 없음 — 통합 미완성 또는 orphan |
| R3-F5 | P2 | rule-violation | `SleepQueryService.swift:147` | Sequential await in loop (healthkit-patterns 위반) |
| R3-F6 | P2 | rule-violation | `StepsQueryService.swift:43` | Sequential await in loop |
| **R3-F8** | **P1** | **risky** | `HRVQueryService.swift:41` | **HRV upper bound 누락 (>500ms 허용)** |
| **R3-F9** | **P1** | **risky** | `HRVQueryService.swift:116` | **HRV collection upper bound 누락** |
| **R3-F10** | **P1** | **risky** | `HRVQueryService.swift:67,92` | **RHR 범위 검증 전혀 없음 (20-300 bpm)** |
| **R3-F11** | **P1** | **risky** | `HRVQueryService.swift:143` | **RHR collection 범위 검증 없음** |
| **R3-F12** | **P1** | **risky** | `BodyCompositionQueryService.swift:186` | **Weight/BMI 범위 검증 없음** |
| R3-F13 | P2 | risky | `StepsQueryService.swift:36` | Steps upper bound 없음 (200,000) |
| R3-F15 | P3 | wasteful | WorkoutQueryService + BGEvaluator | extractDistance/validHR 중복 |
| R3-F17 | P3 | wasteful | `WorkoutQueryService.swift:227` | `static var` → `static let` |
| R3-F22-24 | P3 | l10n | HealthKitManager/WorkoutWrite/EffortScore | Error descriptions not localized |

### R4: SwiftData Persistence — 6 findings (0 P1, 2 P2, 4 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R4-1 | P3 | disconnected | `HealthSnapshotMirrorContainerFactory.swift` | 전체 파일 dead code |
| R4-2 | P2 | risky | 4 Presentation files | `modelContext.delete()` without `withAnimation` (4곳) |
| R4-3 | P2 | risky | `ExerciseDefaultRecord.swift:30` | `precondition` → production crash 가능 |
| R4-4 | P3 | rule-violation | `WorkoutTemplate.swift:153-195` | display label이 Data layer에 위치 (layer violation) |
| R4-5 | P3 | wasteful | `PersonalRecordStore.swift:343` | prDisplayName이 Data layer에서 localization 수행 |
| R4-6 | P3 | incomplete | `HealthSnapshotMirrorStore.swift:61` | save 실패 시 retry 경로 없음 |

### R5: External Services & WatchConnectivity — 7 findings (0 P1, 2 P2, 5 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R5-1 | P2 | incomplete | `HealthSnapshotMirrorMapper.swift:177` | baselineStatus always nil on deserialization |
| R5-2 | P2 | risky | `HealthSnapshotMirrorMapper.swift:117-119` | No HRV/RHR validation on deserialized CloudKit payload |
| R5-3 | P3 | wasteful | `HealthSnapshotMirrorMapper.swift` | Multiple String ↔ Data conversions |
| R5-4 | P3 | l10n | Various Service files | Error descriptions not localized |
| R5-5 | P3 | disconnected | `WeatherKitFetcher.swift` | Unused internal helper |
| R5-6 | P3 | wasteful | `AirQualityFetcher.swift` | Duplicate validation logic |
| R5-7 | P3 | incomplete | `WatchSessionManager.swift` | Transfer error retry 미구현 |

### R6+R7: Dashboard + Activity — 15 findings (0 P1, 6 P2, 9 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R67-1 | P2 | rule-violation | `TrendChartView.swift:10` | Missing `.clipped()` on Chart |
| R67-2 | P2 | rule-violation | `WeeklySummaryChartView.swift:68` | Missing `.clipped()` on Chart |
| R67-3 | P2 | performance | `ConsistencyDetailView.swift:94,99` | Calendar operations in body (~60 ops per render) |
| R67-4 | P2 | performance | `MuscleMap3DView.swift:21-23` | `fatigueByMuscle` Dictionary rebuilt per-access |
| R67-5 | P2 | l10n | `VolumeAlgorithmSheet.swift:108,116` | `formulaRow`/`bulletPoint` accept String → localization leak |
| R67-6 | P2 | l10n | `VolumeDonutChartView.swift:135` | "Others" label hardcoded, not localized |
| R67-7 | P3 | wasteful | Various Activity files | Minor duplicate computations |
| R67-8 | P3 | l10n | Various Dashboard files | Minor localization gaps |
| R67-9~15 | P3 | mixed | Various files | Minor style/cleanup items |

### R8: Exercise Session & Workout Flow — 9 findings (2 P1, 4 P2, 3 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R8-1 | **P1** | **risky** | `CompoundWorkoutView.swift` | No draft persistence, no scenePhase monitoring → data loss if app terminated during workout |
| R8-2 | **P1** | **risky** | `TemplateWorkoutView.swift` | Same as R8-1 — no draft persistence for template workouts (30+ min sessions) |
| R8-3 | P2 | risky | `CardioSessionView.swift` | No onDisappear data protection |
| R8-4 | P2 | risky | `WorkoutSessionView.swift` | onDisappear vs scenePhase gap |
| R8-5 | P2 | rule-violation | `WorkoutTemplateListView.swift:49` | modelContext.delete without withAnimation |
| R8-6 | P2 | rule-violation | `UserCategoryManagementView.swift:102-106` | modelContext.delete without withAnimation |
| R8-7 | P3 | l10n | `OneRMAnalysisSection.swift:57` | formula rawValue in Text |
| R8-8 | P3 | l10n | `ExerciseTransitionView.swift:98` | hardcoded "kg" |
| R8-9 | P3 | wasteful | `ExercisePickerView.swift` | Large view with many computed properties |

### R9+R10: Wellness + Life + Injury — 20 findings (7 P1, 8 P2, 5 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R910-1 | **P1** | **risky** | `BodyCompositionViewModel.swift:133` | `defer { isSaving = false }` in returning function — double-tap guard defeated |
| R910-2 | **P1** | **risky** | `BodyHistoryDetailView.swift:41` | modelContext.delete() without withAnimation |
| R910-3 | **P1** | **risky** | `LifeView.swift:606-607` | modelContext.delete() without withAnimation (loop) |
| R910-4 | **P1** | **risky** | `InjuryFormSheet.swift:131` | Save button not disabled by isSaving |
| R910-5 | **P1** | **risky** | `BodyCompositionFormSheet.swift:47-51` | Save button not disabled by isSaving |
| R910-6 | **P1** | **l10n** | `InjuryWarningBanner.swift:47-56` | 3 user-facing strings without String(localized:) |
| R910-7 | **P1** | **risky** | `BodyCompositionFormSheet.swift:47-49` | sensoryFeedback fires before validation |
| R910-8 | P2 | rule-violation | `InjuryHistoryView.swift:42` | .onChange(of: array.map) O(N) — use hash |
| R910-9 | P2 | wasteful | `WellnessScoreDetailView.swift:17-33` | Redundant sort (data already sorted) |
| R910-10 | P2 | risky | `InjuryViewModel.swift:151-153` | static let Date() captured at class load time |
| R910-11 | P2 | incomplete | `BodyCompositionViewModel.swift` | Missing didFinishSaving() method |
| R910-12 | P2 | incomplete | `BodyCompositionViewModel.swift:143` | applyUpdate does not set isSaving = true |
| R910-13 | P2 | l10n | `InjuryHistoryView.swift:196` | Inconsistent "Active" localization pattern |
| R910-14 | P2 | wasteful | `LifeView.swift:391-443` | autoAchievementGroups computed per body eval |
| R910-15 | P2 | wasteful | `InjuryBodyMapView.swift:48-54` | muscleInjuries/jointInjuries filtered per body eval |
| R910-16 | P3 | disconnected | (scope note) | SleepViewModel not in expected directory |
| R910-17 | P3 | incomplete | `BodyHistoryDetailView.swift` | loadHealthKitData() never called — HK data invisible |
| R910-18 | P3 | wasteful | `WellnessScoreDetailView.swift:17-33` | Duplicate of R910-9 |
| R910-19 | P3 | risky | `HabitRowView.swift:222-223` | countInput has no upper bound guard |
| R910-20 | P3 | l10n | `SleepDeficitGaugeView.swift:92,98` | "14d avg"/"90d avg" — verify xcstrings |

### R11+R12: Shared Components + Charts — 26 findings (2 P1, 19 P2, 5 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R1112-1 | P2 | disconnected | `SleepStageChartView.swift` | Entire file dead code — zero consumers |
| R1112-2 | P2 | disconnected | `HeartRateZoneChartView.swift` | Entire file dead code — zero consumers |
| R1112-3 | P2 | disconnected | `PeriodSwipeModifier.swift` | Entire file dead code — zero consumers |
| R1112-4 | P3 | disconnected | `HanokEaveShape.swift` | Dead code — zero consumers |
| R1112-5 | P3 | disconnected | `OceanWaveShape.swift` | Dead code — zero consumers |
| R1112-6 | P2 | incomplete | `SleepStageChartView.swift:154-162` | segmentColor uses hardcoded English string matching |
| R1112-7 | P3 | wasteful | `DotLineChartView.swift:21-24` | Redundant Period enum (duplicates TimePeriod) |
| R1112-8 | **P1** | **rule-violation** | `OceanWaveBackground.swift:1156-1169` | 14 inline Color(red:green:blue:) — FORBIDDEN |
| R1112-9 | P2 | rule-violation | `MuscleMap3DScene.swift:525-531` | 4 inline UIColor(red:green:blue:) |
| R1112-10 | P2 | rule-violation | `WaveShape.swift:101-115` | .onAppear for repeatForever animation (should use .task) |
| R1112-11 | P2 | rule-violation | `WaveRefreshIndicator.swift:48-53` | .onAppear for repeatForever animation |
| R1112-12 | P2 | rule-violation | 4 chart views | Missing .clipped() (AreaLine, Bar, DotLine, RangeBar) |
| R1112-13 | P2 | wasteful | `TimePeriod+View.swift` | Uncached DateFormatter |
| R1112-14 | P2 | wasteful | `ChartAccessibility.swift:16` | Uncached DateFormatter |
| R1112-15 | P3 | wasteful | `SectionGroup.swift:30-215` | Gradients not hoisted to static |
| R1112-16 | P3 | rule-violation | `BodyCalculationCard.swift`, `ConditionCalculationCard.swift` | String(format:) for debug labels |
| R1112-17 | P2 | l10n | `ConditionCalculationCard.swift:67-72,86-87` | Hardcoded English "well above"/"today"/"yesterday" |
| R1112-18 | P2 | l10n | `BodyCalculationCard.swift:13,22` | Hardcoded "Body Calculation"/"neutral start" |
| R1112-19 | P2 | l10n | `ChangeBadge.swift:20` | "— No previous data" verify xcstrings |
| R1112-20 | **P1** | **l10n** | `WorkoutSet+Summary.swift:15-20` | Hardcoded "sets"/"reps" in String (not LocalizedStringKey) |
| R1112-21 | P2 | l10n | `InjuryRecord+View.swift:15` | Hardcoded "Today" without String(localized:) |
| R1112-22 | P2 | l10n | `AppTheme+View.swift:326` | "Hanok" missing String(localized:) |
| R1112-23 | P2 | l10n | `ExerciseMuscleMapView.swift:14-15` | "Front"/"Back" as String params → localization leak |
| R1112-24 | P2 | l10n | `ExerciseSetColumnHeaders.swift:14-36` | "REPS"/"MIN"/"SEC"/"LVL" verify xcstrings |
| R1112-25 | P2 | l10n | `ConfirmDeleteRecordModifier.swift:69` | Alert message interpolation — verify xcstrings key format |
| R1112-26 | P2 | l10n | `DetailScoreHero.swift:7-13` | String params for labels — Leak Pattern 1 risk |

### R13+R14: App Layer + watchOS — 10 findings (1 P1, 3 P2, 6 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R1314-1 | **P1** | **l10n** | `WorkoutPreviewView.swift:98,112,129` | "Indoor"/"Outdoor" missing from Watch xcstrings |
| R1314-2 | P2 | incomplete | `SessionSummaryView.swift:534-574` | saveCardioRecord does not persist averageHeartRate/maxHeartRate |
| R1314-3 | P2 | rule-violation | `WatchWaveBackground.swift:304-319` | .onAppear for repeatForever animation |
| R1314-4 | P3 | risky | `SettingsView.swift:10` | CLLocationManager() in @State initializer |
| R1314-5 | P3 | risky | `WorkoutManager.swift:986` | discardWorkout() without error handling |
| R1314-6 | P3 | wasteful | `DUNEWatch/DesignSystem.swift` | Full copy of iOS DS tokens |
| R1314-7 | P3 | rule-violation | `WatchWaveBackground.swift:80-87` | Inline Color(red:green:blue:) |
| R1314-8 | P3 | rule-violation | Watch cardio views | String(format:) for numeric formatting (acceptable exception) |
| R1314-9 | P2 | disconnected | `CardioMetricProfile.swift:55-71` | primaryLabel unused dead code |
| R1314-10 | P3 | l10n | `AppSection.swift:12-19` | Tab names hardcoded English (documented product decision) |

### R15: Widget & visionOS — 15 findings (1 P1, 6 P2, 8 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R15-1 | P2 | l10n | `ConditionScatter3DView.swift:201-205` | ScatterPeriod.displayName missing String(localized:) |
| R15-2 | P2 | l10n | `ConditionScatter3DView.swift:90-93` | Legend labels "Good (80+)" etc. passed as String to helper |
| R15-3 | P2 | l10n | `TrainingVolume3DView.swift:17` | Hardcoded English muscle group names in static array |
| R15-4 | P2 | wasteful | `VisionDashboardWindowScene+2` | 3x duplicated MuscleGroup→localized name mapping |
| R15-5 | P2 | wasteful | `VisionImmersiveSceneView+1` | blended() UIColor utility duplicated 3 places |
| R15-6 | **P1** | **incomplete** | `VisionDashboardView.swift:6-68` | Entire dashboard static placeholder; service+refreshSignal unused |
| R15-7 | P2 | incomplete | `ConditionScatter3DView+TrainingVolume3DView` | 3D charts random data only; sharedHealthDataService unused |
| R15-8 | P2 | rule-violation | `VisionExerciseFormGuideView.swift:215,234` | NSLocalizedString instead of String(localized:) |
| R15-9 | P3 | l10n | `VisionContentView.swift:77,92` | Placeholder tab messages not localized |
| R15-10 | P3 | disconnected | `VisionContentView.swift:14` | refreshSignal incremented but never consumed |
| R15-11 | P3 | risky | `VisionContentView.swift:15` | foregroundTask never cancelled on disappear |
| R15-12 | P3 | wasteful | `WidgetScoreComponents.swift:49-81` | metrics computed property rebuilt per access |
| R15-13 | P3 | wasteful | `VisionMuscleMapExperienceView.swift:294-305` | iconName(for:) duplicates MuscleGroup.iconName |
| R15-14 | P3 | rule-violation | `VisionMuscleMapExperienceView.swift:29` | fatigueByMuscle Dictionary rebuilt every access |
| R15-15 | P3 | incomplete | `VisionTrainView.swift:8,68-101` | Training view uses hardcoded demo data |

### R16: Cross-Cutting — 11 findings (2 P1, 6 P2, 3 P3)

| ID | Sev | Category | File | Description |
|----|-----|----------|------|-------------|
| R16-1 | P2 | dead-code | `CardioSessionManager.swift` | 391-line class, zero external references |
| R16-2 | P2 | dead-code | `WorkoutTemplateRecommendationService.swift` | 181-line file, zero external references |
| R16-3 | P2 | dead-code | `SleepViewModel.swift` | 129-line ViewModel, zero external references |
| R16-4 | **P1** | **l10n** | `NotificationTargetNotFoundView.swift:13,17` | Korean text used as xcstrings keys (violates English-key rule) |
| R16-5 | **P1** | **l10n** | Multiple files | 15 String(localized:) keys missing from xcstrings entirely |
| R16-6 | P2 | l10n | `Localizable.xcstrings` | 18 orphan keys in iOS xcstrings (no code reference) |
| R16-7 | P2 | l10n | `DUNEWatch/Localizable.xcstrings` | 12 orphan keys in Watch xcstrings |
| R16-8 | P2 | l10n | `Localizable.xcstrings` | 36 keys missing ko+ja translations |
| R16-9 | P3 | wasteful | 2 files | SwiftUI + Foundation duplicate import |
| R16-10 | P3 | wasteful | 18 files | SwiftData + Foundation duplicate import |
| R16-11 | P3 | stale | `.claude/` | .DS_Store files (not git-tracked, informational)

---

## Final Consolidation: 전체 P1 액션 아이템 (21건)

### Category A: HealthKit 값 범위 검증 누락 (5건) — 데이터 무결성

| # | File | 설명 | 수정 방향 |
|---|------|------|----------|
| 1 | `HRVQueryService.swift:41` | HRV 상한 검증 누락 (>500ms 허용) | 0-500ms 범위 guard 추가 |
| 2 | `HRVQueryService.swift:67,92` | RHR 범위 검증 누락 | 20-300bpm guard 추가 |
| 3 | `HRVQueryService.swift:116,143` | HRV/RHR collection 쿼리 미검증 | 개별 sample 범위 필터 |
| 4 | `BodyCompositionQueryService.swift:186` | Weight/BMI 범위 검증 누락 | Weight 0-500, BMI 0-100 guard |
| 5 | `ConditionEngine.swift:228` | `log()` 호출 전 input > 0 미확인 | `.filter { $0 > 0 }` 추가 |

### Category B: Form 안전성 — 이중 저장/삭제 방어 (5건)

| # | File | 설명 | 수정 방향 |
|---|------|------|----------|
| 6 | `BodyCompositionViewModel.swift:133` | `defer { isSaving = false }` in returning func | 명시적 리셋으로 교체 |
| 7 | `BodyHistoryDetailView.swift:41` | modelContext.delete() without withAnimation | withAnimation {} 래핑 |
| 8 | `LifeView.swift:606-607` | modelContext.delete() without withAnimation (loop) | withAnimation {} 래핑 |
| 9 | `InjuryFormSheet.swift:131` | Save 버튼 isSaving guard 없음 | `.disabled(viewModel.isSaving)` 추가 |
| 10 | `BodyCompositionFormSheet.swift:47-51` | Save 버튼 isSaving guard 없음 + sensoryFeedback 순서 | guard + 순서 수정 |

### Category C: 로컬라이제이션 누락 (8건) — 번역 불가

| # | File | 설명 | 수정 방향 |
|---|------|------|----------|
| 11 | `ActiveRecoverySuggestion.swift:11-13` | Sendable struct String(localized:) 누락 | String(localized:) 팩토리 |
| 12 | `InjuryWarningBanner.swift:47-56` | 3개 사용자 대면 문자열 미번역 | String(localized:) + xcstrings 등록 |
| 13 | `BodyCompositionFormSheet.swift:47-49` | sensoryFeedback fires before validation | validation 후 feedback |
| 14 | `WorkoutSet+Summary.swift:15-20` | "sets"/"reps" 하드코딩 | String(localized:) 래핑 |
| 15 | `WorkoutPreviewView.swift:98,112,129` | "Indoor"/"Outdoor" Watch xcstrings 누락 | Watch xcstrings 등록 |
| 16 | `NotificationTargetNotFoundView.swift:13,17` | 한국어 텍스트가 xcstrings 키로 사용 | 영어 키로 변경 + 번역 등록 |
| 17 | Multiple files | 15개 String(localized:) 키 xcstrings에 미등록 | xcstrings에 en/ko/ja 등록 |
| 18 | `OceanWaveBackground.swift:1156-1169` | 14개 인라인 Color(red:green:blue:) FORBIDDEN | xcassets 색상으로 교체 |

### Category D: 워크아웃 데이터 손실 (2건) — 사용자 데이터 보호

| # | File | 설명 | 수정 방향 |
|---|------|------|----------|
| 19 | `CompoundWorkoutView.swift` | Draft persistence 없음, scenePhase 미감시 | UserDefaults draft + scenePhase 감시 |
| 20 | `TemplateWorkoutView.swift` | Draft persistence 없음, scenePhase 미감시 | UserDefaults draft + scenePhase 감시 |

### Category E: visionOS 미완성 (1건)

| # | File | 설명 | 수정 방향 |
|---|------|------|----------|
| 21 | `VisionDashboardView.swift:6-68` | 전체 대시보드 placeholder; service 미연결 | Phase 4에서 연결 또는 placeholder 명시 |

---

## P2 요약 (71건) — 주요 카테고리

| 카테고리 | 건수 | 대표 예시 |
|----------|------|----------|
| 로컬라이제이션 | 22 | orphan keys, 미번역, displayName 패턴 |
| 성능/캐싱 위반 | 14 | body 내 Calendar, computed property 반복 계산 |
| Dead code | 8 | SleepViewModel(129줄), CardioSessionManager(391줄), 미사용 UseCase |
| 중복 코드 | 7 | visionOS MuscleGroup 매핑 3중복, blended() 3중복 |
| 아키텍처/패턴 위반 | 10 | CoreLocation in Domain, NSLocalizedString 사용 |
| Incomplete/Disconnected | 10 | 3D 차트 미연결, refreshSignal dead, heart rate 미저장 |

## P3 요약 (71건) — 백로그

| 카테고리 | 건수 | 대표 예시 |
|----------|------|----------|
| 중복 import 정리 | 20 | SwiftData+Foundation, SwiftUI+Foundation |
| 마이너 코드 품질 | 25 | exhaustive case, dead default 분기, 불필요 computed |
| 로컬라이제이션 마이너 | 15 | placeholder text, visionOS 데모 텍스트 |
| 기타 | 11 | .DS_Store, 정보성 findings |
