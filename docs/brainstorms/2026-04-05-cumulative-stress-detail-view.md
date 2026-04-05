---
tags: [dashboard, stress, detail-view, chart, explainer]
date: 2026-04-05
category: brainstorm
status: draft
---

# Brainstorm: 장기 스트레스 상세 화면

## Problem Statement

투데이 탭의 `CumulativeStressCard`는 30일 스트레스 점수를 요약 표시하지만:

1. **설명 부재**: 사용자가 "장기 스트레스 점수"가 무엇인지, 어떻게 계산되는지 이해할 수 없음
2. **상세 화면 부재**: 카드가 탭 불가 — 기여 요소 분석, 트렌드 차트, 개선 가이드가 없음
3. **히스토리 부재**: `CumulativeStressScore`가 SwiftData에 저장되지 않아 과거 추이를 볼 수 없음

ConditionScore, WellnessScore, TrainingReadiness는 모두 상세 화면이 있으나 CumulativeStress만 빠져 있는 상태.

## Target Users

- 건강/피트니스를 모니터링하는 일반 사용자
- "내 스트레스가 왜 높은지", "어떻게 낮출 수 있는지" 알고 싶은 사용자
- HRV, 수면, 운동량의 상호작용을 이해하고 싶은 사용자

## Success Criteria

- 카드 탭 → 상세 화면 진입 (NavigationLink)
- 상세 화면에서 스트레스가 무엇인지 설명
- 3개 기여 요소(HRV/수면/활동) 각각의 상세 점수와 의미 표시
- 과거 추이 차트 (최소 7일, 최대 30일)
- 레벨별 의미와 개선 가이드 제공

## Current State Analysis

### 있는 것
| 항목 | 위치 | 상태 |
|------|------|------|
| `CumulativeStressScore` 모델 | `Domain/Models/` | 완성 (score, level, contributions, trend) |
| `CalculateCumulativeStressUseCase` | `Domain/UseCases/` | 완성 (HRV 40% + 수면 35% + 활동 25%) |
| `CumulativeStressCard` | `Dashboard/Components/` | 완성 (요약 카드, 탭 불가) |
| `CumulativeStressScore+View` | `Shared/Extensions/` | 완성 (color, iconName) |
| 유닛 테스트 | `DUNETests/` | `CalculateCumulativeStressUseCaseTests` 존재 |

### 없는 것
| 항목 | 필요 여부 | 비고 |
|------|----------|------|
| 상세 화면 (DetailView + ViewModel) | **필수** | ConditionScoreDetailView 패턴 참조 |
| 히스토리 저장 | **필수** | HourlyScoreSnapshot에 stressScore 필드 추가 또는 별도 저장 |
| Info/Explainer 섹션 | **필수** | 3개 기여 요소 설명 + 레벨별 의미 |
| 카드 → 상세 NavigationLink | **필수** | DashboardView에서 연결 |
| 기간 차트 데이터 로더 | **필수** | 7d/14d/30d 기간별 히스토리 조회 |

## Proposed Approach

### Phase 1: 히스토리 저장 (데이터 기반)

**Option A: HourlyScoreSnapshot 확장** (권장)
- `HourlyScoreSnapshot`에 `stressScore: Double?` 필드 추가
- 기존 `ScoreRefreshService`가 스트레스도 함께 저장
- 장점: 기존 인프라 재사용, VersionedSchema migration 1회
- 단점: HourlyScoreSnapshot이 점점 비대해짐

**Option B: 별도 DailyStressSnapshot 모델**
- 스트레스는 시간별이 아닌 일별 변동이므로 별도 모델이 의미론적으로 적합
- 장점: 관심사 분리, 일별 granularity 명확
- 단점: 새 @Model + migration + 저장 로직 추가 비용

→ **Option A 권장**: 30일 윈도우지만 일일 1회 저장이면 충분. HourlyScoreSnapshot의 특정 시간대(예: 오전 계산 시점)에 기록.

### Phase 2: 상세 화면 (ConditionScoreDetailView 패턴)

ConditionScoreDetailView의 canonical layout을 따르되 스트레스에 맞게 조정:

