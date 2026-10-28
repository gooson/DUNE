---
topic: life-tab-redesign
tags: [life, habits, flow, design, accessibility, astra]
date: 2026-10-28
category: plan
status: draft
confidence: high
related_solutions:
  - ../solutions/architecture/2026-03-22-auto-linked-habit-section-routing.md
  - ../solutions/architecture/2026-04-05-habit-archive-management-view.md
  - ../solutions/general/2026-10-26-today-compact-density-and-pin-hit-area.md
related_brainstorms:
  - ../brainstorms/2026-03-22-life-tab-enhancement.md
  - ../brainstorms/2026-04-05-habit-full-list-view.md
---

# Implementation Plan: Life Flow 디자인 개편

## Context

사용자는 남은 Life 탭의 개편 **시안**과 다른3탭과의 통합 룩앤필, 분류/순서/터치/시각화 개선, Astra의 독립 계획을 합친 제안을 요청했다. 이번 산출물은 [동작 시안](../design/theme-map/themes/dune-life-redesign.html), [통합 배치·데이터 계약](../design/layout-map/life-redesign-proposal.md), [Astra 독립 계획과2차 의견](2026-10-28-life-tab-astra-review.md)이다. 아래 앱 변경은 후속 구현 계획이다.

최근 Today Compact·Activity Flow·Wellness Flow 계획/구현·실제 갤러리와 LifeView/HabitRow/VM/analytics/템플릿을 조사했다. 과거 Life 계획은 기존 구현 이력으로 참조하고 현재 개편을 새 날짜의 제안으로 기록한다. 관련 완료 TODO는 Life 폼/이력/E2E이며 이번 디자인을 승인한 신규 active TODO는 없다.

## Requirements

### Functional

- 오늘 행동 우선, 오늘/주간/예정의 의미 유지. 완료 접힘·목적별 보조 필터·기한 지난 반복 우선·안정적인 시간대/사용자 순서.
- HABITS·골드104pt 고정 링·큰 남은 수, 큰 글씨 외부 완료 수. 긴 문장·중복 하단 요약·스크롤 CTA 없음. 대상0개는 —. 히어로7일 그래프를 실천의 리듬으로 이동.
- 수치 ±/시간 총합 수정/명시적 완료/메뉴를 분리하고 최소44pt. invalid 입력에서 기존 기록 보존, 변경 취소, 완료 후 포커스 복원.
- 주간 목표는 완료일/목표일 + 오늘 분/횟수. 반복의 미룸·건너뜀·조기완료·첫 완료/지정 시작 의미 유지.
- 자동은 사용자 운동 연동 먼저, 기본 도전 펼침. 현재 지원하는 exercise만 연결. 주간 workout 횟수·거리와 수동 주간 날짜 수 구분.
- 큰 완료 건수·7일 막대·28일 패턴·주간 돌아보기. 현재 목표 기반 한계 표시. 역사 분모나 불변 이력을 꾸며내지 않음.
- 관리에서 원래12개 분류·알림·보관/복원·순서 유지. Life 상단+와 Today/Watch에서의 기존 진입 유지.

### Non-functional

- DS/AppTheme/Desert 팔레트·공통 header/링 사용, Query child 격리·eager 배치와 basedOnSize 스크롤 유지.
- iPhone/iPad/Duo 접힘·펼침과 큰 글씨에 맞는 한 열/두 열. en/ko/ja 번역. 실제 영향이 있는 화면만 새 캡처.
- 이번 단계의 고정 fixture를 앱 코드로 옮기지 않는다. CloudKit raw value migration이나 HealthKit 새 권한은 이번 디자인에 숨겨 추가하지 않는다.

## Approach

Flow 한 방향을 권장하고 Compact 시각 비교안을 함께 제공한다. source를 조사한 parent 계획과 gpt-6-astra/high의 독립 계획을 교차 검토했다. Astra는 read-only로 source 의미와 시안 문구/조작을 검토했고 브라우저 중복 검증은 하지 않았다. 이견/반영은 통합 계약 표에 남겼다.

**선행 구현은 저장 안전성·통계 계약이다.** `updateValue` 삭제→검증 순서를 고친 후 UI를 연결한다. 기존 주/월 rate는 새 루트 강조에서 제외하되 상세 기능을 무단 삭제하지 않는다. 루트 건수도 현재목표/보관 영향을 받으므로 현재 등록 습관 기준이라는 한계를 명시한다. 역사 불변 목표/완료 이력은 별도 데이터 범위로 둔다.

### Alternative Approaches Considered

