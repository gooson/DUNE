---
tags: [watchos, cardio, ui-redesign, apple-fitness, heart-rate-zone, multi-page]
date: 2026-03-03
category: plan
status: approved
---

# Plan: Watch 유산소 운동 UI — Apple Fitness 스타일 리디자인

## Summary

현재 단일 페이지 `CardioMetricsView`를 Apple Fitness Watch 앱과 유사한 다중 페이지 구조로 개편한다.
HR Zone 실시간 표시, 운동 종류별 메트릭 최적화, 컨트롤 분리를 포함한다.

## Decisions

| 항목 | 결정 |
|------|------|
| maxHR 소스 | HealthKit 생년월일 자동 (220-age). dateOfBirth 미설정 시 default 190 |
| Zone 색상 | DS 토큰 매핑 — Watch DS에 zone1-5 추가 (iOS DS와 동일 xcassets 참조) |
| 수영 모드 | 포함 — Laps/Stroke 메트릭 표시. Water Lock은 MVP 범위 외 |

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNEWatch/DesignSystem.swift` | **modify** | zone1-5 색상 토큰 + 대형 메트릭 typography 추가 |
| `DUNEWatch/Views/SessionPagingView.swift` | **modify** | 다중 페이지 구조로 변경 (5 pages) |
| `DUNEWatch/Views/CardioMetricsView.swift` | **delete** | 새 페이지들로 대체 |
| `DUNEWatch/Views/Cardio/CardioMainMetricsPage.swift` | **create** | Page 1: elapsed, distance/pace, HR, cal |
| `DUNEWatch/Views/Cardio/CardioHRZonePage.swift` | **create** | Page 2: HR zone bar + zone name + HR |
| `DUNEWatch/Views/Cardio/CardioSecondaryPage.swift` | **create** | Page 3: activity-specific secondary metrics |
| `DUNEWatch/Views/Cardio/CardioMetricProfile.swift` | **create** | Activity → metric mapping enum |
| `DUNEWatch/Views/Cardio/Components/WorkoutMetricCard.swift` | **create** | 재사용 메트릭 카드 (large/medium/compact) |
| `DUNEWatch/Views/Cardio/Components/HRZoneBar.swift` | **create** | 5-segment zone progress bar |
| `DUNEWatch/Managers/WorkoutManager.swift` | **modify** | currentZone computed property + maxHR 추가 |
| `DUNEWatch/Views/ControlsView.swift` | 유지 | 이미 분리됨 — 변경 불필요 |
| `DUNE/Domain/Models/HeartRateZone.swift` | 유지 | Zone model + calculator 이미 존재 |
| `DUNETests/CardioMetricProfileTests.swift` | **create** | 메트릭 프로파일 매핑 테스트 |
| `DUNETests/WatchHRZoneTests.swift` | **create** | Watch maxHR 추정 + 실시간 zone 계산 테스트 |
| `DUNE/Resources/Localizable.xcstrings` | **modify** | 새 UI 문자열 ko/ja 번역 |
| `DUNEWatch/Resources/Localizable.xcstrings` | **modify** | Watch 전용 UI 문자열 ko/ja 번역 |

## Implementation Steps

### Step 1: Watch DS 확장

Watch DesignSystem에 HR zone 색상 토큰과 대형 메트릭 typography 추가.

```swift
// DS.Color
static let zone1 = SwiftUI.Color("HRZone1")
static let zone2 = SwiftUI.Color("HRZone2")
static let zone3 = SwiftUI.Color("HRZone3")
static let zone4 = SwiftUI.Color("HRZone4")
static let zone5 = SwiftUI.Color("HRZone5")

// DS.Typography
static let primaryMetric = Font.system(size: 42, weight: .bold, design: .rounded).monospacedDigit()
static let secondaryMetric = Font.system(.title3, design: .rounded).monospacedDigit().bold()
```

### Step 2: CardioMetricProfile 생성

운동 종류별 메트릭 세트를 정의하는 enum.

```swift
enum CardioMetricProfile: Sendable {
    case running   // pace, cadence (future)
    case cycling   // speed
    case swimming  // laps, stroke (future)
    case generic   // elapsed + HR + cal only

