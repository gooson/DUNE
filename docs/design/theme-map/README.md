---
tags: [design, theme, visual-direction, animation, archive]
date: 2026-10-17
category: plan
status: in-progress
---

# DUNE 테마 맵

[테마 맵 열기](index.html) · [8개 테마 전체 구현 맵](../full-redesign-map/index.html) · [7개 테마 앱 적용 맵](app-contract.md) · [UX·비주얼 명세](../2026-10-17-ux-visual-spec.md) · [실제 화면 디자인맵 열기](../phone-design-map/actual/index.html)

[4탭 레이아웃 기준맵](../layout-map/index.html)은 배치와 정보 순서의 별도 기준이다. 이 테마 맵은 색·장면·링·움직임을 정의한다.

2026-10-17까지 논의한 **8개 테마 방향 시안**과 공통 능선 표현 연구안을 저장소에 보존한다. 이 자료는 움직이는 디자인 제안이며 앱의 현재 구현이나 실제 시뮬레이터 캡처가 아니다. 시안의 컨디션 수치와 문구는 예시다.

2026-10-19 [전체 디자인 개편 맵](../full-redesign-map/index.html)은 이 8개 시안을 앱의 4탭과 전체 화면군에 구현하기 위한 새 목표다. 기존 `app-contract.md`는 7개 구현 테마의 당시 적용 기록이며, WATER LILIES는 새 맵에서 구현 대상으로 확장했다. 시안 자체가 구현 완료를 뜻하지 않는다.

2026-10-24 시안 방향을 실제 SwiftUI 앱·WidgetKit에 반영했다. [새 실제 화면 전후 비교](../full-redesign-map/review/desert-horizon-final-2026-10-24/index.html)에는 캡처별 기기·소스·테스트를 기록하고 [구현 검증 보고서](../../reviews/2026-10-24-desert-horizon-final.md)에서 완료·진행·미검증 범위를 구분한다. 아래 HTML은 계속 방향 시안이며 실제 캡처가 아니다.

2026-10-24 DESERT HORIZON은 [4탭 전체 배치 시안](themes/dune-final-four-tab.html)을 현재 방향으로 보존했다. 상단 능선은 [초기 방향 시안](themes/dune-design-direction.html)의 비대칭 곡선을 유지하고 화면 전체 배경 그라데이션에 녹아든다. 카드 아래에서 갑자기 끝나거나 큰 원호로 보이지 않게 한다. 첫 카드 아래에도 날씨·습관·지표 아이콘, 목적에 맞는 작은 링과 기간이 표시된 그래프를 배치했다. Activity에는 앞·뒤 전신 근육 지도와 회복/볼륨 선택을 두고, 지도 아래에 회복됨→피로 또는 주간 세트 수 범례를 표시한다. 그 옆 또는 아래의 이번 주 운동은 실제 앱의 훈련 볼륨·칼로리·운동 시간·활동일 4개 통계 카드와 제공되는 이전 기간 대비 변화값을 유지한다. 추천 운동은 검색, 헬스장/집·장비, 부위별 운동 카드, 추천 루틴, 내 템플릿, AI 운동 만들기와 전체 운동의 실제 순서를 복원했다. 주간 보고서에는 운동 횟수·활동일·볼륨·기간 대비 변화뿐 아니라 주요 근육군, 요약 문장과 최대 2개 하이라이트를 담는다. 개인 기록은 근력·유산소 최고 기록을 최대 8개 2열 카드로 복원하고 레벨·배지·포인트와 값·단위·날짜·출처를 함께 표시한다. 운동 페이스는 현재·최고 연속 운동 일수와 월간 목표 진행률을 구분해 보여 준다. 운동 구성은 근력/유산소 비율과 주요 근력 부위를 요약에 두고, [상세 배치안](../layout-map/exercise-mix-detail-proposal.md)에 따라 주별 구성·부위별 세트 환산 비율·유산소 종류·운동별 횟수를 펼친다. 네 탭 바에도 실제 앱의 심장·기록지, 불꽃, 잎, 체크리스트 아이콘을 표시한다. Today 상단의 알림·설정과 알림함 안의 새로운 소식은 [알림함 배치안](../layout-map/notification-inbox-proposal.md)에 따라 조작할 수 있다. 시안 안에서 탭별 기존 실제 캡처와 목표 화면, 카드별 변경점도 비교한다. Duo 펼침은 실제 내부 화면과 같은 951×669pt 가로 비율이며 해당 가로 캡처와 대조한다. 마지막 섹션까지, 밝음·어두움, 기기 폭, 큰 글씨, 기록 없음·일부 누락 상태를 확인할 수 있다. 상세 배치와 실제 앱 차이는 [레이아웃 계약](../layout-map/desert-horizon-final.md)에서 추적한다.

