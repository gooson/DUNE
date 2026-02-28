---
tags: [ui-test, xcuitest, ci, mock-data, accessibility, e2e]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: 체계적인 UI Test 설계

## Problem Statement

현재 UI 테스트가 사실상 CI gate로 기능하지 않고 있음:
- `continue-on-error: true`로 실패해도 PR merge 가능
- HealthKit entitlement 부재로 CI runner에서 권한 관련 코드 실패
- 5개 테스트 파일/373줄 — 30+ 화면 중 ~5개만 커버
- Accessibility ID가 일부 화면에만 정의됨
- Mock 데이터 없이 빈 화면만 검증하는 수준

## Target Users

- 개발자 (PR merge 전 UI regression 자동 검증)
- CI 시스템 (자동화된 안정성 검증)

## Success Criteria

1. CI에서 `continue-on-error` 제거 — UI 테스트 실패 시 PR merge 차단
2. 전체 30+ 화면이 crash 없이 렌더링되는지 검증
3. 핵심 사용자 플로우 4개+ E2E 검증
4. HealthKit 권한 무관하게 CI green 보장
5. CI green rate 95%+

## Current State (As-Is)

### 테스트 파일 구조
```
DUNEUITests/
├── DailveUITests.swift          (75줄) — 탭 navigation 기본
├── ExerciseUITests.swift        (63줄) — Activity 탭 add 버튼/sheet
├── BodyCompositionUITests.swift (96줄) — Wellness 탭 form 필드 확인
├── HealthKitPermissionUITests.swift (117줄) — 수동 전용 권한 테스트
├── DailveUITestsLaunchTests.swift   (22줄) — 런치 스크린 캡처
└── Helpers/UITestHelpers.swift  (52줄) — AXID enum + 네비게이션 헬퍼
```

### 권한 처리 현황
- `--uitesting` launch argument → HealthKit 데이터 로드 우회
- `--healthkit-permission-uitest` → 실제 HealthKit 권한 플로우 (수동 전용)
- 앱 코드에 `ProcessInfo` 기반 분기 산재 (`DUNEApp.swift`, `DashboardViewModel.swift`)

### CI 현황
- `test-ui.yml`: `continue-on-error: true` (실질적 검증 없음)
- iPhone 17 / iOS 26.2 시뮬레이터 사용
- xcodegen 재생성 + 시뮬레이터 부팅 포함

## Proposed Approach

### 아키텍처: Launch Argument 기반 분기 확장

현재 `--uitesting` 패턴을 유지하면서 Mock 데이터 주입 레이어를 추가:

```
--uitesting              → HealthKit 우회 + 빈 상태 (현재)
--uitesting --seed-mock  → HealthKit 우회 + Mock 데이터 시딩 (신규)
--healthkit-permission-uitest → 실제 HealthKit 플로우 (수동 전용)
```

### Mock 데이터 전략: Fixture JSON + SwiftData Seeder

```swift
// TestDataSeeder.swift (Debug only)
#if DEBUG
enum TestDataSeeder {
    static func seedIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("--seed-mock") else { return }
        // Read TestFixtures.json from bundle
        // Insert ExerciseRecord, BodyCompositionRecord, InjuryRecord, HabitRecord...
        // Insert mock HealthMetric snapshots for dashboard/charts
    }
}
#endif
```

장점:
- 앱의 실제 SwiftData 쿼리 경로를 통해 렌더링 검증
- JSON fixture로 시나리오 관리 용이
- `#if DEBUG`로 프로덕션 영향 없음

### 테스트 파일 재구조화

```
DUNEUITests/
├── Helpers/
│   ├── UITestHelpers.swift        (AXID 상수 확장)
│   ├── UITestBaseCase.swift       (공용 setUp, 인터럽션 모니터)
│   └── UITestNavigation.swift     (탭/시트 네비게이션 헬퍼)
├── Smoke/                         ← Phase 2: 전체 화면 존재 확인
│   ├── DashboardSmokeTests.swift
│   ├── ActivitySmokeTests.swift
│   ├── WellnessSmokeTests.swift
│   ├── LifeSmokeTests.swift
│   └── SettingsSmokeTests.swift
├── Flow/                          ← Phase 3: E2E 사용자 플로우
│   ├── ExerciseFlowUITests.swift
│   ├── BodyCompositionFlowUITests.swift
│   ├── InjuryFlowUITests.swift
│   └── HabitFlowUITests.swift
├── Data/                          ← Phase 4: 데이터 표시 검증
│   ├── DashboardDataUITests.swift
│   └── MetricDisplayUITests.swift
├── Manual/                        ← 수동 전용 (CI 제외)
│   └── HealthKitPermissionUITests.swift
└── Launch/
    └── LaunchUITests.swift
```

