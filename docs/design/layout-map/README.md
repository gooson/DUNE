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

Life의 링 옆에는 현재 진행 상태를 설명하는 문장을 둔다. 히어로에서 개별 습관 3개를 다시 나열하지 않으며, 개별 기록·실행은 아래 습관 목록에 둔다. 히어로의 오늘 행동은 기존 체크리스트로 연결한다.

이 Life 배치는 [2026-10-22 실제 화면 15장](../full-redesign-map/review/life-hero-narrative-2026-10-22/README.md)에서 전용 iPhone 402pt·440pt, iPad, Duo 접힘·펼침의 밝음·어두움·최대 글씨로 확인했다. Today는 카드 전체를 컨디션 상세 링크로 사용하고 탭 전환 버튼을 두지 않는다. Activity는 긴 조회 중에도 주 카드·운동 진입을 표시한다. Wellness는 날짜가 붙은 최근 수면 기록·유효한 7일 평균을 구분하고, iPad에서는 두 열로 배치한다. 신체 기록은 예측 다음에 둔다. 이 세 화면의 [새 iPhone·iPad 실제 캡처 12장](../full-redesign-map/review/first-fold-ux-2026-10-22/README.md)은 별도로 보존했다.

나머지 7개 테마의 Life 기본 글씨도 [전용 iPhone 밝음·어두움 실제 화면 14장](../full-redesign-map/review/life-seven-themes-2026-10-22/README.md)에서 링 옆 설명과 체크리스트 행동을 대조했다. 해당 테마의 다른 기기·접근성 상태를 통과한 것으로 확대하지 않는다.

2026-10-22 전용 Duo 접힘 세로·펼침 가로에서 [4탭 밝음·어두움 실제 배치](../full-redesign-map/review/duo-four-tab-hero-rings-2026-10-22/README.md)를 확인했다. 접근성 프레임은 124pt 원 바깥의 11pt 획도 포함하므로, 테스트는 Today의 실제 링 프레임과 다른 세 탭을 비교한다. Duo 펼침 미리보기는 해당 가로 캡처와 같은 951×669pt 비율이다.

[Activity·Life 히어로 흐름과 근거 승인안](activity-life-hero-proposal.md)은 공통 링에 구성 점수·저장된 준비도·습관 완료 기록을 더하는 2026-10-25 구현 대상이다. 과거 습관 분모는 복원하지 않는다.

## 화면별 맵 목록

| 범위 | 맵 |
|---|---|
| Today T03·Activity A01·Wellness H01·Life L01 | [4탭 레이아웃 맵](index.html) |
| DESERT HORIZON 4탭 상세 배치 | [밝음·어두움 시안](../theme-map/themes/dune-final-four-tab.html) · [상세 계약](desert-horizon-final.md) |
| Today 알림함·새로운 소식 | [알림함 배치·상태·목적지](notification-inbox-proposal.md) · [시안의 종 아이콘](../theme-map/themes/dune-final-four-tab.html) |
| Activity 운동 구성 상세 | [근력·유산소와 부위별 구성 배치](exercise-mix-detail-proposal.md) · [4탭 시안](../theme-map/themes/dune-final-four-tab.html) |
| Activity·Wellness·Life 기록 진입 | [상단 추가 버튼·메뉴 배치](record-entry-navigation.md) · [4탭 시안](../theme-map/themes/dune-final-four-tab.html) |
| iOS 위젯·휴식 라이브 액티비티 | [크기·상태별 배치 기준](widget-live-activity-proposal.md) · [DESERT HORIZON 추가 시안](../theme-map/themes/dune-widget-live-activity.html) |
| Watch H01·H02·H03 홈 카드 | [Watch 홈 스크롤 맵](watch-home-scroll.html) |
| Watch C01·C03·C04 유산소 세션 | [Watch 유산소 세션 맵](watch-cardio-session.html) |
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
