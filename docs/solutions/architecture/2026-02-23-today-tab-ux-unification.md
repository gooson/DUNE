---
tags: [swiftui, vitalcard, dashboard, ux-unification, lazyvgrid, fraction-digits, pinned-metrics]
date: 2026-02-23
category: architecture
status: implemented
---

# Today 탭 UX 통일 — VitalCard + LazyVGrid 전환

## Problem

Today 탭이 `MetricCardView` + `SmartCardGrid` 조합을 사용하고 Wellness 탭은 `VitalCard` + `LazyVGrid`를 사용하여 동일 데이터가 다른 UI로 표시되었음. 카드 숫자 포맷도 Steps에 소수점(`-13,067.0`)이 표시되는 등 카테고리별 구분 없이 `fractionDigits: 1`을 일괄 적용하는 문제가 있었음.

## Solution

### 1. VitalCard 통일
- `MetricCardView.swift`, `SmartCardGrid.swift` 삭제
- `DashboardView`에서 `VitalCard` + `LazyVGrid` 직접 사용
- `DashboardViewModel`에 `buildVitalCardData(from:)` 메서드 추가하여 `HealthMetric` → `VitalCardData` 변환
- 카드를 `pinnedCards`, `conditionCards`, `activityCards`, `bodyCards`로 분류

### 2. 카테고리별 fractionDigits
- `HealthMetric+View.swift`에 `changeFractionDigits` computed property 추가
- Weight/BMI/BodyFat 등은 `1`, Steps/HRV/RHR 등은 `0`
- `BaselineDetail`에 `fractionDigits` 필드 추가
- `DashboardViewModel`과 `WellnessViewModel` 모두 `metric.changeFractionDigits`를 참조 (DRY)

### 3. Hashable 일관성
- `VitalCardData.==`/`hash`에 `baselineDetail`과 `inversePolarity` 포함
- Correction #26 준수

### 주요 변경 파일
| 파일 | 변경 |
|------|------|
| `DashboardView.swift` | VitalCard + LazyVGrid + contextMenu + reduceMotion |
| `DashboardViewModel.swift` | buildVitalCardData, 카드 분류, dead code 제거 |
| `HealthMetric+View.swift` | changeFractionDigits (exhaustive switch) |
| `MetricBaselineDelta.swift` | BaselineDetail.fractionDigits 추가 |
| `BaselineTrendBadge.swift` | detail.fractionDigits 사용 |
| `VitalCardData.swift` | Hashable 필드 확장 |
| `WellnessViewModel.swift` | metric.changeFractionDigits 위임 |
| `VitalCard.swift` | inversePolarity, baselineDetail 지원 |

## Prevention

1. **숫자 포맷은 항상 카테고리 기반**: `formattedWithSeparator(fractionDigits:)`에 하드코딩 금지. `metric.changeFractionDigits` 경유
2. **fractionDigits 로직은 단일 소스**: `HealthMetric+View.changeFractionDigits`만 수정. ViewModel에 inline switch 금지
3. **Hashable 필드 추가 시 ==와 hash 동시 업데이트**: Correction #26
4. **SmartCardGrid 삭제 시 contextMenu/reduceMotion 이관 확인**: 기능 삭제 시 체크리스트

## Lessons Learned

1. `TodayPinnedMetricsStore.load()`는 빈 배열 저장 시 fallback `[.hrv, .rhr, .sleep]`을 반환함 — 테스트에서 "피닝 없음"을 원하면 `makePinnedStore([.weight])` 같은 비충돌 카테고리 사용
2. UI 컴포넌트 삭제 시 `.contextMenu`, `.hoverEffect`, `.accessibilityReduceMotion` 등 부가 기능이 같이 사라지므로 기능 이관 체크리스트 필수
3. 동일 로직이 2곳에 있으면 리뷰에서 5명 모두 지적함 — 처음부터 DRY 적용이 효율적
