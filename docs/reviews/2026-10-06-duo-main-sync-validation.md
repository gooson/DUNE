---
tags: [iphone-duo, visual-qa, main-sync]
date: 2026-10-06
category: review
status: in-progress
---

# Duo 최신 main 병합과 잔여 검사

## 통합 기준

- `origin/main` `f11e6b3a`를 `codex/iphone-duo-experience`에 병합한 커밋은 `6a5eb872`이다. remote main은 이 커밋의 조상이다.
- 기존 미커밋 tracked 6개와 untracked 9월 감사 자료를 보존했다. tracked 변경은 임시 stash 및 `/tmp/duo-resume-20261006/baseline-tracked.patch`로 보관한 뒤 복원했고, 복원 전후 patch의 `cmp` 결과가 일치했다. 기존 stash는 복구를 위해 유지한다.
- main 변경 40개 파일: 알림 상세 및 반복 진입 경로, 자세 촬영 진입 버튼, 알림/보상 목업 및 테스트, Watch 운동 밀도·휴식·자동 저장, 테스트 범위 규칙.
- 충돌 두 파일은 양쪽 목적을 유지했다. Seeder는 선택한 알림 scenario와 opt-in 합성 자세 기록을 함께 생성한다. 운동 테스트는 최신 morning briefing 대기와 기존 post-tap 시각 캡처를 함께 사용한다.
- `.claude` 원본은 수정하지 않았다. 최신 adapter의 '영향 범위 테스트, 전체 suite는 명시 요청 시에만' 규칙을 적용한다. targeted 결과를 full 결과로 보고하지 않는다.

## 환경 및 검증

Xcode 27.1: `/Users/shanks/Downloads/Xcode27.1.app/Contents/Developer`. 전용 시뮬레이터: DUNE Duo Visual Audit `5A2A5D3F-3D53-4326-99DE-47823CA256FA`, iOS 27.1. 다른 장치에는 접힘 조작·초기화를 수행하지 않는다.

표준 앱 빌드 `scripts/build-ios.sh --no-regen`, generic iOS Simulator, `/tmp/duo-resume-20261006/main-merge-build.log`: **BUILD SUCCEEDED / exit 0**.

Device Hub의 실제 Book 프리셋 접근이 가능해졌다. `/tmp/duo-resume-20261006/devicehub-book.png`는 반접힌 기기 셸의 홈 화면이다. GUI 접근 및 프리셋 조작 증거이며 앱 레이아웃이나 운동 상태 유지 통과를 뜻하지 않는다.

병합 영향 확인 대상으로 운동 통계 최대 AX, Personal Records 보상, 알림 운동 상세, 자세 비교 4개를 선택했다. 결과는 실행 완료 후 아래에 기록한다. chart axis 최종 anchor의 픽셀 확인은 자동 assertion과 별도로 수행한다.

## 변경분 검토

- SwiftUI: 새 Capture fullScreenCover의 상태는 PostureHistoryView에 소유되며 기존 record/comparison navigation destinations와 합쳐졌다. 새로운 상위 screen identifier가 기존 비교 버튼 쿼리를 가리지 않는지 실제 테스트로 확인한다. workout phone sheet 조건과 shared seed gate는 main 병합 후에도 유지된다.
- Apple UX: 큰 글자에서 새 Capture/Compare toolbar의 실제 접근성 및 기존 스크롤 비교 버튼이 함께 사용 가능한지 검사한다. 실제 Book/Open/Closed를 바꾸지 않은 내부 화면 캡처는 접힘 검증으로 인정하지 않는다.
- UI 테스트: 모든 selector는 선언 class를 기준으로 지정하고 runner receipt의 실행 수, skipped, 실패 및 누락 selector를 확인한다. synthetic posture fixture는 사진 분석·건강 추론의 검증이 아니다. 휴식 timer는 단순 존재가 아니라 실제 경과 시간과 감소를 검사한다.

## 아직 남은 범위