| 접근 | 장점 | 문제 | 결정 |
|---|---|---|---|
| 현재 카드 색/여백만 정리 | 변경 적음 | 조작/분류/통계 문제 잔존 | Compact를 비교 목적으로만 보존 |
| 목적별4분류를 루트 최상위로 변경 | 탐색 쉬움 | 일정 의미·오늘 우선순위 약화 | 보조 필터로 한정 |
| 모든 수동/자동 점수를 하나로 합산 | 큰 링에 단순화 | 오늘/주간·회/일/km 혼합 | 제외 |
| 신규 역사 스키마까지 동시 구현 | 과거 분석 정확성 개선 가능 | CloudKit·migration·동기화 범위 과대 | 별도 계획 |
| 기존 의미를 보존한 Flow | 행동/주기/출처 구분, 공유컴포넌트 재사용 | 집계 한계를 명시해야 함 | 권장 |

## Affected Files

| 파일 | 변경 유형 | 후속 구현 내용 |
|---|---|---|
| `DUNE/Presentation/Life/LifeView.swift` | modify | Flow 순서·분류·동작 라우팅·저장 순서·자동 metadata |
| `DUNE/Presentation/Life/LifeViewModel.swift` | modify | 안정 분류 DTO·주간 완료일/하루값·대상0·소스 상태 |
| `DUNE/Presentation/Life/HabitRowView.swift` | modify | 명시적 버튼·44pt·단위·총합 편집·포커스 |
| `DUNE/Presentation/Life/HabitFormSheet.swift`, `HabitTemplateSheet.swift`, `HabitManagementView.swift` | modify | 분류 표시/입력 방식·알림·원래 분류·관리 동선 |
| `DUNE/Presentation/Life/HabitCompletionChartView.swift`, `HabitHeatmapView.swift`, `HabitHeatmapDetailView.swift` | modify | 루트 건수·28일 뷰, 상세90일·현재설정 의미 |
| `DUNE/Presentation/Life/WeeklyHabitSummaryCard.swift`, `WeeklyHabitReportView.swift` | modify | 기간과 진행 중 주간, 새건수/레거시rate 구분 |
| `DUNE/Presentation/Shared/Extensions/HabitType+View.swift` 또는 새 Life 목적 그룹 extension | modify/add | 원래12개 raw value의 표시 묶음 단일 매핑 |
| `DUNE/Domain/UseCases/HabitAnalyticsService.swift` | conditional | 기간/분모 정책 확정 후 필요한 수정. 주/월/interval 의미 변경은 별도 테스트 |
| `DUNE/Presentation/Dashboard/Components/CompactConditionRing.swift`, `CardNavigationHeader.swift` | reuse | 공통104pt링/헤더 재사용, 공유 기본값 변경 피함 |
| `DUNETests/LifeViewModelTests.swift`, `HabitAnalyticsServiceTests.swift`, Life 기록 테스트 | modify/add | 저장 안전성·일정/주간·분류/통계 |
| `DUNEUITests/Full/LifeRegressionTests.swift`, `Smoke/Life*`, 새 `Visual/LifeFlowUITests.swift` | modify/add | 실행/메뉴·상세·큰글씨·native 새캡처 |
| `Shared/Resources/Localizable.xcstrings` | modify | en/ko/ja 상태·동사·단위·범위 메시지 |
| `docs/design/layout-map`, `theme-map`, `phone-design-map/actual` | modify/add | 계약·시안 보존·구현 후 실제 갤러리 |

현재 실제 변경은 시안 HTML, 시안 QA/PNG, 위 두 계획, 배치 계약과 맵 연결뿐이다. 앱/문자열 카탈로그/테스트 타깃은 수정하지 않았다.

## Implementation Steps

### Step 1: 데이터·동작 계약

- 검증 성공 전 기존 로그를 지우지 않도록 저장 순서를 수정하고 invalid/0/중복/상한 회귀를 추가한다.
- 일정/기준일/타임존과 수동/자동 범위·주 경계를 고정한다. 주간 완료일과 오늘 값을 별도 DTO로 만든다.
- 검증: 기존30분→1500분 거부 후30분 유지, 정상25분 변경,0정책,999상한,interval90일·주간경계·자동만/예정만.

### Step 2: 루트와 조작

- 기존 child Query와 DS 컴포넌트 기반으로 HABITS/오늘/주간/예정/자동을 구성한다.
- 목적별 묶음은 표시 전용. stable ID,44pt,contentShape·Button 단독 hit area, 접근성 label/value/action·focus·undo를 연결한다.
- 검증: 메뉴 tap으로 완료되지 않음, 행 중앙과 ±/시간 각각 의도한 동작 하나, 기록 후 상태/undo/초점, 큰 글씨 한 열.

