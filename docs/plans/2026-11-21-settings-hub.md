---
tags: [settings, theme, navigation]
topic: S01 설정 허브
date: 2026-11-21
category: plan
status: approved
confidence: high
related_solutions: [2026-11-07-settings-s01, 2026-11-19-artist-theme-native-rollout]
---

# 설정 허브 구현 계획

[승인 시안](../design/layout-map/settings-hub/index.html)과 현재 설정의 42개 행을 기준으로 메뉴의 위치를 고정한다. 기존 Form의 각 섹션을 접으면 아래쪽 메뉴가 밀리므로 별도 목적지로 이동한다.

## 영향 파일

| 위치 | 변경 |
|---|---|
| DUNE/Presentation/Settings | 허브·검색·폭 대응 배치와 상세 설정, 아티스트 테마 갤러리·미리보기 |
| Shared/Resources/Localizable.xcstrings | 새 문구와 검색에 사용하는 표시 이름의 한국어·일본어 |
| DUNEUITests 및 관련 DUNETests | 이전 단일 Form 경로를 새 진입점으로 연결하고 핵심 동작 검증 |
| docs/design/layout-map 및 phone-design-map/actual | 승인안과 새 네이티브 화면 기록 |

## 구현 순서

1. 현재 설정의 저장과 동기화 코드를 재사용하면서 운동, 알림·브리핑, 데이터·개인정보, 앱 정보, 시뮬레이터 전용 데이터 도구를 분리한다. 앱 아이콘은 독립 진입점을 유지한다.
2. 설치된 테마의 정지 원화로 3열 갤러리를 구성한다. 후보 테마와 저장 테마를 분리하고 Today 컨디션 카드 예시에서만 밝기·테마를 바꾼다. 적용과 취소 경로를 구분한다.
3. 메뉴와 검색 목적지를 공유하고 넓은 창에서는 목록을 유지한다. 새 NavigationStack을 탭 안에 중첩하지 않는다.
4. 기존 UI 경로를 수정하고 아래 검증에서 확보한 신규 첨부 이미지를 실제 맵에 연결한다.

## 검증·종료 조건

- 전용 iPhone에서 설정 홈 → 테마 → 미리보기 → 뒤로/적용 → 앱 아이콘, 검색 → 취침 설정과 빈 결과, 운동·개인정보 진입을 선택 XCTest로 확인한다. 전용 iPad에서 같은 허브가 분할되어 상세를 바꾸는지 확인한다. Duo는 전용 기기 런타임/자세 지원을 확인해 접힘·펼침을 검증한다. 화면별 증거와 미갱신 범위를 기록한다.
- 관련 검색/라우트 unit selector 및 UI selector만 사용한다. string catalog는 변경 전후와 빌드 후 포맷·수동 추출 상태를 검사한다. unit 및 UI 각각 1200초, 한 번에 하나의 실행만 유지한다.
- 회귀 위험은 후보 테마의 조기 저장, 재검색 시의 복귀 상태 손실, iPad에서 중첩된 탐색, 알림 스케줄 재등록, 큰 글씨에서의 선택 이름 잘림이다. 키·저장소를 유지하고 공간이 부족하면 열 수와 행 배치를 바꾼다. Watch 저장 형식과 동기화 경로는 유지한다.
