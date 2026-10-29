---
topic: t04-condition-detail-redesign
date: 2026-10-30
status: approved
confidence: high
---

# T04 컨디션 상세 네이티브 개편

## Context / Requirements

검토된 상세 시안을 실제 앱에 화면별 PR로 적용한다. L03은 PR858로 머지했고 이번 기준은60bd7c4b, 브랜치는 codex/t04-condition-detail-redesign이다. 원본 da96 시안과 서버는 보존한다. 이 작업은 T04 하나이며 공통 Today 색상 추출은 값과 root UI를 보존하는 재사용 목적이다.

- 탭과 같은104pt CompactConditionRing과 원래 상태 심볼을 사용하는 강조 히어로. 실제 점수·상태·평가 시점과 narrative를 유지한다.
- HRV/RHR은 실제 ms/bpm, 기존 waveform.path.ecg/heart.fill과 텍스트 영향 상태를 사용한다. 범주형 영향에 임의 수치 막대를 그리지 않는다. 이전 RHR을 표시하면 날짜를 함께 둔다.
- 일/주/월/6개월/년·기간 이동·가로 스크롤·추세선·차트 선택을 한 카드에 모은다. 날짜는 추세 헤더 한 곳에 두고 보이는 구간의 통계를 작게 연결한다.
- 하이라이트, 일간 외 HRV/RHR 하위 추세, 제한된 이력·빈 기록·불러오기·뒤로를 유지한다.
- 계산 상세와 기존 설명을 native DisclosureGroup 하나로 묶고 시스템 chevron/펼침 상태와44pt 조작 영역을 유지한다.
- 시안 예시 값과 미리보기 상태 선택기를 앱에 복사하지 않는다. Watch/다른 상세 화면의 시각 변경은 범위 밖이다.

## Research / Source of Truth

Repo·Solution·Apple UX 조사3개를 실행했다. 관련 해결책은2026-02-28 detail-score-hero-unification,2026-03-14 score-detail-unification,2026-10-19 condition-day-history-hero-alignment,2026-10-29 detail-prototype-feature-parity다. 원본 시안의 manifest T04와 실제 브라우저 배치를 확인했다. Apple Charts/Accessibility/Layout/DisclosureGroup 지침을 참조했다.

현재 summaryStats는 현재 선택 기간, 차트 헤더는 스크롤한 구간이다. 새 통계를 헤더와 함께 표시하므로 원시 일별/시간별 점수를 보관하고 실제 chart visibleDomain의 반열린 구간으로 요약한다. 월별 평균을 다시 평균 내지 않는다. 기존 summaryStats와 하이라이트 계약은 보존한다. 데이터 조회·비동기 requestID 게이트·점수 계산은 바꾸지 않는다.

현재 T04의70/30 비율과 rawScore+rhrAdjustment 표현은 실제 UseCase 계산식과 일치하지 않는다. 새 구성란은 실제 HRV Z-score, signed RHR 조정, 시간 조정으로 표시한다. rawScore는 이미 RHR/time 조정을 포함한다. 시간대 곡선은 공유 helper와 UseCase가 동일하므로 변경하지 않으며 T04 projection에는 rawScore-timeAdjustment를 전달한다.

## Affected Files / Approach

1. Shared/Components/ScoreHeroPalette.swift: Today hero의 기존8개 테마 색상을 그대로 추출한다. DesertHorizonConditionHeroView는 같은 값에 위임하고 기존 탐색/레이아웃을 유지한다.
2. Dashboard/ConditionScoreDetailView.swift 및 Components/ConditionDetailHeader.swift: 강조 히어로·기여 카드·통합 추세·실제 구성값·단일 설명 펼침. Dynamic Type 접근성에서는 세로 배치하고 Reduce Motion을 따른다.
3. ConditionScoreDetailViewModel.swift: raw summary data와 visible summary helper, 현재/최초 경계를 지키는 기간 이동. 기존 chart/history/query/score 결과와 selected-period summary를 보존한다.
4. ConditionCalculationCard.swift: embedded content 옵션은 T04만 사용하고 Wellness 기본 표현은 유지한다. ConditionExplainerSection은 유일한 T04 호출부에서 단일 펼침의 본문으로 재사용한다.
5. ConditionScoreDetailViewModelTests.swift 및 T04 범위 UI 테스트: 통계 경계·이전 비교·빈 구간·집계 전 원시값과 기간 조작/펼침/큰 글씨 회귀를 검증한다. 기존 Condition 구성 테스트의 잘못된 고정 비율 가정만 실제 모델 표현으로 수정한다.
6. T04 레이아웃 계약·시안 데이터 보존본·테마 구현 링크와 네 기기 새 실제 PNG/출처·갤러리/보드·해결책·검증 기록을 갱신한다. 다른 화면과 curated portal 링크는 보존한다.

## Testing Strategy