### Step 3: 기록 시각화와 관리

- 동일 수동 snapshot에서7일건수·28일패턴·주간요약을 파생한다. 생성 전/무기록/부분값/목표 변경/보관/미래/auto를 구분한다.
- 기존90일/주월 차트는 상세에서 적절한 기준 문구와 함께 보존하고 신규 루트와 상충하지 않게 정리한다.
- 전체관리·편집·순서·알림·보관·복원·조기완료·건너뜀은 실제 운영 경로에 연결한다.
- 검증: 같은날 중복로그 dedup,7일/28일 일치,필터 변경 시 전체 Hero 불변,미루기 양쪽 목록 반영.

### Step 4: 번역·네이티브 검증과 실제 맵

- 새 문자열 en/ko/ja,formatter 전/후/빌드 후 `--check`.
- `scripts/build-ios.sh`, 관련 `scripts/test-unit.sh`, 변경 범위 기반 UI plan을 먼저 확정하고 `scripts/test-ui.sh`로 영향 suite만 실행한다.
- worktree 소유 전용 기기·직렬 runner·deadline·동일원인 조건부1회 제한 준수. 전체 회귀로 자동 확장하지 않는다.
- L01과 실제 수정된 폼/관리/이력 screen ID를 inventory에서 확인하고 iPhone/iPad/Duo·큰 글씨·밝음/어두움의 영향 상태를 새캡처한다. UI통과와 육안검토/실제맵 동기화는 별도 확인한다.
- Today/Watch와 공유한 모델/라우트가 바뀌면 해당 소비자 검증을 추가한다. Watch의 독립UI를 변경하지 않으면 Watch 캡처를 무의미하게 늘리지 않는다.

## Edge Cases

| 경우 | 처리 |
|---|---|
| 습관 없음/보관만/auto-only/오늘0 | —와 상태별 행동, 가짜0/0·예시수동목록 없음 |
| 필터0개 | 전체보기,Hero/다른구획 분모 변화 없음 |
| 주간 목표 완료일·오늘 부분값 | 주간/오늘 각각 표시,하루 중복1일 |
| 첫완료 대기·미래·미룸·skip·early | 기준일/로그 의미 보존,오늘 대상 판정과 별개 행동 |
| 잘못된 값·NaN·Inf·상한·빈값 | 저장 전 검증,기존값/이력 보존,오류 인라인 |
| 과거 목표/보관/긴interval | 현재설정 기준 한계,역사분모/확정 개선률 금지 |
| auto pending/누락/오류 | 원천 상태metadata로 구분,권한 추측/0대입 금지 |
| 다중 기기 동기화·자정 | stable ID·원자적 변경·Calendar 주/일 경계 테스트 |
| 큰글씨·긴번역·Duo 폭변경 | 자연높이·외부수치·단일열·읽기순서 |

## Testing Strategy

이번 시안 단계는 브라우저 배치·상태·상호작용 검증과 PNG 육안검토,테마맵 생성/동기화·문서링크 확인을 수행한다. 앱 빌드/시뮬레이터/UI suite/새실제맵 캡처는 앱 변경이 없으므로 실행하지 않는다. 브라우저100%를 native accessibility 합격으로 표현하지 않는다.

후속 구현은 위 Step의 의미있는 unit/UI 검증을 수행한다. 수치상한·로그보존·기간/스케줄·순서/단위/소스 검증이 단순 스냅샷보다 우선이다. 일반기기 native 상태 capture와 최대글씨/긴번역은 서로 대체하지 않는다.

## Risks

| 위험 | 대응 |
|---|---|
| 예쁜시각화가 잘못된 과거 분모를 확대 | counts 우선·현재설정기준·정확한역사 별도 계획 |
| 범위밖 입력으로 기존로그 삭제 | Step1 최우선 fix + 회귀 |
| 자동기록의 미지원source/잘못된unit | exercise-only,workout횟수,로컬+HK 출처 |
| 완료후 재배치/메뉴와행 충돌 | 분리된Button·focus·undo·실제 tap state 확인 |
| 앱전역/데이터스키마로 범위확장 | Life presentation 중심·공유소비자만 검증 |

## Confidence Assessment

시안·분류·기존source 조사 신뢰도는 높음. 실제 SwiftData 저장/CloudKit 동시성,Native VoiceOver,HealthKit 원천 상태,역사 목표분모는 후속 구현/검증이 필요하다. 사용자가 구현을 선택하기 전에는 이 문서를 implemented로 바꾸지 않는다.

## Proposal verification