```
1. Hero Section
   - DetailScoreHero (점수 링 + 레벨 라벨)
   - 스트레스 전용 색상 (low=green → high=red)

2. Explainer Section (신규)
   - "장기 스트레스란?" 설명
   - HRV 변동성, 수면 일관성, 운동 부하의 상호작용 설명
   - ConditionExplainerSection 패턴 참조

3. Contribution Breakdown
   - 3개 기여 요소 각각의 상세 카드
   - 각 요소: 점수 바 + 가중치 표시 + 상세 설명
   - ScoreContributorsView 재사용 또는 확장

4. Level Guide
   - 4단계 레벨(Low/Moderate/Elevated/High) 각각의 의미
   - 현재 레벨 하이라이트
   - 레벨별 조언 (예: "Elevated → 수면 일관성 개선과 회복일 추가 권장")

5. Period Picker + Trend Chart
   - 7d / 14d / 30d 기간 선택
   - DotLineChart로 일별 스트레스 점수 추이
   - 레벨 구간 배경색 (0-30 초록, 30-55 노랑, 55-75 주황, 75-100 빨강)

6. Summary Stats
   - 기간 평균, 최고, 최저, 변동폭
   - ScoreDetailSummaryStats 패턴 재사용

7. Highlights
   - "이번 주 스트레스 15% 감소"
   - "수면 일관성이 가장 큰 개선 요소"
   - ScoreDetailHighlights 패턴 재사용

8. Calculation Method Card
   - 가중치 시각화 (HRV 40%, 수면 35%, 활동 25%)
   - 각 요소의 계산 방식 간략 설명
   - CalculationMethodCard / ConditionCalculationCard 패턴 참조
```

### Phase 3: 카드 → 상세 연결

- `CumulativeStressCard`를 `NavigationLink`로 감싸기
- `DashboardView`에 `.navigationDestination(for:)` 추가
- 또는 기존 `ActivityDetailDestination` 패턴처럼 enum value 기반 라우팅

## Constraints

### 기술적
- `HourlyScoreSnapshot` 필드 추가 시 새 `VersionedSchema` + migration 필요
- 스트레스 계산에 최소 7일 HRV 데이터 필요 → 차트 초기에는 데이터 부족 가능
- CloudKit 동기화 대상이므로 @Model 변경에 신중해야 함

### UX
- ConditionScore와 시각적 일관성 유지 (canonical detail layout)
- 스트레스는 "높을수록 나쁨" — 색상/방향 반전 주의 (Condition은 높을수록 좋음)
- 빈 상태(데이터 부족) 처리 필수

## Edge Cases

| 케이스 | 처리 방안 |
|--------|----------|
| HRV 데이터 7일 미만 | 차트 대신 데이터 수집 안내 표시 |
| 수면 데이터 없음 | HRV + 활동만으로 계산 (가중치 재배분), 수면 섹션은 "데이터 없음" 표시 |
| 활동 데이터 없음 | HRV + 수면만으로 계산, 활동 섹션은 "데이터 없음" 표시 |
| 히스토리 1일만 존재 | 차트 비표시, 점수만 표시 |
| 점수가 급격히 변동 | trend = .volatile 시 "변동이 큼" 메시지 |

## Scope

### MVP (Must-have)
- [ ] `HourlyScoreSnapshot`에 `stressScore` 필드 추가 + migration
- [ ] `ScoreRefreshService`에서 스트레스 점수 저장 로직 추가
- [ ] `CumulativeStressDetailView` + `CumulativeStressDetailViewModel` 생성
- [ ] Hero + Explainer + Contribution Breakdown + Level Guide
- [ ] Period Picker + DotLineChart (7d/14d/30d)
- [ ] Summary Stats
- [ ] `CumulativeStressCard` → NavigationLink 연결
- [ ] 빈 상태 처리
- [ ] 유닛 테스트 (ViewModel)
- [ ] 다국어 (en/ko/ja)

### Nice-to-have (Future)
- [ ] Highlights (자동 인사이트 생성)
- [ ] Calculation Method Card (가중치 시각화)
- [ ] 기여 요소별 개별 트렌드 차트
- [ ] 스트레스 알림 (Elevated 이상 지속 시)
- [ ] Watch에서 간략 스트레스 표시
- [ ] 스트레스-수면 상관관계 분석 연동

## Open Questions

1. **히스토리 granularity**: 시간별 vs 일별? — 일별이면 HourlyScoreSnapshot보다 DailySnapshot이 적합할 수 있음
2. **차트 레벨 구간 배경색**: 다른 차트와의 시각적 일관성? ConditionScore 차트에는 없는 패턴
3. **Explainer 텍스트 분량**: 간결한 2-3문장 vs 상세한 FAQ 스타일?
4. **스트레스 감소 조언**: 정적 텍스트 vs 현재 기여도 기반 동적 조언?

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (Phase 1~3 순서, 파일 목록, 테스트 계획)
