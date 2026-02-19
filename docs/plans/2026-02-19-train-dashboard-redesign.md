---
topic: train-dashboard-redesign
date: 2026-02-19
status: draft
confidence: high
related_solutions:
  - general/2026-02-17-exercise-visual-guide.md
  - architecture/2026-02-17-activity-tab-review-patterns.md
  - general/2026-02-17-chart-ux-layout-stability.md
  - performance/2026-02-16-computed-property-caching-pattern.md
related_brainstorms:
  - 2026-02-19-train-dashboard-redesign.md
---

# Implementation Plan: Train 대시보드 전면 재설계

## Context

현재 Train 대시보드에 3가지 문제가 있음:
1. **추천 알고리즘 버그**: Compound 보강 로직에서 recovery check bypass → 방금 훈련한 근육 재추천
2. **낮은 정보 밀도**: 서제스티드 카드가 최상단이지만 추천 근거 불투명, 핵심 정보(회복 상태)가 없음
3. **시각적 일관성 부족**: 3개 섹션이 독립적으로 설계되어 맥락 연결 없음

해결: Recovery-Centered Dashboard로 전면 재설계. 근육 회복 맵을 히어로 섹션으로, 서제스티드 워크아웃을 그 안에 통합.

## Requirements

### Functional

- F1: Compound 보강 시 모든 primary muscle의 recovery 검증
- F2: 운동 선택 다양성 (exercises.first → 최근 미수행 우선)
- F3: 시간 기반 정확한 회복률 계산 (정수 일수 → 실제 경과 시간)
- F4: 근육 그룹별 차등 회복 시간 (하체 72h, 가슴/어깨 48h, 소근육 24~36h)
- F5: 근육 회복 맵 (정면/후면 Body Diagram, 색상 코딩)
- F6: 회복 맵 내 서제스티드 워크아웃 통합
- F7: 근육 부위 탭 → 상세 팝오버 (최근 훈련일, 볼륨 트렌드)
- F8: 추천 운동 스와이프로 대안 보기
- F9: 요일/시간대 패턴 반영 (특정 요일에 주로 하는 근육 우선 추천)
- F10: Rest Day — 긍정적 프레이밍 + Active Recovery 3종 제안 + 다음 훈련 가능 시점
- F11: Weekly Progress Bar (compact, 상단)
- F12: Training Volume Summary compact화

### Non-functional