최종 결과는 `docs/design/theme-map/themes/assets/life-redesign-qa.json`의 소스SHA256과 일치하는 범위만 인정한다. 샌드박스에서 Chrome launch가 종료돼0건으로 중단된 초기 실행은 성공 근거가 아니다. 로컬 시안에 한정한 실행 권한으로 브라우저 검증을 진행한다. 구체 결과·수정 원인·캡처 범위는 최종 실행 후 아래에 기록한다.


### 초기 통합 시안 확인 · 2026-10-28

- 브라우저80개 배치(2방향×5폭×4글씨×2밝기),14개 추가 상태,18개 동작/정합성 검사 통과. JavaScript runtime error0건. 시안 PNG12장 보존. 이는 브라우저 시안 검증이며 네이티브 테스트가 아니다.
- 초기41px 필터를44px로 수정하고 닫힌 완료 그룹의 버튼을 포커스 대상에서 제외했다. 완료 후 제목 포커스와 undo를 확인했다. 해당 실패를 원인 수정 없이 반복하지 않았다.
- 1차 육안 확인 후 iPad의 반쪽 습관 목록을 전체 폭 가로 행으로 고치고 카드 높이를 자연 높이로 변경했다. 해당 최종 소스로 위 검사를 완료했다.
- Astra의 마지막3개P2(첫 습관 추가 후 숨김/없는 CTA 목적지,5건 초과 차트 척도,완료 cycle 미루기)는 parent가 보완했다. empty/auto-only 추가 후 새 수동 항목 표시,주간 완료를 포함한7건의 공통 차트 척도,완료 cycle 미루기 버튼 제거/handler 방어를 검사했다.
- 최근7일 막대와28일heatmap은 한 날짜 fixture를 사용한다. 주간 기록은 Hero분모와 분리돼도 추세에는 반영된다. 개별history·미루기양방향·count수정/undo·invalid시간보존·새습관·헤더오른쪽빈곳 진입을 확인했다.
- 밝음/어두움 hero·전체·리듬·보고서,320px/200% 전체,iPad전체,빈 상태,402px상단 PNG를 보존했다. 최신 상단·최대글씨·iPad,히어로와다크차트를 육안 확인했다. en/ja전체와VoiceOver,실제HealthKit/CloudKit 저장/알림은 미검증이다.
- 테마맵재생성/--check,관련로컬링크,문서공백과소스해시를 확인했다. .claude/adapter/app 소스 변경이 없어 parity검사·앱빌드·시뮬레이터·actual재캡처는 대상이 아니다. 디자인 제안 단계이므로 merged implementation을 기준으로 하는 solution문서는 만들지 않았다.
- 초기 통합 source SHA256: `aae842cf29e33902b459ea9cb65693955013bf5a2e1bdd9535c650f226a0089d`. 아래 사용자 보완 후의 최신 해시/검증과 구분한다.


### 문장 축약·히어로 수치 강조 보완 · 2026-10-28

사용자 첨부 이미지의 지적을 반영했다. 히어로에서 장문2개·하단중복요약·구분선·아래이동버튼과scroll handler를제거했다. 골드그라데이션104px링의2/5완료와기본64px의3남음만강조한다. 대상0개에는짧은상태와—를보이고추가는상단+에서만한다. 바로아래목록제목의중복남은수,주간/자동/리듬/보고서의불필요한안내도줄였다. 날짜·단위·출처·현재등록습관기준은유지한다.

최신브라우저검증:80배치·14상태·19동작통과,13개새시안PNG,JavaScript오류0건. 기본히어로200px미만·히어로버튼0개·기본/큰글씨수치·자동전용/빈상태에서상단추가를확인했다. 밝음/어두움/200%히어로와최신상단을육안확인했다. 앱소스/actual화면은변경하지않았다.

문장 축약 당시 source SHA256: `d7a7463ecf8e45607600df298b33d6f6ec89362f4b719b78e262db7be608911c`. 이전통합시안의수치/해시는이력이며현재근거로대체하지않는다.


## 추가 범위: 지난 날짜 기록 · 2026-10-28

사용자가 지난 날짜에 누락한 습관을 추가하는 경로를 요청했다. 기존 시안/계획의 후속 개선으로 [L-P01 폼 계약](../design/layout-map/habit-past-record-proposal.md)을 통합한다. 날짜 인자를 받는 VM 생성 함수와 HabitLog.date/completedAt는 존재하나 이력 UI는 조회 전용이다. 이번 작업은 시안에서 경로·입력·결과를 구체화하며 앱 구현은 후속이다.

