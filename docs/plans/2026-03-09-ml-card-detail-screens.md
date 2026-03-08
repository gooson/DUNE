---
tags: [ml, injury-risk, sleep-prediction, weekly-report, detail-view, localization, foundation-models]
date: 2026-03-09
category: plan
status: draft
---

# Plan: ML 카드 상세화면 연동 + 다국어 완성

## Background

ML SDK로 계산된 3개 카드(Injury Risk, Weekly Report, Tonight's Sleep)가 Dashboard에 표시되지만:
1. **상세화면 없음**: 카드 탭 시 이동할 Detail View가 구현되지 않음
2. **다국어 누락**: 섹션 타이틀 "Injury Risk"/"Tonight's Sleep" xcstrings 키 누락 + Foundation Models 요약이 영어 전용

Brainstorm: `docs/brainstorms/2026-03-09-ml-card-detail-screens.md`

## Reference Solutions

- `docs/solutions/architecture/2026-02-23-activity-detail-navigation-pattern.md` — NavigationLink(value:) + ActivityDetailDestination enum + .buttonStyle(.plain)
- `docs/solutions/architecture/2026-03-08-on-device-prediction-features.md` — ML prediction architecture

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/Presentation/Activity/ActivityDetailDestination.swift` | Edit | `.injuryRisk`, `.weeklyReport` case 추가 |
| `DUNE/Presentation/Activity/ActivityView.swift` | Edit | NavigationLink 래핑 + activityDetailView switch case 추가 |
| `DUNE/Presentation/Activity/InjuryRiskDetail/InjuryRiskDetailView.swift` | New | Injury Risk 상세 화면 |
| `DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift` | New | Weekly Report 상세 화면 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | Edit | SleepPredictionDestination struct 추가 + NavigationLink + navigationDestination |
| `DUNE/Presentation/Wellness/SleepPredictionDetail/SleepPredictionDetailView.swift` | New | Tonight's Sleep 상세 화면 |
| `DUNE/Presentation/Shared/Extensions/InjuryRiskAssessment+View.swift` | New | FactorType displayName extension |
| `DUNE/Presentation/Shared/Extensions/SleepQualityPrediction+View.swift` | New | FactorType displayName extension |
| `DUNE/Data/Services/FoundationModelReportFormatter.swift` | Edit | locale-aware 프롬프트 |
| `Shared/Resources/Localizable.xcstrings` | Edit | 새 키 추가 (en/ko/ja) |
| `DUNE/DUNETests/InjuryRiskDetailViewModelTests.swift` | New | ViewModel 테스트 |
| `DUNE/DUNETests/SleepPredictionDetailViewModelTests.swift` | New | ViewModel 테스트 |

## Implementation Steps

### Step 1: Navigation 인프라 (ActivityDetailDestination + WellnessView)

1. `ActivityDetailDestination`에 `.injuryRisk`, `.weeklyReport` case 추가
2. `WellnessView.swift` 하단에 `struct SleepPredictionDestination: Hashable {}` 추가
3. `ActivityView.activityDetailView(for:)`에 새 case 핸들러 추가 (빈 placeholder view 우선)
4. `WellnessView`에 `.navigationDestination(for: SleepPredictionDestination.self)` 추가

**검증**: 빌드 통과

### Step 2: FactorType displayName Presentation extension

1. `InjuryRiskAssessment+View.swift` 생성 — FactorType에 `displayName`, `iconName` computed property
2. `SleepQualityPrediction+View.swift` 생성 — FactorType에 `displayName`, `iconName` computed property
3. 기존 카드의 `factorIcon()` / `impactIcon()` 헬퍼와 패턴 일관성 유지

**검증**: 빌드 통과

### Step 3: Injury Risk Detail View

**위치**: `DUNE/Presentation/Activity/InjuryRiskDetail/`

**구성**:
- `InjuryRiskDetailView.swift`: ScrollView + DetailWaveBackground
  - Hero: DetailScoreHero (score, level displayName, guideMessage)
  - 전체 Factor 목록 (6개): icon + displayName + contribution bar + detail
  - 권장 액션 섹션: 레벨별 구체적 안내 (rest, stretch, reduce volume 등)
- ViewModel 불필요 (데이터가 이미 계산됨, pass-through)

**Navigation 연결**:
- `ActivityView`에서 InjuryRiskCard를 `NavigationLink(value: ActivityDetailDestination.injuryRisk)` 래핑
- `activityDetailView(for: .injuryRisk)` → `InjuryRiskDetailView(assessment:)`

**검증**: 카드 탭 → 상세화면 이동 확인, 빌드 통과

### Step 4: Weekly Report Detail View

**위치**: `DUNE/Presentation/Activity/WorkoutReportDetail/`

**구성**:
- `WorkoutReportDetailView.swift`: ScrollView + DetailWaveBackground
  - 기간 표시 (period displayName)
  - 통계 그리드: sessions, activeDays, totalVolume, totalDuration, averageIntensity, volumeChange
  - 전체 ML 요약 텍스트 (Foundation Models/template, lineLimit 제거)
  - 전체 하이라이트 목록 (카드는 max 2)
  - 근육 그룹별 볼륨 breakdown (수평 바 차트)
- ViewModel 불필요 (WorkoutReport 데이터 pass-through)

**Navigation 연결**:
- `ActivityView`에서 WorkoutReportCard를 `NavigationLink(value: ActivityDetailDestination.weeklyReport)` 래핑
- `activityDetailView(for: .weeklyReport)` → `WorkoutReportDetailView(report:)`

**검증**: 카드 탭 → 상세화면, 빌드 통과

### Step 5: Tonight's Sleep Detail View

**위치**: `DUNE/Presentation/Wellness/SleepPredictionDetail/`

**구성**:
- `SleepPredictionDetailView.swift`: ScrollView + DetailWaveBackground (sleep 색상)
  - Hero: DetailScoreHero (score, outlook displayName, guideMessage) + confidence badge
  - 전체 Factor 목록 (5개): impact icon + displayName + detail
  - 전체 Tips 목록 (카드는 max 2)
- ViewModel 불필요 (SleepQualityPrediction 데이터 pass-through)

**Navigation 연결**:
- `WellnessView`에서 SleepPredictionCard를 `NavigationLink(value: SleepPredictionDestination())` 래핑
- `.navigationDestination(for: SleepPredictionDestination.self)` → `SleepPredictionDetailView(prediction:)`

**검증**: 카드 탭 → 상세화면, 빌드 통과

### Step 6: Foundation Models 다국어 프롬프트

`FoundationModelReportFormatter.buildPrompt(report:)` 수정:
- `Locale.current.language.languageCode?.identifier`로 현재 locale 확인
- ko: "다음 운동 데이터를 한국어로 2-3문장으로 요약해주세요."
- ja: "以下のワークアウトデータを日本語で2-3文にまとめてください。"
- en (default): 기존 영어 프롬프트 유지

**검증**: 시뮬레이터 locale 변경 후 요약 언어 확인 (실기 테스트 필요)

### Step 7: Localizable.xcstrings 업데이트

**누락 섹션 타이틀**:
- "Injury Risk" → ko: "부상 위험도", ja: "怪我リスク"
- "Tonight's Sleep" → ko: "오늘 밤 수면", ja: "今夜の睡眠"

**새 FactorType displayName 키**:
- InjuryRisk: "Muscle Fatigue", "Consecutive Training", "Volume Spike", "Sleep Deficit", "Active Injury", "Low Recovery"
- Sleep: "Recent Sleep Pattern", "Workout Effect", "HRV Trend", "Bedtime Consistency", "Condition Level"

**상세화면 UI 문자열**:
- "Recommended Actions", "Risk Factors", "All Factors", "All Tips", "Muscle Breakdown", "Highlights", "Statistics" 등
- 각 level별 권장 액션 문자열

### Step 8: 테스트

- 새 ViewModel이 없으므로 ViewModel 테스트 불필요 (pass-through views)
- FactorType displayName extension 테스트 추가 (모든 case에 displayName이 비어있지 않은지)
- FoundationModelReportFormatter locale 분기 테스트

## Test Strategy

| 대상 | 테스트 유형 | 파일 |
|------|-----------|------|
| FactorType displayName (InjuryRisk) | Unit | DUNETests |
| FactorType displayName (Sleep) | Unit | DUNETests |
| FoundationModelReportFormatter locale prompt | Unit | DUNETests |
| Detail View navigation | Manual/UI | 시뮬레이터 |
| i18n 커버리지 | Build verification | xcstrings |

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| InjuryRisk factors 0개 (score=0) | "현재 위험 요소가 감지되지 않았습니다" empty state |
| WorkoutReport nil | 카드가 emptyState 표시 → NavigationLink 비활성 |
| SleepPrediction factors/tips 0개 | empty state 메시지 |
| Foundation Models 미지원 기기 | TemplateReportFormatter fallback (이미 구현됨) |
| Foundation Models가 locale 프롬프트 무시 | fallback: 영어 요약 표시 (기능 저하이지 기능 파괴 아님) |
| iPad sizeClass | DetailWaveBackground + ScrollView로 자동 대응 |

## Scope Exclusion (Future)

- Injury Risk 7일 히스토리 차트 (SwiftData 저장 인프라 필요)
- Sleep Prediction vs 실제 Sleep Score 비교 차트
- Weekly Report 월간 비교 모드
- 상세화면에서 직접 액션 (운동 추천 이동 등)