### CI 전략: Xcode Test Plan 기반

```
DUNEUITests/
├── TestPlans/
│   ├── UITests-CI.xctestplan      ← CI용: Manual 폴더 제외
│   └── UITests-Full.xctestplan    ← 로컬용: 전체 포함 (env var 조건부)
```

```yaml
# test-ui.yml 변경
- name: Run UI Tests
  # continue-on-error: true  ← 제거
  run: scripts/test-ui.sh  # Test Plan이 Manual 제외를 처리
```

- CI는 `UITests-CI.xctestplan` 사용 → Manual/ 자동 제외
- 로컬에서 `UITests-Full.xctestplan` 사용 시 env var 조건으로 권한 테스트 실행
- `continue-on-error` 제거 → UI 테스트 실패 시 PR merge 차단

## Constraints

### 기술적 제약
- CI runner에 HealthKit entitlement 없음 → 권한 관련 API 호출 불가
- SwiftData in-memory store는 CloudKit 동기화 비활성화 필요
- 시뮬레이터에서 일부 센서 데이터 (HRV, RHR) 생성 불가
- `XCUITest`는 앱 프로세스 외부에서 실행 → 앱 내부 상태 직접 접근 불가

### 시간/리소스 제약
- CI 시간: 현재 45분 timeout → Mock 데이터 시딩 시간 추가 고려
- Accessibility ID 추가 작업량: 30+ 화면에 ID 부여 필요

## Edge Cases

### 권한 관련
- 첫 실행 시 HealthKit 권한 다이얼로그 → `--uitesting`이 이미 우회
- 알림 권한 다이얼로그 → `UIInterruptionMonitor`로 자동 처리
- 위치 권한 (Weather) → 현재 위치 사용 안함 (IP 기반)

### 데이터 관련
- Mock 데이터 없는 경우 → 빈 상태 placeholder 렌더링 확인
- Mock 데이터 스키마 불일치 → `@Model` 변경 시 fixture 동기화 필요
- 날짜 의존 데이터 → fixture에서 상대 날짜 사용 (`Date.now - 7days`)

### 디바이스 관련
- iPad에서 sidebar layout → `guard !app.isIPadLayout` 스킵 (iPhone only in CI)
- 다크 모드 → 별도 테스트 불필요 (색상은 asset catalog 관리)
- Dynamic Type → Phase 4+에서 고려

## Scope

### MVP (Must-have) — Phase 1 + Phase 2

**Phase 1: 인프라 구축**
- [ ] `UITestBaseCase` 생성 (공용 setUp, 인터럽션 모니터, launch argument)
- [ ] AXID enum 확장 (전체 30+ 화면의 핵심 요소)
- [ ] 앱 코드에 accessibility identifier 추가 (모든 탭/시트/디테일)
- [ ] `--seed-mock` launch argument + `TestDataSeeder` 구현
- [ ] `TestFixtures.json` 작성 (운동 기록, 체성분, 부상, 습관 데이터)
- [ ] CI workflow 수정: `continue-on-error` 제거, Manual 제외
- [ ] `test-ui.sh`에 `--exclude-manual` 옵션 추가

**Phase 2: 전체 화면 Smoke Tests**
- [ ] `DashboardSmokeTests`: hero card, metrics grid, settings 진입, pinned editor
- [ ] `ActivitySmokeTests`: readiness card, muscle map, weekly stats, volume, PR, consistency, exercise mix
- [ ] `WellnessSmokeTests`: wellness score, body history, injury history, add body record, add injury
- [ ] `LifeSmokeTests`: progress ring, habit list, add habit, toggle habit
- [ ] `SettingsSmokeTests`: exercise defaults 진입, 외관 설정

### Nice-to-have (Future) — Phase 3 + Phase 4

**Phase 3: E2E User Flow Tests**
- [ ] 운동 기록 플로우: 운동 선택 → 세트 기록 → 완료 → 목록 확인
- [ ] 체성분 플로우: 추가 → 저장 → 히스토리 확인 → 수정 → 반영 확인
- [ ] 부상 플로우: 추가 → 배너 확인 → 해결 → 히스토리 이동
- [ ] 습관 플로우: 추가 → 토글 → 진행률 변화 확인

