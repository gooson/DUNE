### [P2] 이전 기간 첫날 HealthKit 운동이 누락된 합계를 표시함
- **File**: DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift:233
- **Category**: consistency
- **Issue**: 새 이전 기간 카드가 `previous.startDate`부터의 전체 수치를 표시하지만, `TrainingVolumeViewModel.swift:67,74`는 `days * 2`일을 조회하고 `WorkoutQueryService.swift:34-42`는 현재 시각 기준으로 시작한다. 반면 `TrainingVolumeAnalysisService.swift:22-26,47-49`는 D−2N 자정부터 이전 기간을 집계한다. 따라서 표시된 첫날 자정부터 조회 시각까지의 HealthKit 운동은 빠지지만 manual 기록은 포함된다.
- **Risk**: 이전 활동일·시간·칼로리·세션과 변동률이 과소 표시된다. 예를 들어 정오에 1W 화면을 열면 14일 전 오전 운동이 이전 주 합계에서 빠진다.
- **Fix**: 분석과 같은 기준 시각 및 자정 경계를 사용해 HealthKit 조회 시작을 지정하고, 첫날의 경계 전후 운동과 manual/HealthKit 동등성을 검증한다.

### [P2] 주간 목표 링이 8개 날짜의 활동일을 사용함
- **File**: DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift:120
- **Category**: consistency
- **Issue**: 1W 링은 `comparison.current.activeDays`를 주간 목표 5일의 분자로 사용한다. 하지만 `TrainingVolumeAnalysisService.swift:22-25,35-39`의 현재 기간은 D−7 자정부터 현재까지여서 오늘 포함 최대 8개 날짜이며, 이전 기간은 7개 날짜다.
- **Risk**: 7일 중 4일만 운동해도 8일 전 경계에 포함된 운동 때문에 목표 달성으로 보일 수 있고, 이전 기간과의 증감도 길이가 다른 기간을 비교한다.
- **Fix**: 현재와 이전 기간을 명시적인 동일 길이의 날짜 경계로 정렬하고 링과 비교 값이 같은 7일 범위를 사용하도록 한다. 경계일 운동을 포함한 테스트를 추가한다.

## DataResolve 재검토 (snapshot 98120380)

- **이전 기간 첫날 누락: 해결.** `TrainingVolumeViewModel.swift:68-75`가 동일한 `referenceDate`로 만든 `bounds.previousStart`부터 명시적으로 조회하고 같은 bounds를 집계에 전달한다. 범위에 따라 실제 응답을 필터링하는 `RangeTrainingWorkoutService` 테스트가 첫날 오전 HealthKit 및 manual 합계를 확인한다.
- **주간 목표 8일: 해결.** `TrainingVolumeAnalysisService.swift:38-43`의 명시적 bounds는 현재 7일과 이전 7일을 만들고 화면 모델이 이를 사용한다. 4일 활동과 D−7의 다섯 번째 활동을 구분하는 테스트 및 네 기간의 날짜 수·경계 테스트가 추가됐다.
- 기존 `referenceDate` overload는 기존 D−N 및 D−2N 경계를 유지하며 동일 집계 본문을 호출한다. 운동 종류 상세의 조회 범위는 새 이전 기간 전체를 포함하고 기존 rolling 최근 목록 범위도 보존한다. 추가 P1/P2/P3 없음.
- 정적 리뷰만 수행했으며 새 테스트의 실행 결과는 확인하지 않았다.

## DST 보정 최종 재검토

추가 데이터 무결성 지적 없음. 동일한 Calendar가 기간 경계·활동일 집계·일별 버킷과 히스토리에 전달되며, 자정 DST 전환 후 각 날짜를 다시 startOfDay로 정규화한다. 운동 종류 조회 mock도 요청 범위를 실제로 적용한다. 기존 기본 overload의 날짜 오프셋은 유지된다.
