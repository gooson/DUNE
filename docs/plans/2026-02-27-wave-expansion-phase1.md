---
topic: wave-expansion-phase1
date: 2026-02-27
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-26-visual-overhaul-warm-tone-alignment
  - architecture/2026-02-27-design-system-consistency-integration
  - performance/2026-02-19-swiftui-color-static-caching
related_brainstorms:
  - 2026-02-27-wave-expansion-tab-identity
---

# Implementation Plan: 웨이브 전면 확산 + 탭별 파라미터 차별화 (Phase 1)

## Context

웨이브 배경이 4개 탭 루트(Dashboard, Activity, Wellness, Exercise)에만 적용되어 있고, 모든 화면의 웨이브 파라미터가 동일하다. Detail 화면, Sheet, Watch 앱에는 웨이브가 없어 화면 전환 시 시각적 일관성이 끊긴다.

Phase 1에서는 **웨이브를 모든 화면으로 확산**하고, **탭별 웨이브 캐릭터를 차별화**한다. 컬러 변경(Desert Horizon 팔레트)은 Phase 2에서 별도 Push로 진행.

## Requirements

### Functional

- 모든 Detail 화면(push destination)에 부모 탭의 웨이브 배경 표시
- 모든 Sheet/Modal에 맥락에 맞는 웨이브 배경 표시
- Injury 화면에 `DS.Color.caution` 컬러 웨이브 표시
- Watch 앱에 간소화된 웨이브 배경 표시
- 탭별 웨이브 파라미터(amplitude, frequency, layers) 차별화

### Non-functional

- `reduceMotion` 접근성 존중 (기존 구현 유지)
- 추가 렌더 비용 최소화 (WaveShape의 pre-compute 패턴 유지)
- DS 토큰 체계와 일관된 구조

## Approach

**Environment 기반 컬러 전파** + **3개 레벨의 웨이브 변형(Tab/Detail/Sheet)** + **탭별 preset 토큰**

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Environment key로 컬러 전파 | 자동 상속, 코드 중복 없음 | 커스텀 EnvironmentKey 첫 도입 | **채택** |
| 각 화면에 직접 컬러 지정 | 명시적, 단순 | 30+ 화면에 반복 코드 | 거부 |
| ViewModifier로 래핑 | 일관된 API | `.background {}` 패턴과 중복 | 거부 |

## Affected Files

### 신규 생성

| File | Description |
|------|-------------|
| `Presentation/Shared/Components/WavePreset.swift` | 탭별 웨이브 파라미터 preset enum + EnvironmentKey |

### 수정 (Core)

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Shared/Components/WaveShape.swift` | modify | TabWaveBackground에 preset 파라미터 수용, DetailWaveBackground/SheetWaveBackground 추가 |
| `Presentation/Shared/DesignSystem.swift` | modify | DS.Gradient에 탭별 wave preset 토큰 추가 |
| `App/ContentView.swift` | modify | `.environment(\.wavePreset, ...)` 설정 |

### 수정 (Tab Roots — preset 적용)

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Dashboard/DashboardView.swift` | modify | TabWaveBackground → preset 기반으로 전환 |
| `Presentation/Activity/ActivityView.swift` | modify | 동일 |
| `Presentation/Wellness/WellnessView.swift` | modify | 동일 |
| `Presentation/Exercise/ExerciseView.swift` | modify | 동일 |

### 수정 (Detail Views — 웨이브 추가)

| File | Parent Tab | Description |
|------|-----------|-------------|
| `Dashboard/ConditionScoreDetailView.swift` | Today | `.background { DetailWaveBackground() }` 추가 |
| `Shared/Detail/MetricDetailView.swift` | Today/Wellness | 동일 (EnvironmentKey에서 자동 상속) |
| `Shared/Detail/AllDataView.swift` | Today/Wellness | List 기반 — `.scrollContentBackground(.hidden)` + `.background {}` |
| `Shared/Detail/ExerciseTotalsView.swift` | Train | 동일 |
| `Wellness/WellnessScoreDetailView.swift` | Wellness | 동일 |
| `Wellness/BodyHistoryDetailView.swift` | Wellness | 동일 |
| `Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | Train | 동일 |
| `Activity/WeeklyStats/WeeklyStatsDetailView.swift` | Train | 동일 |
| `Activity/TrainingVolume/TrainingVolumeDetailView.swift` | Train | 동일 |
| `Activity/TrainingVolume/ExerciseTypeDetailView.swift` | Train | 동일 |
| `Activity/ExerciseMix/ExerciseMixDetailView.swift` | Train | 동일 |
| `Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Train | 동일 |
| `Activity/Consistency/ConsistencyDetailView.swift` | Train | 동일 |
| `Exercise/ExerciseSessionDetailView.swift` | Train | 동일 |
| `Exercise/HealthKitWorkoutDetailView.swift` | Train | 동일 |
| `Exercise/Components/VolumeAnalysisView.swift` | Train | 동일 |

