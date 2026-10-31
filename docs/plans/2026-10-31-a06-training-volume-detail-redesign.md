---
topic: a06-training-volume-detail-redesign
date: 2026-10-31
status: planned
confidence: medium
tags: [activity, training-volume, detail, design]
category: plan
related_solutions:
  - docs/solutions/testing/2026-03-08-training-volume-daily-volume-scroll-and-day-bucket-alignment.md
  - docs/solutions/general/2026-02-19-review-p1-p2-training-volume-fixes.md
related_brainstorms:
  - docs/brainstorms/2026-02-19-training-volume-analysis.md
---

# Implementation Plan: A06 훈련량 상세 재설계

## Context

Activity의 Training Load에서 열리는 Training Volume 상세는 이미 실제 네 기간 집계, 활동일 링과 네 지표, 운동 종류 도넛, 일별 운동 시간 막대, 조건부 Training Load/RPE 차트, 운동 종류별 상세 링크를 제공한다. 현재 요약 카드의 위계와 이전 기간 값의 가독성을 개선한다. 일별 차트는 제목이 “Daily Volume”이지만 **분 단위 운동 시간**을 표시하므로 제목과 접근성 이름을 “Daily Duration”으로 바로잡는다. HealthKit 운동 시간·횟수로 중량이나 근육별 세트를 만들지 않는다.

`git show 672d5fdb:<파일> | shasum -a 256`로 원본 blob을 확인했다. `TrainingVolumeDetailView.swift` `69d7547c8aabcf6e8d93b758e12bd8c2bdffecb0410c4a66e02447d352565c0c`, `TrainingVolumeViewModel.swift` `28a677298ed9984930d688c0f0240de8b6bae7103cd4127e060ffb1aae11f80f`, `TrainingVolume.swift` `e85f82e3ff6d18d9e9abdf795e381147a208de9f19b655e2e439595812258bcb`, `TrainingVolumeAnalysisService.swift` `4aff0a76d6a4fb1ad8c6aba26f30e0fb03f251d4691494e27b17145143e5004c`, `StackedVolumeBarChartView.swift` `e5800dd782d355857ec2eed38ec0f865f7ccd45cb98efeaf60115d2f1ed7f8ca`, `VolumeDonutChartView.swift` `05b7ab22310360aee4d39710d498bb0dfa3c8f161cc167506fad1b79a90fdb46`이다. 구현 직전 A06 worktree에서 다시 확인한다.

## Requirements

### Functional

- Activity `TrainingVolumeDestination.overview` 진입, 시스템 Back, `1W/1M/3M/6M` 네 기간(7/30/90/180일), 기본 Week, 비영속 선택과 `.task(id:)` 재조회, 기존 AX ID를 유지한다.
- 현재 `PeriodComparison.current`의 Active Days, Duration, Calories, Sessions 네 지표와 원래 formatter 및 `ChangeBadge`의 nil/양·음 의미를 보존한다. **1W에서만** `current.activeDays / weeklyGoal(5)` 링을 “주간 활동일 목표”로 명시한다. **1M/3M/6M에서는** 선택한 기간의 `current.activeDays` 실제 건수를 단독으로 보여 주고 링/`count of 5` 진행 표현을 쓰지 않는다. 같은 `weeklyGoal=5` 값은 별도 “Weekly goal: 5 days” 참고 chip으로 보존하되 기간 목표나 분모로 설명하지 않는다. 상세 전용 히어로에서 네 아이콘을 같은 leading 슬롯에 둔다. `timer`/`flame.fill`은 기존 요약 심볼, `calendar`/`figure.strengthtraining.traditional`은 A06 표현 선택이다.
- `comparison.previous`가 있을 때 같은 네 지표의 실제 이전 값과 동일 단위를 정렬한다. 이전 `startDate/endDate`를 현지화된 제목 한 곳에만 표시한다. 이전값 부재·분모0에서 가짜 `0%`를 만들지 않는다. 원래 `ChangeBadge` 계산을 다시 구현하지 않는다.
- `VolumeDonutChartView`의 Duration/Calories/Sessions 세 모드, 선택된 운동 종류의 중앙값·아이콘, 상위5+Others, 빈 상태와 탭 동작을 보존한다. `StackedVolumeBarChartView`의 실제 분 단위 segment, 날짜 선택, 가시 구간, 좌우 스크롤, probe ID를 보존한다. 표시 제목과 `ChartUITestSurface` label을 “Daily Duration”으로 바꾸고 기존 빈 상태의 “Daily volume will appear as you exercise”도 분 단위 운동 시간에 맞는 “No daily workout duration for this period”로 교체한다. 차트/빈 상태의 표시 조건은 그대로다.
- 데이터가 있을 때만 나타나는 Training Load/RPE 차트와 운동 종류별 목록, `ExerciseTypeDetailView`의 네 기간·추세·최근 운동·조건부 거리/중량×횟수·장비/PR 정보를 유지한다. 로딩·빈 상태·기존 오류 분기·쿼리 실패 fallback도 유지한다.
- HealthKit 기여는 운동 시간·칼로리·세션, 해당 종목의 거리까지다. 수동 기록의 유한한 양수 중량×횟수만 kg 볼륨에 기여한다. HK와 수동 연결 운동 중복 제거·999,999 상한·표시 단위는 원래 서비스 그대로 둔다.
- A03 Muscle Map의 근육별 세트/목표 막대는 별도 원천이다. A03은 수동 완료 세트의 주근육 전량·보조근육 `max(setCount/2,1)`, 13군·기본15세트 목표(5…30, 5단위), 초과 원값을 가진다. A06에는 이 원천이 없으며 다섯 활동일 목표는 세트 목표가 아니다. A06에 그 막대를 추가하거나 HK 세션에서 세트를 합성하지 않는다.