- 실제 Book/Open/Closed 전환 중 완료 세트 요약과 휴식 타이머 연속성. kg/reps 초안은 아래의 부분 assertion/capture 결과와 구분한다.
- 변경 후 차트 첫/마지막 축 레이블 픽셀 검증.
- 새 Capture/Compare와 기존 자세 비교의 최대 AX 및 내부 화면 접근성.
- 일반 글자 및 최대 AX의 실제 펼침/회전 레이아웃.
- 이미 복원된 legacy workout Insights 보조 창의 업그레이드 복귀 경로. 새 phone sheet 통과와 구분한다.

계정 주간 사용량은 시작 시 23%였으며 실제 작업별 토큰 수는 제공되지 않았다. 계정 사용량을 이 작업만의 토큰 비용으로 환산하지 않는다.

## 첫 병합 영향 실행과 원인별 보정

`main-affected-ui.log`: **4개 실행, 2 passed, 2 failed, 0 skipped / exit 65**. 원본 [receipt](assets/2026-10-06-duo/main-affected-ui-result.json)를 유지한다.

- 알림 운동 상세 45.029초, 최대 AX 운동 통계의 목업 데이터·메뉴·닫기·운동 복귀 132.823초는 통과했다.
- Personal Records 51.417초 실패: 마지막 AX에서 PR 버튼 y=3756.3으로 아직 화면 아래였다. [실패 PNG](assets/2026-10-06-duo/personal-records-before-route-correction.png)는 Training Volume/Weekly Report 위치이며 PR 페이지에 도달하지 않았다. 해당 case의 bounded swipe budget을 10→24로 늘린다. 전체 공통 helper의 실행 비용은 늘리지 않는다.
- 자세 비교 104.789초 실패: Compare Selected 탭 뒤에도 Posture History에 머물렀다. [AX](assets/2026-10-06-duo/posture-offscreen-hittable-target.txt)에서 화면/ScrollView는 466×678이고 Compare Selected는 y=1538.3인데 기존 helper가 hittable로 판단했다. 자세 테스트 helper는 tap point가 실제 viewport 안에 있는지 함께 확인한다. 실패 후 같은 원인 조건부 재실행은 이번 1회뿐이다.
- fold case는 검증 목적과 무관한 긴 history 우회를 제거하고, 이미 통과한 기능 검사의 toolbar Quick Start 경로를 사용한다. 접힘과 저장 검증 조건은 그대로다. 이 test-only 변경은 첫 4개 실행의 AUT 코드를 변경하지 않는다.

### 픽셀 결함: 일별 차트

[최종 anchor 후보의 실제 PNG](assets/2026-10-06-duo/daily-axis-anchor-still-clipped.png)에서 첫 요일 글자가 잘리고 마지막 두 요일이 겹친다. 기능 테스트가 passed인 것과 별개로 **시각적 실패**다. `AxisValue.index/count`는 전체 axis marks에 대한 순서인데, scrollable chart는 현재 visible range의 경계를 별도로 갖는다. 전체 첫/마지막 mark만 anchor를 조정한 후보로 현재 viewport 끝을 보호하지 못했다. 추가로 Training Volume의 월간 날짜 레이블도 최대 AX에서 겹친다(위 PR 실패 PNG). 소스·범위가 다른 차트이며 해당 UI도 미해결로 등록한다.

이미 실패한 padding 및 anchor 경로를 다시 반복 실행하지 않는다. `.codex/skill-compat.md`의 동일 원인 최대 1회 재시도 제한을 유지한다. visible domain 기반 축 배치와 충돌 처리를 검토해야 하며, 새 후보를 컴파일했다는 사실만으로 해결됐다고 처리하지 않는다. 독립적인 실제 접힘 검사는 계속한다.

### 보정된 두 경로의 재검증

`affected-route-correction-ui.log`: **2개 실행, 1 passed, 1 failed, 0 skipped / exit 65**. [receipt](assets/2026-10-06-duo/affected-route-correction-result.json).

