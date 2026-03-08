---
tags: [ml, injury-risk, sleep-prediction, weekly-report, detail-view, localization, foundation-models]
date: 2026-03-09
category: brainstorm
status: draft
---

# Brainstorm: ML 카드 상세화면 연동 + 다국어 완성

## Problem Statement

ML SDK로 계산된 3개 카드(Injury Risk, Weekly Report, Tonight's Sleep)가 Dashboard에 표시되지만:
1. **상세화면 없음**: 카드 탭 시 이동할 Detail View가 구현되지 않음
2. **다국어 누락**: 일부 섹션 타이틀 번역 키 누락 + Foundation Models 요약이 영어 전용

## Target Users

- 운동하는 사용자가 자신의 부상 위험도, 수면 예측, 주간 리포트를 상세히 분석하고 싶을 때

## Success Criteria

1. 3개 카드 모두 탭 → 상세화면으로 NavigationLink 연결
2. 상세화면에서 풀 분석 데이터 제공 (전체 factor, 히스토리 차트, 액션 플랜)
3. 모든 새 UI 문자열이 xcstrings에 en/ko/ja 3개 언어 등록
4. Foundation Models 요약이 현재 locale에 맞는 언어로 생성
5. 빌드 통과 + 새 UseCase/ViewModel 테스트 통과

## 현재 상태 분석

### 기존 아키텍처

```
Domain (Models + UseCases) — 완료
├── InjuryRiskAssessment + CalculateInjuryRiskUseCase
├── SleepQualityPrediction + PredictSleepQualityUseCase
└── WorkoutReport + GenerateWorkoutReportUseCase
       ↓ (WorkoutReportFormatting protocol)
Data (Services)
├── FoundationModelReportFormatter (Apple Foundation Models)
└── TemplateReportFormatter (fallback)

Presentation (Cards only — Detail 없음)
├── InjuryRiskCard → ActivityViewModel.injuryRiskAssessment
├── SleepPredictionCard → WellnessViewModel.sleepPrediction
└── WorkoutReportCard → ActivityViewModel.weeklyReport (chevron 있지만 navigation 미연결)
```

### Navigation 패턴

- `ActivityDetailDestination` enum에 `.weeklyStats` 등 6개 case 존재
- `.navigationDestination(for: ActivityDetailDestination.self)` 패턴 사용 중
- Wellness에도 `WellnessScoreDestination` 유사 패턴

### 다국어 현황

| 항목 | 상태 |
|------|------|
| 카드 내부 문자열 (displayName, guideMessage 등) | `String(localized:)` 적용 + ko/ja 번역 완료 ✅ |
| Factor detail 문자열 (보간 포함) | `String(localized:)` 적용 + ko/ja 번역 완료 ✅ |
| SectionGroup 타이틀 "Injury Risk" | xcstrings 키 누락 ❌ |
| SectionGroup 타이틀 "Tonight's Sleep" | xcstrings 키 누락 ❌ |
| SectionGroup 타이틀 "Weekly Report" | ko/ja 번역 완료 ✅ |
| Foundation Models 요약 | 영어 프롬프트 고정 → locale 대응 필요 ❌ |
| 상세화면 UI 문자열 | 화면 자체가 없음 → 신규 작성 필요 |

## Proposed Approach

### 1. Injury Risk Detail View

**위치**: `DUNE/Presentation/Activity/InjuryRiskDetail/`

**콘텐츠**:
- 히어로: 점수 게이지 (큰 버전) + 레벨 + 가이드 메시지
- 전체 Factor 목록 (6개): 아이콘 + 타입명 + contribution bar + detail
- 히스토리 차트: 최근 7일 injury risk score 추이 (Swift Charts)
- 권장 액션 섹션: 레벨별 구체적 개선 안내 (rest, stretch, reduce volume 등)
- 근육별 fatigue breakdown: 현재 overworked/high fatigue 근육 시각화

**필요 작업**:
- `ActivityDetailDestination`에 `.injuryRisk` case 추가
- `InjuryRiskDetailView` + `InjuryRiskDetailViewModel` 신규
- 히스토리 데이터 소스: ActivityViewModel이 이미 매일 계산 → 7일치 저장/조회 로직 필요
- 새 UseCase 또는 기존 UseCase 확장 (히스토리 집계)

### 2. Weekly Report Detail View

**위치**: `DUNE/Presentation/Activity/WorkoutReportDetail/`

**콘텐츠**:
- 전체 ML 요약 텍스트 (Foundation Models 생성)
- 기간 통계 그리드: 세션수, 활동일수, 총 볼륨, 총 시간, 평균 강도
- 볼륨 변화율 비교
- 전체 하이라이트 목록 (PR, streak, volume increase, consistency, new exercise)
- 근육 그룹별 볼륨 breakdown (차트)
- 개선 제안 (ML 기반)

**필요 작업**:
- `ActivityDetailDestination`에 `.weeklyReport` case 추가
- `WorkoutReportDetailView` + ViewModel (또는 기존 WorkoutReport 데이터 활용)
- 근육 그룹 차트: WorkoutReport.muscleBreakdown 데이터 이미 있음 → 시각화만 필요
- Foundation Models 요약 전체 표시 (카드는 3줄 프리뷰)

### 3. Tonight's Sleep Detail View

**위치**: `DUNE/Presentation/Wellness/SleepPredictionDetail/`

**콘텐츠**:
- 히어로: 점수 게이지 (큰 버전) + outlook + 신뢰도 배지
- 전체 Factor 목록 (5개): 타입 + impact 표시 + detail
- 전체 Tips 목록
- 수면 이력 차트: 최근 14일 실제 sleep score 추이 (예측과 비교)
- 수면 패턴 분석: 취침 시간 일관성, 평균 수면 시간

**필요 작업**:
- Wellness에 navigation destination 추가 (WellnessScoreDestination에 case 추가 또는 별도 enum)
- `SleepPredictionDetailView` + `SleepPredictionDetailViewModel` 신규
- 수면 이력 데이터: WellnessViewModel이 이미 sleep 데이터 접근 → 14일치 이력 조회
- 차트 데이터 집계 UseCase

### 4. 다국어 완성

**A. 누락 xcstrings 키 추가**:
- "Injury Risk" → ko: "부상 위험도", ja: "怪我リスク"
- "Tonight's Sleep" → ko: "오늘 밤 수면", ja: "今夜の睡眠"
- 상세화면 신규 문자열 전체

**B. Foundation Models 다국어 프롬프트**:
- `FoundationModelReportFormatter`의 프롬프트에 현재 locale 반영
- `Locale.current.language.languageCode`로 ko/ja/en 분기
- 프롬프트: "Summarize in Korean/Japanese/English" 조건 추가
- fallback `TemplateReportFormatter`도 locale 대응

**C. Factor 타입 displayName** (상세화면용):
- `InjuryRiskAssessment.FactorType`에 Presentation extension으로 `displayName` 추가
- `SleepQualityPrediction.FactorType`에도 동일 처리
- 각각 ko/ja 번역 필요

## Constraints

- **Domain에 SwiftUI import 금지**: Factor displayName은 Presentation extension으로
- **CloudKit 호환**: 새 @Model 추가 시 VersionedSchema 동기화 (히스토리 저장이 SwiftData인 경우)
- **Foundation Models availability**: A17 Pro+ 전용 → fallback 필수
- **기존 WeeklyStatsDetailView와 공존**: 별도 navigation path 유지

## Edge Cases

- **데이터 부족**: 히스토리 차트에 7일/14일 미만 데이터 → placeholder + "N일 후에 차트가 표시됩니다" 안내
- **Foundation Models 미지원 디바이스**: Template fallback 요약 표시 + locale 대응
- **Factor가 0개**: 위험도 0이면 factor 없음 → "현재 위험 요소가 감지되지 않았습니다" 상태
- **오프라인**: 이미 계산된 로컬 데이터 기반이므로 네트워크 불필요
- **iPad 레이아웃**: 각 상세화면에 sizeClass 대응 필요

## Scope

### MVP (Must-have)
- [ ] Injury Risk Detail: 전체 factor + 권장 액션 (히스토리 차트는 데이터 인프라에 따라 조정)
- [ ] Weekly Report Detail: 전체 ML 요약 + 하이라이트 + 근육 breakdown 차트
- [ ] Tonight's Sleep Detail: 전체 factor + 전체 tips (수면 이력 차트는 데이터 소스에 따라 조정)
- [ ] 3개 카드 → 상세화면 NavigationLink 연결
- [ ] 누락 xcstrings 키 추가 (섹션 타이틀 + 상세화면 신규 문자열)
- [ ] Foundation Models 프롬프트 locale 대응
- [ ] FactorType displayName Presentation extension + 번역
- [ ] 새 ViewModel 테스트

### Nice-to-have (Future)
- [ ] Injury Risk 7일 히스토리 차트 (SwiftData 저장 인프라 필요)
- [ ] Sleep Prediction vs 실제 Sleep Score 비교 차트
- [ ] Weekly Report 월간 비교 모드
- [ ] 상세화면에서 직접 액션 (예: 운동 추천으로 이동)
- [ ] Widget에서 상세화면 deep link

## Open Questions

1. **Injury Risk 히스토리 저장**: 현재 매번 재계산. 7일 추이를 보여주려면 SwiftData에 일별 스냅샷을 저장해야 하는가, 아니면 과거 데이터로 재계산 가능한가?
2. **Foundation Models locale 동작**: Apple Foundation Models가 한국어/일본어 프롬프트에 얼마나 잘 대응하는지 테스트 필요. 영어 프롬프트 + "respond in Korean" vs 한국어 프롬프트 직접 전달?
3. **상세화면 Wave Background**: `DetailWaveBackground` 사용? 색상은 각 섹션 테마 (Activity: warmGlow, Wellness: sleep)?

## Next Steps

- [ ] `/plan` 으로 3개 상세화면 구현 계획 생성
- [ ] Foundation Models 다국어 테스트 (실기 또는 시뮬레이터)
