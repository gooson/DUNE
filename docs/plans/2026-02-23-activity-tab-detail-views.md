---
tags: [activity, detail-view, personal-records, consistency, exercise-mix, info-button, navigation]
date: 2026-02-23
category: plan
status: draft
---

# Plan: Activity 탭 상세 화면 및 UX 개선

## Summary

Activity 탭의 3가지 문제를 해결합니다:
1. Training Volume 섹션 타이틀 이중 표시 제거
2. Personal Records / Consistency / Exercise Mix 상세 화면 연결 (차트 + 분석)
3. 위 3개 섹션에 info 버튼 추가 (Recovery Map 패턴 재사용)

**Fidelity**: F3 (복잡한 변경 — 새 View 6개 + ViewModel 3개 + 서비스 확장)
**Brainstorm**: `docs/brainstorms/2026-02-23-activity-tab-detail-views.md`

## Architecture

```
ActivityView (기존)
├── SectionGroup("Personal Records", infoAction: ...)
│   └── NavigationLink(value: .personalRecords)
│       └── PersonalRecordsSection (기존)
├── SectionGroup("Consistency", infoAction: ...)
│   └── NavigationLink(value: .consistency)
│       └── ConsistencyCard (기존)
└── SectionGroup("Exercise Mix", infoAction: ...)
    └── NavigationLink(value: .exerciseMix)
        └── ExerciseFrequencySection (기존)

Navigation Destinations:
├── PersonalRecordsDetailView + PersonalRecordsDetailViewModel
├── ConsistencyDetailView + ConsistencyDetailViewModel
└── ExerciseMixDetailView + ExerciseMixDetailViewModel

Info Sheets:
├── PersonalRecordsInfoSheet
├── ConsistencyInfoSheet
└── ExerciseMixInfoSheet
```

## Affected Files

### 수정 파일

| File | Change |
|------|--------|
| `Presentation/Shared/Components/SectionGroup.swift` | `infoAction` 옵셔널 파라미터 추가 |
| `Presentation/Activity/TrainingVolume/Components/TrainingVolumeSummaryCard.swift` | `headerRow` 제거 |
| `Presentation/Activity/ActivityView.swift` | NavigationLink 래핑 + info sheet state + navigationDestination 추가 |
| `Presentation/Activity/Components/PersonalRecordsSection.swift` | chevron 힌트 추가 |
| `Presentation/Activity/Components/ConsistencyCard.swift` | chevron 힌트 추가 |
| `Presentation/Activity/Components/ExerciseFrequencySection.swift` | chevron 힌트 추가 |
| `Domain/UseCases/WorkoutStreakService.swift` | streak history 메서드 추가 |

### 신규 파일

| File | Purpose |
|------|---------|
| `Presentation/Activity/ActivityDetailDestination.swift` | Navigation enum |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | PR 상세 화면 |
| `Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | PR 상세 VM |
| `Presentation/Activity/Consistency/ConsistencyDetailView.swift` | 일관성 상세 화면 |
| `Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift` | 일관성 상세 VM |
| `Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift` | 운동 구성 상세 화면 |
| `Presentation/Activity/ExerciseMix/ExerciseMixDetailViewModel.swift` | 운동 구성 상세 VM |
| `Presentation/Activity/Components/PersonalRecordsInfoSheet.swift` | PR 설명 sheet |
| `Presentation/Activity/Components/ConsistencyInfoSheet.swift` | 일관성 설명 sheet |
| `Presentation/Activity/Components/ExerciseMixInfoSheet.swift` | 운동 구성 설명 sheet |
| `Domain/Models/StreakPeriod.swift` | Streak 히스토리 모델 |
| `DailveTests/StreakHistoryTests.swift` | Streak 히스토리 서비스 테스트 |

## Implementation Steps

### Step 1: Training Volume 타이틀 중첩 해결

**파일**: `TrainingVolumeSummaryCard.swift`

`headerRow` computed property 제거. body에서 `headerRow` 참조 삭제. `metricsRow` + `miniBarChart`만 유지.

```swift
// BEFORE
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    headerRow      // ← 제거
    metricsRow
    miniBarChart
}