Activity·Wellness·Life의 기록 추가 행동은 [상단 내비게이션 배치안](../layout-map/record-entry-navigation.md)에 따라 각 탭 제목 오른쪽으로 모았다. 준비도 히어로, 웰니스 본문, 습관 없음 히어로의 중복 버튼을 시안에서 제거하고 상단 더하기로 진입 화면을 열 수 있다.

Activity 추천 운동의 검색·설정·운동 카드 묶음은 iPhone과 Duo 접힘 화면 안쪽 너비에 맞춘다. 운동 이름은 카드 안에서 줄을 바꾸고 추천 루틴·내 템플릿만 각 목록 안에서 가로로 스크롤한다. 본문 전체의 가로 스크롤은 막는다.

Wellness 시안에는 첫 카드의 7일 점수 흐름과 실제 수면 막대의 기간을 두고, 신체·활성 지표를 2열 카드와 표본별 작은 추세 그래프로 복원했다. BMI처럼 표본이 없는 지표는 점선 자리를 보이며, 신체 기록 내역에는 더 긴 30일 체중 그래프를 둔다. 일부 신체 데이터가 빠지면 해당 카드만 숨긴다.

숫자 위주 카드의 변화도 볼 수 있도록 Today 스마트 인사이트에 안정 심박 14일 추세를, 하단 지표에는 HRV·안정 심박·체중 선 그래프와 걸음·운동 시간·수면의 7일 막대를 더했다. Activity 이번 주 운동에는 7일 운동 시간 분포를, 주간 보고서에는 각 7일의 훈련 볼륨 비교를 둔다. Life 운동 성취는 운동한 요일을, 주간 보고서는 이전 7일·최근 7일 습관 완료 수를 비교한다. 모든 그래프에 기간·값·단위를 함께 두며 기록 없음 상태에서는 표시하지 않는다. 일부 누락 예시에서는 해당 Today 체중 카드도 숨긴다.

그 밖의 기본 카드와 기록 없음 상태도 최종 화면 형태로 채웠다. Today의 어제 요약·걸음/수면 진행·날씨/코칭·저녁 요약·고정 지표·건강 Q&A, Activity의 부상 요인·최근 운동·달성 이력·운동 페이스, Wellness의 Watch 자세 지표·평가 기록·활성 부상, Life의 종류별 습관 입력·자동 운동 목표·완료 달력·보고서가 각각 구체적인 값과 행동을 보인다. 상단 추가 메뉴에서 여는 운동·신체·부상·자세·습관 화면에는 목적지별 입력 배치를 둔다. 기기 프레임 안의 구현 설명 문구는 제거했다.

Activity 운동 페이스는 10/16 목표 링의 안쪽 여백과 설명 열을 넓히고, 링 아래 진행 막대 및 요일 표식 사이에 간격을 둔다. 큰 글씨에서는 링과 설명을 세로로 쌓는다.

