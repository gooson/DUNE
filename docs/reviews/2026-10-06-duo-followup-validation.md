---
tags: [iphone-duo, accessibility, visual-qa, scene-restoration]
date: 2026-10-06
category: review
status: in-progress
---

# Duo 잔여 결함 후속 검증

기준: `415dabf1` 이후 변경. Xcode 27.1, 전용 DUNE Duo Visual Audit (`5A2A5D3F-3D53-4326-99DE-47823CA256FA`). 기존 dirty tracked 6개는 binary patch 비교로 보존했다. 다른 시뮬레이터는 조작하지 않았다.

## 수정

- 일별 차트의 접근성 축은 전체 데이터 순서 대신 현재 visible domain 내부의 두 날짜를 표시한다. 양끝 anchor를 안쪽으로 두고 충돌 처리를 사용한다. [PNG](assets/2026-10-06-duo-followup/daily-axis-maxax-readable.png)에서 첫/마지막 요일의 잘림·겹침이 사라졌다.
- Training Volume 미니 차트는 큰 글자에서 날짜 간격을 넓히고 차트 높이를 함께 확대한다. [PNG](assets/2026-10-06-duo-followup/training-summary-maxax-readable-axis.png)의 9일/23일은 서로 겹치지 않는다.
- Wellness 자세 카드의 제목·동작·기록은 접근성 크기에서 세로로 배치한다. 점수 링도 확대한다. [동작](assets/2026-10-06-duo-followup/posture-card-maxax-actions.png), [기록](assets/2026-10-06-duo-followup/posture-card-maxax-score-and-words.png)의 단어와 숫자가 카드 안에서 읽힌다.
- 운동 overview에 중복으로 포함됐던 현재 세트 입력을 제거했다. 실제 입력 pane만 렌더링한다. 휴식 버튼은 접근성 크기에서 세로 배치하고 workout 전용 helper는 실제 viewport의 tap point를 확인한다. [휴식 버튼](assets/2026-10-06-duo-followup/rest-controls-maxax-readable.png)의 문구가 쪼개지지 않는다. 타이머 윗부분은 버튼으로 스크롤한 위치에서 viewport 밖에 있으며 고정 크롭 결함으로 판정하지 않는다.
- 복원된 legacy Insights scene의 phone content는 primary UI로 복구한다. 저장된 운동 초안은 기존 persistence 경로를 사용한다. DEBUG 진입은 이 renderer를 직접 실행한다; 이전 OS scene session 자체의 실제 복원 검증과 구분한다.
- `Resume`은 한국어로 `재개`이므로 고유 Button ID를 제공했다. 보정 후 원본 AX에도 초안 배너가 없어 selector만의 문제로 결론 내리지 않았다. reset 대상 key 목록에 draft는 없다.
- 초안 저장을 scene background 이벤트 외에 세트·메모·휴식 상태 변경에도 연결했다. 복원 즉시 삭제를 제거하고 실제 저장 후 clear를 유지한다. commit guard는 queued observer가 완료된 draft를 다시 저장하지 못하게 한다. Exercise 화면의 sheet 닫기 후에도 최신 draft를 다시 읽는다. renderer 재실행·Resume·원래 무게 유지 검사가 179.416초에 통과했다. 초안 자동 저장 뒤 휴식 검사는 147.415초에 다시 통과했다. DEBUG reset fixture는 draft를 초기화하지만 reset 없는 재실행은 보존한다.
- iPhone 방향 설정은 기존 portrait-only에서 portrait/landscape left/right로 변경하고 표준 프로젝트 재생성·후처리를 거쳤다. 빌드된 Info.plist의 `UISupportedInterfaceOrientations~iphone`도 확인했다. 이 설정은 iPhone 전역이며 검증 장치는 Duo다.

## 실행 증거