범위 판정기와 실제 소비자를 대조하고 표준 build/test 실행기를 사용한다. VM 관련 단위 테스트와 Condition history/trend 회귀, 새 T04 조작·접근성 검사를 실행한다. 전용 iPhone/iPad/Duo의 접힘·펼침을 한 runner씩 검증하고 목표 L03에서 사용한 원자적 repository lock/owned UDID 정책을 따른다. 고정 검토 hinge 도구의 exit가 아니라 활성 패널·새 원본으로 Duo 상태를 판정한다. 같은 원인은 수정/환경 변화 후 최대1회 재시도한다.

새 실제 캡처는 밝음·영어의 범위를 명시하며 원본 T04 비교 이미지는 촬영 당시 출처를 보존한다. 공통 팔레트 추출은 기존 Today 값이 동일함을 대조하고 실제 진입 경로도 확인한다. 불필요한 전체 UI·Watch로 범위를 확대하지 않는다.

## Risks / Edge Cases

- sixMonths/year는 plot이 집계되어 있어도 통계는 원시 일별 값으로 계산한다.
- 비어 있는 구간과 이전 평균0은 없는 자료를0으로 생성하지 않는다.
- RHR 미수신/최근값 fallback/기준선 없음은 실제 측정과 비교 가능 여부를 구분한다.
- 긴 날짜·큰 글씨는 컨트롤과 카드를 세로로 배치한다. 카드 밖 장식은 잘라 hit area를 늘리지 않는다.
- 설명 항목·계산행은 제거하지 않고 하나의 펼침 안에서 모두 접근 가능하게 한다.

## Phase Tracking

0 Init completed; 1 Plan completed; 2 Work completed; 2.5 final UI completed (32 unit /15 unique device UI); 3 Review completed; 3.5 Quality completed; 4 Resolve completed; 5 Compound completed; 5.5 Pre-Ship completed; 6 Ship completed (PR862,9fa10e46,cleanup/standardregen/buildPASS).

Work 사전 검토에서 AX 숫자의 VoiceOver 레이블과 시간대4열·계산행의 큰 글씨 배치를 보완했다. TimeOfDayCard adaptive 옵션은 T04만 사용하며 다른 소비자의 기본 표현은 보존한다. 전체 iOS 단위 실행은 변경하지 않은 live AI 평가에서 실패/정체되어 owner idle deadline600초로 종료됐다. 관련 Condition 단위 통과는 아직 확인하지 않았으며, 선택 실행용 공통 도구 PR을 별도 작업 폴더에서 준비한다.

첫 iPhone 정상 크기 UI는3개 중 기간/앞뒤/통계/추세 전환1개 통과, 나머지2개 실패했다. 실제 AX에서 설명은 펼쳐져 있었고 Raw Score도 존재했다. DisclosureGroup 전체의 identifier가 자식 식별자를 덮은 원인을 제목 Text에만 식별자를 부여해 해소한다. fixture는 contributions가 비어 있으므로 영향 상태 테스트는 임의 평가 대신 Impact unavailable을 정확히 기대하도록 수정한다. 최초 결과 JSON을 보존하고 원인 수정 후 한 번 재검증한다. 공통 선택 실행기 PR860을 포함한 main을 이 브랜치에 통합했다.

컨디션 VM 선택 실행의 실제 xcresult는20개 통과/실패0/skip0이다. Swift Testing의 `20 tests in 1 suite passed` 형식을 기존 wrapper가 인식하지 못해 wrapper exit1이 된 차이는 focused-unit-result.json에 그대로 보존했다. 출력 파서 보완은 별도 공통 PR에서 진행하며, 같은 단위20개를 불필요하게 재실행하지 않는다.

Duo 펼침의 첫5개 검사 중 Hero·최대AX Hero/설명·기간 전환3개는 통과했다. 기존 두 수치/하위 차트 검사는 화면 아래 항목을 찾는 중앙 드래그가 차트에 소비되어 같은 오프스크린 좌표에 멈췄다. 원본 AX에서 항목 ID·크기는 정상이며 y2274 등으로 남아 있었다. Condition 화면만 좌측 거터 드래그/최대32회로 수정하고 전체 요소 포함 여부·수치·plot 검증은 유지한다. 이 두 실패만 수정 후1회 재검증한다. 새10개 문자열에는 영어 source fallback과 같은 명시적 en 항목을 추가해 en/ko/ja를 모두 등록했다.

거터 수정 후 하위 HRV/RHR 차트 전체 검사는 통과했고 구성 HRV/RHR 수치도 화면 안으로 이동했다. 새로 도달한 RHR 수치에서 테스트가0.0에도 부호를 요구하는 별도 기대 오류가 드러났다. 실제 AX는 HRV +2.00/RHR0.0/time0.0이며 공통 formatter는 양수에만+를 붙인다. 실제 fixture값 세 개를 정확히 단언하도록 수정하고 이 새 실패1개만 재검증한다. 기존 스크롤 실패를 다시 반복하는 것이 아니다.

## Resolve 검토 반영