### 수정 (Sheet/Modal — 웨이브 추가)

| File | Context | Description |
|------|---------|-------------|
| `Exercise/ExerciseStartView.swift` | Train | `.background { SheetWaveBackground() }` 추가 |
| `Exercise/WorkoutSessionView.swift` | Train | VStack 기반 — background 추가 |
| `Exercise/CompoundWorkoutView.swift` | Train | 동일 |
| `Exercise/Components/CreateCustomExerciseView.swift` | Train | Form 기반 — `.scrollContentBackground(.hidden)` + background |
| `Exercise/Components/ExercisePickerView.swift` | Train | List 기반 — 동일 패턴 |
| `Exercise/Components/UserCategoryManagementView.swift` | Train | List 기반 — 동일 패턴 |
| `Exercise/Components/CreateTemplateView.swift` | Train | 동일 |
| `Dashboard/Components/PinnedMetricsEditorView.swift` | Today | 동일 |
| `Exercise/Components/RestTimerView.swift` | Train | 이미 `.ultraThinMaterial` — wave 경량 적용 |
| `Shared/CloudSyncConsentView.swift` | Neutral | warmGlow 기본 컬러 사용 |

### 수정 (Injury — caution 컬러)

| File | Description |
|------|-------------|
| `Injury/InjuryHistoryView.swift` | List 기반 — `.scrollContentBackground(.hidden)` + DetailWaveBackground(color: DS.Color.caution) |
| `Injury/InjuryStatisticsView.swift` | ScrollView 기반 — 동일 |
| `Injury/InjuryBodyMapView.swift` | GeometryReader 기반 — background 추가 |

### 수정 (Watch)

| File | Description |
|------|-------------|
| `DUNEWatch/DesignSystem.swift` | DS.Gradient wave 토큰 추가 |
| `DUNEWatch/ContentView.swift` | 루트에 웨이브 배경 추가 |
| `DUNEWatch/Views/SessionSummaryView.swift` | ScrollView 기반 — 웨이브 추가 |
| `DUNEWatch/Views/QuickStartPickerView.swift` | 웨이브 추가 |
| `DUNEWatch/Views/RoutineListView.swift` | 웨이브 추가 |

### xcodegen

| File | Description |
|------|-------------|
| `DUNE/project.yml` | WavePreset.swift 추가 시 자동 포함 (sources glob) |

## Implementation Steps

### Step 1: WavePreset enum + EnvironmentKey 생성

- **Files**: `Presentation/Shared/Components/WavePreset.swift` (신규)
- **Changes**:

```swift
import SwiftUI

/// Tab-specific wave animation presets.
enum WavePreset: Sendable {
    case today
    case train
    case wellness
    case injury
    case watch

    var amplitude: CGFloat { ... }
    var frequency: CGFloat { ... }
    var opacity: Double { ... }
    var verticalOffset: CGFloat { ... }
    var bottomFade: CGFloat { ... }
    /// Train tab uses a secondary overlay wave.
    var secondaryWave: (amplitude: CGFloat, frequency: CGFloat, opacity: Double, phaseOffset: CGFloat)? { ... }
}

// MARK: - Environment

private struct WavePresetKey: EnvironmentKey {
    static let defaultValue: WavePreset = .today
}

private struct WaveColorKey: EnvironmentKey {
    static let defaultValue: Color = DS.Color.warmGlow
}

extension EnvironmentValues {
    var wavePreset: WavePreset { get/set }
    var waveColor: Color { get/set }
}
```

Preset 값:

| Preset | amplitude | frequency | opacity | verticalOffset | secondary |
|--------|-----------|-----------|---------|----------------|-----------|
| today | 0.04 | 1.5 | 0.12 | 0.5 | nil |
| train | 0.08 | 2.5 | 0.15 | 0.5 | amp 0.04, freq 3.5, opacity 0.08, phase π/3 |
| wellness | 0.05 | 1.8 | 0.14 | 0.5 | nil |
| injury | 0.04 | 1.5 | 0.10 | 0.5 | nil |
| watch | 0.03 | 1.5 | 0.10 | 0.6 | nil |

- **Verification**: 빌드 성공 확인

### Step 2: TabWaveBackground를 preset 기반으로 리팩터링 + Detail/Sheet 변형 추가

- **Files**: `Presentation/Shared/Components/WaveShape.swift`
- **Changes**:

TabWaveBackground를 `WavePreset` + `Color`를 받도록 수정:

```swift
struct TabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color

    var body: some View {
        ZStack(alignment: .top) {
            // Primary wave
            WaveOverlayView(
                color: color,
                opacity: preset.opacity,
                amplitude: preset.amplitude,
                frequency: preset.frequency,
                verticalOffset: preset.verticalOffset,
                bottomFade: preset.bottomFade
            )
            .frame(height: 200)

            // Secondary wave (Train only)
            if let secondary = preset.secondaryWave {
                WaveOverlayView(
                    color: color,
                    opacity: secondary.opacity,
                    amplitude: secondary.amplitude,
                    frequency: secondary.frequency,
                    verticalOffset: preset.verticalOffset,
                    bottomFade: preset.bottomFade
                )
                .frame(height: 200)
            }

            // Gradient
            LinearGradient(
                colors: [color.opacity(DS.Opacity.medium), DS.Color.warmGlow.opacity(DS.Opacity.subtle), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
```

DetailWaveBackground (50% amplitude, 70% opacity, height 150pt):

```swift
struct DetailWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    var overrideColor: Color?

    private var effectiveColor: Color { overrideColor ?? color }

    var body: some View {
        ZStack(alignment: .top) {
            WaveOverlayView(
                color: effectiveColor,
                opacity: preset.opacity * 0.7,
                amplitude: preset.amplitude * 0.5,
                frequency: preset.frequency,
                verticalOffset: preset.verticalOffset,
                bottomFade: 0.5
            )
            .frame(height: 150)

            LinearGradient(
                colors: [effectiveColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
```

SheetWaveBackground (30% amplitude 감소, height 120pt):

```swift
struct SheetWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color

    var body: some View {
        ZStack(alignment: .top) {
            WaveOverlayView(
                color: color,
                opacity: preset.opacity * 0.6,
                amplitude: preset.amplitude * 0.4,
                frequency: preset.frequency,
                verticalOffset: 0.5,
                bottomFade: 0.5
            )
            .frame(height: 120)

            LinearGradient(
                colors: [color.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        }
        .ignoresSafeArea()
    }
}
```

- **Verification**: 기존 4개 탭 루트 화면의 웨이브가 정상 렌더되는지 확인

### Step 3: ContentView에서 Environment 설정

- **Files**: `App/ContentView.swift`
- **Changes**:

```swift
Tab(AppSection.today.title, systemImage: AppSection.today.icon) {
    NavigationStack {
        DashboardView(sharedHealthDataService: sharedHealthDataService)
    }
    .environment(\.wavePreset, .today)
    .environment(\.waveColor, DS.Color.warmGlow)
}
Tab(AppSection.train.title, systemImage: AppSection.train.icon) {
    NavigationStack {
        ActivityView(sharedHealthDataService: sharedHealthDataService)
    }
    .environment(\.wavePreset, .train)
    .environment(\.waveColor, DS.Color.activity)
}
Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon) {
    NavigationStack {
        WellnessView(sharedHealthDataService: sharedHealthDataService)
    }
    .environment(\.wavePreset, .wellness)
    .environment(\.waveColor, DS.Color.fitness)
}
```

- **Verification**: 탭 전환 시 각 탭의 웨이브 파라미터가 다른지 확인 (Today 부드럽고, Train 역동적, Wellness 완만)

### Step 4: Tab Root 화면에서 명시적 컬러 제거

- **Files**: `DashboardView.swift`, `ActivityView.swift`, `WellnessView.swift`, `ExerciseView.swift`
- **Changes**:

각 탭 루트에서 `.background { TabWaveBackground(primaryColor: ...) }` → `.background { TabWaveBackground() }`

ExerciseView는 Train 맥락이므로 부모에서 상속받은 preset/color 사용.

- **Verification**: 4개 탭 루트 화면의 웨이브가 기존과 동일하게 표시

### Step 5: Detail 화면에 웨이브 추가 (16개 파일)

- **Files**: 위 Affected Files의 Detail Views 전체
- **Changes**:

ScrollView 기반:
```swift
.background { DetailWaveBackground() }
```

List 기반 (AllDataView, ExerciseTotalsView):
```swift
.scrollContentBackground(.hidden)
.background { DetailWaveBackground() }
```

Injury 화면 (3개):
```swift
.background { DetailWaveBackground(overrideColor: DS.Color.caution) }
```

- **Verification**: 각 Detail 화면에서 부모 탭의 컬러로 웨이브가 subtle하게 표시

### Step 6: Sheet/Modal에 웨이브 추가 (10개 파일)

- **Files**: 위 Affected Files의 Sheet/Modal 전체
- **Changes**:

Sheet에서는 Environment가 자동 상속되지 않으므로, sheet을 여는 쪽에서 `.environment()` 전달 또는 SheetWaveBackground에 명시적 컬러 전달:

NavigationStack 내부가 있는 sheet:
```swift
.background { SheetWaveBackground() }
```

Form/List 기반 sheet:
```swift
.scrollContentBackground(.hidden)
.background { SheetWaveBackground() }
```

