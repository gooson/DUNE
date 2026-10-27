---
tags: [design, layout, ios, ipados, duo]
date: 2026-10-17
category: plan
status: in-progress
---

# DUNE 레이아웃 맵

[4탭 레이아웃 맵](index.html)은 Today(T03), Activity(A01), Wellness(H01), Life(L01)의 정보 순서와 화면 폭·큰 글씨 전환을 시각적으로 정한 **구현 기준 시안**이다. 값과 그래프는 설명용이며 실제 건강 기록이나 앱 캡처가 아니다. 상세·설정·Watch 등 4탭 밖의 화면을 설계할 때는 이 디렉터리에 화면별 맵을 별도로 만들고 아래 목록 및 `index.html`에서 연결한다.

[DESERT HORIZON 4탭 전체 배치 시안](../theme-map/themes/dune-final-four-tab.html)은 2026-10-22 첫 화면 UX와 Wellness 상세 목적지 분리 이후의 첫 카드부터 마지막 섹션까지 카드 구성·문구·행동을 제안한다. 밝음·어두움과 기기 폭·큰 글씨·기록 없음 전환을 제공한다. 알림함 통합, 상단 기록 진입, 운동 구성, 테마 표면은 현재 코드에 반영했으며 [구현 기준과 남은 검증](desert-horizon-final.md)에 상태를 기록한다. 시안과 2026-10-22 캡처는 이번 구현의 실제 캡처나 런타임 합격 증거가 아니다.

[8개 테마 전체 디자인 개편 맵](../full-redesign-map/index.html)은 이 4탭 레이아웃을 모든 테마와 화면군에 적용하는 목표·구현 순서다. WATER LILIES의 신규 테마화도 그 맵에서 추적한다.

미리보기 폭은 이번 실제 캡처 기기의 논리 폭(iPhone 402pt, Duo 외부 세로 466pt, Duo 내부 펼침 가로 951×669pt, iPad 1032pt)이다. 캡처 기기가 바뀌면 표시 폭과 배치 전환을 다시 대조한다.

4탭 첫 카드의 링은 Today의 124pt 크기·호·중앙 수치·상태 문구를 공통 기준으로 한다. Activity는 실제 준비도 점수, Wellness는 실제 웰니스 점수, Life는 오늘 완료 수/대상 수를 표시한다. 수치가 없으면 빈 상태를 사용하며 임의 점수나 완료율을 만들지 않는다. 접근성 글씨 크기에서는 링과 설명을 세로로 배치한다.

Today T03의 큰 제목은 시스템 스크롤에 따라 접히고 펼쳐진다. 상단 근처에서 멈춘 부분 스크롤은 그대로 유지하며, 감속 종료를 이유로 자동으로 맨 위에 정렬하지 않는다. 맨 위로 이동하는 프로그램 동작은 Today 탭 재선택처럼 명시적인 사용자 행동에서만 수행한다. 상단 복귀·실제 당겨서 새로고침의 손 해제 중 제목과 첫 카드가 연속적으로 움직여야 한다.

Life의 링 옆에는 현재 진행 상태를 설명하는 문장을 둔다. 히어로에서 개별 습관 3개를 다시 나열하지 않으며, 개별 기록·실행은 아래 습관 목록에 둔다. 히어로의 오늘 행동은 기존 체크리스트로 연결한다.

이 Life 배치는 [2026-10-22 실제 화면 15장](../full-redesign-map/review/life-hero-narrative-2026-10-22/README.md)에서 전용 iPhone 402pt·440pt, iPad, Duo 접힘·펼침의 밝음·어두움·최대 글씨로 확인했다. Today는 카드 전체를 컨디션 상세 링크로 사용하고 탭 전환 버튼을 두지 않는다. Activity는 긴 조회 중에도 주 카드·운동 진입을 표시한다. Wellness는 날짜가 붙은 최근 수면 기록·유효한 7일 평균을 구분하고, iPad에서는 두 열로 배치한다. 신체 기록은 예측 다음에 둔다. 이 세 화면의 [새 iPhone·iPad 실제 캡처 12장](../full-redesign-map/review/first-fold-ux-2026-10-22/README.md)은 별도로 보존했다.

나머지 7개 테마의 Life 기본 글씨도 [전용 iPhone 밝음·어두움 실제 화면 14장](../full-redesign-map/review/life-seven-themes-2026-10-22/README.md)에서 링 옆 설명과 체크리스트 행동을 대조했다. 해당 테마의 다른 기기·접근성 상태를 통과한 것으로 확대하지 않는다.