| 실행 | 실제 결과 | 범위 |
|---|---|---|
| layout-ui | 2 passed, 0 failed, 0 skipped / exit 0 | 자세 비교, 최대 AX 운동 통계의 목업·메뉴·닫기·운동 복귀 |
| recovery-rest-ui | 2 passed, 1 failed, 0 skipped / exit 65 | 최대 AX 휴식 연장·감소·Skip·다음 입력, 자세 카드 통과. legacy fixture는 최근 목록 진입 budget 10에서 실패 |
| training-summary-ui | 1 passed, 0 failed / exit 0 | 최대 AX 요약 카드와 실제 detail 진입, 축 픽셀 별도 확인 |
| recovery-rotation-ui | 0 passed, 3 failed / exit 143 | 목록 진입 보정 뒤 영어 Resume 쿼리 실패, portrait-only 설정에서 두 회전 검사 실패. 테스트 완료 후 Xcode 결과 정리가 멈춰 이 실행 PID 60286만 중단 |
| draft-lifecycle-ui | 1 passed, 0 failed, 0 skipped / exit 0 | legacy phone renderer, reset 없는 재실행, Resume → Start, 기존 무게 유지 (179.416초) |
| final-rest-ui | 1 passed, 0 failed, 0 skipped / exit 0 | 자동 저장 뒤 최대 AX 입력·휴식 연장·감소·Skip·다음 세트 (147.415초) |
| history-row-ui | 0 passed, 1 failed / exit 143 | 운동 목록 진입 성공 뒤 collection isHittable assertion 실패. 검사 종료 후 Xcode 결과 정리 정체로 해당 PID 93647만 중단 |
| history-observed-row-ui | 1 passed, 0 failed, 0 skipped / exit 0 | 스크롤 중 Bench Press 기록 등장 누적 확인, 최대 AX 추천/기록 캡처 |
| orientation-correction-ui | 0 passed, 3 failed / exit 65 | 고유 ID 뒤에도 초안 배너 없음. 설정 활성화 뒤에도 viewport 회전 없음. 동일 회전 자동 경로는 중단 |

[첫 성공 receipt](assets/2026-10-06-duo-followup/layout-result.json), [휴식/카드 receipt](assets/2026-10-06-duo-followup/recovery-rest-result.json), [카드 축 receipt](assets/2026-10-06-duo-followup/training-summary-result.json), [원본 회전 실패 receipt](assets/2026-10-06-duo-followup/orientation-before-correction-result.json). 전체 suite 실행을 뜻하지 않는다.

앱 빌드: `/tmp/duo-finish-20261006/orientation-build.log`, `/tmp/duo-finish-20261006/draft-lifecycle-build.log`, `/tmp/duo-finish-20261006/history-row-build.log`, **BUILD SUCCEEDED / exit 0**. 표준 Xcode 27.1 스크립트를 사용했다.

## 실제 접힘 검사의 무효·실패 증거

`fold-split`: 처음 Book 조작의 대상 확인이 실패했는데 checkpoint 012 release가 생성됐다. **이 캡처는 partiallyOpen 증거가 아니며 무효**다. 013은 실제 Open, 014는 실제 Closed였고 countdown은 이어졌지만 Skip가 화면 아래에 있어 rest case가 실패했다. 이를 수정해 viewport-aware scroll과 큰 글자 버튼 재배치를 추가했다.

입력 case의 checkpoint 025는 Mac 잠금으로 Book 조작을 수행하지 못했으며 host deadline이 만료됐다. 완료된 fold case는 **0개**다. [판정 기록](assets/2026-10-06-duo-followup/fold-split-validity.json), [Closed 원본 AX](assets/2026-10-06-duo-followup/rest-fold-closed-before-scroll-fix.txt)를 유지한다. 프리셋 조작 실패 시 release를 생성하지 않는 실행 순서로 보완했다.

## 변경분 검토

