---
topic: wellness-section-split
date: 2026-02-21
status: draft
confidence: high
related_solutions: [wellness-tab-consolidation, wellness-viewmodel-sendable-tuples, chart-ux-layout-stability]
related_brainstorms: [2026-02-21-wellness-section-split]
---

# Implementation Plan: Wellness 탭 섹션 분리 + HealthKit 데이터 확장

## Context

Wellness 탭의 vital card가 flat grid에 혼재되어 있어 정보 탐색이 비효율적이다. Physical(체격)과 Active(컨디션/심폐) 지표를 시각적으로 구분하고, 누락된 HealthKit 데이터(Heart Rate, Body Fat 카드, Lean Body Mass)를 추가하며, Heart Rate Zones 시각화와 Body Fat 추세선을 구현한다.

## Requirements

### Functional

- Physical / Active Indicators 2-섹션 분리 (둥근 카드 그룹)
- Heart Rate 카드 (daily latest + 7일 sparkline)
- Body Fat 카드 노출 (이미 fetch 중, sparkline 추가)
- Lean Body Mass 카드 추가
- Heart Rate Zones 시각화 (MetricDetailView 내 또는 별도 섹션)
- Body Fat 변화 추세선 (trend line)

### Non-functional

- 기존 VitalCard 컴포넌트 변경 없음
- HealthKit 값 범위 검증 준수 (#22)
- Formatter 캐싱 (#80)
- 섹션 내 recency 정렬 유지

## Approach

ViewModel에서 카드를 `physicalCards` / `activeCards` 두 배열로 분리하고, View에서 각 섹션을 `StandardCard`로 감싸 시각적 그룹화를 달성한다. HR Zone은 Domain에 모델을 정의하고, Heart Rate Detail View에서 Zone 분포 차트를 표시한다. Body Fat trend는 기존 `MetricDetailView`의 차트 패턴을 활용한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `VitalCardData`에 section 프로퍼티 추가 후 View에서 group | 단순, 기존 구조 최소 변경 | View에서 매번 filter 필요, 정렬 중복 | **채택** |
| ViewModel에서 두 배열로 분리 | View 로직 단순화 | VM 프로퍼티 증가 | **채택 (병행)** — section 프로퍼티 + VM 분리 배열 |
| 섹션별 별도 ViewModel | 완전한 분리 | 과잉 설계, fetch 중복 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/HealthMetric.swift` | **Modify** | Category에 `.heartRate`, `.bodyFat`, `.leanBodyMass` 추가 |
| `Domain/Models/HeartRateZone.swift` | **New** | HR Zone 모델 (zone1~5, 범위, 색상 매핑은 Presentation) |
| `Data/HealthKit/HeartRateQueryService.swift` | **Modify** | `fetchLatestHeartRate(withinDays:)`, `fetchHeartRateHistory(days:)` 추가 |
| `Data/HealthKit/BodyCompositionQueryService.swift` | **Modify** | `fetchLatestBodyFat(withinDays:)`, `fetchLatestLeanBodyMass(withinDays:)` 추가 |
| `Presentation/Shared/Models/VitalCardData.swift` | **Modify** | `section: CardSection` 프로퍼티 추가 |
| `Presentation/Shared/Models/CardSection.swift` | **New** | `enum CardSection { case physical, active }` |
| `Presentation/Wellness/WellnessViewModel.swift` | **Modify** | 새 fetch keys + 카드 빌드 + `physicalCards`/`activeCards` 분리 |
| `Presentation/Wellness/WellnessView.swift` | **Modify** | 섹션별 카드 그룹 UI |
| `Presentation/Wellness/Components/WellnessSectionGroup.swift` | **New** | 섹션 그룹 컨테이너 (header + StandardCard + LazyVGrid) |
| `Presentation/Shared/Extensions/HealthMetric+View.swift` | **Modify** | 새 Category의 icon, color 매핑 추가 |
| `Presentation/Shared/Detail/HeartRateZoneChart.swift` | **New** | HR Zone 분포 바 차트 |
| `Presentation/Shared/Detail/MetricDetailView.swift` | **Modify** | Heart Rate detail에 Zone 차트 삽입 |
| `Presentation/Shared/Detail/BodyFatTrendView.swift` | **New** | Body Fat 추세선 차트 (Swift Charts) |
| `Presentation/Shared/DesignSystem.swift` | **Modify** | HR Zone 색상 추가 (zone1~5) |

## Implementation Steps

### Step 1: Domain 모델 확장

- **Files**: `HealthMetric.swift`, `HeartRateZone.swift`
- **Changes**:
  - `HealthMetric.Category`에 `.heartRate`, `.bodyFat`, `.leanBodyMass` 3개 case 추가
  - `HeartRateZone` 모델 생성:
    ```swift
    struct HeartRateZone: Sendable {
        let zone: Zone
        let durationSeconds: TimeInterval
        let percentage: Double // 0.0-1.0

        enum Zone: Int, CaseIterable, Sendable {
            case zone1 = 1 // Recovery (50-60% maxHR)
            case zone2     // Fat Burn (60-70%)
            case zone3     // Cardio (70-80%)
            case zone4     // Hard (80-90%)
            case zone5     // Peak (90-100%)
        }
    }
    ```
  - Zone 계산 로직: `maxHR = 220 - age` (age는 HealthKit의 `HKCharacteristicType.dateOfBirth`)
- **Verification**: 빌드 성공, 기존 코드 영향 없음

### Step 2: Data 레이어 — Heart Rate 일반 쿼리 추가

- **Files**: `HeartRateQueryService.swift`, `BodyCompositionQueryService.swift`
- **Changes**:
  - `HeartRateQuerying` 프로토콜에 추가:
    - `fetchLatestHeartRate(withinDays:) -> VitalSample?`
    - `fetchHeartRateHistory(days:) -> [VitalSample]`
    - `fetchHeartRateZones(forWorkoutID:maxHR:) -> [HeartRateZone]` (워크아웃 기반 Zone 분포)
  - `BodyCompositionQuerying` 프로토콜에 추가:
    - `fetchLatestBodyFat(withinDays:) -> (value: Double, date: Date)?`
    - `fetchLatestLeanBodyMass(withinDays:) -> (value: Double, date: Date)?`
    - `fetchBodyFatHistory(days:) -> [BodyCompositionSample]` (= 기존 `fetchBodyFat(days:)` 활용 가능)
  - HR 범위 검증: 20-300 bpm (기존 패턴 동일)
  - Body Fat 범위: 0-100%, Lean Body Mass: 0-300kg
- **Verification**: 유닛 테스트 — mock 데이터로 범위 검증 확인

### Step 3: CardSection 모델 + VitalCardData 확장

- **Files**: `CardSection.swift`, `VitalCardData.swift`
- **Changes**:
  - `CardSection` enum 생성:
    ```swift
    enum CardSection: String, Sendable {
        case physical
        case active
    }
    ```
  - `VitalCardData`에 `let section: CardSection` 프로퍼티 추가
  - `buildCard()`에 section 파라미터 추가
  - Category → Section 매핑:
    - physical: `.weight`, `.bmi`, `.bodyFat`, `.leanBodyMass`
    - active: 나머지 전부
- **Verification**: 빌드 성공

### Step 4: WellnessViewModel — 새 데이터 fetch + 섹션 분리

- **Files**: `WellnessViewModel.swift`
- **Changes**:
  - Dependencies에 `heartRateService: HeartRateQuerying` 추가
  - `FetchKey`에 `.heartRate`, `.heartRateHistory`, `.leanBodyMass`, `.bodyFatHistory` 추가
  - `FetchResults`에 `latestHeartRate`, `heartRateHistory`, `latestLeanBodyMass`, `bodyFatHistory` 추가
  - `fetchAllData()` TaskGroup에 4개 fetch task 추가
  - `performLoad()`에 Heart Rate, Body Fat, Lean Body Mass 카드 빌드 추가
  - 기존 `vitalCards` → `physicalCards: [VitalCardData]` + `activeCards: [VitalCardData]` 분리
    - 하위 호환: `vitalCards` computed property 유지 (physicalCards + activeCards)
  - 각 배열 내 recency 정렬 유지
- **Verification**: 빌드 성공, 기존 카드 데이터 동일

### Step 5: WellnessView — 섹션 그룹 UI

- **Files**: `WellnessView.swift`, `WellnessSectionGroup.swift`
- **Changes**:
  - `WellnessSectionGroup` 컴포넌트 생성:
    ```swift
    struct WellnessSectionGroup<Content: View>: View {
        let title: String
        let icon: String
        let iconColor: Color
        @ViewBuilder let content: () -> Content
        // StandardCard 래핑 + 헤더 + 내부 LazyVGrid
    }
    ```
  - `WellnessView.scrollContent`에서 기존 단일 `LazyVGrid` → 두 `WellnessSectionGroup`으로 교체:
    ```
    WellnessSectionGroup("Physical", icon: "figure.stand") {
        LazyVGrid(columns: gridColumns) { ForEach(viewModel.physicalCards) { ... } }
    }
    WellnessSectionGroup("Active Indicators", icon: "heart.text.square") {
        LazyVGrid(columns: gridColumns) { ForEach(viewModel.activeCards) { ... } }
    }
    ```
  - 빈 섹션은 숨김: `if !viewModel.physicalCards.isEmpty { ... }`
- **Verification**: 시뮬레이터 UI 확인 — 두 섹션 시각적 분리, 카드 정상 표시

### Step 6: DesignSystem — HR Zone 색상

- **Files**: `DesignSystem.swift`, Asset Catalog
- **Changes**:
  - `DS.Color`에 zone1~5 색상 추가:
    ```swift
    static let zone1 = SwiftUI.Color("HRZone1") // 회색/파랑 (recovery)
    static let zone2 = SwiftUI.Color("HRZone2") // 파랑 (fat burn)
    static let zone3 = SwiftUI.Color("HRZone3") // 초록 (cardio)
    static let zone4 = SwiftUI.Color("HRZone4") // 주황 (hard)
    static let zone5 = SwiftUI.Color("HRZone5") // 빨강 (peak)
    ```
  - `DS.Color`에 `.heartRate` 메트릭 색상 추가
  - Asset Catalog에 대응 색상 세트 추가
- **Verification**: 프리뷰에서 색상 확인

### Step 7: Heart Rate Zone 차트

- **Files**: `HeartRateZoneChart.swift`, `MetricDetailView.swift`
- **Changes**:
  - `HeartRateZoneChart`: Swift Charts `BarMark`로 Zone 1-5 분포 표시
    - X축: Zone 이름, Y축: 시간(분) 또는 비율(%)
    - 각 바에 Zone 색상 적용
    - 데이터 없을 때 placeholder 표시 (#30)
  - `MetricDetailView`에서 `.heartRate` category일 때 Zone 차트 섹션 추가
  - Zone 데이터는 최근 워크아웃 기반 (워크아웃 없으면 Zone 섹션 숨김)
- **Verification**: Preview + 시뮬레이터 확인

### Step 8: Body Fat 추세선

- **Files**: `BodyFatTrendView.swift`, `MetricDetailView.swift`
- **Changes**:
  - `BodyFatTrendView`: Swift Charts `LineMark` + `AreaMark` gradient로 30/90일 추세
    - X축: 날짜, Y축: Body Fat %
    - `.clipped()` 필수 (#70)
    - Period 전환: `.id(period)` + `.transition(.opacity)` (#29)
  - `MetricDetailView`에서 `.bodyFat` category일 때 trend 차트 표시
- **Verification**: Preview + mock 데이터로 trend 시각화 확인

### Step 9: HealthMetric+View 확장 매핑

- **Files**: `HealthMetric+View.swift` (또는 해당 extension 파일)
- **Changes**:
  - `.heartRate` → icon: `"heart.fill"`, color: `DS.Color.heartRate`
  - `.bodyFat` → icon: `"percent"`, color: `DS.Color.body`
  - `.leanBodyMass` → icon: `"figure.strengthtraining.traditional"`, color: `DS.Color.body`
- **Verification**: 빌드 성공

### Step 10: xcodegen + 빌드 + 테스트

- **Files**: `project.yml`
- **Changes**: `cd Dailve && xcodegen generate`
- **Verification**:
  ```bash
  xcodebuild build -project Dailve/Dailve.xcodeproj -scheme Dailve -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2'
  xcodebuild test -project Dailve/Dailve.xcodeproj -scheme DailveTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' -only-testing DailveTests
  ```

## Edge Cases

| Case | Handling |
|------|----------|
| 한 섹션의 카드가 모두 데이터 없음 | 해당 섹션 숨김 (`if !cards.isEmpty`) |
| Heart Rate 데이터 없음 (워치 미착용) | 카드 미표시, Zone 차트 숨김 |
| Body Fat/Lean Body Mass 수동 입력 오류 | 범위 검증 (BF: 0-100%, LBM: 0-300kg) |
| maxHR 계산 시 생년월일 없음 | `220 - 30`(기본 30세) fallback, 또는 `HKHealthStore.dateOfBirth()` 실패 시 |
| HR > 300bpm 또는 < 20bpm | 기존 검증 패턴 적용, 카드에서 제외 |
| Body Fat trend 데이터 1개뿐 | LineMark 단일 점 표시 + "Need more data" 안내 |

## Testing Strategy

- **Unit tests**:
  - `HeartRateZoneTests` — Zone 계산 경계값 (정확히 60%, 70% 등)
  - `WellnessViewModelTests` — 새 카드가 올바른 section에 배치되는지
  - `BodyCompositionQueryServiceTests` — `fetchLatestBodyFat`, `fetchLatestLeanBodyMass` 범위 검증
- **Manual verification**:
  - 시뮬레이터에서 두 섹션 시각적 분리 확인
  - 한 섹션만 데이터 있을 때 정상 표시
  - Heart Rate Zone 차트 색상/레이아웃
  - Body Fat trend line 스크롤/period 전환

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Heart Rate 일반 쿼리가 빈번하여 배터리 영향 | Low | Medium | `withinDays` 제한, 앱 진입 시 1회만 fetch |
| maxHR 계산 부정확 (220-age 공식의 한계) | Medium | Low | 추후 사용자 커스텀 maxHR 옵션 추가 가능 |
| 기존 `vitalCards` 참조하는 코드 깨짐 | Medium | Medium | computed property로 하위 호환 유지 |
| Zone 데이터가 워크아웃 필수라 일상 HR에는 미적용 | Low | Low | MVP는 워크아웃 기반 Zone만, 추후 확장 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 패턴(VitalCard, StandardCard, TaskGroup fetch, MetricDetailView)이 잘 정립되어 있고, 대부분 기존 구조 확장. 새 HealthKit 쿼리도 기존 서비스 패턴을 따르면 됨. HR Zone은 새 Domain 모델이지만 복잡도 낮음.
