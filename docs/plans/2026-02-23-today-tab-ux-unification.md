---
topic: today-tab-ux-unification
date: 2026-02-23
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-21-wellness-section-split-patterns.md
  - general/2026-02-17-chart-ux-layout-stability.md
  - performance/2026-02-19-swiftui-color-static-caching.md
related_brainstorms:
  - 2026-02-23-today-tab-ux-unification.md
  - 2026-02-22-today-tab-expert-reference-brainstorm.md
---

# Implementation Plan: Today 탭 UX 통합 (Wellness 스타일)

## Context

기존 플랜(2026-02-22)의 기능적 개선 6단계는 모두 완료되었으나, Today 탭과 Wellness 탭의 시각적 일관성이 부족합니다.

핵심 작업: MetricCardView → VitalCard 통합, SmartCardGrid → LazyVGrid 교체, 섹션 헤더 SectionGroup 통일, 햅틱+애니메이션 추가.

## Requirements

### Functional

1. Today 탭의 카드를 VitalCard로 교체 (sparkline + baseline 배지 모두 지원)
2. 섹션 헤더를 SectionGroup으로 교체 (아이콘+제목+색상)
3. 섹션을 의미 기반으로 재그룹: Pinned → Condition → Activity → Body
4. VitalCard 탭 시 햅틱 피드백
5. 카드 등장 시 staggered 애니메이션

### Non-functional

- 기존 기능 회귀 없음 (핀카드 편집, 코칭, baseline 추세, 신선도 라벨)
- ViewModel에 SwiftUI import 금지 유지
- iPhone/iPad 레이아웃 안정성 유지

## Approach

VitalCard를 확장하여 Today와 Wellness 양쪽에서 사용하고, MetricCardView + SmartCardGrid를 제거하는 **컴포넌트 통합** 방식.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| VitalCard 확장 (baseline 추가) | 단일 컴포넌트, DRY | VitalCard 책임 약간 증가 | **채택** |
| 새 UnifiedCard 생성 | 깨끗한 설계 | 기존 VitalCard 유지 비용 | 기각 |
| MetricCardView에 sparkline 추가 | Today 변경 최소 | Wellness와 이중 컴포넌트 유지 | 기각 |

## Affected Files

### 신규 생성

없음 (기존 컴포넌트 확장으로 해결)

### 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `Presentation/Shared/Models/VitalCardData.swift` | Minor | `baselineDetail: BaselineDetail?`, `inversePolarity: Bool` 필드 추가 |
| `Presentation/Wellness/Components/VitalCard.swift` | Medium | baseline 배지 렌더링, 햅틱 피드백, staggered 애니메이션 지원 추가 |
| `Presentation/Dashboard/DashboardViewModel.swift` | Medium | `HealthMetric` → `VitalCardData` 변환 로직 추가, 섹션 재그룹 |
| `Presentation/Dashboard/DashboardView.swift` | Major | SmartCardGrid → LazyVGrid + VitalCard, 섹션 SectionGroup 교체 |
| `Presentation/Wellness/WellnessViewModel.swift` | Minor | `buildCard()`에서 `freshnessLabel` 통합 |
| `Presentation/Wellness/WellnessView.swift` | Minor | staleLabel → freshnessLabel 통합 (VitalCard 내부에서 처리) |
| `DailveTests/DashboardViewModelTests.swift` | Medium | VitalCardData 변환 테스트 추가 |

### 삭제

| File | Reason |
|------|--------|
| `Presentation/Dashboard/Components/MetricCardView.swift` | VitalCard로 완전 대체 |
| `Presentation/Shared/Components/SmartCardGrid.swift` | LazyVGrid로 교체 |

## Implementation Steps

### Step 1: VitalCardData 스키마 확장

