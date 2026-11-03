---
tags: [personal-records, pace, reward, notification, period-filter, swiftui, accessibility]
date: 2026-11-03
category: plan
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-28-personal-record-1rm-repmx-volume-pr.md
  - docs/solutions/architecture/2026-03-29-pr-visual-enhancement.md
  - docs/solutions/architecture/2026-10-14-personal-record-pace-history-chart.md
related_brainstorms:
  - docs/brainstorms/2026-03-28-personal-record-overhaul.md
---

# Implementation Plan: A10 / T16 공통 개인 기록 상세

## Context

기준은 immutable main `df53412c41340861722d422c8da6f4fa0d8e77fd`다. Activity의 A10과 알림의 T16은 같은 `PersonalRecordsDetailView`를 사용한다. 승인된 브라우저 시안 `refs/codex/snapshots/f6123bb0dce51eb02ac8fecddbc9345965b70d50`의 README는 T16의 일·주 추가, 금빛 보상, 원래 아이콘을 보존한 메달, 네 종류 달성 이력과 Reduce Motion을 설명한다. 브라우저 예시와 기존 이미지들은 네이티브 구현·현재 캡처가 아니다. A10 초기 시안의 repMax `12회`는 모델과 다르므로 가져오지 않는다. 실제 repMax는 kg 최고 중량과 `3RM`/`5RM`/`10RM` subtitle이다.

현재 detail은 월/6개월/년만 제공하고 6개월이 기본이다. `TimePeriod.dateRange`의 일은 현지 자정부터 현재까지, 주는 오늘을 포함한 현지 일곱 날짜다. 일/주를 기존 계약으로 추가하되 Day 축은 시간, Week 축은 요일/날짜로 실제 점을 표시한다. `TimePeriod`의 기존 stride/format은 재사용 후보이나 실제 차트 도메인과 DST에서 동일하게 동작하는지 구현 때 확인한다. 공통 enum을 전역 변경하지 않는다.

## Requirements

### Functional

- 같은 View에서 일·주·월·6개월·년을 제공하고 원래 6개월 기본, 선택 종류 및 all-time 현재 최고를 유지한다. 해당 기간에 실제 기록이 없거나 한 점뿐이면 그 상태를 정확히 표시한다. 비페이스 기록에 가짜 운동 시계열을 만들지 않는다.
- 아홉 종류와 원래 symbol, 색, 이름, 단위/정밀도, 제목·subtitle, NEW·실제 delta·기록일, 사전 선택 및 유효하지 않은 선택 fallback을 보존한다. 특히 repMax kg, pace 초/km→기존 표시, distance 원본 m→km, duration 기존 형식을 바꾸지 않는다.
- 최상단의 풍부한 DUNE 현재 최고 hero와 차트 카드(기간, 선택 범위 한 번, 단위, 실제 점), 실제 level/points/badges/locked 상태의 보상, 월별 최신 30개 네 event kind의 title/detail/date/points를 축하형 메달·타임라인으로 표현한다. 날짜 범위를 타일마다 복제하지 않되 최고 달성일과 실제 event 날짜는 보존한다. 정적인 깊이·광택 메달을 사용하고 연속 애니메이션을 추가하지 않아 Reduce Motion을 존중한다. 장식은 accessibility에서 숨긴다.
- Share 버튼·기존 `PRShareService`/`ShareImageSheet`, 보상 정보 A21 sheet와 내용, Activity/알림 경로·Back, 원래 notice와 nil/empty/error/loading, 이전 pace 조회·저장소 데이터 의미를 유지한다. 기존 입력을 넘기는 좁은 T16 parity 수정 외 A21이나 PR 데이터 모델/계산을 변경하지 않는다.
- `NotificationPersonalRecordsPushView`는 현재 `unlockedBadgeKeys`를 전달하지 않지만 Activity 소비자는 전달한다. 동일 `viewModel.unlockedBadgeKeys`를 전달하고 동일 입력에 대한 잠금 상태를 검증한다. 기존 detail의 `recordsUpdateKey`는 badge/reward 변화를 포함하지 않으므로, 실제 소비자에서 독립 변경 가능성이 확인되면 보상 입력 갱신을 별도 최소 task/update 경계로 처리한다. UI 상태를 초기화하거나 pace fetch를 불필요하게 재시작하지 않는다.

### Non-functional