[휴식 라이브 액티비티·점수 위젯 추가 시안](themes/dune-widget-live-activity.html)은 현재 `DUNEWidget`의 표시 내용을 기준으로 잠금 화면, Dynamic Island 세 상태, Watch Smart Stack small과 DUNE Today small·medium·large, 선택형 DUNE Score small·medium·large·세로 크기를 배치한다. 밝음·어두움, 점수 일부 누락·전체 누락, 휴식 시간 예시를 전환할 수 있다. 이것은 코드 기반 제안 시안이며 실제 기기 캡처는 [별도 증거 목록](../live-activity-captures/README.md)에서 추적한다. 화면 순서와 차이는 [보조 화면 레이아웃 맵](../layout-map/widget-live-activity-proposal.md)에 기록했다.

Small 위젯의 세 점수 링과 하단 상태·시각은 카드 전체 높이의 위아래 영역에 배치한다. 하단 행은 절대 위치를 쓰지 않아 점수 링이나 C·R·W 레이블과 겹치지 않는다.

| 테마 | 시안 | 핵심 표현 |
|---|---|---|
| DUNE | [Desert Horizon](themes/dune-final-four-tab.html) | 세 겹의 흐르는 모래 능선, 공통 링과 4탭 정보 위계 |
| OCEAN | [Ocean Current](themes/ocean-cool-direction.html) | 두꺼운 밝은 포말과 교차하는 해류 |
| FOREST | [Forest Canopy](themes/forest-green-direction.html) | 안개와 깊은 숲 능선, 금빛 링 |
| SAKURA | [Spring Haze](themes/sakura-calm-direction.html) | 벚꽃 군집과 얇은 가지, 적은 꽃잎 |
| ARCTIC | [Aurora Drift](themes/arctic-dawn-direction.html) | 고요한 배경 위로 이동하는 오로라 |
| SOLAR | [Solar Pulse](themes/solar-pop-direction.html) | 고정된 태양 코어 주변의 빛 궤적 |
| CONTOUR | [Contour Field](themes/contour-atlas-direction.html) | 석회색 지형과 호흡하는 등고선 |
| WATER LILIES | [Lily Reverie](themes/water-lilies-direction.html) | 푸른 수면, 겹친 초록 붓질, 작은 보랏빛 꽃점 |

[공통 능선 표현 연구안](themes/theme-crest-language.html)은 초기 시각 언어 탐색으로 별도 보존한다. 수련 시안은 현재 방향으로 두고 세부 표현은 추후 개선하기로 했다.

## Today 하단 읽기 위계 (2026-10-25)

[원본 대비 V1·V2 시안](themes/dune-today-reading.html)을 보존했다. V2의 큰 수면 시간·분리된 수면 부족·접히는 스트레스 근거·지표형 요약을 실제 앱에 적용했으며 [실제 화면 갤러리](../full-redesign-map/review/today-reading-v2-2026-10-25/index.html)와 [구현 계획](../../plans/2026-10-25-today-reading-v2.md)에서 검증 범위를 추적한다. 이 HTML과 시안 PNG는 실제 앱 캡처가 아니다.

## 갱신 방법

2026-10-26 [Today 재설계 세 방향 시안](themes/dune-today-restart.html)을 추가했다. 기존 DUNE 테마를 유지하며 Today 전체를 Compact, Metrics, Editorial로 비교하며, 글자 확대가 패딩과 그래프를 함께 확대하지 않도록 설계했다. [배치와 범위](../layout-map/today-restart-proposal.md)에 원인·데이터 계약·남은 범위를 기록한다. 신규 테마 구현이나 실제 앱 캡처가 아니며 방향 승인 전 제안이다. [편집 원본](themes/assets/today-restart-fragment.html)을 보존한다.

테마의 색, 능선·배경, 링, 그래프, 움직임, 화면별 표현을 바꿀 때 **같은 작업에서** 아래를 갱신한다.