- **Files**: `VitalCardData.swift`
- **Changes**:
  - `baselineDetail: BaselineDetail?` 필드 추가 (nil이면 미표시)
  - `inversePolarity: Bool` 필드 추가 (기본값 false)
  - `Hashable` 구현에 두 필드 반영 (#26: == 와 hash 일치 필수)
- **Verification**:
  - 기존 Wellness VitalCardData 생성 코드 컴파일 확인 (기본값으로 호환)
  - Hashable 일관성

### Step 2: VitalCard 확장 (baseline + 햅틱 + 애니메이션)

- **Files**: `VitalCard.swift`
- **Changes**:
  - sparkline 위에 `BaselineTrendBadge` 조건부 렌더링 추가:
    ```
    if let detail = data.baselineDetail {
        BaselineTrendBadge(detail: detail, inversePolarity: data.inversePolarity)
    }
    ```
  - 신선도 라벨: `data.isStale` 분기 내부에서 `data.lastUpdated.freshnessLabel` 사용 (기존 커스텀 staleLabel 교체)
  - 햅틱 피드백: NavigationLink 래핑 레벨에서 `.sensoryFeedback(.impact(weight: .light), trigger:)` 적용
    - 단, VitalCard는 NavigationLink를 포함하지 않으므로, 호출처(DashboardView, WellnessView)에서 적용
  - staggered 애니메이션: VitalCard에 `animationIndex: Int` 파라미터 추가, `.opacity` + `.offset(y: 8)` transition with delay
- **Verification**:
  - Wellness 탭 회귀 없음 (baselineDetail nil이면 기존 동작)
  - 오래된 데이터 opacity 통일 (0.6)

### Step 3: DashboardViewModel 데이터 변환 추가

- **Files**: `DashboardViewModel.swift`
- **Changes**:
  - `sortedMetrics` 대신 `[VitalCardData]` 기반 출력 추가:
    - `pinnedCards: [VitalCardData]`
    - `conditionCards: [VitalCardData]` (HRV, RHR)
    - `activityCards: [VitalCardData]` (Steps, Exercise)
    - `bodyCards: [VitalCardData]` (Weight, BMI, Sleep)
  - `buildVitalCardData(from metric: HealthMetric) -> VitalCardData` 변환 메서드 추가:
    - WellnessViewModel의 `buildCard()` 패턴 참고
    - `baselineDetail`: `baselineDeltasByMetricID[metric.id]?.preferredDetail`
    - `inversePolarity`: `metric.category == .rhr`
    - `sparklineData`: 각 메트릭의 7일 데이터 (이미 fetch 중인 데이터 활용)
    - `isStale`: `metric.date.daysAgo >= 3`
  - 섹션 분류 로직 변경:
    - `conditionCategories: Set = [.hrv, .rhr]`
    - `activityCategories: Set = [.steps, .exercise]`
    - `bodyCategories: Set = [.weight, .bmi, .sleep]`
    - pinned에 포함된 메트릭은 하위 섹션에서 제외 (기존 동작 유지)
  - `invalidateFilteredMetrics()` 리팩터: VitalCardData 배열로 출력
- **Verification**:
  - 기존 baseline 계산/코칭/핀카드 로직 회귀 없음
  - 빈 섹션 처리 (`conditionCards.isEmpty`이면 섹션 미표시)
  - sparkline 데이터 2점 미만 시 빈 배열

### Step 4: DashboardView UI 교체

- **Files**: `DashboardView.swift`
- **Changes**:
  - SmartCardGrid 3곳 → LazyVGrid 2열 + VitalCard로 교체
  - 섹션 헤더 → SectionGroup으로 교체:
    ```
    SectionGroup("Pinned", systemImage: "pin.fill", iconColor: .accent) { ... }
    SectionGroup("Condition", systemImage: "heart.fill", iconColor: .red) { ... }
    SectionGroup("Activity", systemImage: "figure.run", iconColor: .green) { ... }
    SectionGroup("Body", systemImage: "bed.double.fill", iconColor: .blue) { ... }
    ```
  - Pinned 섹션의 Edit 버튼: SectionGroup 내부 또는 header trailing으로 배치
  - NavigationLink(value: card.metric) + VitalCard(data: card) 조합
  - 햅틱: `.sensoryFeedback(.impact(weight: .light), trigger:)` 적용
  - staggered 애니메이션:
    - ForEach 내 인덱스 기반 delay: `animation.delay(Double(index) * 0.05)`
    - `.transition(.opacity.combined(with: .move(edge: .bottom)))`
  - 빈 섹션 숨김: `if !viewModel.conditionCards.isEmpty { ... }`
  - 기존 `navigationDestination(for: HealthMetric.self)` 유지 (VitalCardData.metric 활용)
- **Verification**:
  - 핀카드 편집 flow 정상 동작
  - 메트릭 탭 → MetricDetailView 네비게이션 정상
  - Hero + Coaching + Pinned + 3개 섹션 레이아웃 확인
  - iPad 레이아웃 확인

### Step 5: Wellness 측 신선도 라벨 통합

- **Files**: `VitalCard.swift`, `WellnessViewModel.swift`
- **Changes**:
  - VitalCard의 staleLabel 계산을 `lastUpdated.freshnessLabel`로 교체
  - WellnessViewModel의 `isStale` 계산을 `daysAgo >= 3`으로 통일 (이미 동일할 수 있음 확인)
  - VitalCard 내 stale 표시 opacity를 0.6으로 통일
- **Verification**:
  - Wellness 탭 신선도 표시 회귀 없음
  - "Today" / "Yesterday" / "3d ago" 라벨 정확성

### Step 6: Dead code 삭제 + 테스트

- **Files**: `MetricCardView.swift` (삭제), `SmartCardGrid.swift` (삭제), `DashboardViewModelTests.swift`
- **Changes**:
  - MetricCardView.swift 파일 삭제
  - SmartCardGrid.swift 파일 삭제
  - xcodegen 재생성 (`cd Dailve && xcodegen generate`)
  - DashboardViewModelTests에 추가:
    - `buildVitalCardData` 변환 정확성 (sparkline, baseline, inversePolarity)
    - 섹션 분류 정확성 (condition/activity/body)
    - pinned 메트릭이 하위 섹션에서 제외되는지
    - 빈 입력 시 빈 배열 반환
- **Verification**:
  - 빌드 성공 (`scripts/build-ios.sh`)
  - 기존 테스트 회귀 없음
  - 새 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| Sparkline 데이터 2점 미만 | VitalCard 기존 동작: 대시 플레이스홀더 |
| Baseline 없는 메트릭 (Weight, BMI) | baselineDetail = nil → 배지 미표시 |
| 핀 메트릭이 섹션과 중복 | pinned에 표시된 메트릭은 하단 섹션에서 제외 |
| 모든 카드가 pinned | 하단 3개 섹션 모두 빈 → 섹션 미표시 |
| iPad 레이아웃 | 2열 고정 (Wellness와 동일) |
| staggered 애니메이션 카드 수 많을 때 | 최대 delay cap (예: 6개 이상이면 동일 delay) |

## Testing Strategy

- **Unit tests**:
  - `DashboardViewModelTests`: VitalCardData 변환, 섹션 분류, pinned 제외 로직
  - 기존 baseline/coaching 테스트 회귀 확인
- **Manual verification**:
  - Today/Wellness 탭 간 카드 스타일 일관성
  - 핀카드 편집 → 저장 → 즉시 반영
  - 카드 탭 → MetricDetailView 네비게이션
  - 카드 등장 staggered 애니메이션
  - 카드 탭 햅틱 피드백
  - iPhone/iPad 레이아웃
  - 데이터 없는 상태, 부분 실패 상태

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SmartCardGrid 삭제 시 contextMenu 기능 손실 | Medium | Low | LazyVGrid 내 NavigationLink에 .contextMenu 재적용 |
| DashboardViewModel 비대화 | Low | Medium | buildVitalCardData를 private extension으로 분리 |
| Sparkline 데이터 부족으로 Today 카드 빈 차트 | Medium | Low | 대시 플레이스홀더로 graceful fallback (기존 VitalCard 동작) |
| staggered 애니메이션이 데이터 로딩 후 재트리거 | Medium | Medium | `.task` 완료 후 1회만 트리거 (flag 기반) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: VitalCard와 SectionGroup은 Wellness에서 검증된 컴포넌트이며, MetricCardView 사용처가 SmartCardGrid 1곳으로 국한되어 교체 범위가 명확합니다. DashboardViewModel의 변환 로직은 WellnessViewModel의 buildCard() 패턴을 재사용할 수 있습니다.