Personal Records는 78.509초에 실제 PR 상세의 period picker/timeline/reward progress/achievement history까지 통과했다. 자세 비교는 66.173초에 새 viewport 조건으로 실패했다. 이번에는 root의 첫 View All 진입부터 full swipe가 위/아래 위치를 오가며 안정적으로 정렬하지 못했다. [PNG](assets/2026-10-06-duo/posture-entry-swiping-still-overshoots.png)와 [AX](assets/2026-10-06-duo/posture-entry-swiping-still-overshoots.txt)에서 대상은 y=-2.7..99.6, 전체 화면은 466×678이다. 기존 hit-test의 잘못된 통과를 허용하지 않는다. 같은 실패 경로의 자동 재시도를 추가하지 않는다. 후속 후보는 보이는 target frame과 viewport 중심의 차이만큼 짧은 drag를 사용해야 하며 실측 재검증 전에는 해결로 표시할 수 없다.

최대 AX의 Wellness root에도 실제 레이아웃 결함이 있다: Posture Assessment/Capture/Real-time이 짧은 음절로 나뉘고, 86/73 점수 글자가 작은 고정 ring 밖으로 나온다. PostureHistoryView에 적용한 큰 글자 개선이 Wellness root 카드에도 적용됐다고 가정하지 않는다.

### 첫 실제 접힘 검사와 시간 제한

`fold-maxax-ui.log`의 Book/Open 프리셋과 native capture가 실제 수행됐다. 해당 초안 검사는 62.5kg/11회를 유지했지만, **기본 case 제한 300초로 XCTest가 종료**했다. [timeout receipt](assets/2026-10-06-duo/fold-maxax-timeout-result.json): exit 65, 명시적 passed case 없음, restart 후 0개라는 요약을 성공으로 인정하지 않는다. 타이머 접힘은 이 실행에서 미도달이다.

표준 runner의 최대 허용 600초 안에서 opt-in `testVisualAuditWorkoutPreservesInputsAcrossFoldStates` 한 case만 `executionTimeAllowance=600`으로 보정했다. 일반 case 및 runner의 기본/최대 제한은 변경하지 않았다. 확인된 timeout 원인에 대한 조건부 재시도는 이번 1회이다. 이후 같은 timeout에 대한 추가 자동 실행은 하지 않는다. 실제 전환 성공과 전체 case 성공을 구분해 아래 최종 결과를 기록한다.

호스트 캡처 파일명은 simulator port의 default width/height를 사용하므로 회전 후 실제 PNG dimensions와 다를 수 있다. 화면 크기는 파일명 대신 PNG header를 확인한다. inactive display의 이미지 존재는 실제 프리셋 증명이 아니다. 각 fold checkpoint는 Device Hub의 전용 기기 선택, 실제 Closed/Book/Open action 및 pose 캡처, refresh된 XCTest AX와 built-in 두 화면을 함께 보존한다.

## 실제 접힘 부분 결과와 후속 코드

`fold-maxax-allowance-ui.log`의 전체 case는 **실패 / exit 65**이며 [receipt](assets/2026-10-06-duo/fold-maxax-allowance-result.json)에 positive passed case가 없다. Book→Open→Closed의 각 입력 검증을 진행한 뒤 `completeSet.tap()`에 도달했다. 62.5kg/11회 및 미완료 set 상태의 assertions는 세 전환 뒤 유지됐다. [실제 상태·PNG 크기 manifest](assets/2026-10-06-duo/workout-draft-fold-evidence.json), state별 Device Hub pose/AX, paired native PNG와 갱신된 XCTest AX를 보존한다. 이 부분 assertion 증거를 전체 fold case 통과로 승격하지 않는다.

세트 완료 탭은 약 t=420초에 시작해 t=543초에 반환됐다. 해당 post-tap AX에는 완료 요약 `62.5kg × 11 회`와 이미 `0:30`이 된 휴식 countdown 및 +30초가 있었다. 이후 +30초 tap의 idle 대기 중 타이머가 만료해 target query가 없어졌고 t≈614초에 failure/10분 timeout이 발생했다. **휴식 중 fold checkpoint는 세 상태 모두 미도달**이다. 앱 타이머가 리셋됐다고 이 실패에서 단정하지 않는다.

원인에 맞춘 다음 코드를 준비했다. 동일 실패 UI 실행은 추가하지 않는다.