추가 예정 파일은 `DUNE/Presentation/Life/HabitPastRecordSheet.swift`(또는 동등한폼),`LifeView.swift`/`LifeViewModel.swift`/`HabitManagementView.swift`의 라우트·선택날짜별 upsert·검증·이력refresh,관련 단위/UI 및 번역이다. 순서는 검증/원자적저장→폼/진입→주간/히트맵/주기와알림재계산→관련native검증/실제맵이다. 과거수동기록의원천을유지하고 같은날총합을덮어쓸때기존로그를검증전에삭제하지않는다. 자동도전은선택대상에서제외한다.

시안은 오늘목록/더보기/이력에서 진입하고 습관·날짜·그날총값을 저장한다. 이미3잔인날을8잔으로수정하면8잔으로표시하며 재저장도중복집계하지않는다. 보통의일간은오늘상태불변,주간은해당주완료일재계산,반복은다음예정일미리보기/오늘대상재분류와undo를제공한다. 과거기록추가후정확하지않은연속4일고정문구는제거하고 보고서에실제해당주의완료일수를표시한다.

native회귀는 등록전/미래·같은날재저장·부분기록/단위·날짜별원자성·중복탭/동기화·주경계·최신완료기준·skip/snooze충돌·알림재예약/취소·원천/생성일제한을포함한다. 시안검증은새폼폭/큰글씨·저장전검증·일간오늘보존·주간/반복/undo와역사막대정합성에한정한다.


### 지난 기록 시안 검증

최신92배치(루트80+새폼12),14상태,24동작검사통과. 15개시안PNG와0JavaScript오류를확인했다. 날짜범위/수치거부후기존값보존,어제3→8잔수정후오늘4잔유지/어제완료건수+1,동일날짜재저장중복방지,주간안부완료일1→2재계산,10.27화분완료→11.03예정/undo를확인했다. 새폼320/402/1032폭·100/200%·밝음/어두움에서가로넘침과44px미만조작없음. 새폼/저장후선택이력/상단진입PNG를육안확인했다.

원본 시안/테마맵/레이아웃맵과별도L-P01계약을동기화했다. 네이티브저장·CloudKit·알림·앱캡처는미실행이며기존앱에기능추가완료로표시하지않는다. 최종 source SHA256: `92e4ad926bdd7c77ab78ab3f3e1b8f59e37cff042260658a68e2c83df00e27ee`.


## 오늘의 실천 카드 표현 보완 · 2026-10-28

새동작추가없이시안의today구획을개선했다. 큰line아이콘/목적별색/습관별카드·큰기록값·진행막대·8잔물방울,한묶음필터와짧은시간대라벨을사용한다. native구현은HabitRowView/루트그룹표현범위에서DS/AppTheme/SFSymbol을재사용하고공유카드기본값을변경하지않는다. 물방울은장식progress이며기존44pt버튼/원천수치가조작을소유한다. 반복경과일은고정1일문구대신실제예정일에서계산한다. 새기록/지난기록/시간수정/완료취소/필터/주간/주기계약은변경하지않는다.

최신카드표현검증:92배치·14상태·24동작통과,17개시안PNG,0JavaScript오류. 물4→5→3잔에서물방울수와값일치,기존지난기록/수정/완료/undo/주간/주기동작을확인했다. 밝음/어두움의오늘구획과iPad가로행을새PNG로육안확인했다. 앱미적용. Source SHA256: `eedeca8714bd990e168f183c9a00228c330720dec630935953c485e4ad947ba9`.


## 히어로 시각 강화 · 2026-10-28

추가요청으로골드능선장면/금속링의안쪽디스크/완료상태를따르는습관메달을시안에추가했다. 메달최대5개와초과개수는오늘수동습관에서파생하고보상데이터를새로만들지않는다. 큰글씨는메달숨김,무기록은무메달,짧은수치/버튼없음계약을유지한다. native예정파일은Life히어로의feature전용표현이며공유링의기본기하를변경하지않는다. 기존3탭의색/링언어는유지하고장식은정적으로둔다.

히어로시각강화최종검증:92배치·14상태·24동작통과,17개최신시안PNG,JavaScript오류0건. 작은폭검사에서배경SVG능선/원경끝점이경계밖으로이어지는것을발견해경로를0–400범위로수정했다. 정상5개습관/완료2개메달,화분완료후3개메달,104px링·200px미만기본높이·큰글씨수치·히어로버튼없음을확인했다. 최신밝음/어두움/200%히어로를육안확인했다. 이전수치형heroPNG2장은비교이력으로따로보존했다. 앱미적용. Source SHA256: `bc1353252e58207a6b9defe3d0971327e9e217c6725af30bae660051e2323030`.
