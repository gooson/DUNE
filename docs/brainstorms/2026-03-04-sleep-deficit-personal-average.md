---
tags: [sleep, deficit, personal-average, wellness, healthkit]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 수면 부족 분석 개인화 (평균 수면시간 대비)

## Problem Statement

현재 수면 분석은 고정 기준(7-9h ideal)으로만 평가하고, 코칭은 급성 부족(<6h)만 감지한다.
사용자의 실제 수면 패턴을 반영하지 못하므로:
- 평소 6.5h 자는 사용자에게 항상 "부족" 판정
- 평소 8.5h 자는 사용자가 7h 잤을 때 부족을 감지 못함
- 누적 수면 부채(sleep debt) 개념이 없어 회복 필요성을 알 수 없음

**개선**: 14일/90일 이중 기준 개인 평균을 계산하고, 이를 기반으로 수면 부족을 분석한다.

## Target Users

- 자신의 수면 패턴을 이해하고 싶은 건강 관심 사용자
- 수면 부족이 누적되는지 추적하고 싶은 사용자
- Today 탭에서 오늘의 컨디션에 수면 부채가 어떻게 영향을 미치는지 알고 싶은 사용자

## Success Criteria

1. 14일/90일 개인 평균 수면시간이 정확히 계산됨
2. 누적 수면 부채가 일 단위로 추적됨 (최근 7일 기준)
3. Sleep 화면에 수면 부채 섹션이 표시됨
4. Today 탭 수면 평가에 부채 정보가 반영됨
5. 기존 수면 점수(SleepScore)는 변경 없음

## Proposed Approach

### 이중 기준선 (Dual Baseline)

| 기간 | 용도 | 계산 |
|------|------|------|
| **14일 단기 평균** | 최근 패턴 파악, deficit 계산 기준 | 최근 14일 수면시간 평균 |
| **90일 장기 평균** | 기저선(baseline), 단기 변화 대비 참조 | 최근 90일 수면시간 평균 |

### 수면 부채(Deficit) 계산

```
일별 부족 = 14일 평균 - 실제 수면시간
주간 누적 부채 = sum(최근 7일 일별 부족) // 양수만 합산 (초과 수면은 부채 상환)
```

- **부채 상환 규칙**: 초과 수면은 당일 부채를 0으로 만들 수 있지만, 과거 부채를 소급 상환하지 않음
- **부채 표시**: 시간:분 형식 (예: "2h 30m 부족")

### 부채 수준 분류

| 수준 | 7일 누적 부채 | UI 표시 |
|------|--------------|---------|
| Good | < 2h | 녹색, "수면 충분" |
| Mild | 2-5h | 노란색, "약간 부족" |
| Moderate | 5-10h | 주황색, "수면 부채 누적" |
| Severe | > 10h | 빨간색, "심각한 수면 부족" |

### 아키텍처

```
Domain/UseCases/
  CalculateSleepDeficitUseCase.swift   -- NEW: 부채 계산 로직

Domain/Models/
  SleepDeficitAnalysis.swift           -- NEW: 결과 모델

Data/HealthKit/
  SleepQueryService.swift              -- MODIFY: 14일/90일 데이터 fetch 메서드 추가

Presentation/Sleep/
  SleepViewModel.swift                 -- MODIFY: deficit 로드 + 캐싱
  SleepDeficitSection.swift            -- NEW: 부채 표시 UI

Presentation/Dashboard/ (Today)
  DashboardViewModel.swift             -- MODIFY: deficit 요약 전달
```

## Constraints

### 기술적 제약
- HealthKit 90일 수면 데이터 쿼리 성능: TaskGroup 병렬화 필수
- HealthKit 수면 데이터 없는 날 처리 (여행, 센서 미착용)
- Watch 소스 vs iPhone 소스 중복 제거는 기존 로직 활용

### 프로젝트 규칙 준수
- Correction #115: Fetch window >= filter threshold x 2
- Correction #25: 4+ async let 시 partial failure 보고
- Correction #114: 통계 파라미터 변경 시 3+개 실데이터 시나리오 검증
- Layer boundaries: UseCase는 HealthKit 직접 접근 금지 → SleepQueryService 경유

### 범위 제약
- 기존 SleepScore 로직 변경 없음 (7-9h ideal 유지)
- 사용자 수면 목표 설정 UI는 MVP 미포함

## Edge Cases

1. **데이터 부족**: 14일 중 3일 미만 데이터 → "데이터 수집 중" 표시, 부채 미계산
2. **90일 데이터 부족**: 14일은 충분하지만 90일 부족 → 14일 평균만 사용, 장기 비교 생략
3. **극단적 수면 패턴**: 평균이 4h 미만 또는 12h 초과 → 의학적 권장(7-9h) clamp 경고 표시
4. **0분 수면일**: HealthKit에 수면 데이터 없는 날 → 평균 계산에서 제외 (미착용 추정)
5. **시간대 변경/여행**: HealthKit이 UTC 기준 처리 → 기존 SleepQueryService 로직 의존
6. **이전 기기 데이터**: 새 기기 설정 후 HealthKit 동기화 지연 → graceful fallback

## Scope

### MVP (Must-have)
- 14일/90일 평균 수면시간 계산 UseCase
- SleepDeficitAnalysis 도메인 모델
- 7일 누적 부채 계산
- Sleep 화면에 부채 섹션 추가 (평균 대비 차이, 부채 수준)
- Today 탭 수면 평가에 부채 요약 연동
- 유닛 테스트 (UseCase 모든 분기)

### Nice-to-have (Future)
- 수면 부채 트렌드 차트 (주간 부채 추이)
- 코칭 메시지 부채 기반 개인화 ("3일 연속 부족, 오늘 30분 일찍 취침 권장")
- 수면 목표 설정 UI (사용자가 직접 목표 수면시간 설정)
- 수면 점수에 개인 평균 반영 (ideal range 개인화)
- watchOS 수면 부채 요약 표시
- 수면 부채 회복 예측 ("현재 속도로 3일 후 정상화")

## Open Questions

1. **0분 수면일 처리**: 센서 미착용 vs 실제 불면 구분이 불가 → 평균 계산에서 제외가 맞는지?
2. **초과 수면 상환 한도**: 초과분이 당일 부채만 상환? 아니면 이전일 부채도 부분 상환?
3. **Today 탭 표시 형태**: 숫자만? 게이지? 텍스트 코멘트?

## Next Steps

- [ ] `/plan sleep-deficit-personal-average` 로 구현 계획 생성