**Phase 4: 데이터 표시 검증**
- [ ] 대시보드 컨디션 점수가 Mock 값과 일치하는지 확인
- [ ] 메트릭 카드에 데이터가 표시되는지 (빈 상태 아닌지) 확인
- [ ] 차트에 데이터 포인트가 렌더링되는지 확인
- [ ] 목록 아이템 수가 fixture와 일치하는지 확인

## 전체 화면 커버리지 맵

### Tab 1: Today (Dashboard)
| 화면 | 접근 경로 | Smoke 검증 항목 |
|------|----------|----------------|
| DashboardView | Tab "Today" | hero card 존재, metrics grid 존재 |
| ConditionScoreDetailView | hero card tap | score ring 존재, trend chart 존재 |
| MetricDetailView | metric card tap | period picker 존재, chart 존재 |
| AllDataView | context menu "Show All" | 데이터 리스트 존재 |
| SettingsView | toolbar gear icon | 섹션 존재 (Workout, Appearance, About) |
| PinnedMetricsEditorView | "Edit" button in pinned | 메트릭 선택 리스트 존재 |

### Tab 2: Activity
| 화면 | 접근 경로 | Smoke 검증 항목 |
|------|----------|----------------|
| ActivityView | Tab "Activity" | readiness card, add button 존재 |
| TrainingReadinessDetailView | readiness card tap | score, chart 존재 |
| MuscleMapDetailView | muscle map section tap | body diagram 존재 |
| WeeklyStatsDetailView | weekly stats tap | daily chart 존재 |
| TrainingVolumeDetailView | volume card tap | period comparison 존재 |
| ExerciseTypeDetailView | exercise type tap | type chart 존재 |
| PersonalRecordsDetailView | PR section tap | PR list 존재 |
| ConsistencyDetailView | consistency card tap | streak counter 존재 |
| ExerciseMixDetailView | exercise mix tap | distribution chart 존재 |
| ExercisePickerView (sheet) | add button tap | search bar, list 존재 |

### Tab 3: Wellness
| 화면 | 접근 경로 | Smoke 검증 항목 |
|------|----------|----------------|
| WellnessView | Tab "Wellness" | score card, add menu 존재 |
| WellnessScoreDetailView | score card tap | breakdown chart 존재 |
| BodyHistoryDetailView | body history link | records table 존재 |
| InjuryHistoryView | injury history link | injury list 존재 |
| BodyCompositionFormSheet | add menu → "Body Record" | weight/fat/muscle fields 존재 |
| InjuryFormSheet | add menu → "Injury" | body part picker, severity 존재 |

### Tab 4: Life
| 화면 | 접근 경로 | Smoke 검증 항목 |
|------|----------|----------------|
| LifeView | Tab "Life" | progress ring, habit list 존재 |
| HabitFormSheet | add button tap | name, frequency, target fields 존재 |

### Settings (Push from Dashboard)
| 화면 | 접근 경로 | Smoke 검증 항목 |
|------|----------|----------------|
| ExerciseDefaultsListView | Settings → Exercise Defaults | exercise list 존재 |
| ExerciseDefaultEditView | exercise row tap | weight field 존재 |

## Resolved Questions

1. **Mock 데이터 범위**: SwiftData 레코드만 (ExerciseRecord, BodyComposition, Injury, Habit). HealthMetric 스냅샷은 Phase 1-2에서 제외. HealthKit 의존 화면(HRV/RHR/Sleep 차트, 컨디션 점수)은 빈 상태 placeholder로 검증
2. **CI 분리 방법**: Xcode Test Plan 사용. CI용 Plan에서 Manual 폴더 제외. 네이티브 기능으로 깔끔하게 분리
3. **Accessibility ID 네이밍**: `{tab}-{section}-{element}` 3단계 패턴으로 통일. 기존 ID는 마이그레이션 (예: `activity-add-button` → `activity-toolbar-add`)
4. **빈 상태 테스트**: 두 모드 모두 테스트. `--uitesting`(빈 상태) + `--uitesting --seed-mock`(데이터 상태). 빈 상태 placeholder/crash 검증 포함

## Accessibility ID 체계: `{tab}-{section}-{element}` 3단계

기존 ID는 마이그레이션하여 통일된 3단계 패턴으로 전환.

### 마이그레이션 매핑

