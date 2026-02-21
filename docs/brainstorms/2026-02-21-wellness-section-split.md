---
tags: [wellness, healthkit, ui-sections, body-composition, vitals]
date: 2026-02-21
category: brainstorm
status: draft
---

# Brainstorm: Wellness 탭 섹션 분리 + HealthKit 데이터 확장

## Problem Statement

현재 Wellness 탭은 모든 vital card를 **하나의 flat 2-column grid**에 표시한다. 신체 구성(Weight, BMI)과 활성 지표(HRV, HR Recovery 등)가 혼재되어 있어 정보 탐색이 비효율적이다. 또한 HealthKit에서 가져올 수 있는 Heart Rate, Lean Body Mass, Body Fat 카드가 누락되어 있다.

## Target Users

- 운동하는 사람이 자신의 건강 지표를 한눈에 확인
- Physical 지표(체격 변화)와 Active 지표(컨디션/심폐 기능)를 구분하여 관심사별 탐색

## Success Criteria

1. Wellness 탭이 **Physical** / **Active Indicators** 두 섹션으로 시각적 구분
2. 각 섹션이 둥근 배경 카드로 그룹화되어 시각적 분리 강화
3. 새 카드 추가: Heart Rate, Lean Body Mass, Body Fat (sparkline 포함)
4. 기존 카드 기능/동작 100% 유지 (regression 없음)

## Proposed Approach

### 1. 섹션 분류

| Section | Cards | 비고 |
|---------|-------|------|
| **Physical** | Weight, BMI, Body Fat, Lean Body Mass | 체격/신체 구성 지표 |
| **Active Indicators** | Sleep, HRV, Resting HR, Heart Rate, SpO2, Respiratory Rate, VO2 Max, HR Recovery, Wrist Temp | 컨디션/심폐 기능 지표 |

### 2. 새 HealthKit 데이터

| 데이터 | 현재 상태 | 필요 작업 |
|--------|----------|----------|
| **Heart Rate** | `HeartRateQueryService` 존재하나 workout-only (forWorkoutID:) | Daily average/latest HR 메서드 추가 필요. `HKQuantityTypeIdentifier.heartRate` 일반 쿼리 |
| **Lean Body Mass** | `BodyCompositionQuerying.fetchLeanBodyMass(days:)` 이미 존재 | 카드 빌드 로직만 추가 |
| **Body Fat** | `BodyCompositionQuerying.fetchBodyFat(days:)` 존재, `latestBodyFat` fetch 중이나 카드 미노출 | 카드 빌드 로직 + sparkline history fetch 추가 |

### 3. UI 변경

- 현재: 단일 `LazyVGrid` → 모든 카드 flat
- 변경: 섹션별 `StandardCard` (또는 신규 그룹 컨테이너)로 감싸서 시각적 구분
- 각 그룹 내부는 기존 2-column `LazyVGrid` 유지
- 섹션 헤더: 아이콘 + 텍스트 (예: "Physical", "Active Indicators")

### 4. 구현 변경 범위

#### Domain Layer
- `HealthMetric.Category`에 `heartRate`, `bodyFat`, `leanBodyMass` case 추가

#### Data Layer
- `HeartRateQueryService` 또는 `VitalsQueryService`에 daily heart rate 쿼리 메서드 추가
  - `fetchLatestHeartRate(withinDays:)` — 최신 RHR 아닌 일반 HR
  - `fetchHeartRateHistory(days:)` — sparkline용
- `BodyCompositionQuerying`에 `fetchLatestBodyFat(withinDays:)`, `fetchLatestLeanBodyMass(withinDays:)` 추가

#### Presentation Layer
- `VitalCardData`에 `section: CardSection` 프로퍼티 추가 (`.physical` / `.active`)
- `WellnessViewModel`:
  - `FetchKey`에 `.heartRate`, `.heartRateHistory`, `.leanBodyMass`, `.bodyFatHistory` 추가
  - `FetchResults`에 대응 프로퍼티 추가
  - `performLoad()`에서 Heart Rate, Lean Body Mass, Body Fat 카드 빌드 추가
  - `vitalCards` 대신 `physicalCards` + `activeCards` 두 배열로 분리 (또는 section 기반 그룹핑)
- `WellnessView`:
  - 단일 grid → 두 섹션 그룹 (각각 `StandardCard` 래핑 + 내부 `LazyVGrid`)

## Constraints

- **HealthKit 가용성**: Heart Rate average는 수면 중 자동 측정이 아니므로 워크아웃/일상 측정 의존. 데이터 없을 수 있음
- **기존 UI 유지**: VitalCard 컴포넌트 자체는 변경 없음. 레이아웃 구조만 변경
- **Correction Log 준수**: #22(HealthKit 값 범위 검증), #70(.clipped()), #80(formatter 캐싱) 등

## Edge Cases

- 한 섹션의 카드가 모두 데이터 없음 → 해당 섹션 자체를 숨김 (empty section 방지)
- Physical 데이터만 있고 Active 없음 (또는 반대) → 있는 섹션만 표시
- Heart Rate가 300+bpm 또는 20-bpm → 기존 HR 범위 검증(20-300) 적용
- Lean Body Mass 음수/비현실적 값 → 0-300kg 범위 검증

## Scope

### MVP (Must-have)
- Physical / Active 2-섹션 분리 (둥근 카드 그룹)
- Heart Rate 카드 추가 (daily latest + sparkline)
- Body Fat 카드 노출 (이미 fetch 중, 카드 빌드만)
- Lean Body Mass 카드 추가
- Heart Rate Zones 시각화
- Body Fat 변화 추세선 (trend line)

### Nice-to-have (Future)
- 섹션 접기/펼치기 토글
- 카드 순서 사용자 커스터마이즈

## Open Questions

- ~~섹션 내 카드 정렬 기준: 현재 recency 기반 → 섹션 내에서도 동일?~~ → 예, 섹션 내 recency 정렬 유지
- Heart Rate 쿼리: `HeartRateQueryService` 확장 vs `VitalsQueryService`에 추가? → 기존 서비스 역할 분리 유지하면 `HeartRateQueryService` 확장이 적절

## Next Steps

- [ ] `/plan wellness-section-split` 으로 구현 계획 생성