- DS palette·spacing, 기존 상세 hero/차트 primitives와 SF Symbols를 활용한다. 최신 main의 `ScoreHeroPalette`, `DetailWaveBackground`, `PRChipBar`, `RewardProgressSection`, `AchievementHistorySection`, `TimePeriod`/`TimePeriod+View`와 기존 Charts를 우선 검토한다. 점수 전용 `DetailScoreHero`/`ScoreDetailSummaryStats`를 kg·pace에 의미가 맞지 않게 강제하지 않는다.
- iPhone/Duo Closed 및 접근성 글자에서 단일 열, 적절한 iPad/Duo Open 폭 및 실제 터치 타깃을 유지한다. 비싼 `groupedHistory`와 `funComparisons`는 기존처럼 ViewModel에서 캐시한다. 색/문구는 기존 DS와 로컬라이제이션 규칙을 따르고 필요한 신규 문자열만 번역·format한다.

## Approach

현재 `PersonalRecordsDetailView`와 세 기존 section을 국소 재구성하고 VM의 실제 필터와 pace 수명주기를 보존한다. 먼저 시안·현재 layout/theme/actual map과 원본 종류별 값을 대조하고, 구현 전 A10과 T16 각각의 실제 경로 및 fixture를 명시한다. 원본 아이콘/데이터는 presentation 모델을 그대로 사용한다. 레벨·포인트·badge 진행도는 실제 값이 제공하는 범위에서만 표현한다. 월별 event 순서 및 네 기존 심볼은 장식으로 가리지 않는다.

Day/week는 `TimePeriod.dateRange(referenceDate:)`의 현재 정의와 동일한 하나의 기준 시각으로 실제 점을 자른다. 이 ViewModel의 동일한 캐시 범위를 구간·축·포인트에 사용하고 경계 검증에 필요한 경우 기본값 호환 clock/referenceDate를 주입한다. DST 및 일중 미래 레코드를 제외한다. 이전/다음 기간 이동과 추세선 토글은 이번 범위에서 구현하지 않는다. 현재 선택 범위를 ViewModel에서 한 번 계산·캐시하고 interval 표시, 점 필터와 차트 domain에 동일하게 사용한다. 부족한 history fetch, 임의 샘플이나 동작하지 않는 버튼은 추가하지 않는다.

Pace는 최근 distance workout을 즉시 표시하고 기존 1년 조회·60…3600초/km의 finite 필터, workout ID 중복 제거와 미매칭 저장 PR, generation에 의한 이전 결과 무효화, 기존 공유 fetch/취소 의미를 유지한다. pace 선은 linear이며 all-time 최고와 선택 기간 운동열은 별개다. 종류 변경 시 현재 로딩·실패·빈 상태를 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| A10과 T16에 별도 구현 | 화면별 독립 수정 | 표시·badge 및 데이터 중복 | 기각: 공통 View와 좁은 소비자 parity |
| 시안의 데이터/곡선을 그대로 이식 | 시안과 빠른 유사성 | repMax 단위와 희소 실제 기록을 왜곡 | 기각 |
| 새 범용 chart/reward coordinator | 확장 여지 | 이번 가족 범위를 넘어 기존 상태·fetch를 중복 | 기각 |
| 기존 component와 실제 period 범위 기반 국소 리디자인 | 기존 계산/상태 재사용, 검증 범위 명확 | 각 기기 접근성 확인 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Modify | hero, 다섯 기간 차트/축, 원래 값과 접근성·Share 유지 |
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | Minimal conditional | day/week 경계의 기준 시각 주입이 실제로 필요할 때만; pace 동작·캐시 보존 |
| `.../Components/PRChipBar.swift` | Conditional | 아홉 종류 기존 IDs/상징 유지하며 필요 시 배치만 조정 |
| `.../Components/RewardProgressSection.swift`, `AchievementHistorySection.swift` | Modify | 실제 보상 및 네 event 종류의 풍부한 배치·모션 접근성. A21 정보 내용/route 유지 |
| `DUNE/Presentation/Shared/NotificationPersonalRecordsPushView.swift` | Modify | 기존 Activity 소비자와 동일한 `unlockedBadgeKeys` 전달 |
| `DUNETests/PersonalRecordsDetailViewModelTests.swift` | Modify | 의미 있는 day/week 경계·기존 pace/종류 보존 및 필요한 badge parity 검증 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, `DesignMapNotificationDetailTests` 실제 파일 | Modify as needed | Month 의미 기반 선택, day/week 실제 fixture, A10/T16 진입·Back 및 선택 경로 |
| `Shared/Resources/Localizable.xcstrings` | Conditional | 필요한 신규 copy만 추가·번역·formatter/manual 검사 |
| layout/theme maps 및 actual A10/T16 captures, review provenance | Modify | 실제 변경 화면만 새 소스·기기 증거로 갱신. 기존 A21/Watch/다른 화면 보존 |