- SwiftUI: 초안 observer는 준비 완료 이후와 미완료 세션에서만 저장한다. `didCommitWorkout`은 rest timer 중단보다 먼저 설정되며 완료 후 queued observer의 재생성을 막는다. 공유 운동 행과 추천 이름도 AX에서 세로로 배치하고 전체 이름이 줄바꿈된다. AnyLayout은 기존 query/binding을 유지하며 내용만 재배치한다. overview의 입력 중복 제거로 같은 binding과 action이 두 번 나타나는 문제를 없앤다. legacy phone은 같은 app runtime/model container를 사용하는 windowContent를 제공한다.
- Apple UX: Dynamic Type을 제한하지 않고 높이·행 수를 늘린다. 축 간격·점수 링·버튼 폭을 실제 픽셀로 확인한다. 숫자 증감 버튼만 단일 줄 및 제한된 축소를 적용한다.
- UI testing: 실제 회전은 초기 viewport 대비 실제 크기 변화를 요구한다. value 유지·미완료 Done 상태·세트 action까지 검사한다. 실제 프리셋 증거 없는 화면을 Book/Open 통과로 승격하지 않는다. 모든 failure receipt를 보존한다.

## 남은 범위

- 수정된 최종 소스에서 실제 Book/Open/Closed의 입력 및 휴식 case 전체 성공.
- 실제 내부 화면의 기본/최대 AX 및 회전에서 나머지 감사 경로 시각 확인.
- 실제 이전 scene session의 업그레이드 복원. renderer fixture 검증만으로 시스템 복원 완료라고 보고하지 않는다.

Mac 잠금 해제를 요청한 상태다. 잠금 상태에서 가능한 백그라운드 검사는 진행하며 동일 잠금 조건의 GUI 호출을 반복하지 않는다. 계정 주간 사용량은 33%로 확인했고 작업별 정확한 토큰 수는 unknown이다.

## 초안 수명 주기 진단

고유 ID 보정 뒤에도 [실패 화면](assets/2026-10-06-duo-followup/draft-absent-after-relaunch.png)과 [AX](assets/2026-10-06-duo-followup/draft-absent-after-relaunch.txt)에 unfinished banner/Resume가 없었다. 저장은 scenePhase 변화에만 의존했고 복원 직후 저장된 draft를 지웠다. 입력 변경 시 저장하고 복원본은 commit/discard까지 유지하도록 수정했다. 실제 background callback 누락 또는 복원 과정의 소비 중 어느 이벤트가 이번 nil을 만든 것인지는 단정하지 않는다. 같은 회전 실패를 추가 실행하지 않고 독립적인 데이터 수명 주기 수정 검증을 `draft-lifecycle-ui`로 좁혔다.

[초안 복구 receipt](assets/2026-10-06-duo-followup/draft-lifecycle-result.json), [최종 휴식 receipt](assets/2026-10-06-duo-followup/final-rest-result.json), [운동 목록 보정 전 실패 receipt](assets/2026-10-06-duo-followup/history-row-before-correction-result.json). 운동 목록의 보정 검사에서는 실제 호스트 PNG와 AX를 수집했다. 추천 운동과 운동 기록 이름·수치는 시각 확인됐지만 최종 화면의 특정 행 존재 assertion은 실패했다. 스크롤 중 보였던 행이 뒤에 가상화로 제거되는 상태를 확인해 검사를 누적 관찰로 보정했으며 누적 관찰 보정 뒤 `history-observed-row-ui`가 1 passed / exit 0으로 통과했다. 이 상태는 전체 감사 완료가 아니다.

## 운동 이름 후속 픽셀 확인