// AFTER
VStack(alignment: .leading, spacing: DS.Spacing.md) {
    metricsRow
    miniBarChart
}
```

### Step 2: SectionGroup에 info 버튼 슬롯 추가

**파일**: `SectionGroup.swift`

옵셔널 `infoAction` 클로저 파라미터 추가. nil이면 기존과 동일하게 동작.

```swift
struct SectionGroup<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    var infoAction: (() -> Void)? = nil  // NEW
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon) ...
                Text(title) ...

                // NEW: info button
                if let infoAction {
                    Spacer()
                    Button(action: infoAction) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        ...
    }
}
```

**주의**: 기존 SectionGroup 호출부(Activity, Wellness 등)는 `infoAction` 기본값이 nil이므로 변경 불필요.

### Step 3: Navigation 인프라

**파일 (신규)**: `ActivityDetailDestination.swift`

```swift
enum ActivityDetailDestination: Hashable {
    case personalRecords
    case consistency
    case exerciseMix
}
```

**파일 (수정)**: `ActivityView.swift`

1. info sheet state 3개 추가:
```swift
@State private var showingPRInfo = false
@State private var showingConsistencyInfo = false
@State private var showingExerciseMixInfo = false
```

2. 섹션에 NavigationLink + infoAction 래핑:
```swift
// ⑧ Personal Records
SectionGroup(title: "Personal Records", icon: "trophy.fill",
             iconColor: DS.Color.activity,
             infoAction: { showingPRInfo = true }) {
    NavigationLink(value: ActivityDetailDestination.personalRecords) {
        PersonalRecordsSection(records: viewModel.personalRecords)
    }
    .buttonStyle(.plain)
}
```

3. navigationDestination 추가:
```swift
.navigationDestination(for: ActivityDetailDestination.self) { dest in
    switch dest {
    case .personalRecords:
        PersonalRecordsDetailView()
    case .consistency:
        ConsistencyDetailView()
    case .exerciseMix:
        ExerciseMixDetailView()
    }
}
```

4. sheet 3개 추가:
```swift
.sheet(isPresented: $showingPRInfo) { PersonalRecordsInfoSheet() }
.sheet(isPresented: $showingConsistencyInfo) { ConsistencyInfoSheet() }
.sheet(isPresented: $showingExerciseMixInfo) { ExerciseMixInfoSheet() }
```

### Step 4: 카드에 chevron 힌트 추가

**파일**: `PersonalRecordsSection.swift`, `ConsistencyCard.swift`, `ExerciseFrequencySection.swift`

각 카드 우상단에 chevron 아이콘 추가하여 탭 가능함을 시각적으로 표시.

```swift
// PersonalRecordsSection - 빈 상태 아닌 경우 우상단에
HStack {
    Spacer()
    Image(systemName: "chevron.right")
        .font(.caption2)
        .foregroundStyle(.tertiary)
}
```

### Step 5: Info Sheet 3개 생성

`FatigueAlgorithmSheet` 패턴 따름: ScrollView + VStack + sectionHeader 헬퍼.

#### PersonalRecordsInfoSheet

```
헤더: 🏆 "개인 기록 (PR)"
개요: 각 운동별 최고 무게를 추적합니다
측정 방식:
  - 세션 내 세트 평균 무게 기준
  - 운동별 역대 최고 기록 표시
  - weight 0-500kg 범위 내 유효 기록만 반영
"NEW" 배지:
  - 최근 7일 이내 갱신된 기록에 표시
  - 꾸준한 진전을 시각적으로 확인
활용 팁:
  - 점진적 과부하(Progressive Overload) 추적에 활용
  - 장기적으로 강해지는 과정을 확인
```

#### ConsistencyInfoSheet

```
헤더: 🔥 "운동 일관성"
개요: 얼마나 꾸준히 운동하는지 추적합니다
현재 Streak:
  - 연속 운동일 수 (오늘 또는 어제까지)
  - 20분 이상 운동한 날만 카운트
  - 하루라도 빠지면 리셋
최고 Streak:
  - 역대 최장 연속 운동 기록
월간 진행률:
  - 이번 달 운동 횟수 / 목표(16회, 주 4회 기준)
  - 진행 바로 시각화
활용 팁:
  - 강도보다 일관성이 장기 성과의 핵심
  - 주 3-5회를 꾸준히 유지하는 것이 목표
```

#### ExerciseMixInfoSheet

```
헤더: 📊 "운동 구성"
개요: 어떤 운동을 얼마나 자주 하는지 분석합니다
측정 방식:
  - 전체 기록 중 운동별 수행 횟수 집계
  - 비율(%)로 상대적 빈도 표시
  - 가장 자주 하는 운동 순으로 정렬
균형 잡힌 구성:
  - 밀기/당기기/하체/코어 균형 권장
  - 특정 운동에 편중되면 부상 위험 증가
활용 팁:
  - 다양한 운동으로 전신 균형 발달
  - 소홀한 부위를 발견하고 보완
```

### Step 6: Domain 확장 — StreakPeriod 모델 + 히스토리 메서드

**파일 (신규)**: `Domain/Models/StreakPeriod.swift`

```swift
struct StreakPeriod: Sendable, Hashable, Identifiable {
    let id: Date  // startDate
    let startDate: Date
    let endDate: Date
    let days: Int
}
```

**파일 (수정)**: `Domain/UseCases/WorkoutStreakService.swift`

streak 히스토리 추출 메서드 추가:

```swift
static func extractStreakHistory(
    from workouts: [WorkoutDay],
    minimumMinutes: Double = 20
) -> [StreakPeriod]
```

유니크 날짜를 오름차순 정렬 후, 연속 구간을 그룹핑하여 `StreakPeriod` 배열 반환.

**테스트**: `DailveTests/StreakHistoryTests.swift` 작성 필수 (#testing-required 규칙).

### Step 7: Personal Records Detail View

**파일**: `Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift`

레이아웃:
1. **PR 타임라인 차트** (Swift Charts): X축 날짜, Y축 최대무게. 각 PR 달성 시점을 PointMark로 표시
2. **전체 PR 목록**: LazyVGrid 2열, 제한 없이 전체 표시 (카드 `.prefix(8)` 제거)
3. **빈 상태**: EmptyStateView 패턴

**파일**: `Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift`

```swift
@Observable
final class PersonalRecordsDetailViewModel {
    var personalRecords: [StrengthPersonalRecord] = []
    var isLoading = false