- NF1: 기존 ExerciseMuscleMapView + MuscleMapData 재활용 (새 에셋 제작 최소화)
- NF2: react-native-body-highlighter SVG path로 다이어그램 품질 업그레이드
- NF3: Correction Log 준수 (#16 cancel-before-spawn, #17 isCancelled, #30 레이아웃 시프트, #70 .clipped, #78 .task(id:), #80 formatter 캐싱)
- NF4: Domain 레이어 순수성 유지 (SwiftUI import 금지)

## Approach

**7단계 구현** — 알고리즘 수정 → 모델 확장 → 다이어그램 업그레이드 → 대시보드 재구성 → 테스트 → 빌드 검증

기존 `ExerciseMuscleMapView` + `MuscleMapData`가 이미 정면/후면 다이어그램을 RoundedRectangle + bodyOutline으로 그리고 있음. 이것을 기반으로:
1. react-native-body-highlighter의 SVG path로 시각 품질 업그레이드
2. 색상 로직을 recovery 상태 기반으로 확장
3. 대시보드 전용 MuscleRecoveryMapView 생성

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 RoundedRect 유지 | 공수 없음 | 시각적 품질 낮음, 근육 형태 미표현 | Rejected |
| SVG path로 업그레이드 | 해부학적 시각화, Hevy 수준 | SVG→Shape 변환 공수 | **Selected** |
| SF Symbols 조합 | 즉시 가능 | 개별 근육 하이라이트 불가 | Rejected |
| 처음부터 Canvas로 | 완전한 제어 | 기존 코드 재활용 불가 | Rejected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/MuscleGroup.swift` | Modify | `recoveryHours` computed property 추가 |
| `Domain/UseCases/WorkoutRecommendationService.swift` | Modify | 알고리즘 버그 수정 + 차등 회복 + 다양성 + 요일 패턴 |
| `Domain/Models/MuscleFatigueState.swift` | New | 기존 struct를 별도 파일로 분리, `nextReadyDate` 추가 |
| `Domain/Models/WorkoutSuggestion.swift` | New | 기존 struct 분리, Rest Day용 `activeRecoverySuggestions` 추가 |
| `Domain/Models/ActiveRecoverySuggestion.swift` | New | Walking/Stretching/Yoga 모델 |
| `Presentation/Shared/Components/MuscleMapData.swift` | Modify | SVG path 데이터로 교체 |
| `Presentation/Shared/Components/MuscleBodyShape.swift` | New | SVG path → SwiftUI Shape 변환 |
| `Presentation/Activity/Components/MuscleRecoveryMapView.swift` | New | 대시보드 히어로 — 회복 상태 다이어그램 + 서제스트 통합 |
| `Presentation/Activity/Components/MuscleDetailPopover.swift` | New | 근육 부위 탭 상세 팝오버 |
| `Presentation/Activity/Components/WeeklyProgressBar.swift` | New | compact 주간 진행 바 |
| `Presentation/Activity/Components/ActiveRecoveryCard.swift` | New | Rest Day 대안 활동 카드 |
| `Presentation/Activity/Components/SuggestedExerciseRow.swift` | New | 스와이프 가능한 추천 운동 행 |
| `Presentation/Activity/ActivityView.swift` | Modify | 섹션 재구성 (4섹션 순서 변경) |
| `Presentation/Activity/ActivityViewModel.swift` | Modify | fatigueStates 노출, .task(id:) 통합 |
| `Presentation/Exercise/Components/SuggestedWorkoutCard.swift` | Delete | MuscleRecoveryMapView로 대체 |
| `Presentation/Activity/Components/TrainingVolumeSummaryCard.swift` | Modify | ActivityRing 제거, compact화 |
| `DailveTests/WorkoutRecommendationServiceTests.swift` | New/Modify | 알고리즘 테스트 |

## Implementation Steps

### Step 1: 알고리즘 버그 수정 + 모델 확장

**Files**:
- `Domain/Models/MuscleGroup.swift`
- `Domain/UseCases/WorkoutRecommendationService.swift`

**Changes**:

1-a. MuscleGroup에 `recoveryHours` 추가:
```swift
var recoveryHours: Double {
    switch self {
    case .quadriceps, .hamstrings, .glutes, .back, .lats:
        return 72  // 대근육: 3일
    case .chest, .shoulders, .traps:
        return 48  // 중근육: 2일
    case .biceps, .triceps, .forearms, .core, .calves:
        return 36  // 소근육: 1.5일
    }
}
```

1-b. `computeFatigueStates` — 실제 시간 기반 계산 + 차등 회복:
```swift
// 현재: let hoursSince = Double(daysSince) * 24.0 / fullRecoveryHours
// 수정: let hoursSince = max(0, now.timeIntervalSince(date) / 3600.0)
//       recovery = min(hoursSince / muscle.recoveryHours, 1.0)
```

1-c. Compound 보강에 recovery 검증 추가:
```swift
.filter { exercise in
    exercise.primaryMuscles.allSatisfy { muscle in
        fatigueStates.first(where: { $0.muscle == muscle })?.isRecovered == true
    }
}
```

1-d. `exercises.first` → 최근 미수행 운동 우선:
```swift
let exercise = exercises
    .sorted { lhs, rhs in
        let lhsDate = lastTrainedDate(for: lhs, in: records)
        let rhsDate = lastTrainedDate(for: rhs, in: records)
        return (lhsDate ?? .distantPast) < (rhsDate ?? .distantPast)
    }
    .first
```

1-e. Rest Day 로직 — WorkoutSuggestion에 activeRecovery 추가:
```swift
// candidates 비어있을 때:
return WorkoutSuggestion(
    exercises: [],
    reasoning: "Recovery in progress — your muscles are rebuilding stronger.",
    focusMuscles: [],
    activeRecoverySuggestions: ActiveRecoverySuggestion.defaults,
    nextReadyMuscle: earliestRecoveryMuscle(from: fatigueStates)
)
```

**Verification**: WorkoutRecommendationServiceTests — compound bypass 테스트, 차등 회복 테스트, rest day 테스트

---

### Step 2: MuscleFatigueState 모델 확장

**Files**:
- `Domain/Models/MuscleFatigueState.swift` (새 파일, 기존 struct 분리)
- `Domain/Models/WorkoutSuggestion.swift` (새 파일)
- `Domain/Models/ActiveRecoverySuggestion.swift` (새 파일)

**Changes**:

2-a. MuscleFatigueState에 `nextReadyDate` 추가:
```swift
var nextReadyDate: Date? {
    guard let lastTrained = lastTrainedDate else { return nil }
    let recoverySeconds = muscle.recoveryHours * 3600
    let readyDate = lastTrained.addingTimeInterval(recoverySeconds)
    return readyDate > Date() ? readyDate : nil  // nil = 이미 회복됨
}
```

2-b. ActiveRecoverySuggestion:
```swift
struct ActiveRecoverySuggestion: Identifiable, Sendable {
    let id: String
    let title: String
    let iconName: String  // SF Symbol
    let duration: String

    static let defaults: [ActiveRecoverySuggestion] = [
        .init(id: "walking", title: "Light Walking", iconName: "figure.walk", duration: "20-30 min"),
        .init(id: "stretching", title: "Stretching", iconName: "figure.flexibility", duration: "10 min"),
        .init(id: "yoga", title: "Yoga Flow", iconName: "figure.yoga", duration: "15 min")
    ]
}
```

**Verification**: 빌드 확인, 기존 참조 깨지지 않는지 확인

---

### Step 3: 요일/시간대 패턴 서비스

**Files**:
- `Domain/UseCases/WorkoutRecommendationService.swift` (확장)

**Changes**:

3-a. `recommend` 함수에 요일 패턴 보너스:
```swift
// 현재 요일에 주로 훈련한 근육에 가중치 부여
let weekday = Calendar.current.component(.weekday, from: Date())
let weekdayPatterns = computeWeekdayPatterns(from: records)
// candidate 정렬 시 weekdayBonus 반영
```

3-b. `computeWeekdayPatterns`: 최근 8주 기록에서 요일별 가장 빈번한 근육 그룹 추출

**Verification**: 패턴 계산 유닛 테스트 (특정 요일 데이터 → 기대 보너스)

---

### Step 4: Body Diagram SVG 업그레이드

**Files**:
- `Presentation/Shared/Components/MuscleMapData.swift` (수정)
- `Presentation/Shared/Components/MuscleBodyShape.swift` (새 파일)

**Changes**:

4-a. react-native-body-highlighter에서 SVG path 추출:
- `bodyFront.ts` → 정면 근육 path
- `bodyBack.ts` → 후면 근육 path
- MIT 라이선스 attribution 추가

4-b. `MuscleBodyShape`: SwiftUI Shape 변환
```swift
struct MuscleBodyShape: Shape {
    let pathData: String  // SVG path string

    func path(in rect: CGRect) -> Path {
        // SVG path → SwiftUI Path 변환
        // viewBox "0 0 724 1448" → rect 스케일링
    }
}
```

4-c. `MuscleMapData` 업데이트:
- 기존 `bodyOutline` Path → 새 SVG 기반 outline
- 기존 `frontMuscles`/`backMuscles` `[MuscleMapItem]` → `[MuscleBodyPart]` (path 기반)
- slug → MuscleGroup 매핑 테이블

4-d. Slug ↔ MuscleGroup 매핑:
```
chest → .chest
abs + obliques → .core
deltoids → .shoulders
biceps → .biceps
triceps → .triceps
forearm → .forearms
trapezius → .traps
quadriceps → .quadriceps
hamstring → .hamstrings
gluteal → .glutes
calves → .calves
upper-back → .lats (정면 없음, 후면만)
lower-back → .back
```

**Verification**: Preview에서 정면/후면 다이어그램 렌더링 확인, 각 근육 하이라이트 동작 확인

---

### Step 5: 대시보드 UI 컴포넌트 생성

**Files** (모두 신규):
- `Presentation/Activity/Components/MuscleRecoveryMapView.swift`
- `Presentation/Activity/Components/MuscleDetailPopover.swift`
- `Presentation/Activity/Components/WeeklyProgressBar.swift`
- `Presentation/Activity/Components/ActiveRecoveryCard.swift`
- `Presentation/Activity/Components/SuggestedExerciseRow.swift`

**Changes**:

5-a. **MuscleRecoveryMapView** (히어로 섹션):
```
┌───────────────────────────────────┐
│  Muscle Recovery                  │
│  [Front ↔ Back toggle]           │
│                                   │
│  [Body Diagram with color]       │
│  🔴 Fatigued  🟡 Recovering  🟢 Ready │
│                                   │
│  ── Suggested Workout ──         │
│  🟢 Back + Biceps                │
│  ├ Pull-up · 4 sets    [→ alt]  │
│  ├ Barbell Row · 3 sets [→ alt] │
│  └ [Start Workout →]            │
│                                   │
│  OR (rest day):                  │
│  Recovery in progress 💪         │
│  Chest ready in ~24h            │
│  [Walking] [Stretching] [Yoga]  │
└───────────────────────────────────┘
```

- Props: `fatigueStates: [MuscleFatigueState]`, `suggestion: WorkoutSuggestion?`
- 다이어그램 색상: recovery 0~0.5 → red, 0.5~0.8 → yellow, 0.8~1.0 → green, 미훈련 → gray
- 근육 탭 → `MuscleDetailPopover` sheet
- 추천 운동 행 → 좌로 스와이프 시 대안 운동 표시

5-b. **MuscleDetailPopover**:
- 근육 이름 (한/영), 회복률 %, 마지막 훈련일, 주간 볼륨, 추천 운동 3개

5-c. **WeeklyProgressBar**:
```
●●●○○  3/5 days this week
```
- `activeDays: Int`, `weeklyGoal: Int`
- 탭 → TrainingVolumeDetailView 이동

5-d. **ActiveRecoveryCard**: 3가지 추천 (Walking, Stretching, Yoga) 가로 스크롤 카드

5-e. **SuggestedExerciseRow**: 운동명 + 세트 수, 좌 스와이프 → 대안 운동 (`alternatives: [ExerciseDefinition]`)

**Verification**: Preview로 각 컴포넌트 독립 확인, 다양한 상태 (모든 근육 회복, 모든 근육 피로, 부분 회복)

---

### Step 6: 대시보드 재구성

**Files**:
- `Presentation/Activity/ActivityView.swift`
- `Presentation/Activity/ActivityViewModel.swift`
- `Presentation/Activity/Components/TrainingVolumeSummaryCard.swift`
- `Presentation/Exercise/Components/SuggestedWorkoutCard.swift` (삭제)

**Changes**:

6-a. ActivityViewModel 확장:
- `fatigueStates: [MuscleFatigueState]` 프로퍼티 노출 (View에서 사용)
- `updateSuggestion` + `.task` + `.onChange` → `.task(id:)` 통합 (Correction #78)
- `loadTask?.cancel()` 후 재할당 (Correction #16)

6-b. ActivityView 섹션 재구성:
```swift
ScrollView {
    VStack(spacing: DS.Spacing.lg) {
        // ① Weekly Progress Bar
        WeeklyProgressBar(activeDays: viewModel.activeDays, goal: viewModel.weeklyGoal)

        // ② Muscle Recovery Map (히어로)
        MuscleRecoveryMapView(
            fatigueStates: viewModel.fatigueStates,
            suggestion: viewModel.workoutSuggestion,
            onStartExercise: { exercise in selectedExercise = exercise },
            onMuscleSelected: { muscle in selectedMuscle = muscle }
        )

        // ③ Training Volume Summary (compact)
        TrainingVolumeSummaryCard(viewModel: viewModel)

        // ④ Recent Workouts
        ExerciseListSection(...)
    }
}
```

6-c. TrainingVolumeSummaryCard compact화:
- ActivityRing 제거 (WeeklyProgressBar로 이동)
- 28일 바 차트 + 마지막 운동 메트릭만 유지

6-d. SuggestedWorkoutCard.swift 삭제

**Verification**: 빌드 + 시뮬레이터에서 전체 플로우 확인

---

### Step 7: 테스트 + 빌드 검증

**Files**:
- `DailveTests/WorkoutRecommendationServiceTests.swift`

**Changes**:

7-a. 알고리즘 테스트:
- `test_compoundBypass_checksRecovery`: 미회복 근육의 compound 운동이 추천되지 않는지
- `test_differentialRecovery_smallMuscle36h`: 소근육 36h 후 회복 판정
- `test_differentialRecovery_largeMuscle72h`: 대근육 72h 전 미회복 판정
- `test_exerciseDiversity_prefersLeastRecent`: 최근 미수행 운동 우선 선택
- `test_restDay_returnsActiveRecovery`: 모든 근육 피로 시 ActiveRecovery 제안
- `test_restDay_nextReadyMuscle`: 가장 빨리 회복될 근육 + 시점 표시
- `test_weekdayPattern_boostedOnMatchingDay`: 요일 패턴 보너스 적용
- `test_hourBased_preciseRecovery`: 정수 일수 대비 시간 기반 정확도

7-b. 빌드 검증:
```bash
cd Dailve && xcodegen generate
xcodebuild build -project Dailve.xcodeproj -scheme Dailve -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2'
xcodebuild test -project Dailve.xcodeproj -scheme DailveTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -only-testing DailveTests
```

**Verification**: 전체 테스트 통과, 빌드 warning 0

---

## Edge Cases

| Case | Handling |
|------|----------|
| 첫 사용자 (기록 0건) | 모든 근육 "회복 완료" (gray) → 전신 운동 추천 |
| 모든 근육 피로 | Rest Day 카드 + Active Recovery 3종 + "Chest ready in ~24h" |
| HealthKit만 있고 수동 기록 없음 | ExerciseRecord 기반이므로 HK-only → 미훈련 취급 → 전신 추천 |
| 운동 라이브러리에 해당 근육 운동 없음 | compound 운동으로 대체 (recovery 검증 포함) |
| 스와이프 대안 운동이 없는 경우 | 스와이프 비활성화, 대안 없음 표시 안 함 |
| 모든 근육 미훈련 (gray) + 요일 패턴 없음 | 기본 push/pull/legs 균형 추천 |
| SVG path 렌더 실패 | 기존 RoundedRectangle fallback |

## Testing Strategy

- **Unit tests**: WorkoutRecommendationService (8개 케이스), 요일 패턴 계산, MuscleFatigueState.nextReadyDate
- **Preview tests**: 각 UI 컴포넌트 다양한 상태로 Preview 검증
- **Manual verification**: 시뮬레이터에서 전체 플로우 (운동 기록 → 대시보드 갱신 → 회복 맵 색상 변화 → 추천 변경)

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SVG→Shape 변환 품질 | Medium | Medium | Preview로 사전 검증, fallback 준비 |
| SVG path 크기가 크면 렌더 성능 | Low | Medium | `.drawingGroup()` 적용, LazyVStack |
| 기존 SuggestedWorkoutCard 삭제 시 참조 깨짐 | Low | Low | 컴파일 에러로 즉시 발견 |
| 요일 패턴 계산이 데이터 부족 시 무의미 | Medium | Low | 8주 미만 데이터 시 패턴 보너스 비활성화 |
| lats ↔ upper-back 매핑 부정확 | Medium | Low | upper-back을 lats로 매핑, back은 lower-back |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 ExerciseMuscleMapView + MuscleMapData가 이미 정면/후면 다이어그램을 구현하고 있어 SVG 업그레이드만 하면 됨. 알고리즘 버그는 코드 위치와 원인이 명확. 대시보드 재구성은 기존 섹션 재배치 + 새 컴포넌트 추가 수준으로 아키텍처 변경 없음.
