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

0 Init completed; 1 Plan completed; 2 Work pending; 2.5 UI pending; 3 Review pending; 3.5 Quality pending; 4 Resolve pending; 5 Compound pending; 5.5 Pre-Ship pending; 6 Ship pending.

Work 사전 검토에서 AX 숫자의 VoiceOver 레이블과 시간대4열·계산행의 큰 글씨 배치를 보완했다. TimeOfDayCard adaptive 옵션은 T04만 사용하며 다른 소비자의 기본 표현은 보존한다. 전체 iOS 단위 실행은 변경하지 않은 live AI 평가에서 실패/정체되어 owner idle deadline600초로 종료됐다. 관련 Condition 단위 통과는 아직 확인하지 않았으며, 선택 실행용 공통 도구 PR을 별도 작업 폴더에서 준비한다.

첫 iPhone 정상 크기 UI는3개 중 기간/앞뒤/통계/추세 전환1개 통과, 나머지2개 실패했다. 실제 AX에서 설명은 펼쳐져 있었고 Raw Score도 존재했다. DisclosureGroup 전체의 identifier가 자식 식별자를 덮은 원인을 제목 Text에만 식별자를 부여해 해소한다. fixture는 contributions가 비어 있으므로 영향 상태 테스트는 임의 평가 대신 Impact unavailable을 정확히 기대하도록 수정한다. 최초 결과 JSON을 보존하고 원인 수정 후 한 번 재검증한다. 공통 선택 실행기 PR860을 포함한 main을 이 브랜치에 통합했다.

컨디션 VM 선택 실행의 실제 xcresult는20개 통과/실패0/skip0이다. Swift Testing의 `20 tests in 1 suite passed` 형식을 기존 wrapper가 인식하지 못해 wrapper exit1이 된 차이는 focused-unit-result.json에 그대로 보존했다. 출력 파서 보완은 별도 공통 PR에서 진행하며, 같은 단위20개를 불필요하게 재실행하지 않는다.

Duo 펼침의 첫5개 검사 중 Hero·최대AX Hero/설명·기간 전환3개는 통과했다. 기존 두 수치/하위 차트 검사는 화면 아래 항목을 찾는 중앙 드래그가 차트에 소비되어 같은 오프스크린 좌표에 멈췄다. 원본 AX에서 항목 ID·크기는 정상이며 y2274 등으로 남아 있었다. Condition 화면만 좌측 거터 드래그/최대32회로 수정하고 전체 요소 포함 여부·수치·plot 검증은 유지한다. 이 두 실패만 수정 후1회 재검증한다. 새10개 문자열에는 영어 source fallback과 같은 명시적 en 항목을 추가해 en/ko/ja를 모두 등록했다.