`ActivityPersonalRecord`, PR 서비스/저장소, workout query 모델·계산, Share payload와 A21 내용은 변경 대상이 아니다. 선택한 개선에 따라 실제 파일 범위는 구현 전 재확인한다.

## Implementation Steps

1. **계약·지도 정리.** 현재 main의 A10/T16 및 시안 map, 9개 symbol/단위, 4개 event kind, T16 loading/loaded와 Activity preselection을 조사한다. baseline은 각각 기기/소스/action/AX provenance가 확인된 경우만 before로 인증한다. 시안 fixture와 실제 원본을 구분하고 실제 구현을 시작하기 전 layout/theme map을 준비한다. 기존 역사 실패 및 승인 예산은 그대로 보존한다.
2. **기간·소비자.** 다섯 period 노출과 Day 시간/Week 일 축을 구현한다. 날짜 범위는 현지 캘린더 현재 범위·한 기준 시각, 기존 month/6M/year와 all-time best를 유지한다. T16에 badge keys를 전달하고 독립 갱신 이슈가 재현 가능한 경우에만 task 경계를 고친다. 각 부분을 소스·경계 테스트로 확인한다.
3. **실제 값의 시각 계층.** hero/차트/보상/이력의 원래 필드와 버튼을 그대로 재구성한다. 원래 icon, 4개 유형, locked/unlocked, share/help, 정보·빈 상태와 Reduce Motion을 검토한다. iPad/큰 글자에서 잘리는 고정 크기나 2열을 피한다.
4. **범위 기반 검증·문서.** 변경 동작 관련 테스트와 해당 기기 네이티브 캡처를 표준 실행기·한 번에 한 owned simulator로 수행한다. 신규 layout/theme·actual A10/T16 map은 실제 source/pose/PNG/AX evidence로만 갱신하고 다른 행/Watch/A21을 보존한다. 품질 리뷰 및 해결과 compound/ship은 각 단계의 실제 결과에 기반한다.

## Edge Cases

| Case | Handling |
|---|---|
| 기준일 자정, DST, 다수 같은 날, 미래 데이터 | 현지 Calendar의 실제 범위, 기준 시각 하나, 경계 포함/제외를 결정적 테스트. 전역 TimePeriod 의미는 유지 |
| 기간에 점 없음/한 점, 과거 all-time 최고 | 실제 비어 있는 차트 또는 한 점; 최고 카드는 기간 필터와 독립 |
| 종류 변경·미지원 preselection | 기존 resolvedKind fallback, nine-kind label/unit 및 현재 선택 유효성 보존 |
| 비동기 pace 조회 지연·변경·취소 | generation, dedupe, 유효 pace, 최근 snapshot 교체 및 기존 task 의미 유지 |
| reward 없음, badge 입력 독립 변경 | 기존 노출 조건·locked 표시를 따르고 두 소비자에 같은 키 전달 |
| 큰 글자/Reduce Motion | 실제 콘텐츠 읽기와 의미상 아이콘 보존, 장식 제외·애니메이션 중지 |

## Testing Strategy

