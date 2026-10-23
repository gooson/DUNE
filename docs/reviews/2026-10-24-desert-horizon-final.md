---
tags: [swiftui, desert-horizon, design, widgets, live-activity, verification]
date: 2026-10-24
status: in-progress
---

# DESERT HORIZON 실제 구현 검증

## 변경 내용

- 원래 사구 곡선을 유지한 전체 화면 그라데이션과 밝음·어두움 카드 표면.
- Today 알림함 안의 건강 알림·새 소식 필터, 합산 미열람·모두 읽음·기존 상세 이동.
- Activity·Wellness·Life의 상단 기록 진입. 기존 차트·추천 운동·근육 지도·개인 기록·보고서 유지.
- 최근 28일 운동 구성: 근력·유산소·기타, 주별 구성, 주요 부위별 완료 세트 환산, 유산소 종류·시간·거리, 기존 빈도 상세.
- 실제 수면 이력 차트와 주간 습관 보고서의 이번 주·지난 주 비교.
- WidgetKit 크기별 여백과 대비, Rest Live Activity의 시스템 표면·실제 카운트다운.

## 범위와 데이터

DUNE 색·카드 표현은 Desert 테마에 한정한다. 알림 통합과 기록 진입·운동 구성은 모든 테마의 실제 기능이다. 앱에 시안의 임의 건강 점수·기록은 넣지 않았다. 캡처는 명시된 UI 테스트의 mock fixture 데이터이며 실제 앱을 빌드해 렌더링한 결과다.

[실제 화면·변경 전 비교](../design/full-redesign-map/review/desert-horizon-final-2026-10-24/index.html)와 [방향 시안](../design/theme-map/themes/dune-final-four-tab.html)은 구분한다.

## 검증 기록

| 항목 | 현재 결과 | 증거 |
|---|---|---|
| iOS·Widget 통합 빌드 | 통과, c4d07845 앱 소스 | .codex-checks/desert-final-build.log |
| 영향 단위 테스트 | 58 통과 / 0 실패 / 0 건너뜀, 7 suites | desert-targeted-unit-retry.xcresult, desert-unit-summary.json |
| iPhone 초기 targeted UI | 10 통과 / 5 실패 / 0 건너뜀 | Test-DUNEUITests-2026.10.24_04-02-34-+0900.xcresult |
| iPhone 수정 후 targeted UI | 진행 중 | desert-phone-ui-retry.log |
| iPad | 대기 | — |
| Duo 접힘·펼침 가로 | 대기 | — |
| 시스템 Widget·Live Activity | 대기 | — |

초기 실패 5개는 새 소식 필터를 영어 문구로 찾던 테스트 3개와 카드 부모의 접근성 식별자가 자식 차트·비교율 식별자를 덮은 2개였다. 화면 합본에서 실제 내용은 표시됐음을 확인했고, containment와 언어 독립적인 세그먼트 선택을 적용했다. 존재 여부만 확인하던 상세 테스트도 스크롤 후 실제 표시 여부를 검증한다. 수정 원인당 한 번만 재검증한다.

전체 회귀는 사용자 요청이 없어 실행하지 않는다. 자동 UI 분류의 full 영향 판정과 실제 targeted 실행은 구분하며, targeted 결과를 전체 통과로 표시하지 않는다.

## 캡처 출처

일반 iPhone 루트 밝음·어두움 8장과 최대 접근성 크기 4장은 3d9ba7e7에서 개별 통과한 ThemeMatrix 메서드의 실제 결과다. 전체 초기 번들이 통과했다는 증거는 아니다. Before 이미지는 이전 구현 참고용이며 새 구현의 증거가 아니다. 기기·커밋·테스트·시각은 갤러리의 capture-index.json에 기록한다.

## 실행 격리

원래 e1e6 작업 트리에 독립 작업의 변경이 시작되어, 커밋된 디자인 53fd5c2d에서 관리 워크트리 desert-horizon-final-validation과 브랜치 codex/desert-horizon-final-ship을 만들었다. 다른 작업의 파일과 시뮬레이터는 보존한다. 모든 런타임 검증은 단일 표준 실행기·저장소 잠금·현재 작업 트리 소유 기기를 사용한다.

기존 registry subprocess의 잠금 FD 환경 상속 문제는 저장소 실행기를 수정하지 않고 task-local 환경 shim으로 격리했다. 바깥 실행기는 실제 잠금을 계속 보유한다. 이 수정은 제품 변경에 포함하지 않는다.

## Proof Ledger

| Phase | 상태 | 증빙 |
|---|---|---|
| Init·Plan | 완료 | 승인 시안·계획서·영향 경로·위험·테스트 전략 |
| Work | 완료 | 논리 단위 커밋·실제 통합 빌드·전문 정적 검토 |
| UI Test | 진행 중 | 위 표의 실제 결과와 기기별 새 캡처 |
| Review·Quality·Resolve | 대기 | — |
| Compound·Pre-Ship·Ship | 대기 | — |
