---
tags: [visionos, data-pipeline, real-data, ux-fix]
date: 2026-03-08
category: plan
status: approved
---

# Plan: visionOS Phase 5A — 실데이터 연결 + Critical UX Fix

## Summary

visionOS 앱의 모든 화면을 실제 HealthKit/SharedHealthSnapshot 데이터로 연결하고,
production 차단 수준의 UX 문제를 수정한다.

## Key Insight

**HealthKit은 visionOS에서 이미 사용 가능하다.** VisionSpatialViewModel이 이미 WorkoutQuerying으로
실제 워크아웃을 가져오고 SpatialTrainingAnalyzer로 근육 피로도를 계산한다.
ExerciseRecord SwiftData 모델이나 별도 mirror record 없이도 기존 파이프라인으로 실데이터 연결 가능.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNEVision/Presentation/Activity/VisionTrainView.swift` | 수정 | 데모 데이터 → 실데이터 ViewModel 연결 |
| `DUNE/Presentation/Vision/VisionTrainViewModel.swift` | **신규** | Train 탭용 ViewModel (HealthKit + 피로도 계산) |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | 수정 | 샘플 데이터 → SharedHealthSnapshot 연결 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | 수정 | 샘플 데이터 → 실제 워크아웃 데이터 연결 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | 수정 | ViewModel/service 주입 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | 수정 | placeholder "--" → 실데이터 표시 |
| `DUNEVision/Presentation/Volumetric/BodyHeatmapSceneView.swift` | 수정 | DragGesture delta 기반 수정 |
| `DUNEVision/Presentation/Wellness/VisionWellnessView.swift` | **신규** | Sleep + Body 기본 표시 |
| `DUNEVision/Presentation/Life/VisionLifeView.swift` | **신규** | Habit 기본 표시 (read-only) |
| `DUNEVision/App/VisionContentView.swift` | 수정 | Wellness/Life 탭 placeholder 교체 + VM 주입 |
| `DUNEVision/App/DUNEVisionApp.swift` | 수정 | ViewModel 생성 + 주입 |
| `DUNE/project.yml` | 수정 | 새 파일 포함 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 새 UI 문자열 번역 |
| `DUNE/DUNETests/VisionTrainViewModelTests.swift` | **신규** | ViewModel 테스트 |

## Implementation Steps

### Step 1: VisionTrainViewModel 생성 (핵심)

**목적**: VisionTrainView에 실데이터를 공급하는 ViewModel

**패턴**: VisionSpatialViewModel과 동일한 패턴 사용

```swift
@Observable @MainActor
final class VisionTrainViewModel {
    enum LoadState { case idle, loading, ready, unavailable, failed(String) }

    var loadState: LoadState = .idle
    var fatigueStates: [MuscleFatigueState] = []

    private let workoutService: WorkoutQuerying
    private let fatigueService: FatigueCalculating
    private let sharedHealthDataService: SharedHealthDataService?
    private let healthKitAvailable: Bool

    func loadIfNeeded() async
    func reload() async {
        // 1. Fetch 14-day workouts from HealthKit (if available)
        // 2. Convert WorkoutSummary → ExerciseRecordSnapshot
        // 3. Fetch SharedHealthSnapshot for sleep/readiness modifiers
        // 4. Compute CompoundFatigueScore per muscle
        // 5. Map to MuscleFatigueState[]
    }
}
```

**검증**: HealthKit 없을 때 → empty fatigueStates + meaningful empty state

### Step 2: VisionTrainView 실데이터 연결

- `VisionMuscleMapDemoData` 참조 제거
- `@State var viewModel: VisionTrainViewModel` 추가
- `.task { await viewModel.loadIfNeeded() }` 로 데이터 로드
- 개발 설명 텍스트 ("visionOS training sync is still using demo...") 제거
- 기술 설명 → 사용자 가치 메시지로 교체

### Step 3: Chart3D 실데이터 연결

**ConditionScatter3DView**:
- `sharedHealthDataService` 주입
- `generateSampleData()` → SharedHealthSnapshot 기반 데이터 변환
- `SharedHealthSnapshot.recentConditionScores` + `hrvSamples14Day` + `rhrCollection14Day` 활용
- 데이터 부족 시 empty state

**TrainingVolume3DView**:
- `workoutService: WorkoutQuerying` 주입
- `generateSampleData()` → 실제 워크아웃 기반 주간 근육별 volume
- `SpatialTrainingAnalyzer.snapshot()` 으로 WorkoutSummary → muscle 매핑

### Step 4: VisionDashboardView 실데이터 표시

- `SharedHealthDataService`에서 snapshot fetch
- Condition Score 표시 (conditionScore?.score ?? "--")
- HRV 표시 (todayRHR, latestRHR)
- Sleep 표시 (todaySleepMinutes)
- Activity 표시 (recent workout count)
- `.task { }` 로 데이터 로드

### Step 5: BodyHeatmapSceneView DragGesture 수정

현재 (absolute 기반):
```swift
yaw = 0.28 + Float(value.translation.width * 0.01)
```

수정 (delta 기반, VisionMuscleMapExperienceView 패턴):
```swift
@State private var dragStartYaw: Float = 0.28
@State private var dragStartPitch: Float = -0.16