1. `themes/`의 해당 HTML을 수정하거나 새 시안을 복사한다. 이 저장소 안의 파일을 보존본으로 취급한다. 대화용 시안 파일을 따로 수정했다면 최신 내용을 다시 복사한다.
2. `manifest.json`에서 설명·색상·수정일을 갱신한다. 새 테마라면 항목을 추가한다.
3. `python3 docs/design/theme-map/build-theme-map.py`를 실행해 `index.html`을 재생성한다.
4. `python3 docs/design/theme-map/build-theme-map.py --check`로 동기화를 확인하고, 맵에서 해당 시안과 비교 화면의 링크·움직임을 확인한다.
5. 테마 목록이나 방향이 바뀌면 이 README의 표와 결정 상태도 갱신한다.

앱 화면에 테마를 **구현하거나 변경**했다면 별도로 [실제 화면 디자인맵 갱신 절차](../phone-design-map/README.md#화면-수정-시-갱신)를 수행한다. 방향 시안은 실제 앱 화면의 증거로 사용하지 않는다.

`index.html`이 실제로 여는 맵이다. `template.html.in`은 생성용 원본이고, 옛 `template.html` 주소는 `index.html`로 이동한다. 생성된 맵은 스크립트가 실행되지 않아도 테마 목록과 첫 시안, 각 원본 링크를 표시한다.

### 실제 구현 검증 상태 (2026-10-24)

앱·Widget·Live Activity 소스 구현과 통합 빌드, 영향 단위 테스트58개는 완료했다. iPhone·iPad·Duo 접힘의 대표 UI와 WidgetKit3family 및 Rest/Watch Notification Center를 확인했다. Duo 펼침 Today의 최신 상단은 표시 컨트롤러가 세로로 남아 검증 대기이며, Mac 잠금 해제 후 Device Hub 확인이 필요하다. 사용자는 2026-10-24 “일단 넘어가”로 해당 Duo 검증 보류 후 진행을 지시했다. 펼침 Today는 계속 미검증이며, 나머지 검토·PR·머지는 이 예외를 명시해 진행한다. [검증 기록](../../reviews/2026-10-24-desert-horizon-final.md)을 기준으로 한다.

## Activity·Life 히어로 승인안 (2026-10-25)

[흐름과 근거·핵심 요약 시안](themes/dune-activity-life-heroes.html)의 흐름과 근거를 사용자가 승인했다. [구현 계획](../../plans/2026-10-25-activity-life-hero-rhythm.md)에 따라 저장된 준비도와 수동 습관 완료 기록을 사용한다. 과거 습관 대상 수는 복원하지 않는다. 방향 시안은 예시이며 실제 캡처와 구분한다. [편집 원본](themes/assets/activity-life-hero-fragment.html)을 보존한다.

## Today 세 시안 동시 비교 (2026-10-26)

[Compact·Metrics·Editorial 나란히 비교](themes/dune-today-comparison.html)를 추가했다. 테마·내용은 기존 제안을 유지하고, 세 전체 화면을 한 줄로 배치한다. 대화에서는 글씨·기록 상태·시간대·언어를 공통으로 변경할 수 있다. 좁은 창은 화면 글씨를 축소하지 않고 비교 영역을 좌우로 이동한다. 세 화면의 세로 스크롤은 한 페이지에서 함께 진행한다. [편집 원본](themes/assets/today-comparison-fragment.html)과 [비교 화면 검사](themes/assets/today-comparison-qa.json)를 보존한다. 실제 앱 화면은 아니다.

## Today Compact 선택·링·간격 확정 (2026-10-26)

사용자는 Today에 Compact를 선택했다. [구현 계획](../../plans/2026-10-26-today-compact-layout-and-ring.md)을 추가했고 시안 링의 원형/중심/0·100점과 큰 글씨 전환을 바로잡았다. CONDITION은 같은 카드 상단에 유지한다. 아이콘–수치4–6pt, 링–설명12pt를 기준으로 불필요한 공간을 줄였다. [수정 캡처](themes/assets/today-compact-ring-fixed.png)와 [전후 측정·한정 검증](themes/assets/today-compact-ring-qa.json)을 보존한다. 브라우저 파일은 시안 보존본이다. SwiftUI에는 Today 전용 104pt 링·조밀한 지표·수면·스트레스·목표 카드를 구현했으며, 네이티브 빌드와 기기별 실제 화면 검증을 진행하고 있다. 고정 편집 중앙 터치·선택·저장·홀수 전체 폭 검사는1/1 통과했다. [새 네이티브 화면](../full-redesign-map/review/today-compact-2026-10-26/index.html)을 보존했으며 최종 Today 관련21개가 통과했으며 전체 상태 검증과는 구분한다.

## Activity 전체 개편 두 방향 (2026-10-26)

[Activity Compact / Training](themes/dune-activity-redesign.html)을 추가했다. Today에서 선택한 Compact의 DUNE 브라운·골드·능선·104pt 링·낮은 플롯·큰 글씨 외부 점수를 이어간다. Compact는 현재 정보 순서를 보존하고 Training은 추천 운동/최근 운동을 앞당기며 분석을 펼침으로 두며 달성 이력은 독립 카드로 표시한다. [레이아웃과 실제 데이터 의미](../layout-map/activity-redesign-proposal.md), [편집 원본](themes/assets/activity-redesign-fragment.html), [브라우저 한정 검증](themes/assets/activity-redesign-qa.json)을 함께 보존한다. 7개 기록 상태와 휴식일·밝음/어두움·폭·글씨를 비교하는 제안이며 어느 방향도 아직 승인/앱 적용 상태가 아니다. 실제 앱 화면맵과 시뮬레이터 캡처는 변경하지 않았다.

2026-10-26 Activity 후속 시안에는 `hrv-rhr-grouping` 작업에서 사용자가 승인한 **제목 옆 ›·헤더 전체 터치**를 반영했다. 하단의 중복 상세 링크를 없애고 달성 이력은 두 방향에서 최근 3개 이벤트와 날짜·포인트를 가진 독립 카드로 보여 준다. 준비도 구성 점수도 항목별 구획으로 분리했다. 이 반영은 방향 시안이며 다른 워크트리의 앱 구현을 완료로 표시하지 않는다.

2026-10-26 후속 요청으로 Activity 개인 기록의 금빛 표면·메달·최고 기록 표시와 이전 최고 대비 개선을 강화했다. 첨부된 HRV/수면/회복 구성 점수는 같은 100점 척도의 가로 막대 3개로 바꿨다. 수면 누락에서는 `—`를 유지하고 큰 글씨는 막대를 다음 행 전체 폭으로 둔다. 제목 헤더·달성 이력 기준은 유지하며 개인 기록·보상·날짜는 계속 예시다.

Activity 후속 요청으로 근육 회복 카드의 3D 진입을 두 방향 모두에서 제거했다. 제목 헤더 상세와 회복/볼륨만 유지한다. 앱의 3D 소스 변경은 포함하지 않는다.

Activity 근육 지도 아래에는 카드 전체 폭의 **회복됨 → 피로 10단계 범례**를 추가했다. 앱의 밝음/어두움 피로도 팔레트와 지도 색을 맞췄고, 볼륨 모드에서는 0 / 1–5 / 6–10 / 11–15 / 16+ 세트의 다섯 단계로 바뀐다. 큰 글씨의 볼륨 범례는 한 열 목록으로 표시한다.

Activity 훈련 부담 카드는 수준·짧은 해석·기간과 함께 주간 훈련량 변화, 연속 운동일, 근육 회복의 세 관측값을 바로 표시하도록 보강했다. 수면/준비도 누락 안내도 구분한다. 관측값과 부담 기여 요인은 다르게 표시하며, 예시에서 실제 조건에 미달하는 +12%/1일을 위험 요인으로 부르지 않는다.

Activity 훈련 부하의 마지막 운동 시간·칼로리는 큰 숫자, 타이머·불꽃 아이콘과 금빛·구릿빛 표면으로 강조했다. 최근 28일 부하 그래프와 기간을 분리해 표시하며 값·단위·기존 상세 경로는 유지한다.

Activity 주간 보고서는 +12%/12,480kg의 금빛 강조 영역, 3회·3일·142분, 주요 부위/달성 하이라이트로 보강했다. 최근 운동에는 5K·PR·연결된 보상 배지, HealthKit 연동 표시와 값이 있는 평균 심박을 추가했다. 연결 표시와 실시간 동기화 상태를 혼용하지 않으며, 심박이 없는 수동 기록에는 숫자를 만들지 않는다.

## Activity Flow · 전체 정보구조 자문 (2026-10-26)

사용자 요청으로 Astra 자문과 Gentler Streak·Hevy·Athlytic·Garmin의 공식 자료를 대조해 **상태→운동 선택→기록·성취→누적 분석**의 Flow를 추가했다. 현재 기본 비교안이며 Compact/Training도 유지한다. [카드별 순서·명칭·원천 계약과 출처](../layout-map/activity-information-architecture-study.md)를 따른다. 시간/칼로리는 최근 운동일 합계, 운동 꾸준함은 월 목표/연속일, 근력 볼륨은 kg, 근육 모드는 세트 수, 구성은 최근28일로 명확히 했다. 주간 통계/보고서는 원천이 달라 바로 합치지 않으며 앱 소스는 변경하지 않는다.

Activity 운동 구성은 덤벨·발자국, 큰 68%/32%, 금빛/녹색의 16px 구성 막대와 주요 근력 부위 태그로 강조했다. 기간은 최근28일, 비율의 기준은 운동 횟수로 유지하며 값을 새로 산정하지 않는다.

## Activity 최종 통합안 (2026-10-26)

[최종 한 화면](themes/dune-activity-final.html)에 현재 Flow의 12개 카드와 모든 후속 피드백을 통합했다. 선택용 캐러셀 없이 전체 흐름을 읽으며, 앞선 세 방향 비교본은 따로 보존한다. [최종 요약/계약](../layout-map/activity-final-proposal.md), [편집 원본](themes/assets/activity-final-fragment.html), [브라우저 검사](themes/assets/activity-final-qa.json)를 함께 보존한다. 최종 제안이며 네이티브 앱 적용 완료를 의미하지 않는다.

최종안의 HealthKit 표시는 기존 앱처럼 작은 분홍색 Apple 마크만 남겼다. 텍스트 칩과 회전 아이콘을 제거하고 접근성 설명을 유지했다. 이전 비교본의 표시는 당시 시안으로 보존한다.

최근 운동의 달성 배지는 금속 질감의 리본 메달로, PR은 더 밝은 골드 트로피와 작은 빛 아이콘으로 강조했다. 문구와 실제 달성 의미는 유지하고, 반복되는 반짝임 애니메이션은 사용하지 않는다.

각 탭의 히어로 제목도 [공통 표기 계약](../layout-map/hero-heading-style.md)에 따라 CONDITION·READINESS·WELLNESS·HABITS의 영어 대문자로 통일하는 개편 범위에 포함한다. 현재 Activity 최종 시안의 READINESS가 기준이며 설명은 사용자 언어를 유지한다.

2026-10-27 Activity Flow와 4탭 대문자 제목을 네이티브에 적용했다. [레이아웃 계약](../layout-map/activity-final-proposal.md)과 [새 실제 화면](../full-redesign-map/review/activity-flow-2026-10-27/index.html)에서 현재 앱·검증 제한을 확인한다. 위 시안의 PNG/브라우저 검사와 앱 캡처를 구분하며, 실제 비율은 기록 항목 수 기준이고 원래 DS 범주 색을 따른다.
