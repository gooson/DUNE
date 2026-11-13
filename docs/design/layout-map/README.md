---
tags: [design, layout, ios, ipados, duo]
date: 2026-10-17
category: plan
status: in-progress
---

# DUNE 레이아웃 맵

2026-11-14 후속 작업은 [T12 수치 강조 계약](notification-message-detail-proposal.md)과 [Watch 시간 우선 유산소 현재 존 계약](watch-cardio-time-zone-proposal.md)을 따른다. 테마 시안과 실제 캡처 검증을 구분한다.

2026-11-05 [H07·P06 자세 기록 상세 배치 계약](posture-record-detail-h07.html)은 저장된 점수 다음에 실제 평가 항목의 값·상태·신뢰도를 두고, Front/Side 사진과 원래 행동을 뒤에 둔다. [정적 DUNE 시안](../theme-map/themes/dune-posture-record-detail-h07.html)은 실제 기록이나 앱 캡처가 아니다. H07·P06의 현재 소스 `1514deb7`에서 네 프로필의 핵심 검사 11건과 실제 PNG/AX 20쌍을 검토했다. [실제 화면과 검증 범위](../full-redesign-map/review/h07-p06-posture-native-2026-11-05/index.html)는 English·Light 및 Duo 0°/180°이며 원래 90° FOLD 실패는 별도로 보존한다.

2026-11-05 [H06 신체 기록 이력 배치 계약](body-history-h06.html)은 기존 날짜·측정값·수동 편집 메뉴·Apple Health 읽기 전용 행을 유지하며, 세 값의 원래 아이콘과 DUNE 신체 색의 캡슐을 한 행 구성요소로 묶는다. 수동 muscle은 Muscle Mass (kg), Apple Health의 HealthKit lean 값은 Lean Body Mass로 접근성 이름을 구분한다. 밝은 화면의 아이콘만 같은 신체 색을 진하게 표시해 두 kg 값의 기호를 읽을 수 있게 한다. [정적 표현 시안](../theme-map/themes/dune-body-history-h06.html)은 예시이며 실제 앱 캡처가 아니다. 검증 완료한 H05 입력 Form과 별개다. 일반 iPhone·iPad·Duo 접힘·펼침의 기존 여섯 사례와 실제 PNG/AX 12쌍은 [H06 네이티브 갤러리](../full-redesign-map/review/h06-body-history-native-2026-11-05/index.html)에서 확인한다.

2026-11-05 [H05 신체 기록 입력·수정 배치 계약](body-record-form-h05.html)은 한 네이티브 Form의 날짜·세 측정 필드·메모·키보드·고정 저장 행동과 큰 글씨 스크롤을 정한다. [DUNE 표현 시안](../theme-map/themes/dune-body-record-form-h05.html)의 값은 설명용이며 새 앱 캡처가 아니다. H05 편집은 같은 ID이고 H06 이력 화면은 별개다.

2026-11-05 [H04 두 지표 기간 비교 배치 계약](wellness-metric-comparison-h04.html)은 하나의 날짜 범위와 두 독립 값 축, 두 네이티브 지표 피커, 다섯 기간·큰 글씨 세로 배치를 정한다. [DUNE 표현 시안](../theme-map/themes/dune-metric-comparison-h04.html)의 값은 설명용이며 현재 소스의 네이티브 캡처가 아니다. [새 실제 화면](../full-redesign-map/review/h04-metric-comparison-native-2026-11-05/index.html)은 유효 사례 5건과 PNG/AX 31쌍을 별도로 보존한다.

A15 피로도 계산 설명은 [전용 배치 계약](activity-fatigue-algorithm-a15.html)을 따른다. 시안은 실제 캡처가 아니다.

A11 운동 일관성 상세는 [배치 계약](activity-consistency-detail-a11.html)과 [테마 시안](../theme-map/themes/dune-consistency-detail-a11.html)을 따른다. 예시이며 네이티브 캡처가 아니다.

H03 수면 예측 상세와 이를 공유하는 T15 알림 수면 상세의 로드 완료 상태는 [전용 배치 계약](sleep-prediction-detail-h03.html)을 따른다. 기존 링·신뢰도·요인·팁을 한 열에서 읽고 큰 글씨에서는 세로로 쌓는다. 이 HTML은 시안이며 실제 앱 캡처가 아니다.

T14 운동 알림의 누락된 대상 화면은 [전용 배치 계약](notification-target-not-found-t14.html)을 따른다. 원래 문구·아이콘·선택 가능한 실제 ID와 시스템 뒤로가기를 보존하며, iPhone·iPad·Duo의 큰 글씨에서도 한 열 스크롤로 읽는다. 이 HTML은 시안이며 새 실제 앱 캡처가 아니다.

2026-10-28 Today 지표의 Wellness 표현과 동일 행 높이는 [상태/배치 계약](today-case-matrix.md), [새 실제 화면](../full-redesign-map/review/today-wellness-metrics-2026-10-28/index.html)을 따른다. 큰 글씨 한 열과 홀수 전체 폭은 유지한다.

2026-10-28 H01 오늘 밤 수면은 큰 예측 점수·달 상징·0–100 가로 게이지와 실제3단계 신뢰도 배지·팁 영역을 사용한다. [배치 계약](wellness-redesign-proposal.md)과 [실제 화면](../full-redesign-map/review/wellness-prediction-visual-2026-10-28/index.html)을 함께 따른다. 큰 글씨는 세로 전환한다.

2026-10-28 H01 최근 수면은 적은 기록에서도7일 날짜 위치와16pt 막대 폭을 유지한다. 누락일은 비워 두고 큰 글씨의 날짜 축은 첫날·중간·마지막을 표시한다. [후속 계약](wellness-redesign-proposal.md)과 [새 실제 화면](../full-redesign-map/review/wellness-sparse-sleep-2026-10-28/index.html)을 따른다. 테마 팔레트·카드·탭 순서는 유지한다.