DragGesture()
    .onChanged { value in
        yaw = dragStartYaw + Float(value.translation.width) * 0.008
        pitch = (dragStartPitch + Float(value.translation.height) * 0.004).clamped(to: -0.48...0.18)
    }
    .onEnded { _ in
        dragStartYaw = yaw
        dragStartPitch = pitch
    }
```

### Step 6: Wellness 탭 기본 UI

**VisionWellnessView**: SharedHealthSnapshot 기반 read-only 표시

- **Sleep Section**: 어제 수면 시간, 수면 단계 비율, 14일 평균
- **Body Section**: (visionOS에서 body composition은 HealthKit 제한적 → placeholder 또는 mirror 데이터)
- glass material 배경, visionOS 스타일 카드 레이아웃

### Step 7: Life 탭 기본 UI

**VisionLifeView**: 간단한 안내 + iOS 앱 연동 메시지

- Habit 데이터는 SwiftData 기반이므로 visionOS에서 직접 접근 불가
- "Habits are synced from your iPhone" 안내 메시지
- 향후 CloudKit mirror 연결 시 실데이터 표시 예정

### Step 8: VisionContentView + DUNEVisionApp 업데이트

- Wellness/Life placeholder 교체
- VisionTrainViewModel 생성 + 주입
- Chart3D에 service 주입

### Step 9: Localization (xcstrings)

새 UI 문자열에 en/ko/ja 번역 추가:
- VisionTrainView 사용자 메시지
- VisionWellnessView 레이블
- VisionLifeView 안내 메시지
- Empty state 메시지

### Step 10: 테스트 작성

**VisionTrainViewModelTests.swift**:
- 워크아웃 데이터 → fatigue 계산 검증
- HealthKit 없을 때 empty state 검증
- 0건 워크아웃 → empty fatigueStates 검증

## Test Strategy

| 테스트 | 방법 |
|--------|------|
| VisionTrainViewModel 로직 | Swift Testing (@Suite, @Test) |
| Chart3D 데이터 변환 | 단위 테스트 (SharedHealthSnapshot → chart points) |
| DragGesture delta | 수동 확인 (시뮬레이터) |
| Wellness/Life UI | 수동 확인 (시뮬레이터) |
| 빌드 검증 | `scripts/build-ios.sh` + visionOS scheme 빌드 |

## Risks & Edge Cases

| 리스크 | 대응 |
|--------|------|
| HealthKit 권한 미승인 | empty state + 설정 안내 메시지 |
| visionOS 시뮬레이터에서 HealthKit 데이터 없음 | fallback empty state 검증 |
| 워크아웃 0건 | "Start training on iPhone or Watch" 안내 |
| SharedHealthSnapshot 미러 지연 | fetchedAt 타임스탬프 표시 |
| 수면 데이터 없음 | "Wear Apple Watch tonight" 안내 |

## Alternatives Considered

1. **ExerciseRecordMirrorRecord 별도 생성** — 불필요. HealthKit WorkoutQuerying이 visionOS에서 직접 작동.
2. **SharedHealthSnapshot 확장** — 불필요. 운동 데이터는 HealthKit에서 직접 쿼리 가능.
3. **SwiftData ExerciseRecord visionOS 포함** — 과도. Sendable snapshot으로 충분.