### Non-functional

- 현재 DUNE 팔레트/DS 토큰을 쓰는 상세 전용 불투명 히어로와 읽기 쉬운 잉크·원래 의미색. 밝음/어두움, iPhone/iPad, Duo 접힘/펼침, 최대 Dynamic Type에서 글자·단위·기간/도넛 조작을 유지한다. 고정 높이와 비활성 화살표를 쓰지 않는다.
- `TrainingVolumeViewModel`, domain/use case, 쿼리 서비스, Activity 루트 요약 카드, A03 근육 지도, 공유 hero·차트 알고리즘을 수정하지 않는다. 실제 데이터 조회 범위와 시간 기준을 바꾸지 않는다.

## Approach

`TrainingVolumeDetailView` 안에 private 현재 히어로와 이전 기간 표시를 구성한다. 기존 네 지표의 source 값·formatter·ChangeBadge를 그대로 전달한다. 1W의 주간 목표 링과 1M/3M/6M의 실제 기간 활동일 건수+분리된 주간 참고 chip을 `selectedPeriod`로 표현만 분기한다. AX는 1W “해당 주 활동일 N, 주간 목표 5일”, 긴 기간 “1M/3M/6M 활동일 N”과 별도 “주간 목표 5일”로 읽히게 하며 N/5 진행으로 합치지 않는다. `.id(selectedPeriod)`, chart 인자, 조건부 차트, 운동 종류 목록, AX ID는 유지한다. A06 단독 소비인 일별 차트의 제목·AX label·빈 문구를 시간 의미에 맞게 바꾼다. [별도 배치 맵](../design/layout-map/activity-training-volume-detail-a06.html)과 [테마 표현 시안](../design/theme-map/themes/dune-training-volume-detail-a06.html)은 구현 기준 제안이며 실제 캡처가 아니다.

### Alternative Approaches Considered

