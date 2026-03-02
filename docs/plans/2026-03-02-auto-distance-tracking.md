---
tags: [cardio, distance, gps, watch, healthkit, live-tracking]
date: 2026-03-02
category: plan
status: draft
---

# Plan: Watch 카디오 거리 자동 추적

## 요약

Watch에서 isDistanceBased 유산소 운동 시작 시, HKWorkoutSession을 올바른 activityType으로 생성하여
HKLiveWorkoutBuilder가 자동으로 거리 데이터를 수집하도록 한다.
실시간 거리(km)/페이스(min/km)/심박수/칼로리를 표시하는 CardioMetricsView를 추가한다.

## 아키텍처 결정

**단일 WorkoutManager + 모드 분기** (옵션 A 채택)

```swift
enum WorkoutMode: Sendable {
    case strength(template: WorkoutSessionTemplate)
    case cardio(activityType: WorkoutActivityType, isOutdoor: Bool)
}
```

근거: HK 세션 관리, delegate, recovery 코드가 동일. 두 번째 Manager는 복잡도만 증가.

## 구현 단계

### Phase 1: WorkoutManager 카디오 모드 추가 (커밋 1)

**파일 1**: `DUNEWatch/Managers/WorkoutManager.swift`

변경 사항:
1. `WorkoutMode` enum 추가
2. `private(set) var workoutMode: WorkoutMode?` 프로퍼티 추가
3. `private(set) var distance: Double = 0` (meters) 추가
4. `private(set) var currentPace: Double = 0` (sec/km) 추가
5. `startCardioSession(activityType:isOutdoor:)` 메서드 추가
6. `startSession(with:)` → `startStrengthSession(with:)`로 명확화 (기존 호출처 업데이트)
7. `requestAuthorization()` — distance type 추가
8. `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didCollectDataOf:)` — distance 수집 분기 추가
9. `reset()` — distance, currentPace, workoutMode 초기화
10. `isCardioMode` computed property 추가

```swift
// 새 카디오 시작 메서드
func startCardioSession(activityType: WorkoutActivityType, isOutdoor: Bool) async throws {
    self.workoutMode = .cardio(activityType: activityType, isOutdoor: isOutdoor)
    self.isSessionEnded = false
    self.isFinalizingWorkout = false
    self.healthKitWorkoutUUID = nil
    self.isRecoveredSession = false
    self.heartRateSamples = []
    self.distance = 0
    self.currentPace = 0

    let config = HKWorkoutConfiguration()
    config.activityType = activityType.hkWorkoutActivityType
    config.locationType = isOutdoor ? .outdoor : .indoor

    // ... 기존 세션 시작 로직 공유
}
```

**distance 수집 (delegate):**

```swift
case HKQuantityType(.distanceWalkingRunning),
     HKQuantityType(.distanceCycling),
     HKQuantityType(.distanceSwimming),
     HKQuantityType(.distanceCrossCountrySkiing),
     HKQuantityType(.distanceDownhillSnowSports),
     HKQuantityType(.distancePaddleSports),
     HKQuantityType(.distanceWheelchair):
    let meters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0
    if meters >= 0, meters < 500_000 {  // 500km upper bound
        distance = meters
    }
```

**검증**: 빌드 성공. 기존 strength 워크플로우 미변경.

---

### Phase 2: WorkoutActivityType+HealthKit Watch 공유 (커밋 1 포함)

**파일**: `DUNE/project.yml`

DUNEWatch sources에 추가:
```yaml
- path: Data/HealthKit/WorkoutActivityType+HealthKit.swift
  group: Shared/HealthKit
```

`WorkoutActivityType+HealthKit.swift`는 이미 `hkWorkoutActivityType` 매핑을 갖고 있음.
Watch 타겟에 공유하면 별도 매핑 불필요.

---

### Phase 3: CardioMetricsView 추가 (커밋 2)

**새 파일**: `DUNEWatch/Views/CardioMetricsView.swift`

Apple 워크아웃 앱 스타일 실시간 메트릭 화면:

```
┌─────────────────────────┐
│   🏃 Running  12:34     │  ← 운동 아이콘 + 경과시간
│                         │
│      3.42               │  ← 거리 (km, 대형)
│       km                │
│                         │
│  5:12    ❤️ 156   🔥245 │  ← 페이스 + 심박 + 칼로리
│  /km      bpm     kcal  │
└─────────────────────────┘
```

구현:
- `@Environment(WorkoutManager.self)` 참조
- 거리: `workoutManager.distance / 1000.0` → km, 소수점 2자리
- 페이스: `workoutManager.currentPace` → "M:SS /km" 포맷
- 심박수: 기존 `workoutManager.heartRate`
- 칼로리: 기존 `workoutManager.activeCalories`
- 경과 시간: `TimelineView(.periodic(every: 1))` 기반
- Always-On Display: `isLuminanceReduced` 시 업데이트 빈도 감소 (10초)
- `.contentTransition(.numericText())` for animated value changes

**검증**: 빌드 성공.

---

### Phase 4: SessionPagingView 분기 (커밋 2 포함)

**파일**: `DUNEWatch/Views/SessionPagingView.swift`

```swift
var body: some View {
    TabView(selection: $selectedTab) {
        ControlsView()
            .tag(SessionTab.controls)

        // 운동 모드에 따라 적절한 메트릭 뷰 표시
        if workoutManager.isCardioMode {
            CardioMetricsView()
                .tag(SessionTab.metrics)
        } else {
            MetricsView()
                .tag(SessionTab.metrics)
        }

        NowPlayingView()
            .tag(SessionTab.nowPlaying)
    }
    .tabViewStyle(.verticalPage(transitionStyle: .blur))
    // ...
}
```