- 기존 opt-in 입력 fold case는 3개 초안 전환까지만 검사한다. 별도 `testVisualAuditRestTimerAcrossFoldStates`가 완료 후 3개 전환과 timer wall-clock, summary, Skip, 다음 세트 접근을 검사한다. 기존 non-fold 기능 case는 입력/휴식 전체 경로를 유지한다.
- rest fold case의 `--ui-fold-audit-long-rest`만 합성 Bench Press의 이전 세트 `restDuration=600`을 채운다. ViewModel의 기존 previous-session rest 우선순위를 사용하며 실제 사용자/일반 fixture의 휴식 동작은 변경하지 않는다. 타이머 업데이트나 XCTest idle 조건을 끄지 않는다.
- 자세 route helper는 기존 viewport 조건에 더해, 보이는 target/viewport 중심 차이만큼 45% 이내의 짧은 drag를 사용한다. full swipe의 위/아래 overshoot를 피하는 후보이며 **실행 재검증 전**이다.

위 분리 case·긴 휴식 fixture·짧은 drag 후보는 컴파일 결과만 별도로 기록한다. 기존 실패 receipt를 교체하거나 새 case를 실행한 것으로 기록하지 않는다. 기본/최대 AX의 회전, legacy 보조 scene 복귀, 차트 축 및 Wellness root의 점수·줄바꿈 결함도 완료 처리하지 않는다.

종료 직전 계정 주간 사용량은 29%였다(시작 23%). 계정 전체 변화이며 이 작업의 정확한 토큰 수나 단독 사용량이 아니다.

최종 테스트 소스와 AUT의 표준 `scripts/build-target.sh --scheme DUNEUITests --platform ios --build-for-testing --no-regen`: `/tmp/duo-resume-20261006/audit-followup-compile.log` **TEST BUILD SUCCEEDED / exit 0**. 분리된 두 fold case, opt-in long-rest fixture 및 짧은 drag 후보의 컴파일 증거다. 후보의 runtime 검증이나 전체 UI 통과 증거가 아니다.

같은 후속 소스의 표준 앱 빌드 `/tmp/duo-resume-20261006/audit-followup-app-build.log`도 Xcode 27.1 generic iOS Simulator에서 **BUILD SUCCEEDED / exit 0**이다.

후속 변경 검토: DEBUG seeder만 긴 휴식 flag를 읽고, Bench Press 합성 세트에만 적용한다. 실제 timer 구현·앱 기본 rest·CloudKit schema는 변경하지 않았다. 입력 case는 rest 시작 전에 끝나고 휴식 case는 타이머 phase에서만 3개 actual fold checkpoint를 사용한다. 두 case의 각 제한은 기존 runner 최대 600초를 넘지 않는다. 자세 drag의 normalized y는 0.25..0.75 내에 제한되며 실제 viewport tap-point assert를 유지한다. 자동 재시도 한도 및 미해결 시각 결함은 보존한다.

## 최종 main 기준과 보존 상태

검사 도중 `origin/main`이 `0ab0847d`(#792)까지 진행돼 이 변경도 `b646fe4e`에서 병합했다. 시뮬레이터 소유 registry/안전한 Ship 정리, 3개 test runner의 명시 cleanup 경로와 관련 계약 테스트 및 adapter 지침이 변경됐다. 앱/프로젝트/UITest source에는 추가 변화가 없음을 `git diff --name-only c4eb4623 HEAD -- DUNE DUNETests DUNEUITests DUNEWatch`의 빈 결과로 확인했다. 기존 UI 결과는 위 개별 실행 범위와 당시 소스 기준이며 full/최종 runtime 성공으로 승격하지 않는다.

`python3 -B scripts/tests/test-simulator-worktree.py`: `/tmp/duo-resume-20261006/simulator-registry-contracts.log`, **14개 / OK / exit 0 / 3.613초**. fake simctl/임시 git worktree 기반이며 실제 전용 Duo나 다른 장치를 삭제하지 않았다. 원래 tracked dirty 6개는 두 번째 병합 뒤에도 초기 binary patch와 일치했다.

중간 커밋: main 최초 병합 `6a5eb872`, 후속 코드·원본 증거 `c4eb4623`, 추가 main 도구 병합 `b646fe4e`. Ship/PR/원격 push는 수행하지 않았다. 전체 감사는 미완료이며 남은 결함과 미검증 후보를 본 기록에 유지한다.