| 접근 | 장점 | 단점 | 결정 |
|---|---|---|---|
| HK 세션에서 kg·세트 총량 합성 | 시안 숫자에 가까움 | 실제 kg/세트 원천 없음, 의미 오류 | 제외 |
| A03 근육 목표와 행을 A06에 복제 | 다른 화면에 원천 존재 | A06 입력·라우트·조회 계약 확대 | 별도 제품/원천 계약까지 보류 |
| 상세 전용 히어로·이전 값 + 일별 제목만 수정 | 기존 분석·제스처 유지 | 네이티브 폭·AX 검증 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/TrainingVolume/TrainingVolumeDetailView.swift` | 수정 예정 | Private 현재 히어로·이전 네 값·날짜 한 번 표시; 하위 View와 AX 유지. |
| `DUNE/Presentation/Activity/TrainingVolume/Components/StackedVolumeBarChartView.swift` | 좁은 문구 수정 예정 | 실제 분 단위 차트의 보이는 제목과 AX label만 수정. |
| `Shared/Resources/Localizable.xcstrings` | 수정 예정 | 새 키 “Daily Duration”과 “No daily workout duration for this period”를 en/ko/ja로 수동 번역; 활동일·주간 참고 AX는 기존 번역된 `Active Days`/`Weekly goal: %lld days`와 기간 표시를 분리해 사용한다. formatter/check. |
| `DUNEUITests/Regression/ChartInteractionRegressionUITests.swift` | 조건부 focused test | 기존 fixture가 안정적 이전값을 제공할 때 실제 값·한 날짜·분 단위 이름 계약. |
| `docs/design/layout-map/activity-training-volume-detail-a06.html`, index/README | 시안/계약 | 자료·상태·반응형 별도 맵. |
| `docs/design/theme-map/themes/dune-training-volume-detail-a06.html`, manifest/index/README | 시안/인덱스 | DUNE 밝음/어두움 정적 표현; 실제 앱 아님. |
| `docs/design/phone-design-map/actual/index.html` 및 A06 PNG | 구현 후 | 동일 source/fixture 기기의 새 실제 캡처만 추가. |

## Implementation Steps

### Step 1: 원본 근거와 별도 맵 동결

- **Files**: 이 계획·레이아웃/테마 시안, ignored baseline evidence.
- **Changes**: 위 source hash를 재확인하고 원본 `ActivityExerciseRegressionTests/testActivityDetailRoutesOpenExpectedScreens`를 실행한다. 이 multi-route test의 teardown PNG는 화면 AX·Week 선택·`manual-strength` 행을 확인한 경우에만 A06 before로 쓴다. `443a32ca…` 과거 PNG를 현재 baseline으로 재명명하지 않는다.
- **Verification**: source/seed/locale/theme/type size/device와 실제 스크린 ID를 기록한다. iPhone/iPad/Duo 원본 상태를 after와 정확히 짝짓는다.

### Step 2: 현재·이전 표현 구현

- **Files**: detail View, 단독 소비 일별 차트, 필요 시 문자열 카탈로그.
- **Changes**: 원래 `@Query`, loading/error, period `.task(id:)`, `.id(selectedPeriod)`, 차트 인자·조건부 표출·종류별 링크를 유지한다. `current/previous` 값·날짜와 기존 formatter를 사용한다. 차트 제목/AX를 `Daily Duration`으로, 빈 상태를 이 기간의 일별 운동 시간 부재로 고친다. 새 문구와 기간/목표 AX 문구는 en/ko/ja 수동 번역 후 `format-xcstrings.swift --check --check-manual`로 확인한다.
- **Verification**: Swift parse, xcstrings format/check, 보호 원본 hash, diff review. App 구현 전까지 이 단계 완료로 표시하지 않는다.

### Step 3: 범위 지정 네이티브 검증과 실제 맵

- **Files**: 필요한 focused UI test, 실제 화면 맵/PNG.
- **Changes**: 네 현재/이전 값과 날짜 한 번, 도넛 세 모드, 일별 분 단위 선택/스크롤, 조건부 차트, 종류별 링크를 확인한다. 밝음·어두움·큰 글씨와 영향받는 iPhone/iPad/Duo 상태를 새 source에서 캡처한다.
- **Verification**: 아래 선택자와 native AX/PNG를 대조한다. 계획 단계에서 build/native PASS를 주장하지 않는다.

### 문구·접근성 계약 (구현 시 카탈로그 반영)

| 의미 | en | ko | ja |
|---|---|---|---|
| 일별 차트 제목·AX | Daily Duration | 일별 운동 시간 | 日別の運動時間 |
| 일별 차트 빈 상태 | No daily workout duration for this period | 이 기간에 표시할 일별 운동 시간이 없어요 | この期間に表示できる日別の運動時間はありません |

주간 목표 chip은 기존 수동 번역 키 `Weekly goal: %lld days`를 쓰며 실제 `weeklyGoal` 값을 보간한다. 1W 활동일/목표와 긴 기간의 기간 활동일/주간 참고는 **서로 다른 AX 요소**로 읽게 한다. `Active Days`와 picker의 현지화된 기간 이름을 사용하고 긴 기간 활동일 접근성 값에 “N of 5”를 포함하지 않는다. 새 문구를 카탈로그에 등록한 뒤 extraction key·`%lld` 타입·en/ko/ja 번역을 확인하고 `swift scripts/format-xcstrings.swift` 및 `--check --check-manual`을 실행한다.

## Edge Cases

| Case | Handling |
|---|---|
| 이전 요약 nil 또는 지표 분모0 | 기존 change=nil, 현재 지표는 유지; 존재하지 않는 이전값·0%를 만들지 않는다. |
| 운동·종류 없음 | 기존 도넛/일별 빈 상태, 조건부 load/RPE와 목록 숨김 유지. 일별 빈 문구는 분 단위 운동 시간 부재를 설명한다. |
| 운동 조회 오류 | 기존 기록/빈 배열 fallback과 view 오류 분기를 유지; 임의 재시도·데이터 없음. |
| 1M/3M/6M | 원래 rolling 30/90/180일, 축 stride/히스토리 범위·이전 window 사용. 활동일은 해당 기간 실제 건수; 5일은 별도 주간 참고 값이다. 기간 목표나 N/5 링으로 표현하지 않는다. |
| 수동 중량 없음·HK만 있음 | kg/세트로 환산하지 않는다. |
| Duo 접힘·최대 글씨 | 지표/변화는 세로 확장, 기간/모드/선택과 아래 링크 도달 가능. |

## Testing Strategy

- **Original before**: `ActivityExerciseRegressionTests/testActivityDetailRoutesOpenExpectedScreens`; teardown visual audit가 실제 A06 Week인지 AX와 PNG로 확인한다. `testTrainingVolumeSummaryAtMaximumAccessibilityTextSize`는 Activity 진입/루트 점검이며 정상 A06 detail baseline이 아니다.
- **Core UI**: `ChartInteractionRegressionUITests/testTrainingVolumeSurfaceShowsOverviewChartsAndTypeList`, `testTrainingVolumeDailyVolumeChartScrollsToPastData`; 차트 배치 영향 시 `testTrainingVolumeTrainingLoadChartScrollsToPastData`, `testTrainingVolumeTrainingLoadLongPressKeepsVisibleRangeAndActivatesSelection`; 행 변경 시 `ActivityExerciseRegressionTests/testExerciseTypeDetailShowsTrendSurface`.
- **Gap**: seeded 이전 window가 검증 가능한 경우 한 개의 값·한 날짜·차트 의미 focused 계약. 같은 fixture에서 1W→1M으로 바꿔 실제 선택 기간 활동일 건수가 바뀌어도 1M은 N/5 진행이 아니고, “주간 목표 5일”이 별도 참고임을 AX/화면에서 확인한다. 일별 빈 상태가 나타나는 실제 fixture가 확인되면 새 분 단위 문구도 검증한다. Prototype 숫자/레이아웃 미러 테스트는 쓰지 않는다.
- **Actual tiers**: iPhone, iPad, Duo 접힘/펼침의 영향받는 상태를 순차 확인하고 source/fixture·기간을 일치시킨다. Watch 변경 없음.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| “Volume”을 kg로 오해 | 높음 | 높음 | 일별 표시/AX를 Duration으로 명시, 원자료 유지. |
| 다섯 활동일을 30/90/180일 목표 또는 A03 15세트 목표로 오해 | 높음 | 높음 | 1W에만 목표 링, 긴 기간은 실제 count+별도 주간 참고 chip; A03 근육 세트 미추가. |
| 이전 날짜가 달력 월로 오해 | 보통 | 보통 | `previous.startDate/endDate`만 한 번 표시. |
| 큰 글씨에서 hero/차트 조작 가림 | 보통 | 보통 | 유연한 높이·AX 자식/viewport 확인. |
| multi-route teardown을 A06 before로 오인 | 보통 | 높음 | 최종 screen/기간/원본 hash 확인. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: 원본 blob과 데이터/제스처 계약은 확인했다. 실제 before 화면 상태, previous fixture oracle, 기기별 밀도는 네이티브 검증 전이다.