[4탭 레이아웃 맵](index.html)은 Today(T03), Activity(A01), Wellness(H01), Life(L01)의 정보 순서와 화면 폭·큰 글씨 전환을 시각적으로 정한 **구현 기준 시안**이다. 값과 그래프는 설명용이며 실제 건강 기록이나 앱 캡처가 아니다. 상세·설정·Watch 등 4탭 밖의 화면을 설계할 때는 이 디렉터리에 화면별 맵을 별도로 만들고 아래 목록 및 `index.html`에서 연결한다.

[DESERT HORIZON 4탭 전체 배치 시안](../theme-map/themes/dune-final-four-tab.html)은 2026-10-22 첫 화면 UX와 Wellness 상세 목적지 분리 이후의 첫 카드부터 마지막 섹션까지 카드 구성·문구·행동을 제안한다. 밝음·어두움과 기기 폭·큰 글씨·기록 없음 전환을 제공한다. 알림함 통합, 상단 기록 진입, 운동 구성, 테마 표면은 현재 코드에 반영했으며 [구현 기준과 남은 검증](desert-horizon-final.md)에 상태를 기록한다. 시안과 2026-10-22 캡처는 이번 구현의 실제 캡처나 런타임 합격 증거가 아니다.

[8개 테마 전체 디자인 개편 맵](../full-redesign-map/index.html)은 이 4탭 레이아웃을 모든 테마와 화면군에 적용하는 목표·구현 순서다. WATER LILIES의 신규 테마화도 그 맵에서 추적한다.

미리보기 폭은 이번 실제 캡처 기기의 논리 폭(iPhone 402pt, Duo 외부 세로 466pt, Duo 내부 펼침 가로 951×669pt, iPad 1032pt)이다. 캡처 기기가 바뀌면 표시 폭과 배치 전환을 다시 대조한다.

2026-10-28 현재 Today Compact·Activity Flow·Wellness Flow는 104pt 전용 링을 사용한다. Life는 기존 공유 링을 유지한다. Activity는 실제 준비도 점수, Wellness는 실제 웰니스 점수, Life는 오늘 완료 수/대상 수를 표시한다. 수치가 없으면 빈 상태를 사용하며 임의 점수나 완료율을 만들지 않는다. Wellness 접근성 글씨 크기는 외부 점수와 한 열 근거를 사용한다. 아래 124pt 비교 기록은 2026-10-22 당시의 검증 이력이다.

Today T03의 큰 제목은 시스템 스크롤에 따라 접히고 펼쳐진다. 상단 근처에서 멈춘 부분 스크롤은 그대로 유지하며, 감속 종료를 이유로 자동으로 맨 위에 정렬하지 않는다. 맨 위로 이동하는 프로그램 동작은 Today 탭 재선택처럼 명시적인 사용자 행동에서만 수행한다. 상단 복귀·실제 당겨서 새로고침의 손 해제 중 제목과 첫 카드가 연속적으로 움직여야 한다.

Life의 링 옆에는 현재 진행 상태를 설명하는 문장을 둔다. 히어로에서 개별 습관 3개를 다시 나열하지 않으며, 개별 기록·실행은 아래 습관 목록에 둔다. 히어로의 오늘 행동은 기존 체크리스트로 연결한다.

이 Life 배치는 [2026-10-22 실제 화면 15장](../full-redesign-map/review/life-hero-narrative-2026-10-22/README.md)에서 전용 iPhone 402pt·440pt, iPad, Duo 접힘·펼침의 밝음·어두움·최대 글씨로 확인했다. Today는 카드 전체를 컨디션 상세 링크로 사용하고 탭 전환 버튼을 두지 않는다. Activity는 긴 조회 중에도 주 카드·운동 진입을 표시한다. Wellness는 날짜가 붙은 최근 수면 기록·유효한 7일 평균을 구분하고, iPad에서는 두 열로 배치한다. 신체 기록은 예측 다음에 둔다. 이 세 화면의 [새 iPhone·iPad 실제 캡처 12장](../full-redesign-map/review/first-fold-ux-2026-10-22/README.md)은 별도로 보존했다.

나머지 7개 테마의 Life 기본 글씨도 [전용 iPhone 밝음·어두움 실제 화면 14장](../full-redesign-map/review/life-seven-themes-2026-10-22/README.md)에서 링 옆 설명과 체크리스트 행동을 대조했다. 해당 테마의 다른 기기·접근성 상태를 통과한 것으로 확대하지 않는다.

2026-10-22 전용 Duo 접힘 세로·펼침 가로에서 [4탭 밝음·어두움 실제 배치](../full-redesign-map/review/duo-four-tab-hero-rings-2026-10-22/README.md)를 확인했다. 접근성 프레임은 124pt 원 바깥의 11pt 획도 포함하므로, 테스트는 Today의 실제 링 프레임과 다른 세 탭을 비교한다. Duo 펼침 미리보기는 해당 가로 캡처와 같은 951×669pt 비율이다.

[Activity·Life 히어로 흐름과 근거 승인안](activity-life-hero-proposal.md)은 공통 링에 구성 점수·저장된 준비도·습관 완료 기록을 더하는 2026-10-25 구현 대상이다. 과거 습관 분모는 복원하지 않는다.

2026-10-31 [A07 운동 종류 상세 배치](activity-exercise-type-detail-a07.html)는 실제 유형별 시간·칼로리·세션, 조건부 거리/무게 볼륨, 4기간 분 추세, 건강 앱 최근 세션의 읽기 순서를 제안한다. 수치·도형은 설명용이며 원본 네이티브 Week/Month 캡처는 현재 확인 대기다. [테마 표현](../theme-map/themes/dune-exercise-type-detail-a07.html)은 별도 정적 시안이다.