    func loadRecords(from exerciseRecords: [ExerciseRecord]) {
        let entries = exerciseRecords.compactMap { ... }
        personalRecords = StrengthPRService.extractPRs(from: entries)
    }
}
```

데이터는 `@Query` ExerciseRecord에서 추출 (ActivityViewModel 패턴 참조).

### Step 8: Consistency Detail View

**파일**: `Presentation/Activity/Consistency/ConsistencyDetailView.swift`

레이아웃:
1. **현재/최고 Streak 카드**: 큰 숫자 표시 (ConsistencyCard 확장)
2. **월간 운동 캘린더**: 7열 그리드(일~토), 해당 일 운동 여부를 색상 표시 (GitHub 잔디 스타일)
3. **Streak 히스토리 목록**: `StreakPeriod` 배열 → List로 시작일-종료일, 일수 표시
4. **빈 상태**: EmptyStateView

**파일**: `Presentation/Activity/Consistency/ConsistencyDetailViewModel.swift`

```swift
@Observable
final class ConsistencyDetailViewModel {
    var workoutStreak: WorkoutStreak?
    var streakHistory: [StreakPeriod] = []
    var workoutDates: Set<DateComponents> = []  // 캘린더용
    var isLoading = false

    func loadData(from exerciseRecords: [ExerciseRecord]) {
        let workouts = exerciseRecords.map { ... }
        workoutStreak = WorkoutStreakService.calculate(from: workouts)
        streakHistory = WorkoutStreakService.extractStreakHistory(from: workouts)
        workoutDates = Set(workouts.map { Calendar.current.dateComponents([.year, .month, .day], from: $0.date) })
    }
}
```

### Step 9: Exercise Mix Detail View

**파일**: `Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift`

레이아웃:
1. **도넛 차트**: 운동별 비율 시각화 (Swift Charts SectorMark). Training Volume의 `VolumeDonutChartView` 패턴 참조
2. **전체 빈도 목록**: ForEach 전체 (`.prefix(6)` 제거), 수평 바 차트
3. **빈 상태**: EmptyStateView

**파일**: `Presentation/Activity/ExerciseMix/ExerciseMixDetailViewModel.swift`

```swift
@Observable
final class ExerciseMixDetailViewModel {
    var exerciseFrequencies: [ExerciseFrequency] = []
    var isLoading = false

    func loadData(from exerciseRecords: [ExerciseRecord]) {
        let entries = exerciseRecords.map { ... }
        exerciseFrequencies = ExerciseFrequencyService.analyze(from: entries)
    }
}
```

### Step 10: xcodegen + 빌드 검증

```bash
cd Dailve && xcodegen generate
scripts/build-ios.sh
```

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| SectionGroup 변경이 Wellness 탭에 영향 | `infoAction` 기본값 nil → 기존 호출부 변경 불필요 |
| 대량 PR 데이터에서 차트 성능 | PointMark + .clipped() + 최근 6개월 기본 표시 |
| 캘린더 그리드 레이아웃 복잡 | LazyVGrid 7열 고정, 이번 달만 기본 표시 |
| NavigationLink 내 카드 터치 영역 | `.buttonStyle(.plain)` 적용하여 터치 시각 피드백 제거 |

## Test Strategy

| 대상 | 테스트 |
|------|--------|
| `WorkoutStreakService.extractStreakHistory()` | 빈 배열, 단일 날, 연속 3일, 갭 포함, 중복 날짜 |
| 기존 서비스 테스트 | 변경 없으므로 회귀 테스트만 (기존 테스트 실행) |
| Detail View | Preview + 수동 확인 (빈 상태, 데이터 있는 상태) |

## Implementation Order

1. Step 1 (타이틀 수정) — 독립적, 즉시 완료 가능
2. Step 2 (SectionGroup) — Step 3의 선행 조건
3. Step 6 (Domain 확장) — Step 8의 선행 조건
4. Step 3 (Navigation) — Step 7-9의 선행 조건
5. Step 4 (chevron) — Step 3과 병행 가능
6. Step 5 (Info Sheets) — Step 2 완료 후
7. Step 7-9 (Detail Views) — 병렬 구현 가능
8. Step 10 (빌드 검증) — 마지막
