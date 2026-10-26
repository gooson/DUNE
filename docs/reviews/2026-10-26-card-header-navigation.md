---
tags: [card-navigation, design-map]
date: 2026-10-26
category: review
status: reviewed
---

# 카드 상세 헤더·수면 부채 검증 · 2026-10-26

2026-10-27 후속: 복구 근거를 확인한 뒤 제한적으로 재개한 관련 UI 6개가 모두 통과하고 정상 종료했다. 기존 실패 이력은 아래에 유지하며 [후속 리뷰·검증](2026-10-27-card-navigation-review-ship.md)과 [새 실제 캡처](../design/full-redesign-map/review/card-headers-review-ship-2026-10-27/index.html)를 최신 결과로 사용한다.

## 범위

사용자가 승인한 네 메인 탭의 제목 옆 chevron·헤더 전체 터치, 기존 상세 목적지 보존, Today 수면 부채 링. 스트레스 점수 강조는 세 방향 시안만 준비했으며 네이티브 점수 표시에는 적용하지 않았다.

## 실행 이력

| 작업 | 결과·원인 | 변화·재시도·후속 |
|---|---|---|
| 헤더 변경 전 수면 링 UI | 상세 진입 1건 24.309초 통과, 다중 밝기/큰 글씨 캡처는 5분 테스트 한도에 걸림. 전체 소유 실행은 600초에서 124로 종료 | 실패한 다중 변형 selector는 재실행하지 않음. 원본 스냅샷 `.codex-checks/pre-header/` 보존 |
| 체크포인트 pre-commit 빌드 | 새 CardNavigationHeader 파일이 pbxproj에 없어서 심볼을 찾지 못함 | 표준 UI 실행기의 프로젝트 재생성으로 등록. 같은 원인 재시도 1회 범위. 체크포인트는 제공된 `DAILVE_SKIP_PRECOMMIT_BUILD=1` 옵션으로 저장했으며 이 커밋의 존재를 빌드 성공 증거로 쓰지 않음 |
| 첫 네 탭 헤더 UI | Activity는 SwiftUI가 합친 레이블 아래에 별도 AX 자식이 있다고 가정한 검사에서 실패(210.227초). Life는 37.841초 통과. Today는 5분 한도, 전체 소유 실행은 900초에서 124 종료 | 실제 독립 헤더 버튼 자체의 44–100pt 영역을 검증하도록 선택자를 수정. 기존 VoiceOver 레이블은 바꾸지 않음. 이 원인에 대한 재시도는 아래 1회로 제한 |
| 헤더 선택자 보완 UI | 앱·UI 테스트 타깃 컴파일/링크는 완료. 러너의 `Running tests...` 뒤 개별 테스트 시작·완료 보고 없이 900초/124 종료. 실행/성공 개수는 unknown | 이 실행 경로는 추가 반복하지 않음. 최종 suite 통과로 처리하지 않음 |
| 직접 실제 화면 캡처 | 설치가 40초 한도에 걸려 해당 소유 기기를 한 번 재부팅. bootstatus·설치 정상화 후 네 탭 기본 viewport와 Today 수면 상태의 새 원본 5장을 촬영·육안 확인 | 자동 UI를 다시 실행하지 않음. 최초 H01 흰 시작 프레임은 진단용으로 분리. 준비된 저장소로 다시 실행한 H01만 완료 증거로 사용 |

최종 명령은 `DUNE_UI_TEST_WALL_TIMEOUT=900 DAILVE_UI_TEST_DERIVED_DATA_DIR=.deriveddata/build-ios bash scripts/test-ui.sh --no-regen --simulator-udid 02CE1F65-F721-44A3-9BBF-523AE138F678 --only-testing DUNEUITests/CardNavigationHeaderUITests --only-testing DUNEUITests/ActivityExerciseRegressionTests/testTrainingVolumeSummaryAtMaximumAccessibilityTextSize --log-file .xcodebuild/card-navigation-headers-resolved-ui.log`다. 프로젝트는 첫 헤더 실행에서 재생성했고 새 Swift 파일 두 개의 등록을 확인했다. 전체 회귀는 요청되지 않아 실행하지 않았다.

pre-commit 훅의 기본 정리는 `.xcodebuild`를 삭제한다. 이전 실행 결과는 최종 로그의 성공으로 덮어쓰지 않으며 Xcode 결과 번들·PNG·위 실패 기록과 구분한다.

## 미갱신 범위

[새 실제 iPhone 원본 5장](../design/full-redesign-map/review/card-headers-sleep-debt-2026-10-26/index.html)은 밝음·한국어·기본 글씨·Desert Warm의 첫 viewport와 수면 부채 0분 상태다. Life 보고서/히트맵 헤더와 하단 모든 카드, 부채 0 초과·10시간 초과, 어두움·큰 글씨·다른 테마·iPad·Duo 접힘·펼침 T03/A01/H01/L01은 새 캡처 대기다. 기존 PNG를 최신 헤더의 증거로 쓰지 않는다. Watch는 이 iOS View를 사용하지 않는다. 제목이 상세 목적지가 아닌 입력·닫기·정보·다중 행동 묶음에는 별도의 잘못된 상세 chevron을 만들지 않는다.

재개 조건은 정상화된 전용 기기에서 XCTest 러너가 개별 테스트 결과를 반환하는지 확인한 뒤 남은 selector/상태만 실행하는 것이다. 같은 AX 자식 가정이나 시간 한도 실패를 이름만 바꿔 반복하지 않는다. CLI 설치·실행 복구는 자동 테스트 통과 증거가 아니다.

## 설계 근거

[카드 상세 헤더 계약](../design/layout-map/card-detail-navigation.md)과 [계획](../plans/2026-10-26-sleep-debt-and-card-navigation.md)을 따른다. 실제 기여 요소나 건강 계산은 바꾸지 않는다. 클릭 목적지는 기존 타입을 유지하며 버튼 중첩 대신 정보 버튼·보조 행동을 형제로 분리한다.

전문가 읽기 전용 검토에서 P1은 없었다. P2 두 건(밝은 모드의 불투명한 어두운 히어로 chevron 대비, 날씨 행 중복 chevron)과 날씨 아이콘 강조색 소실을 보완했다. Life 히어로의 `Today's Habits`는 같은 화면 체크리스트로 스크롤하는 실제 행동이어서 상세 헤더로 바꾸지 않았다. Stage된 소스 전체 및 후속 delta의 Swift 구문 검사는 통과했다.
