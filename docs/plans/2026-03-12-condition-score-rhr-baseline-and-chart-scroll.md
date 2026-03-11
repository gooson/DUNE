---
tags: [condition-score, rhr, baseline, dashboard, charts]
date: 2026-03-12
category: plan
status: approved
---

# Plan: Condition Score RHR Baseline 반영 및 상세 차트 Today Scroll 수정

## Context

컨디션 스코어는 HRV는 baseline-relative로 계산하지만 RHR는 전일 비교 기반 보정으로만 적용하고 있어,
Today hero 카드와 컨디션 상세의 기여요소/계산 방식 설명이 서로 다르게 보인다.
추가로 컨디션 상세 차트는 그래프는 오늘자 점을 그리면서도 스크롤 한계가 어제까지로 잡혀 오늘이 잘린다.

## Affected Files

| 파일 | 변경 | 영향도 |
|------|------|--------|
| `DUNE/Domain/Models/ConditionScore.swift` | RHR baseline-relative detail 필드와 narrative 규칙 조정 | High |
| `DUNE/Domain/UseCases/CalculateConditionScoreUseCase.swift` | RHR 보정식을 baseline-relative 연속값으로 교체 | High |
| `DUNE/Data/Services/SharedHealthDataServiceImpl.swift` | 최근 점수/스냅샷 계산에 RHR baseline 컨텍스트 전달 | High |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | hero/detail/chart용 RHR baseline data 연결 | High |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | chart scrollDomain을 오늘까지 확장 | Medium |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | scrollDomain 주입 및 RHR 설명 UI 반영 | Medium |
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift` | Today hero에 RHR 변화 표시 | Medium |
| `DUNE/Presentation/Shared/Components/ConditionCalculationCard.swift` | RHR 계산 방식 설명을 baseline-relative 기준으로 갱신 | Medium |
| `DUNETests/*ConditionScore*`, `DUNETests/*DashboardViewModel*` | 점수/기여요소/차트 회귀 테스트 추가 | High |

## Implementation Steps

### Step 1: RHR 계산식 정렬
- RHR를 전일 비교가 아닌 baseline-relative 편차로 정규화
- score contribution과 detail payload가 같은 RHR 근거를 공유하도록 통합
- historical score 계산에도 동일 로직이 적용되도록 sample-window 기반 RHR baseline 전달

### Step 2: Dashboard/Detail UI 반영
- Today hero 카드에서 RHR 변화가 baseline-relative badge 또는 설명으로 노출되게 조정
- Condition Score detail의 contributors와 calculation card가 새로운 RHR baseline 문구를 사용하도록 수정
- narrative/guide 문구가 최신 detail 필드와 일관되게 연결되도록 정리

### Step 3: Chart Today Scroll Fix
- Condition Score detail chart에 scrollDomain을 도입해 현재 period의 end-exclusive를 오늘까지 열어둠
- 주간/월간 스크롤에서 오늘 점이 잘리지 않는지 회귀 테스트 추가

## Test Strategy

- `CalculateConditionScoreUseCaseTests`에 baseline-relative RHR 가감점과 contributor 조건 검증 추가
- `DashboardViewModelTests` 또는 detail view model 테스트에 chart scrollDomain today 포함 회귀 추가
- `scripts/build-ios.sh --no-regen`
- 필요 시 `scripts/test-unit.sh --ios-only --no-stream-log`

## Risks

- historical score 계산에 RHR baseline window를 잘못 주입하면 기존 차트 값이 크게 변할 수 있음
- RHR inverse polarity를 hero badge에 반영할 때 HRV badge 스타일이 깨질 수 있음
- display fallback RHR와 scoring RHR를 다시 혼용하면 과거 해결한 누락/오표시가 재발할 수 있음