    static func profile(for activityType: WorkoutActivityType) -> CardioMetricProfile
    var mainMetrics: [CardioMetric]       // Page 1에 표시
    var secondaryMetrics: [CardioMetric]  // Page 3에 표시
    var showsDistance: Bool
    var showsPace: Bool
    var showsSpeed: Bool
}
```

### Step 3: WorkoutMetricCard 컴포넌트 생성

3가지 크기의 재사용 메트릭 카드.

```swift
struct WorkoutMetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    let size: MetricSize  // .large, .medium, .compact
}
```

### Step 4: HRZoneBar 컴포넌트 생성

5-segment 수평 바 + 현재 zone 강조.

```swift
struct HRZoneBar: View {
    let currentZone: HeartRateZone.Zone?
    let fraction: Double  // currentHR / maxHR (0.0-1.0)
}
```

### Step 5: WorkoutManager maxHR + currentZone 추가

```swift
// WorkoutManager에 추가
private(set) var estimatedMaxHR: Double = HeartRateZoneCalculator.defaultMaxHR

var currentZone: HeartRateZone.Zone? {
    guard heartRate > 0, estimatedMaxHR > 0 else { return nil }
    return HeartRateZone.Zone.zone(forFraction: heartRate / estimatedMaxHR)
}

var hrFraction: Double {
    guard estimatedMaxHR > 0 else { return 0 }
    return min(heartRate / estimatedMaxHR, 1.0)
}

// startCardioSession에서 HealthKit dateOfBirth 기반 maxHR 계산
func fetchEstimatedMaxHR() {
    do {
        let dob = try healthStore.dateOfBirthComponents()
        if let year = dob.year {
            let age = Calendar.current.component(.year, from: Date()) - year
            estimatedMaxHR = HeartRateZoneCalculator.estimateMaxHR(age: age)
        }
    } catch {
        // fallback: defaultMaxHR (190)
    }
}
```

### Step 6: 메트릭 페이지 3개 생성

**CardioMainMetricsPage (Page 1):**
- Elapsed time (large)
- Distance + Pace/Speed (medium 2-col) — profile에 따라 Pace vs Speed
- HR + Calories (compact 2-col)

**CardioHRZonePage (Page 2):**
- Heart Rate (large, zone color)
- Zone bar (5-segment)
- Zone name + time in zone
- Avg HR

**CardioSecondaryPage (Page 3):**
- Running: Avg Pace (primary), 현재 Pace + Distance (secondary)
- Cycling: Avg Speed (primary), 현재 Speed + Distance (secondary)
- Swimming: Distance (primary), Avg Pace per 100m (secondary)
- Generic: Distance (primary), Duration (secondary)

### Step 7: SessionPagingView 재구성

```swift
TabView(selection: $selectedTab) {
    if workoutManager.isCardioMode {
        CardioMainMetricsPage()
            .tag(SessionTab.cardioMain)
        CardioHRZonePage()
            .tag(SessionTab.hrZone)
        CardioSecondaryPage()
            .tag(SessionTab.cardioSecondary)
    } else {
        MetricsView()
            .tag(SessionTab.metrics)
    }

    ControlsView()
        .tag(SessionTab.controls)

    NowPlayingView()
        .tag(SessionTab.nowPlaying)
}
```

기존 `CardioMetricsView`에 있던 controlButtons를 제거하고 Controls 페이지에 통합.

### Step 8: 테스트 작성

- `CardioMetricProfileTests`: profile(for:) 매핑 검증, 각 프로파일 메트릭 세트 검증
- `WatchHRZoneTests`: maxHR 계산 (age → maxHR), currentZone 경계값, hrFraction 범위

### Step 9: Localization

새 UI 문자열을 xcstrings에 등록:
- "Recovery", "Fat Burn", "Cardio", "Hard", "Peak" — 이미 iOS에 존재, Watch xcstrings에도 추가
- "Zone %lld", "Avg HR", "Avg Pace", "Avg Speed", "Current Pace", "Current Speed", "Laps" 등
- ko/ja 3개 언어

### Step 10: 빌드 및 검증

`scripts/build-ios.sh` → 빌드 통과 확인

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Watch xcassets에 HRZone1-5 미등록 | iOS와 동일 색상값으로 Watch Assets에 추가 |
| dateOfBirth 접근 권한 미승인 | defaultMaxHR(190) fallback — HealthKit 권한 추가 없이 try/catch |
| 5페이지 TabView 성능 | 보이지 않는 페이지 TimelineView 업데이트 제한 필요 |
| 수영 laps/stroke HK 데이터 부재 | MVP에서는 distance 기반만, laps는 distance / poolLength 추정 |
