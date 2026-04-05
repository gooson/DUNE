---
tags: [dashboard, stress, detail-view, chart, explainer, score-detail]
date: 2026-04-05
category: plan
status: draft
---

# Plan: 장기 스트레스 상세 화면 (ConditionScore급 Full)

## Overview

투데이 탭의 `CumulativeStressCard`에 탭 가능한 NavigationLink를 추가하고, ConditionScoreDetailView와 동일한 canonical layout의 상세 화면을 구현한다. 히스토리 저장을 위해 `HourlyScoreSnapshot`에 `stressScore` 필드를 추가한다.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Data/Persistence/Models/HourlyScoreSnapshot.swift` | MODIFY | `stressScore: Double?` 필드 추가 |
| `Data/Services/ScoreRefreshService.swift` | MODIFY | `stressScore` 파라미터 추가 + 저장 로직 |
| `Presentation/Dashboard/DashboardViewModel.swift` | MODIFY | recordSnapshot 호출에 stressScore 전달 |
| `Presentation/Dashboard/DashboardView.swift` | MODIFY | NavigationLink + navigationDestination 추가 |
| `Presentation/Dashboard/Components/CumulativeStressCard.swift` | MODIFY | chevron 힌트 추가 (선택적) |
| `Presentation/Dashboard/CumulativeStressDetailView.swift` | CREATE | 상세 화면 View |
| `Presentation/Dashboard/CumulativeStressDetailViewModel.swift` | CREATE | 상세 화면 ViewModel |
| `Presentation/Dashboard/Components/CumulativeStressExplainerSection.swift` | CREATE | 설명 섹션 |
| `Presentation/Dashboard/Components/CumulativeStressLevelGuide.swift` | CREATE | 레벨 가이드 |
| `Shared/Resources/Localizable.xcstrings` | MODIFY | en/ko/ja 번역 추가 |
| `DUNETests/CumulativeStressDetailViewModelTests.swift` | CREATE | ViewModel 유닛 테스트 |
| `DUNE.xcodeproj/project.pbxproj` | MODIFY | xcodegen 재생성 |

## Implementation Steps

### Step 1: HourlyScoreSnapshot에 stressScore 추가

- `HourlyScoreSnapshot.swift`에 `var stressScore: Double?` 필드 추가
- init 파라미터에 `stressScore: Double? = nil` 추가
- 자동 lightweight migration으로 처리 (additive optional field)

### Step 2: ScoreRefreshService에 stressScore 저장 로직 추가

- `recordSnapshot()` 시그니처에 `stressScore: Int? = nil` 파라미터 추가
- 기존 clamping 패턴 따라 `min(max($0, 0), 100)` 적용
- upsert 로직에 stressScore 필드 merge 추가

### Step 3: DashboardViewModel에서 stressScore 전달

- `recordSnapshot()` 호출부에 `stressScore: cumulativeStressScore?.score` 추가

### Step 4: CumulativeStressDetailViewModel 생성

- `@Observable @MainActor` 패턴 (ConditionScoreDetailViewModel 참조)
- Properties: selectedPeriod, chartData, summaryStats, highlights, isLoading
- `configure(stressScore:)` + `loadData()` async
- 기간별 데이터 로드: HourlyScoreSnapshot에서 stressScore 조회
- 하이라이트 계산 (평균/최고/최저/트렌드)

### Step 5: CumulativeStressExplainerSection 생성

- ConditionExplainerSection 패턴 참조
- 4개 항목: "What is Cumulative Stress?", "HRV Variability", "Sleep Consistency", "Activity Load"
- DisclosureGroup + 애니메이션

### Step 6: CumulativeStressLevelGuide 생성

- 4단계 레벨 (Low/Moderate/Elevated/High) 설명
- 현재 레벨 하이라이트 표시
- 레벨별 조언 텍스트

### Step 7: CumulativeStressDetailView 생성

Canonical layout 순서:
1. DetailScoreHero (점수 링 + 레벨)
2. Insight 메시지 (레벨 기반 코칭)
3. ScoreContributorsView (3개 기여 요소 — 기존 컴포넌트 재사용)
4. Level Guide (신규)
5. Period Picker (7d/14d/30d)
6. DotLineChartView (일별 추이)
7. ScoreDetailSummaryStats (평균/최고/최저)
8. ScoreDetailHighlights (인사이트)
9. CalculationMethodCard (가중치 설명)
10. Explainer Section (신규)

### Step 8: Dashboard NavigationLink 연결

- DashboardView에 `.navigationDestination(for: CumulativeStressScore.self)` 추가
- CumulativeStressCard를 `NavigationLink(value: stressScore)` 로 감싸기

### Step 9: 다국어 (xcstrings)

- 모든 새 문자열에 en/ko/ja 3개 언어 등록
- 레벨 displayName은 이미 localized

### Step 10: 유닛 테스트

- CumulativeStressDetailViewModel 테스트
- chartData 변환, summaryStats 계산, highlights 생성

## Test Strategy

- **Unit**: CumulativeStressDetailViewModelTests (chartData, stats, highlights)
- **Build**: scripts/build-ios.sh
- **Manual**: 시뮬레이터에서 Today → Stress Card 탭 → 상세 화면 진입 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| stressScore 히스토리 0일 | 차트 대신 EmptyState 표시 |
| HRV 7일 미만 (카드 자체가 nil) | 상세 화면 진입 불가 (카드가 안 보이므로 자연스러움) |
| 기간 전환 시 데이터 로딩 지연 | isLoading 상태 + skeleton |
| CloudKit migration | Additive optional field → lightweight auto-migration |

## Alternatives Considered

1. **별도 DailyStressSnapshot 모델**: 의미론적으로 더 정확하나, 추가 @Model + migration 비용이 높고, 기존 HourlyScoreSnapshot 확장으로 충분
2. **InfoSheet로 설명만 추가**: 사용자가 Full 상세 화면(차트 포함)을 원함
