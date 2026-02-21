---
tags: [wellness, section-split, health-metric, category, domain-boundary, exhaustive-switch, vital-card]
category: architecture
date: 2026-02-21
severity: important
related_files:
  - Dailve/Presentation/Shared/Models/VitalCardData.swift
  - Dailve/Presentation/Wellness/WellnessView.swift
  - Dailve/Presentation/Wellness/WellnessViewModel.swift
  - Dailve/Domain/Models/HealthMetric.swift
  - Dailve/Domain/Models/HeartRateZone.swift
  - Dailve/Presentation/Shared/Charts/HeartRateZoneChartView.swift
related_solutions:
  - architecture/2026-02-17-wellness-tab-body-composition
---

# Solution: Wellness Tab Section Split + New HealthMetric Category 추가 패턴

## Problem

### Symptoms

- Wellness 탭이 단일 그리드로 모든 카드를 나열하여 Physical(체중/BMI/체지방/제지방) 메트릭과 Active(HRV/RHR/수면/운동 등) 메트릭 구분 불가
- 새 HealthMetric.Category(heartRate, bodyFat, leanBodyMass) 추가 시 수정해야 하는 파일이 10곳 이상으로 분산되어 누락 위험

### Root Cause

1. `VitalCardData`에 section 개념이 없어 모든 카드가 동일한 그리드에 렌더
2. `HealthMetric.Category`에 새 case 추가 시 `switch` 문에 `default:`를 사용하면 컴파일 타임 검증 누락
3. Domain 모델에 UI 표시 문자열(label)을 넣는 레이어 경계 위반

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `HealthMetric.swift` | `.heartRate`, `.bodyFat`, `.leanBodyMass` case 추가 | 새 메트릭 지원 |
| `VitalCardData.swift` | `CardSection` enum + `section` 프로퍼티 추가 | 카드를 Physical/Active 섹션으로 분류 |
| `WellnessView.swift` | `WellnessSectionGroup`으로 2개 섹션 렌더 | UI 분리 |
| `WellnessViewModel.swift` | `physicalCards`/`activeCards` 분리 + 4개 새 fetch task 추가 | 데이터 소스 확장 |
| `HeartRateZone.swift` | Zone 모델 + Calculator (Domain) | HR zone 분석 |
| `HeartRateZoneChartView.swift` | Zone 차트 뷰 + `displayName`/`color` extension | UI 표시 (Presentation 레이어) |
| `HeartRateQueryService.swift` | `fetchLatestHeartRate`, `fetchHeartRateHistory`, `fetchHeartRateZones` | 비운동 HR 조회 |
| `BodyCompositionQueryService.swift` | `fetchLatestBodyFat`, `fetchLatestLeanBodyMass` | 체지방/제지방 조회 |

### Key Code

**1. CardSection — exhaustive switch (default 금지)**

```swift
enum CardSection: String, Sendable {
    case physical
    case active

    static func section(for category: HealthMetric.Category) -> CardSection {
        switch category {
        case .weight, .bmi, .bodyFat, .leanBodyMass:
            return .physical
        case .hrv, .rhr, .heartRate, .sleep, .exercise, .steps,
             .spo2, .respiratoryRate, .vo2Max, .heartRateRecovery, .wristTemperature:
            return .active
        }
    }
}
```

**2. Domain UI 문자열 분리 — displayName은 Presentation extension에**

```swift
// Domain (HeartRateZone.swift) — label 없음, 순수 데이터만
enum Zone: Int, CaseIterable, Sendable, Comparable {
    case zone1 = 1
    case zone2 = 2
    // ...
}

// Presentation (HeartRateZoneChartView.swift) — 표시명은 extension에
extension HeartRateZone.Zone {
    var displayName: String {
        switch self {
        case .zone1: "Recovery"
        case .zone2: "Fat Burn"
        // ...
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] 새 `HealthMetric.Category` case 추가 시 수정 필요 파일 체크리스트:
  1. `HealthMetric+View.swift` — formattedValue, color, iconName, displayName, unitLabel
  2. `MetricSummaryHeader.swift` — formatValue
  3. `MetricHighlightsView.swift` — formatHighlightValue
  4. `AllDataView.swift` — formatValue
  5. `AllDataViewModel.swift` — fetchPage switch
  6. `MetricDetailView.swift` — chartContent switch
  7. `MetricDetailViewModel.swift` — loadData switch + loadXxxData 함수
  8. `VitalCardData.swift` — CardSection.section(for:) exhaustive switch
  9. `WellnessViewModel.swift` — FetchKey + FetchValue + buildCards + fetchAllData TaskGroup
- [ ] `CardSection.section(for:)` switch에 `default:` 사용 금지 — exhaustive switch만 허용
- [ ] Domain 모델에 표시용 문자열(label, displayName) 금지 — Presentation extension 사용

## Lessons Learned

1. **새 enum case 추가의 파급 범위가 크다**: `HealthMetric.Category`에 case 하나 추가하면 10+ 파일의 switch 문 수정 필요. `default:` 사용 시 컴파일러가 누락을 잡아주지 않으므로 exhaustive switch 필수
2. **섹션 분류는 Presentation 레이어에서**: `CardSection`이 Domain의 `HealthMetric.Category`를 입력받지만, 분류 자체는 UI 관심사이므로 Presentation 모델에 배치하는 것이 적절
3. **ViewModel 프로퍼티 분할 시 원자성 고려**: `physicalCards`/`activeCards`를 순차 할당하면 이론적으로 중간 상태 렌더 가능. `@Observable` + `@MainActor` 동기 메서드 내에서는 같은 run loop tick에 배치되므로 실질 위험 낮지만 인지 필요