**검증**: strength 모드 → MetricsView, cardio 모드 → CardioMetricsView.

---

### Phase 5: 카디오 시작 플로우 (커밋 3)

기존 `WorkoutPreviewView`를 확장하여 카디오 운동일 때 Outdoor/Indoor 선택 + 카운트다운을 표시.

**파일**: `DUNEWatch/Views/WorkoutPreviewView.swift`

카디오 운동 감지:
```swift
private var isCardioExercise: Bool {
    guard snapshot.entries.count == 1 else { return false }
    let id = snapshot.entries[0].exerciseDefinitionID
    return WorkoutActivityType(rawValue: id)?.isDistanceBased == true
        || WorkoutActivityType.infer(from: snapshot.entries[0].exerciseName)?.isDistanceBased == true
}
```

카디오일 때 기존 운동 리스트 대신 Outdoor/Indoor 선택 UI 표시:
```
┌─────────────────────────┐
│     🏃 Running          │
│                         │
│  ┌─────────────────┐    │
│  │  🌳 Outdoor     │    │
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │  🏠 Indoor      │    │
│  └─────────────────┘    │
└─────────────────────────┘
```

Start 시:
```swift
func startCardioWorkout(isOutdoor: Bool) {
    let activityType = resolvedActivityType
    Task {
        try await workoutManager.requestAuthorization()
        try await workoutManager.startCardioSession(
            activityType: activityType,
            isOutdoor: isOutdoor
        )
    }
}
```

**주의**: `resolvedActivityType`은 exerciseDefinitionID → WorkoutActivityType 매핑.
exercises.json의 ID는 "running", "walking" 등 WorkoutActivityType.rawValue와 대응될 수 있으나,
"running-treadmill", "running-intervals" 같은 변형은 stem 추출 필요.

---

### Phase 6: ControlsView 카디오 적응 (커밋 3 포함)

**파일**: `DUNEWatch/Views/ControlsView.swift`

카디오 모드에서:
- "Skip Exercise" 버튼 숨김 (단일 활동)
- 기존 End/Pause/Resume 유지

---

### Phase 7: SessionSummaryView 카디오 적응 (커밋 4)

**파일**: `DUNEWatch/Views/SessionSummaryView.swift`

카디오 모드에서:
- "Volume" → "Distance" 표시 (km)
- "Sets" → "Avg Pace" 표시 (min/km)
- 운동 breakdown 제거 (단일 활동)

**파일**: `SessionSummaryView.swift` init에 `distance: Double`, `workoutMode: WorkoutMode?` 추가
또는 WorkoutManager에서 직접 읽기.

---

### Phase 8: WatchExerciseInfo activityType 추가 (커밋 5)

**파일** (양쪽 동기화 #69):
1. `DUNEWatch/WatchConnectivityManager.swift` — `WatchExerciseInfo`에 `activityType: String?` 필드 추가
2. `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` — 동일

**파일**: `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` (또는 WatchSessionManager)
- 운동 동기화 시 `activityType: exercise.activityType?.rawValue` 전달

이렇게 하면 Watch에서 exerciseDefinitionID 대신 명시적 activityType으로 isDistanceBased 판정 가능.

---

### Phase 9: 유닛 테스트 (커밋 6)

**새 파일**: `DUNETests/CardioWorkoutModeTests.swift`

테스트 항목:
1. `WorkoutMode.cardio` 설정 시 `isCardioMode == true`
2. distance 수집: meters → km 변환 정확성
3. pace 계산: distance와 elapsed time 기반
4. pace edge case: distance == 0 → pace == 0
5. `resolvedActivityType` — exercise ID → WorkoutActivityType 매핑
6. isDistanceBased 운동 12종 모두 올바른 hkWorkoutActivityType 매핑

---

## Affected Files

| 파일 | 변경 | 커밋 |
|------|------|------|
| `DUNEWatch/Managers/WorkoutManager.swift` | WorkoutMode, distance/pace, startCardioSession | 1 |
| `DUNE/project.yml` | Watch에 WorkoutActivityType+HealthKit.swift 공유 | 1 |
| `DUNEWatch/Views/CardioMetricsView.swift` | **신규** — 실시간 거리/페이스/심박/칼로리 | 2 |
| `DUNEWatch/Views/SessionPagingView.swift` | isCardioMode 분기 | 2 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 카디오 Outdoor/Indoor 선택 UI | 3 |
| `DUNEWatch/Views/ControlsView.swift` | 카디오 모드 Skip 숨김 | 3 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 카디오 Distance/Pace 표시 | 4 |
| `DUNEWatch/WatchConnectivityManager.swift` | WatchExerciseInfo.activityType | 5 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | WatchExerciseInfo.activityType (동기화) | 5 |
| `DUNETests/CardioWorkoutModeTests.swift` | **신규** — 유닛 테스트 | 6 |

## 위험 요소

1. **Watch에서 HealthKit import**: `WorkoutActivityType+HealthKit.swift`를 Watch 타겟에 추가할 때, iOS-only API가 없는지 확인 필요. `hkWorkoutActivityType`은 watchOS에서도 사용 가능한 타입만 사용.
2. **NowPlayingView**: 현재 정의되지 않은 View. watchOS 시스템 `WKInterfaceNowPlaying`은 SwiftUI에서 직접 사용 불가. 임시 placeholder 필요할 수 있음.
3. **Recovery**: 카디오 세션 복구 시 `workoutMode` 복원 필요. UserDefaults에 persistence 추가.
