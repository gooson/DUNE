---
tags: [review-fix, watch, performance, localization, validation]
date: 2026-03-29
category: plan
status: draft
---

# Review Findings Batch Fix

## Problem Statement

이전 24h 머지 리뷰에서 발견된 14개 미수정 항목을 일괄 수정한다.

## Affected Files

| # | 파일 | 수정 내용 |
|---|------|----------|
| 1 | `DUNEWatch/WatchConnectivityManager.swift` | sendSetCompletion/sendWorkoutCompletion에 transferUserInfo fallback |
| 2 | `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | isReachable를 computed property로, requestWorkoutBulkSync에 transferUserInfo |
| 3 | `DUNE/Presentation/Shared/Detail/AllDataViewModel.swift` | groupedByDate를 stored property로 캐싱 |
| 4 | `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | computed properties 캐싱 |
| 5 | `DUNE/Presentation/Shared/Charts/HeartRateChartView.swift` | id:\.offset → id:\.element.date, areaGradient static 호이스트 |
| 6 | `DUNE/Presentation/Shared/Detail/MetricSummaryHeader.swift` | badgeColor에 .heartRate 반전 추가 |
| 7 | `DUNE/Presentation/Shared/Detail/MetricDetailView.swift` | duplicate staggeredAppear index 수정 |
| 8 | `DUNE/Presentation/Settings/SettingsView.swift` | CLLocationManager() init 제거 |
| 9 | `DUNE/Presentation/Sleep/Components/SleepRegularityCard.swift` | formatTime FormatStyle 호이스트 |
| 10 | `DUNE/Presentation/Sleep/Components/NapDetectionCard.swift` | String(format:) → .formatted() |
| 11 | `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | chart .padding(.top, 16) 추가 |
| 12 | `DUNE/Data/Weather/OpenMeteoArchiveService.swift` | DateFormatter 캐싱 |
| 13 | `DUNE/Domain/UseCases/AggregateNocturnalVitalsUseCase.swift` | HK range validation 추가 |
| 14 | `DUNE/Presentation/Shared/Detail/AllDataView.swift` | EmptyStateView l10n leak 수정 |
| 15 | `Shared/Resources/Localizable.xcstrings` | 새 번역 키 추가 |

## Implementation Steps

### Step 1: Watch WC 수정 (items 1-2)
- sendSetCompletion: reachable이면 sendMessage, 항상 transferUserInfo fallback
- sendWorkoutCompletion: 동일 패턴
- WatchSessionManager.isReachable → computed property
- requestWorkoutBulkSync: transferUserInfo fallback

### Step 2: Performance 수정 (items 3-4, 9, 12)
- AllDataViewModel.groupedByDate → stored property + invalidation
- PersonalRecordsDetailViewModel → stored property 캐싱
- SleepRegularityCard formatTime → static FormatStyle
- OpenMeteoArchiveService DateFormatter → static 캐싱

### Step 3: UI/Chart 수정 (items 5-8, 11)
- HeartRateChartView: id stable, gradient static
- MetricSummaryHeader: .heartRate badge inversion
- MetricDetailView: staggered index 5로 변경
- SettingsView: CLLocationManager deferred
- PersonalRecordsDetailView: chart padding

### Step 4: Validation/L10N 수정 (items 10, 13-14)
- NapDetectionCard: .formatted()
- AggregateNocturnalVitalsUseCase: HK range validation
- AllDataView: EmptyStateView l10n
- xcstrings 업데이트

## Test Strategy

- `scripts/build-ios.sh` 빌드
- `xcodebuild test ... DUNETests` 유닛 테스트
- 기존 테스트 회귀 확인

## Risks

- Watch WC 변경은 실기기 테스트 필요 (시뮬레이터 검증 불가)
- PersonalRecordsDetailViewModel 캐싱 시 invalidation 누락 가능
- isReachable computed property 전환 시 기존 호출자 영향