[추천 운동](assets/2026-10-06-duo-followup/suggested-exercise-full-names-maxax.png)의 인클라인 바벨 벤치프레스·바벨 로우·카프 레이즈는 말줄임 없이 읽힌다. [기록 이름](assets/2026-10-06-duo-followup/workout-history-full-name-maxax.png)의 바벨 벤치프레스와 [기록 수치](assets/2026-10-06-duo-followup/workout-history-full-metrics-maxax.png)의 세트·무게·횟수·칼로리·날짜가 가로로 잘리지 않는다. 이미지 상하단에는 스크롤로 viewport 밖에 있는 인접 행 일부가 있을 수 있다. [AX](assets/2026-10-06-duo-followup/workout-history-full-name-maxax.txt)에 동일 record ID와 전체 이름이 있다.

`history-row-correction-ui`: 1 executed, 0 passed, 1 failed, 0 skipped / exit 65 (93.797초). 이번 보정 실행은 정상 종료했고 PID 중단은 수행하지 않았다. [receipt](assets/2026-10-06-duo-followup/history-row-correction-result.json). 세 번의 스크롤과 캡처는 수행됐지만 마지막 화면에서 첫 행의 존재를 요구하는 assertion이 실패했다. 특정 행이 보였던 순간을 누적 확인하도록 테스트만 보정했다. 이 최종 보정은 `history-observed-row-ui`에서 1 passed, 0 failed, 0 skipped / exit 0으로 통과했다. [최종 receipt](assets/2026-10-06-duo-followup/history-observed-row-result.json). 실패한 원본 두 receipt는 그대로 유지한다.

중간 커밋: `05fffb26` 차트·자세 카드, `94892abf` 초안·운동 행·회귀 검사, `22060bce` 방향 선언. 최종 목록 assertion은 통과했지만 방향 선언의 실제 회전과 접힘·시스템 복원은 미검증이며 전체 완료/Ship 게이트는 통과하지 않았다. 기존 dirty 6개는 binary patch 동일성을 다시 확인했다. 새 앱 소스는 최종 `history-row-build.log`에서 빌드됐고, 이후 앱 소스 변경 없이 테스트 누적 관찰 조건과 문서만 보정했다.

검사 보정 기록: collection `isHittable` 실패는 exists 기반 보정 1회에서 해소됐고 이후 스크롤 캡처를 완료했다. 새 실패는 마지막 화면에서 가상화로 제거된 첫 record를 요구한 후조건이다. 해당 record가 중간 capture 004에 실제 표시된 AX/PNG를 근거로 누적 관찰로 수정했으며, 이 후조건 실패에 대한 검증은 `history-observed-row-ui` 단일 실행으로 제한한다.

최종 상태: 이번 차트·자세·휴식·초안 복구·운동 이름 수정은 표준 빌드, 관련 기능 검사와 선택한 native PNG로 확인했다. 전체 화면/자세/회전 감사는 완료하지 않았다. 실제 Book/Open/Closed 입력·휴식 전체 case, 내부 화면의 기본/최대 AX·회전 및 실제 이전 OS scene session 복원이 남아 있다. GUI는 Mac 잠금 해제 요청에 대한 응답을 기다린다.

## 2026-10-06 CLI 자동화로 재개

Mac GUI 조작을 필수로 둔 이전 대기 판단을 수정했다. 검토한 pinned hinge source를 사용해 실제 90°/180°/0°를 설정·조회했고, 기본 글자 입력/휴식 두 fold case는 2 passed / exit 0으로 완료됐다. 최신 세트 화면의 compact 배치와 최대 AX 검증은 [CLI 후속 보고서](2026-10-06-duo-cli-fold-validation.md)에 별도로 기록한다. 앞의 무효 release/실패 증거는 그대로 유지한다.

공식 orientation setter는 존재하지만 이 환경에서 성공 응답 뒤 실제 방향 조회가 portrait로 유지됐다. setter 응답과 실제 전환을 구분하는 실패 증거를 보존하고 다른 물리 방향 전달 경로를 조사했다. `.codex/agent-memory/ui-test-expert.md`, `.codex/agent-map.md`, `AGENTS.md`에 향후 실행의 메모리 경로와 실제 readback 기준을 연결했다. 전체 감사 완료를 뜻하지 않는다.