- **Unit (focused):** 기존 `PersonalRecordsDetailViewModelTests`에 고정 시각의 day/week 시작·끝·경계 밖, 같은 날 실제 복수 점 및 empty period/all-time best를 추가한다. 필요한 경우에만 clock injection. 기존 pace 유효 필터, lower-is-better, 연간 fetch, dedupe, unmatched PR, snapshot/generation/cancel 테스트를 재사용하고 변경 관련 실패만 해결한다. T16 badge 전달이 독립 테스트 가능한 실제 경계라면 동일 키의 locked/unlocked 결과를 검증한다; 구현을 그대로 복제하는 테스트는 만들지 않는다.
- **UI:** `testPersonalRecordsPaceHistoryShowsWorkoutsInMonth`는 현재 `tapSegment(... index: 0)`이 Month다. day/week 추가 후 Month를 의미 있는 label/ID로 선택하게 고치고 실제 fixture로 day/week를 확인한다. `testPersonalRecordsDetailShowsTimelineRewardsAndHistory`는 VisualAudit 시 영어/MAX라 일반 글자 baseline을 대체하지 않는다. 기존 `testActivitySecondaryDetailRoutesOpenExpectedScreens` 및 `DesignMapNotificationDetailTests/testNotificationPersonalRecordsPush`를 기반으로 A10/T16 진입·loaded·실제 Back을 확인한다. Share/info는 동작이 바뀌거나 관련 배치가 영향을 받는 경우 기존 selector로 확인한다.
- **Native map:** 해당 변경의 iPhone/iPad/Duo Closed/Open에서 실제 선택 상태와 hero/차트/보상/이력, 공유 T16 loaded, 접근성 크기/Reduce Motion의 영향을 받는 상태를 캡처한다. 일반·dark·MAX는 변경과 기존 evidence에 맞춰 최소 selector로 결합한다. 하나의 소유 기기만 사용하고 실제 pose·활성 display·PNG/AX·selector/source를 기록한다. 실패는 이전 승인 예산과 별개로 임의 재시도하지 않는다. 이 계획은 실행이나 통과를 주장하지 않는다.
- **Data and localization:** 각 9종 symbol/단위·repMax subtitle, 네 실제 이벤트 및 선택된 badge 상태를 소스/fixture 기준으로 확인한다. 필요한 문자열 catalog 변경은 formatter와 해당 검사를 수행한다. 무관한 전체 회귀나 새로운 domain 테스트를 요구하지 않는다.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 희소 PR을 완전 운동 history로 오인 | 높음 | 높음 | 기존 데이터만 점으로 표시, pace만 실제 운동열을 별도 유지 |
| 낮을수록 좋은 pace·kg repMax 의미 왜곡 | 중간 | 높음 | 원래 formatter/units/linear pace 및 경계 테스트 |
| 배지 입력이 두 route 또는 갱신 시 불일치 | 중간 | 중간 | 실제 키 전달과 독립 갱신 경계 검증 |
| DST·축·선택 기간이 서로 다른 시각 사용 | 중간 | 높음 | 캘린더 기준 시각 한 번, day/week 경계 및 레이블 확인 |
| 큰 글자에서 5개 picker/실제 날짜·버튼 잘림 | 중간 | 높음 | 의미 기반 picker, 실제 viewport·AX 검증 |
| 시안 fixture·기존 이미지가 현재 결과로 오인 | 중간 | 높음 | source/action/기기/pose 및 새 PNG/AX provenance 분리 |

## Confidence Assessment

- **Overall: Medium.** `df53412`에서 현재 소비자·VM·기간·기존 테스트와 세 과거 solution, 승인 시안 README를 확인했다. T16 배지 키 누락과 index 기반 Month 선택은 소스로 확인된다. 실제 새 레이아웃, 각 기기/접근성 상태, badge 독립 갱신 가능성, native gate는 구현·검증 전이다. Full 5-period 데이터 또는 스크롤 기능을 이미 제공한다고 가정하지 않는다.


## 실제 UI 검사에서 확인한 선택 기간 요약

차트의 원래 끝값은 네이티브 화면에 보이지만 Swift Charts의 접근성 계층에서는 장식으로 제외됐다. 선택 기간의 실제 `chartData.last` 값·원래 단위·날짜를 차트 카드 안의 최근 기록 요약으로도 표시한다. 전체 기간 최고 카드와 구분하며 데이터가 없으면 이 요약도 표시하지 않는다. 원래 kind 아이콘과 formatter를 그대로 사용하고, 끝값 말풍선은 더 읽기 쉬운 대비로 유지한다. 상위 카드/이력의 접근성 그룹은 하위 날짜·보상·이력 식별자를 보존한다. 모델 계산이나 데이터 조회·원래 기간 선택 의미는 바꾸지 않는다. 두 실제 실패와 재시도 기록은 유지하며, 추가 실행을 통과로 선기록하지 않는다.

## 최종 실행 기록 · 2026-11-03

b0에서 iPhone·iPad·Duo 접힘·펼침의 Activity 및 알림 진입 검사가 각각 2개씩 실제 통과했다. 이후 접근성 크기의 헤더·축 수정은 최신 통합 소스 7ce의 Duo 접힘 원래 MAX 검사 1/1과 전체 플롯을 포함한 실제 PNG·접근성 15개 기록으로 확인했다. 일반 크기의 b0 원본은 변경되지 않은 내용·배치의 소스 대조에 한정하고 촬영 리비전을 유지하며, 배경 파동 픽셀이나 새 접근성 식별자 동일성을 주장하지 않는다. 관련 VM 검사 19개는 소스가 바뀌지 않은 범위에서 재사용했다. 실제 비교 맵은 A10/T16만 갱신하고 A05·T04·T09 및 다른 화면은 보존했다.