| 기존 ID | 신규 ID |
|---------|---------|
| `activity-readiness-card` | `activity-hero-readiness` |
| `activity-add-button` | `activity-toolbar-add` |
| `exercise-add-button` | `exercise-toolbar-add` |
| `exercise-save-button` | `exercise-form-save` |
| `exercise-cancel-button` | `exercise-form-cancel` |
| `exercise-date-picker` | `exercise-form-date` |
| `exercise-type-picker` | `exercise-form-type` |
| `body-add-button` | `wellness-toolbar-add` |
| `body-save-button` | `body-form-save` |
| `body-cancel-button` | `body-form-cancel` |
| `body-date-picker` | `body-form-date` |
| `body-weight-field` | `body-form-weight` |
| `body-fat-field` | `body-form-fat` |
| `body-muscle-field` | `body-form-muscle` |
| `sidebar-list` | `sidebar-nav-list` |

### 전체 AXID enum (제안)

```swift
enum AXID {
    // MARK: - Dashboard Tab
    static let dashboardHeroCondition = "dashboard-hero-condition"
    static let dashboardToolbarSettings = "dashboard-toolbar-settings"
    static let dashboardPinnedEdit = "dashboard-pinned-edit"
    static let dashboardPinnedGrid = "dashboard-pinned-grid"
    static let dashboardWeatherCard = "dashboard-weather-card"
    static let dashboardCoachingCard = "dashboard-coaching-card"

    // MARK: - Activity Tab
    static let activityHeroReadiness = "activity-hero-readiness"
    static let activityToolbarAdd = "activity-toolbar-add"
    static let activitySectionMuscleMap = "activity-section-musclemap"
    static let activitySectionWeeklyStats = "activity-section-weeklystats"
    static let activitySectionVolume = "activity-section-volume"
    static let activitySectionPR = "activity-section-pr"
    static let activitySectionConsistency = "activity-section-consistency"
    static let activitySectionExerciseMix = "activity-section-exercisemix"
    static let activitySectionRecent = "activity-section-recent"

    // MARK: - Wellness Tab
    static let wellnessHeroScore = "wellness-hero-score"
    static let wellnessToolbarAdd = "wellness-toolbar-add"
    static let wellnessSectionBody = "wellness-section-body"
    static let wellnessSectionInjury = "wellness-section-injury"
    static let wellnessLinkBodyHistory = "wellness-link-bodyhistory"
    static let wellnessLinkInjuryHistory = "wellness-link-injuryhistory"

    // MARK: - Life Tab
    static let lifeHeroProgress = "life-hero-progress"
    static let lifeToolbarAdd = "life-toolbar-add"
    static let lifeSectionHabits = "life-section-habits"

    // MARK: - Settings
    static let settingsRowExerciseDefaults = "settings-row-exercisedefaults"
    static let settingsRowAppearance = "settings-row-appearance"
    static let settingsRowDataPrivacy = "settings-row-dataprivacy"
    static let settingsRowAbout = "settings-row-about"

    // MARK: - Detail Views (shared)
    static let detailNavPeriodPicker = "detail-nav-periodpicker"
    static let detailContentChart = "detail-content-chart"
    static let detailLinkAllData = "detail-link-alldata"

    // MARK: - Body Form
    static let bodyFormSave = "body-form-save"
    static let bodyFormCancel = "body-form-cancel"
    static let bodyFormDate = "body-form-date"
    static let bodyFormWeight = "body-form-weight"
    static let bodyFormFat = "body-form-fat"
    static let bodyFormMuscle = "body-form-muscle"

    // MARK: - Exercise Form
    static let exerciseFormSave = "exercise-form-save"
    static let exerciseFormCancel = "exercise-form-cancel"
    static let exerciseFormDate = "exercise-form-date"
    static let exerciseFormType = "exercise-form-type"

    // MARK: - Injury Form
    static let injuryFormSave = "injury-form-save"
    static let injuryFormCancel = "injury-form-cancel"
    static let injuryFormBodyPart = "injury-form-bodypart"
    static let injuryFormSeverity = "injury-form-severity"

    // MARK: - Habit Form
    static let habitFormSave = "habit-form-save"
    static let habitFormCancel = "habit-form-cancel"
    static let habitFormName = "habit-form-name"
    static let habitFormFrequency = "habit-form-frequency"

    // MARK: - Sidebar (iPad)
    static let sidebarNavList = "sidebar-nav-list"
    static func sidebarNavItem(_ section: String) -> String {
        "sidebar-nav-\(section)"
    }

    // MARK: - Exercise Picker
    static let pickerSearchField = "picker-search-field"
    static let pickerSectionRecent = "picker-section-recent"
    static let pickerSectionPopular = "picker-section-popular"
}
```

## Next Steps

- [ ] `/plan` 으로 Phase 1 인프라 구축 구현 계획 생성
- [ ] Open Questions 답변 후 fixture 범위 확정