공식5관점+SwiftUI/AppleUX/AppQuality에서P2네 범주(RHR미적용0, 고정/달력범위, 작은hit area, deadsummary조회)와P3두개(미사용palette passthrough, 기간전환fade)를확인했다. RHReligibility는DomainrequiredDays를참조하는Presentation공유계산으로2소비자에적용하고Wellness기본표시는유지한다. T04고정window는한참조시점의end에맞추어today를포함하고, full±duration만이동하며query범위는기존달력preload와합집합으로한다. deadsummary와전용2조회제거, highlights/subscore범위보존. actualdateIntervalFormatter로중복연도축약. 세plaincontrols에contentShape를부여하고44pt크기/가장자리탭UI검증추가. P3정리및ReduceMotion을따르는fade복원. 표준generic iOS빌드성공. Data/Architecture/Simplicity정적delta재검토는기존지적닫힘/신규P1P2없음; 관련새단위와영향UI검증은이후실행한다.

Resolve後두suite단위30개가실제통과했다. 신규edge UI첫실행은44pt크기는통과했으나버튼이viewport669밖y922에있어서좌표탭이닿지않았다. 기존공용scrollToElementIfNeeded는존재확인용임을AX로확인, T04test로컬거터reveal에서전체frame/hittable를검증한뒤edge tap하도록수정한다. 다른체크포인트도실제보이는대상을촬영하도록강화했으며이동작실패만원인수정후1회재검증한다.

가시성수정후edge검사는목표컨트롤에실제로도달했지만AX좌표44가43.99999999999994로계산되어새부동소수점기대오류가발생했다. 허용오차0.000001pt만더해44pt기준을유지한다(실제이전8ptglyph는계속실패). 이새원인에대해한번만재검증한다.

최종 새 PNG의 최대AX 요약에서 이전 outer360pt frame과 내부 scaled620pt chart가 충돌해100눈금이 날짜/화살표로 나오는 새P2를 발견했다. 032c68e0에서 T04의 바깥 고정 높이만 제거해 공유 차트의 자체 scaled height가 배치를 결정하도록 했다. 내부 chart-selection-probe의 실제 minY가 날짜·화살표 하단 이상인지 UI 단언을 추가했다. Duo 펼침 정상/최대AX2개 재실행 모두 통과했고, 새 AX는 날짜 하단371.2/차트 시작383.3으로12.1pt 분리됐다. AppleUX/SwiftUI delta에서 기존P2 닫힘·추가P1/P2 없음. 수정전 시각 원본은 review evidence/p2-chart-height-before에 출처와 보존했다. 정상 iPad의 내부 plot220pt는 동일하고 불필요한 outer140pt만 사라진다.

새 차트 footprint가 스크롤 배치에 영향을 주므로 네 기기의 Hero 캡처와 AX·기간·조작·기존 하위 차트 관련15개 고유 UI를 032c68e0에서 마무리한다. 아직 끝나지 않은 선택 검사는 통과로 표시하지 않는다.

최종AppQuality가기여tile의nonemptyneutral contribution경로에서는기존RHR조정eligibility가적용되지않은부분을발견했다. 수정전iPhone7개실행은own xcodebuild82588만부모가TERM해exit143으로중단하고통과로계산하지않았다. abe732c1에서shared conditionImpactForDisplay가RHR에동일한baseline규칙을적용하고label/color가모두gatedimpact를사용한다. 측정/설명/날짜는유지. 부족0/1/6일·fallback·missingdetail 및eligible3종·HRVpassthrough2단위추가. Data/AppQualitydelta는원래RHR P2전경로닫힘·새P1/P2없음확인. 최종32단위(26+6)xcresult가통과0fail0skip임을확인했다. archive의존재하지않는unit sidecar경로가실패한것은실제xcresult에서복구해단위를다시돌리지않았다.

abe최종iPhone7/7와Duo펼침5/6가통과했다. 실패한legacyCondition구성검사는HRV값y752.2–817.9가669ptviewport아래에남았다. 값높이65.7은화면보다작고카드가y599에부분노출된PNG/AX로배치잘림이아닌탐색수렴문제임을확인했다. revealCardContent가AX존재만보고coarse스크롤을건너뛴조건을Condition에서만실제viewport/card교차확인으로고쳤다. 반복한도/전체frame검증/다른화면경로는유지하며실패한1개만원인수정후1회재검증한다. batch5pass/1fail은summary/result/log와실패PNG/AX에보존하며6통과로바꾸지않는다. 이미통과한Hero/AX/기간/edge/하위차트의새원본은개별testPassed및원래batch실패1출처를유지해수집했다.

최종정리:구성검사85.547초통과,접힘1/iPad1통과. `final-validation.json`에서testcase합집합15,32단위0fail0skip,새4기기이미지해시를확인했다. 앱ABE와UI헬퍼EE사이앱/단위코드diff없음. 가상완료나기존PNG의새증거전용없이각출처와원래실패기록을유지했다. Compound해결책을architecture/2026-10-30-condition-detail-redesign.md에저장했다.

Ship완료기록:PR862를검증된HEADbd5605b7로merge하여9fa10e46이생성됐다. 관리worktree만origin/main으로detach하고전용branch의local/remote를삭제했다. 사용자primarycheckout은변경하지않았다. buildcache정리후표준regen/genericiOSbuild가통과했고작업tree는깨끗했다.