2026-10-31 [A08 부상 위험 상세 배치](activity-injury-risk-detail-a08.html)는 실제 평가 점수·단계, 공급된 요인과 최대 요인 대비 상대 막대, 원래 권장 문구 및 nil/0점 분기를 구분한다. [DUNE 밝음·어두움 표현](../theme-map/themes/dune-injury-risk-detail-a08.html)은 정적 제안이다. DEBUG 점수42/두 요인은 라우트 검증용이고 원본 네이티브 캡처는 아직 확인 대기다.

2026-10-31 [A09 주간 운동 보고서 배치](activity-weekly-report-detail-a09.html)는 실제 기간·총 kg/분/세션/활동일/정규화 강도와 조건부 요약·하이라이트·근육별 바를 제안한다. [DUNE 테마 표현](../theme-map/themes/dune-weekly-report-detail-a09.html)은 정적 시안이다. 원본 iPad의 DEBUG 보고서 화면은 별도 실제 이미지로 확인됐으며 시안의 값은 그 이미지가 아니다.

2026-11-03 [A10/T16 개인 기록 상세 배치](activity-personal-records-detail-a10-t16.html)와 [DUNE 밝음·어두움 표현](../theme-map/themes/dune-personal-records-detail-a10-t16.html)은 공통 화면의 정적 시안이다. 일·주를 포함한 다섯 기간과 실제 값·원래 아이콘·보상·두 경로를 보존한다. 앱 캡처가 아니다.

## 화면별 맵 목록

2026-10-31 [A06 Training Volume 상세 배치](activity-training-volume-detail-a06.html)는 실제 네 기간·네 현재/이전 지표·1W 주간 목표 링과 긴 기간의 실제 활동일 건수/별도 주간 참고·한 날짜 범위·도넛 세 모드·분 단위 일별 차트와 조건부 하위 그래프를 보존하는 제안이다. HTML 숫자는 예시이며 실제 앱 캡처가 아니다. [구현 계획](../../plans/2026-10-31-a06-training-volume-detail-redesign.md)과 [테마 표현](../theme-map/themes/dune-training-volume-detail-a06.html)을 함께 본다.

2026-10-31 [A03 근육 지도 상세 · A04 3D 진입 비활성화](activity-muscle-map-detail-a04.md)는 2D 선택, compact/regular 배치와 기존 테마 유지 계약이다. 실제 화면 캡처와 구분한다.

2026-10-31 [T13 알림 대상 없음 배치](notification-destination-unavailable-t13.html)는 기존 설명·뒤로 가기·실제 알림 ID를 유지하는 상세 화면의 한 열 계약이다. 정적 시안이며 실제 캡처가 아니다.

2026-10-31 [T09 아침 브리핑 배치 계약](morning-briefing-proposal.md)은 일출 히어로 뒤에 회복·가이드·주간·조건부 날씨를 배치한다. [보존 시안](../theme-map/themes/dune-morning-briefing.html)은 예시로, 실제 앱 캡처와 구분한다.

2026-10-31 [T02 iCloud 동기화 동의 배치](cloud-sync-consent-t02.html)는 앱 시작 시트의 히어로→세 설명→두 선택, 폭·큰 글씨·동작 계약을 정한다. HTML은 구현 기준 시안이며 실제 앱 캡처가 아니다.

2026-10-30 [Siri 건강 정보 질의 SQ01–SQ14](siri-health-queries-proposal.md)와 [기능별 비주얼 시안](../theme-map/themes/dune-siri-health-queries.html)을 추가했다. 최근 운동·주간 운동량·세트·개인 기록·유산소·신체 최신값/추세·수면·컨디션·기간 비교·화면 문맥·메모 검색·보고서 공유·긴 분석의 V1/V2, 밝음/어두움, 폭·큰 글씨·데이터 상태를 비교한다. Watch 짧은 응답 3개를 함께 보존한다. 합성 데이터의 브라우저 제안이며 실제 Siri·앱 구현·실제 화면 캡처가 아니다.

2026-10-26 [4탭 히어로 제목 표기](hero-heading-style.md)는 첫 카드 상단을 CONDITION·READINESS·WELLNESS·HABITS로 통일하는 공통 개편 기준이다. 영어 대문자 제목과 사용자 언어 설명을 구분하며 네이티브 적용 완료를 의미하지 않는다.

2026-10-26 [Today 재설계 방향](today-restart-proposal.md)은 여백·글씨 크기 변화 문제를 다시 검토하는 새 제안이다. [Compact·Metrics·Editorial](../theme-map/themes/dune-today-restart.html)를 비교한 뒤 Compact를 선택했다. 아래 네이티브 적용 기록과 실제 화면을 현재 기준으로 따른다.

[Today 전체 상태·배치 계약](today-case-matrix.md)에 현재 표시 조건, 12개 데이터 상태, 시간대 경계, 오래된 기록, 큰 글씨·언어·기기 폭, 진입과 빈 그래프 처리 기준을 정리했다. 기본 DUNE 테마를 유지하는 전체 스크롤 시안이다.