2026-10-22 전용 Duo 접힘 세로·펼침 가로에서 [4탭 밝음·어두움 실제 배치](../full-redesign-map/review/duo-four-tab-hero-rings-2026-10-22/README.md)를 확인했다. 접근성 프레임은 124pt 원 바깥의 11pt 획도 포함하므로, 테스트는 Today의 실제 링 프레임과 다른 세 탭을 비교한다. Duo 펼침 미리보기는 해당 가로 캡처와 같은 951×669pt 비율이다.

[Activity·Life 히어로 흐름과 근거 승인안](activity-life-hero-proposal.md)은 공통 링에 구성 점수·저장된 준비도·습관 완료 기록을 더하는 2026-10-25 구현 대상이다. 과거 습관 분모는 복원하지 않는다.

## 화면별 맵 목록

2026-10-26 [4탭 히어로 제목 표기](hero-heading-style.md)는 첫 카드 상단을 CONDITION·READINESS·WELLNESS·HABITS로 통일하는 공통 개편 기준이다. 영어 대문자 제목과 사용자 언어 설명을 구분하며 네이티브 적용 완료를 의미하지 않는다.

2026-10-26 [Today 재설계 방향](today-restart-proposal.md)은 여백·글씨 크기 변화 문제를 다시 검토하는 새 제안이다. [Compact·Metrics·Editorial](../theme-map/themes/dune-today-restart.html)를 비교한 뒤 Compact를 선택했다. 아래 네이티브 적용 기록과 실제 화면을 현재 기준으로 따른다.

[Today 전체 상태·배치 계약](today-case-matrix.md)에 현재 표시 조건, 12개 데이터 상태, 시간대 경계, 오래된 기록, 큰 글씨·언어·기기 폭, 진입과 빈 그래프 처리 기준을 정리했다. 기본 DUNE 테마를 유지하는 전체 스크롤 시안이다.

| 범위 | 맵 |
|---|---|
| Today T03·Activity A01·Wellness H01·Life L01 | [4탭 레이아웃 맵](index.html) |
| Wellness H01 개편 · 구현 전 제안 | [Flow / Compact 전체 시안](../theme-map/themes/dune-wellness-redesign.html) · [순서·데이터·상태 계약](wellness-redesign-proposal.md) |
| DESERT HORIZON 4탭 상세 배치 | [밝음·어두움 시안](../theme-map/themes/dune-final-four-tab.html) · [상세 계약](desert-horizon-final.md) |
| Today 하단 읽기 위계 | [회복·스트레스·요약 V2](today-reading-proposal.md) · [원본 대비 시안](../theme-map/themes/dune-today-reading.html) |
| Today T03 요약 · 본문 더 보기 선택 후 | [세부 배치·펼침 기준](digest-read-more-refinement.md) · [핵심 먼저·한 문장 먼저·지표 행 비교](digest-read-more-refinement.html) |
| Today 알림함·새로운 소식 | [알림함 배치·상태·목적지](notification-inbox-proposal.md) · [시안의 종 아이콘](../theme-map/themes/dune-final-four-tab.html) |
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

[Flow / Compact](../theme-map/themes/dune-wellness-redesign.html)는 Today Compact·Activity Flow의 개편 기록을 이어가는 H01 구현 전 제안이다. 권장 Flow는 점수→최근 수면→오늘 밤 예측→건강 지표→신체→자세/부상 순서이며 활성 부상은 예측 다음에 표시한다. Compact는 기존 점수/수면 묶음과 순서를 정돈한다. WELLNESS·104px 링·네 항목의100점 막대·제목 옆 전체 헤더 상세·큰 글씨 외부 점수를 공유한다. 후속 요청의 골드 히어로·건강 지표 면적/수치·신체 항목별 비교·촬영 안내와 점수 강조를 반영하고 Astra에게 두 차례 자문받았다. [데이터 제약·비교 예시·검증 범위](wellness-redesign-proposal.md), 초기 원본·최신PNG20장·80개 배치/20개 상태/60개 동작과 마지막 아이콘24개 한정 배치 기록을 함께 보존했다. 최종 방향 선택·네이티브 구현·실제 H01 캡처는 아직 수행하지 않았다.