VStack 기반 (WorkoutSession, RestTimer, CloudSyncConsent):
```swift
.frame(maxWidth: .infinity, maxHeight: .infinity)
.background { SheetWaveBackground() }
```

RestTimerView는 이미 `.ultraThinMaterial`이 있으므로 wave를 material 아래에 배치.

- **Verification**: 각 Sheet에서 맥락에 맞는 웨이브 표시

### Step 7: Watch 앱에 웨이브 추가

- **Files**: `DUNEWatch/DesignSystem.swift`, Watch View 파일들
- **Changes**:

Watch DS에 Gradient 토큰 추가:
```swift
enum Gradient {
    static let waveAmplitude: CGFloat = 0.03
    static let waveFrequency: CGFloat = 1.5
    static let waveVerticalOffset: CGFloat = 0.6
}
```

WaveShape.swift를 Watch 타겟에도 공유하거나, 간소화된 WatchWaveBackground 생성.

적용 화면:
- ContentView: 루트 배경
- SessionSummaryView: ScrollView 배경
- QuickStartPickerView: 배경
- RoutineListView: 배경

Watch 웨이브 height: 80pt, amplitude 0.03, warmGlow 단일 컬러.

- **Verification**: Watch 시뮬레이터에서 웨이브 표시 확인

### Step 8: DS.Gradient 토큰 정리

- **Files**: `Presentation/Shared/DesignSystem.swift`
- **Changes**:

기존 `waveAmplitude`, `waveFrequency`, `waveVerticalOffset` 토큰은 WavePreset으로 이동했으므로 deprecated 주석 추가 또는 제거. WavePreset이 single source of truth.

- **Verification**: 빌드 성공, 기존 참조 없음 확인

### Step 9: 빌드 검증 + xcodegen

- **Files**: -
- **Changes**: `cd DUNE && xcodegen generate` → `scripts/build-ios.sh`
- **Verification**: iOS 빌드 성공, Watch 빌드 성공

## Edge Cases

| Case | Handling |
|------|----------|
| iPad sidebarAdaptable 탭 전환 | Environment가 탭 단위로 설정되므로 자동 전환 |
| Sheet에서 Environment 미상속 | `.sheet` modifier에 `.environment()` 명시적 전달, 또는 SheetWaveBackground에 overrideColor 사용 |
| List 배경 | `.scrollContentBackground(.hidden)` 필수 — List 기본 배경이 wave를 가림 |
| EmptyStateView | 이미 WaveShape 사용 중 — 충돌 없음 (별도 패턴) |
| reduceMotion | 기존 WaveOverlayView에서 이미 처리됨 — 변경 없음 |
| Watch 작은 화면 | amplitude 0.03으로 제한, height 80pt — 가독성 유지 |
| RestTimerView ultraThinMaterial | wave를 material 아래 레이어에 배치 — ZStack 순서 조정 |
| Train 이중 레이어 성능 | WaveShape 240 sample points (120 x 2) — pre-compute 유지, 문제 없음 |

## Testing Strategy

- **Unit tests**: WavePreset enum의 각 case 값 검증 (amplitude, frequency 범위)
- **Manual verification**:
  - 3개 탭 전환 시 웨이브 캐릭터가 다른지 확인 (Today 부드럽고 느림, Train 역동적+이중, Wellness 완만)
  - Detail 화면 push 시 웨이브가 subtly 표시되는지 확인
  - Sheet 열 때 웨이브가 경량으로 표시되는지 확인
  - Injury 화면에서 caution(노랑) 컬러 웨이브 확인
  - Watch 시뮬레이터에서 웨이브 표시 확인
  - `reduceMotion` 켰을 때 애니메이션 정지 확인
  - iPad에서 sidebarAdaptable 탭 전환 시 정상 동작 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Sheet에 Environment 미전파 | 높음 | 중간 — wave 안 보임 | SheetWaveBackground에 overrideColor 파라미터로 fallback |
| List 배경이 wave를 가림 | 높음 | 낮음 — 빌드에서 확인 가능 | `.scrollContentBackground(.hidden)` 필수 적용 |
| Train 이중 레이어 시각적 과잉 | 중간 | 낮음 — 조절 가능 | 서브 웨이브 opacity를 0.08에서 시작, 필요시 축소 |
| Watch WaveShape 타겟 공유 문제 | 낮음 | 중간 | Watch 전용 간소화 버전 생성으로 대체 가능 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 TabWaveBackground 패턴이 잘 구조화되어 있고, WavePreset enum + EnvironmentKey 추가는 단순한 확장. 30+ 파일 수정이지만 대부분 `.background { DetailWaveBackground() }` 1줄 추가로 패턴이 반복적. 리스크가 높은 부분(Sheet environment, List 배경)은 알려진 해결책이 있음.