| 범위 | 맵 |
|---|---|
| Today T03·Activity A01·Wellness H01·Life L01 | [4탭 레이아웃 맵](index.html) |
| Wellness H01 · 적용된 Flow와 보존된 Compact 제안 | [현재 배치](index.html#wellness) · [실제 화면](../full-redesign-map/review/wellness-flow-2026-10-28/index.html) · [원본 시안/계약](wellness-redesign-proposal.md) |
| DESERT HORIZON 4탭 상세 배치 | [밝음·어두움 시안](../theme-map/themes/dune-final-four-tab.html) · [상세 계약](desert-horizon-final.md) |
| Today 하단 읽기 위계 | [회복·스트레스·요약 V2](today-reading-proposal.md) · [원본 대비 시안](../theme-map/themes/dune-today-reading.html) |
| Today T03 요약 · 본문 더 보기 선택 후 | [세부 배치·펼침 기준](digest-read-more-refinement.md) · [핵심 먼저·한 문장 먼저·지표 행 비교](digest-read-more-refinement.html) |
| Today 알림함·새로운 소식 | [알림함 배치·상태·목적지](notification-inbox-proposal.md) · [시안의 종 아이콘](../theme-map/themes/dune-final-four-tab.html) |
| Activity A03 근육 지도 상세 · A04 진입 | [2D 선택·3D 진입 비활성화 계약](activity-muscle-map-detail-a04.md) |
| Activity 운동 구성 상세 | [근력·유산소와 부위별 구성 배치](exercise-mix-detail-proposal.md) · [4탭 시안](../theme-map/themes/dune-final-four-tab.html) |
| Activity·Wellness·Life 기록 진입 | [상단 추가 버튼·메뉴 배치](record-entry-navigation.md) · [4탭 시안](../theme-map/themes/dune-final-four-tab.html) |
| iOS 위젯·휴식 라이브 액티비티 | [크기·상태별 배치 기준](widget-live-activity-proposal.md) · [DESERT HORIZON 추가 시안](../theme-map/themes/dune-widget-live-activity.html) |
| Watch H01·H02·H03 홈 카드 | [Watch 홈 스크롤 맵](watch-home-scroll.html) |
| Watch C01·C03·C04 유산소 세션 | [Watch 유산소 세션 맵](watch-cardio-session.html) |
| Watch C14·C15 러닝 거리 우선·C16 음성 제어·C17/C18 안내 설정 | [러닝 거리·음성 기준](watch-running-feedback.md) |
| WLA01 Watch 운동 Live Activity | [Watch 운동 Live Activity 맵](watch-workout-live-activity.md) |
| W25·W27·Watch F07 머신 유산소 레벨 변화 | [머신 유산소 레벨 기록 맵](cardio-level-history.html) |

새 화면 맵에는 화면 ID, 대상 기기·상태, 정보 순서, 행동 경로, 빈 상태와 접근성 전환을 명시한다.

## 세 맵의 역할

| 맵 | 기준 | 확인 방법 |
|---|---|---|
| [테마 맵](../theme-map/index.html) | 8개 구현 테마의 색·장면·링·움직임 | 테마 시안·manifest·README 동기화 |
| [레이아웃 맵](index.html) | 4탭 정보 순서, 히어로, 행동, 반응형 배치 | 계획서와 코드·실제 화면 대조 |
| [실제 화면 디자인맵](../phone-design-map/actual/index.html) | 현재 빌드의 시뮬레이터 화면 | 새 PNG·캡처 출처·육안 확인 |

## 디자인 변경 절차

1. 변경할 화면 ID와 compact, regular, Duo 자세, 큰 글씨 중 영향받는 상태를 정한다.
2. 해당 화면의 레이아웃 맵을 먼저 갱신한다. 이번 4탭 출시 범위가 바뀌면 [상세 구현 계획](../../plans/2026-10-17-ux-visual-rollout.md)도 갱신하고, 다른 작업은 그 작업의 계획을 따른다. 테마 표현도 바뀌면 테마 맵을 먼저 갱신한다.
3. 코드를 변경하고 탭별 정보 순서·CTA 목적지·빈 상태를 맵과 대조한다.
4. 영향받는 화면을 실제 시뮬레이터에서 다시 캡처해 실제 화면 디자인맵을 갱신한다. 캡처할 수 없으면 구 버전 이미지를 새 구현의 증거로 사용하지 않고 화면 ID·기기·이유를 기록한다.

맵의 DUNE 색은 레이아웃 식별용이다. 실제 테마별 팔레트는 테마 맵과 앱의 `AppTheme` 토큰을 따른다.

2026-10-26 [Today 세 시안 나란히 비교](../theme-map/themes/dune-today-comparison.html)를 추가했다. 세 화면을 동일 조건에서 동시에 볼 수 있고 기본 DUNE 테마와 기존 상태 계약은 유지한다.

2026-10-26 Today 방향은 **Compact 선택**으로 기록했다. [링 안정화·전체 적용 계획](../../plans/2026-10-26-today-compact-layout-and-ring.md)을 기준으로 숫자 중심, 고정 기하, 외부 CONDITION 레이블과 조밀한 아이콘/수치 간격을 적용한다. 이 문단은 방향 선택 시점의 기록이며 현재 구현 상태는 아래 네이티브 적용 항목을 따른다.


## Today Compact 네이티브 적용 진행 (2026-10-26)

Today만 104pt 전용 링과 외부 CONDITION, 고정 그래프 높이·자연 확장 범례, 조밀한 카드·종목별 운동 행으로 옮겼다. 다른 세 탭은 기존 공유 링과 배치를 유지한다. 브라우저 세 시안과 실제 앱 캡처는 계속 구분한다. 네이티브 빌드·번역 형식 검사는 통과했으며, 실제 UI seed와 행 중앙 hit-area 문제를 확인해 수정했다. 선택·저장·홀수 전체 폭 최종 검사는1/1 통과했고 영향 기기별 실제 화면을 새로 보존했다. 나머지 Today 관련20개도 통과했으며 모든 상태 검증 완료를 뜻하지 않는다.

현재 네이티브 근거는 [Today Compact 실제 화면](../full-redesign-map/review/today-compact-2026-10-26/index.html)에 보존한다. 기본 글씨 캡처와 큰 글씨/상태 검사는 별도로 기록하며 Duo 내부 가로의 미검증을 유지한다.

## Activity 개편 시안 (2026-10-26)

[Compact / Training](../theme-map/themes/dune-activity-redesign.html)은 사용자 선택인 Today Compact의 테마·링·간격·큰 글씨 규칙을 Activity에 이어가는 두 방향이다. 현재 순서를 조밀하게 다듬는 Compact와 운동 선택을 앞당기는 Training을 비교하며 [데이터·상태·배치 계약](activity-redesign-proposal.md)에 범위를 기록했다. A01 방향 제안이며 앱 구현·실제 화면 캡처가 아니다. 이전 Activity·Life 히어로 승인안의 구현 상태와 이번 새 제안의 승인 상태를 구분한다.

Activity 후속 시안은 개인 기록에 금빛 메달·최고 값·개선량을 더하고, 준비도 구성은 100점 기준 가로 막대로 비교한다. [현재 계약](activity-redesign-proposal.md)에 제목 헤더·달성 이력과 함께 기록했다.

2026-10-26 [Astra 자문·타 앱 조사·전체 정보구조](activity-information-architecture-study.md)를 추가했다. Activity 비교에 Flow를 추가하고 운동 선택/성취를 분석보다 앞당겼다. 꾸준함·kg 볼륨·부하·부담의 의미와 최근 운동일 합계를 구분하며 현재 집계가 다른 주간 통계/보고서는 보존한다.

2026-10-26 [최종 통합안](activity-final-proposal.md)에서 모든 피드백을 반영한 Flow 한 화면을 제시한다. 이 문서의 비교/조사 기록은 보존하며 최종 전용 시안은 별도 파일에서 연다.

## Activity Flow 네이티브 적용 · 2026-10-27

[A01 현재 배치](index.html#activity)는 상태→선택→기록/성취→분석의12카드다. [실제 화면](../full-redesign-map/review/activity-flow-2026-10-27/index.html)과 [최종 계약](activity-final-proposal.md)을 함께 따른다. 개인 기록의 값과 미니 그래프를 서로 다른 줄로 두어 iPad 반폭에서도 생략을 방지한다. 제목은4탭영어대문자이며 준비도100점막대·실제보상/심박·범례·시간/칼로리·보고서/구성을 적용했다. 전체 회귀와 수집 시간 초과는 실제 화면의 검증 기록에서 구분한다.

## Wellness 개편 시안 · 2026-10-27

[Flow / Compact](../theme-map/themes/dune-wellness-redesign.html)는 Today Compact·Activity Flow의 개편 기록을 이어가는 H01 구현 전 제안이다. 권장 Flow는 점수→최근 수면→오늘 밤 예측→건강 지표→신체→자세/부상 순서이며 활성 부상은 예측 다음에 표시한다. Compact는 기존 점수/수면 묶음과 순서를 정돈한다. WELLNESS·104px 링·네 항목의100점 막대·제목 옆 전체 헤더 상세·큰 글씨 외부 점수를 공유한다. 후속 요청의 골드 히어로·건강 지표 면적/수치·신체 항목별 비교·촬영 안내와 점수 강조를 반영하고 Astra에게 두 차례 자문받았다. [데이터 제약·비교 예시·검증 범위](wellness-redesign-proposal.md), 초기 원본·최신PNG20장·80개 배치/20개 상태/60개 동작과 마지막 아이콘24개 한정 배치 기록을 함께 보존했다. 이 문단은 2026-10-27 구현 전 시안의 보존 기록이다. 2026-10-28 Flow를 네이티브에 적용했고 [현재 H01 배치](index.html#wellness)와 [새 실제 화면·검증 범위](../full-redesign-map/review/wellness-flow-2026-10-28/index.html)를 현재 기준으로 따른다. Compact와 예시 수치의 브라우저 PNG는 시안으로 남긴다.

## Life 통합 개편 시안 · 2026-10-28

[Flow 통합 시안](../theme-map/themes/dune-life-redesign.html)과 [분류·행동·데이터 계약](life-redesign-proposal.md)을 추가했다. Today Compact·Activity Flow·Wellness Flow를 대조하고 Astra의 독립/2차 의견을 통합했다. 오늘 실행→주간 목표→다가오는 일정→자동 기록→실천 패턴/돌아보기→관리 순서를 권장한다. 기존 일정 분리를 보존하고 목적별4그룹은 보조 탐색으로만 적용한다. 작은 횟수/시간/메뉴 버튼과 저장 전 검증·현재목표의 과거통계 소급 위험을 후속 구현 계획에 포함했다. 밝음/어두움·폭·글씨·상태·로컬 입력을 비교하는 예시 시안이며 현재 Life 앱/실제 화면맵은 변경하지 않았다. [두 계획 통합 실행안](../../plans/2026-10-28-life-tab-redesign.md)을 따른다.

2026-10-28 후속 피드백: Life 시안의 긴 히어로 설명·중복 하단 요약·아래 이동 버튼을 제거했다. 골드 그라데이션104px 링의 완료 수와64px 남은 숫자로 줄이고 다른 카드의 안내 문장도 축약했다. 상단+는 실제 추가 동작으로 유지한다. 새 시안 PNG와 검증 해시를 갱신하며 앱 적용을 의미하지 않는다.

2026-10-28 [지난 날짜 습관 기록 L-P01](habit-past-record-proposal.md)을 새 화면 제안으로 연결했다. 오늘 목록/더보기/이력에서 날짜별 누락 기록을 추가·수정하며 과거 기록과 오늘 상태, 주간 일수, 반복의 다음 예정일을 구분한다. 앱 구현/실제 화면 등록과는 별개다.

2026-10-28 오늘의 실천 카드 보완: 평면 목록 대신 큰 아이콘·세이지/골드/청록의 습관별 카드,큰 기록값·막대·물방울8개 진행 표시로 다듬었다. 필터를 한 묶음으로 정리하고 지난 기록·44px 독립 조작과 큰 글씨/넓은 폭 배치를 유지한다. 브라우저 시안이며 앱 미적용이다.

2026-10-28 Life 히어로의 시각적 강조를 보완했다. 골드 능선·브론즈 반사·입체 링과 실제 완료 습관만 채워지는 작은 메달을 추가했다. 짧은 수치·104px 링·문장/스크롤버튼 없음·큰 글씨 우선 정책을 유지한다. 이전 수치형 PNG를 비교 보존하며 최신 시안 PNG와 QA를 갱신한다. 앱 미적용이다.

## 네이티브 반영 · 2026-10-29

Life Flow를 실제 앱에 반영했다. [검증 보고](../../reviews/2026-10-28-life-flow/README.md)와 [실제 iPhone·iPad·Duo 양쪽74장](../full-redesign-map/review/life-flow-2026-10-28/index.html)을 따른다. 앞의 시안 단계 설명은 제안 당시 기록이며 시안과 실제 캡처는 별도로 보존한다.

## 러닝 지도와 공유 카드 · 2026-10-29

[다섯 시안의 배치·데이터 계약](running-map-share-proposal.md)과 [테마맵 보존본](../theme-map/themes/dune-running-map-sharing.html)을 추가했다. 실외 실제 경로, 실내 거리, 가상 여정, 경로 미수신을 구분한다. 동시 진행 상세 개편의 공통 상단과 기존 분석을 유지하고 지도·전체 보기·공유 편집만 추가하는 제안이다. 앱 적용·실제 화면 캡처가 아니다.

2026-10-29 [유산소 아틀라스 통합 시안](cardio-atlas-integrated-proposal.md)을 추가했다. 다섯 상세 화면 선택 대신 단일 기본 상세와 공유 스타일, 저니·패스포트의 연결로 통합한다. 이전 비교안은 보존하고 앱 소스/실제 화면 캡처는 변경하지 않았다.

- [L03 습관 템플릿 개편](habit-template-redesign-proposal.md): 검토된 카드 시안의 네이티브 배치·동작 계약.

[WLA01 골드 임팩트 · 종목별 지표 선택](live-activity-size-state-proposal.md) · [보존 시안](../theme-map/themes/dune-live-activity-size-state.html) · 네이티브 구현·검증 진행 중.

- [T04 컨디션 상세 개편](condition-detail-redesign-proposal.md): 링·실측 기여·기간/차트/통계·단일 설명 펼침의 화면별 native 계약.

- [T05 누적 스트레스 상세 개편](cumulative-stress-redesign-proposal.md): 동일 히어로·통합 기간/통계·요인 막대·하나의 계산 펼침.
- [T06 건강 지표 상세 개편](health-metric-detail-redesign-proposal.md):16개 지표의 실제 단위/기능 보존, 통합 추세, 검증된 선택형 비교와 정확한 전후 화면 식별.

2026-10-31 [A02 훈련 준비도 상세 배치·데이터 계약](training-readiness-detail-a02.html)은 원본 다섯 구성 점수/가중치, 모델 상태 심볼, 시간 조정, 5기간 실제 차트와 비-일간 세 원천 근사 이력을 분리한다. 브라우저의 값은 설명용이며 앱 캡처가 아니다. 원본 iPhone 영어/max-AX selector 1개와 iPad 첫 max-AX 사례만 통과했다. iPad 배치는 진행 중이며 일반 글씨 원본과 Duo는 미검증이다.

2026-10-31 [A03 2D 근육 지도 상세 배치 시안](activity-muscle-map-detail-a03.html)은 A04의 비활성 3D 진입을 보존하면서 실제 앞/뒤 SVG 지도·Recovery/Sets 범례·선택 근육·볼륨·회복 정보의 새 위계를 정한다. 실제 iPad 기본 캡처의 종아리 가림을 반영해 regular에서는 회복 히어로를 secondary 첫 항목으로, compact에서는 primary 지도 위로 둔다. 도식의 몸체와 막대는 설명용이며 네이티브 캡처·측정값이 아니다.

2026-10-31 [A05 주간 운동 통계 상세 배치](activity-weekly-stats-detail-a05.html)는 기존 세 기간·현재 다섯 지표·이전 기간 실제 네 비교 행·한 날짜 캡션·세 차트 지표와 운동 종류 분해의 화면별 계약이다. [DUNE 테마 방향](../theme-map/themes/dune-weekly-stats-detail-a05.html)의 수치 자리와 막대는 설명용이며 네이티브 캡처가 아니다.

2026-11-03 [A12 운동 구성 상세](activity-exercise-mix-detail-a12.html)는 실제 4주 유형별·주간·근육·유산소·선택 도넛·전체 빈도와 기존 상태를 보존하는 시안이다. 실제 네이티브 검증은 별도다.

2026-11-03 [A13 근육 상세 팝오버](activity-muscle-detail-popover-a13.html)는 실제 근육 상태·주간 세트·기존 계산 및 운동 추천을 유지하는 배치 제안이다. 시트와 인라인 양쪽 네이티브 검증은 별도다.

- [A14 근육별 피로 설명](activity-fatigue-explanation-a14.html): 실제 계산 값을 보존하는 시트 배치 계약.

2026-11-04 [A16 주간 볼륨 계산 설명 배치](activity-volume-algorithm-a16.html)는 단일 히어로·원래 섹션 아이콘·기록별 보조 근육 세트의 내림 및 최소 1세트·5단계·원래 범례를 보존한다. 정적 시안이며 실제 캡처는 검증 후 연결한다.

2026-11-04 [A17 개인 기록 설명 배치](activity-personal-records-explanation-a17.html)는 기존 트로피·다섯 섹션 아이콘과 중간/큰 시트, 실제 기록 종류 설명을 보존하는 정적 제안이다. 실제 캡처와 분리해 검증 후 연결한다.

- [A18 운동 일관성 설명](activity-consistency-explanation-a18.html): 기존 시트·아이콘을 보존한 구현 기준과 검토 완료된 실제 캡처 비교.

- [A19 운동 구성 설명](activity-exercise-mix-explanation-a19.html): 기존 시트·아이콘을 보존한 구현 기준과 검토 완료된 실제 캡처 비교.

- [A20 추천 장비 설정](activity-recommendation-equipment-a20.html): 기존 SVG·토글·저장을 보존한 네이티브 개편. 4개 기기 상태와 큰 글씨 5/5 검증 및 실제 비교 캡처 검토 완료.

- [A21 보상 설명](activity-reward-explanation-a21.html): 기존 아이콘·시스템 시트와 계산을 보존한 개편. 개편 선택 검사6/6과 원본 iPhone1/1을 각각 검증하고 실제 전후 비교에 연결했다.

H05 구현 검증: iPhone·iPad·Duo 접힘·펼침의 기존 검사 5건과 실제 PNG/AX 18쌍을 확인했다. [실제 화면과 검증 한계](../full-redesign-map/review/h05-body-record-native-2026-11-05/index.html)는 시안과 별도이며 첫 iPad 실패 1건도 보존한다.

- [H09 부상 이력](injury-history-h09.html): 원래 두 상태·기록 필드·행동을 보존하는 배치 제안. 두 상태 fixture의 현재 611d70b1 네 프로필·다섯 사례·열 PNG/AX 쌍은 [실제 검토 갤러리](../full-redesign-map/review/h09-injury-history-native-2026-11-05/index.html)에 있다.

2026-11-05 H10 부상 상세는 [전용 배치](injury-detail-h10.html)와 [DUNE 표현](../theme-map/themes/dune-injury-detail-h10.html)의 원래 부위·심각도·기간 히어로, 한 번의 날짜·메모 배치를 따른다. 아직 실제 앱 검증 전 정적 시안이다.

2026-11-05 H11 부상 통계는 [배치 계약](injury-statistics-h11.html)과 [테마 시안](../theme-map/themes/dune-injury-statistics-h11.html)의 실제 건수·회복일 강조를 따른다. 구현 전 정적 제안이며 계산은 기존 서비스를 유지한다.

2026-11-05 H12 수면 설명 시트는 [배치 계약](sleep-debt-explanation-h12.html)과 [테마 시안](../theme-map/themes/dune-sleep-debt-explanation-h12.html)의 원문·표식·스크롤 보존 기준을 따른다. 정적 제안이며 실제 검증 전이다.

2026-11-05 H13 수면 설명 시트는 [배치 계약](waso-explanation-h13.html)과 [테마 시안](../theme-map/themes/dune-waso-explanation-h13.html)의 원문·표식·스크롤 보존 기준을 따른다. 정적 제안이며 실제 검증 전이다.

2026-11-06 H10: [실제 화면과 출처](../full-redesign-map/review/h10-injury-detail-native-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 검증을 완료했다. 영어·Light 시뮬레이터 범위이며 기존 실패·부분 실행과 P3 메모는 갤러리에 구분했다.

2026-11-06 H11: [실제 화면과 출처](../full-redesign-map/review/h11-injury-statistics-native-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 검증을 완료했다. 영어·Light 시뮬레이터 범위이며 기존 실패·부분 실행과 P3 메모는 갤러리에 구분했다.

2026-11-06 H12: [실제 화면과 출처](../full-redesign-map/review/h12-sleep-debt-explanation-native-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 검증을 완료했다. 영어·Light 시뮬레이터 범위이며 기존 실패·부분 실행과 P3 메모는 갤러리에 구분했다.

2026-11-06 H13: [실제 화면과 출처](../full-redesign-map/review/h13-wake-analysis-explanation-native-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 검증을 완료했다. 영어·Light 시뮬레이터 범위이며 기존 실패·부분 실행과 P3 메모는 갤러리에 구분했다.

2026-11-06 H14: [실제 선택 화면과 출처](../full-redesign-map/review/h14-heart-rate-recovery-explanation-native-2026-11-06/index.html). 영어·Light 네 기본 상태와 접힌 Duo 최대 글씨의 해당 메서드 범위다.

2026-11-06 T17: [실제 선택 화면과 출처](../full-redesign-map/review/t17-health-data-qa-native-2026-11-06/index.html). 영어·Light 네 기본 상태와 접힌 Duo 최대 글씨의 해당 메서드 범위다.

2026-11-06 T18: [실제 선택 화면과 출처](../full-redesign-map/review/t18-pinned-metrics-editor-native-2026-11-06/index.html). 영어·Light 네 기본 상태와 접힌 Duo 최대 글씨의 해당 메서드 범위다.

2026-11-06 L02: [실제 선택 화면·출처](../full-redesign-map/review/l02-habit-form-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 메서드 범위다.

2026-11-06 L04: [실제 선택 화면·출처](../full-redesign-map/review/l04-habit-management-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 메서드 범위다.

2026-11-06 L09: [실제 선택 화면·출처](../full-redesign-map/review/l09-habit-past-record-2026-11-06/index.html). 네 기본 프로필과 접힌 Duo 최대 글씨의 관련 메서드 범위다.

2026-11-06 L05: [실제 선택 화면·출처](../full-redesign-map/review/l05-habit-history-2026-11-06/index.html). 관련 메서드·기기 범위다.

2026-11-06 L06: [실제 선택 화면·출처](../full-redesign-map/review/l06-habit-history-detail-2026-11-06/index.html). 관련 메서드·기기 범위다.

2026-11-06 [Watch 러닝 거리·시간·현재 존 시안](watch-running-zone-proposal.md)을 추가했다. [V1/V2 비교](../theme-map/themes/dune-watch-running-zone.html)는 V2 승인된 브라우저 제안이며 Watch 앱 실제 캡처가 아니다.

2026-11-06 L07: [실제 선택 화면·출처](../full-redesign-map/review/l07-habit-heatmap-2026-11-06/index.html). 관련 메서드·기기 범위다.

2026-11-06 L08: [실제 선택 화면·출처](../full-redesign-map/review/l08-habit-weekly-report-2026-11-06/index.html). 관련 메서드·기기 범위다.

- [P01 배치 계약](posture-capture-p01.html): 원래 기능·아이콘 보존. native 검증 범위는 전용 실제 갤러리 참조.

- [P02 배치 계약](posture-realtime-p02.html): 원래 기능·아이콘 보존. native 검증 범위는 전용 실제 갤러리 참조.

- [P04 배치 계약](posture-result-p04.html): 원래 기능·아이콘 보존. native 검증 범위는 전용 실제 갤러리 참조.

2026-11-06 P05: 배치·정적 시안과 실제 PNG/AX를 구분하고, iPhone 일반/MAX·iPad 일반 검증과 Duo 현재 캡처 미갱신 범위를 화면별 갤러리에 보존했다.

2026-11-06 P07: 배치·정적 시안과 실제 PNG/AX를 구분하고, iPhone 일반/MAX·iPad 일반 검증과 Duo 현재 캡처 미갱신 범위를 화면별 갤러리에 보존했다.

2026-11-07 S01: native Form/List·원래 아이콘·실제 설정값을 보존하는 배치와 정적 시안. 실제 PNG/AX와 미검증 기기는 화면별 갤러리에 구분한다.

2026-11-07 S02: native Form/List·원래 아이콘·실제 설정값을 보존하는 배치와 정적 시안. 실제 PNG/AX와 미검증 기기는 화면별 갤러리에 구분한다.

2026-11-07 S04: native Form/List·원래 아이콘·실제 설정값을 보존하는 배치와 정적 시안. 실제 PNG/AX와 미검증 기기는 화면별 갤러리에 구분한다.

2026-11-07 S05: 현재 release/feature·원래 아이콘·내비게이션을 보존한 읽기 폭과 MAX 세로 배치. 정적 시안과 실제 PNG/AX 검증을 구분한다.

2026-11-07 S06: 현재 release/feature·원래 아이콘·내비게이션을 보존한 읽기 폭과 MAX 세로 배치. 정적 시안과 실제 PNG/AX 검증을 구분한다.

2026-11-07 W01: 원래 기능·아이콘·실제 데이터 보존과 native 읽기/MAX 배치. 정적 시안과 새 실제 PNG/AX 검증을 구분한다.

2026-11-07 W02: 원래 기능·아이콘·실제 데이터 보존과 native 읽기/MAX 배치. 정적 시안과 새 실제 PNG/AX 검증을 구분한다.

2026-11-07 W03: 원래 기능·아이콘·실제 데이터 보존과 native 읽기/MAX 배치. 정적 시안과 새 실제 PNG/AX 검증을 구분한다.

2026-11-07 W05: 원래 아이콘·운동/세트 동작·고정CTA를 보존한 배치. 시안과 actual PNG/AX·통과/진단/미갱신 범위를 구분한다.

2026-11-07 W06: 원래 아이콘·운동/세트 동작·고정CTA를 보존한 배치. 시안과 actual PNG/AX·통과/진단/미갱신 범위를 구분한다.

2026-11-07 W07: 원래 세트·휴식·RPE 동작을 보존한 배치. 시안과 실제 PNG/AX·검증 범위를 구분한다.

2026-11-07 W08: 원래 세트·휴식·RPE 동작을 보존한 배치. 시안과 실제 PNG/AX·검증 범위를 구분한다.

2026-11-07 W09: 원래 세트·휴식·RPE 동작을 보존한 배치. 시안과 실제 PNG/AX·검증 범위를 구분한다.

2026-11-07 W10: 원래 값·단위·동작을 보존한 큰 글씨 배치. 시안과 새 실제 PNG/AX를 구분한다.

2026-11-07 W27: 원래 값·단위·동작을 보존한 큰 글씨 배치. 시안과 새 실제 PNG/AX를 구분한다.

2026-11-07 W28: 원래 값·단위·동작을 보존한 큰 글씨 배치. 시안과 새 실제 PNG/AX를 구분한다.

2026-11-07 W19: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W20: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W21: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W22: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W16: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W23: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W24: 기존 기능·아이콘·값·기간을 보존한 배치 계약과 새 실제 PNG/AX를 분리한다.

2026-11-07 W33: 정적 배치 계약과 실제 PNG/AX를 구분한다.

2026-11-07 S07: 정적 배치 계약과 실제 PNG/AX를 구분한다.

2026-11-07 W32: 정적 배치 계약과 실제 PNG/AX를 구분한다.

2026-11-14 W04: 보류된 원본 화면 시안을 보존하고 공통 iPad More 경로의 새 검증과 실제 캡처를 분리한다.
2026-11-14 W12: 보류된 원본 화면 시안을 보존하고 공통 iPad More 경로의 새 검증과 실제 캡처를 분리한다.
2026-11-14 W15: 보류된 원본 화면 시안을 보존하고 공통 iPad More 경로의 새 검증과 실제 캡처를 분리한다.
2026-11-14 W29: 보류된 원본 화면 시안을 보존하고 공통 iPad More 경로의 새 검증과 실제 캡처를 분리한다.
2026-11-14 W30: 보류된 원본 화면 시안을 보존하고 공통 iPad More 경로의 새 검증과 실제 캡처를 분리한다.

2026-11-14 보류 W11/W26/W25 시안을 복원했다. [Compact 이력·공유 표시 계약](compact-workout-history-navigation.md)은 실제 앱 검증 대기다.

2026-11-14 W13/W14/W34: W34는 W13 생성 폼의 내장 AI 상태이며 별도 화면이 아니다. 정적 시안과 새 실제 캡처를 구분한다.
2026-11-14 S03/W31: 원래 입력·세트 동작을 보존한 정적 배치 계약이며 새 실제 PNG/AX 검증을 기다린다.
