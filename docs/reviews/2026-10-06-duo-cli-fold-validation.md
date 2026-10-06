---
tags: [iphone-duo, hinge, cli, visual-qa, automation]
date: 2026-10-06
category: review
status: in-progress
---

# Duo CLI 접힘 전환과 잔여 검사

## 확인한 원인과 해결

공식 `simctl help`, `simctl help io/ui`에는 접힘 설정이 없고 `devicectl device motion hinge-angle --help`는 조회만 제공한다. 그러나 이것만으로 Mac GUI 잠금 해제를 필수 조건으로 판단한 것은 확인 부족이다. 공개 [hinge source](https://github.com/artemnovichkov/hinge/tree/7acb090dd7d28fb0aea8e1907211ceff15aa450e)를 임시 디렉터리에 받아 shell/C source를 읽고 실행했다. 앱 코드나 `.claude`는 변경하지 않았다.

Xcode 27.1에서 `XDG_CACHE_HOME`을 작업 임시 디렉터리로 한정하고 명시적 전용 UDID로만 실행했다. 저장소 simulator test lock 아래 실제 각도가 90° → 180° → 0°로 바뀌었고 시작 각도 0°도 복원됐다. [receipt](assets/2026-10-06-duo-cli/cli-transition-probe.json). native PNG에서 Book의 내부 홈 화면과 Closed의 외부 홈 화면을 직접 확인했다. GUI 조작은 사용하지 않았으며 이 순간의 Mac 잠금 여부 자체는 새로 조회하지 않았다.

## 실행 계약

- `DAILVE_DUO_HINGE_CLI`를 검토한 실행 파일로 명시하면 host가 각 FOLD checkpoint에서 설정 → 실제 readback 확인 → fresh XCTest AX 요청 → 두 native PNG → ACK 순서로 진행한다.
- CLI는 비공개 simulator HID protocol을 사용한다. 앱에 포함하지 않으며 source revision과 검증 결과를 남긴다. 공식 일반 설정 API가 존재한다고 보고하지 않는다.
- setter 성공만으로 ACK하지 않는다. 목표 각도와 조회값의 차이가 1°보다 크거나 nonfinite/실패/timeout이면 실패 ledger를 쓰고 capture와 ACK를 하지 않는다.
- 외부 simulator lock을 사용할 때 test runner에 같은 FD를 전달해 nested lock verification을 유지한다. `booted`나 이름 대신 명시적 UDID가 필수다. 환경 변수가 없으면 기존 수동 checkpoint를 유지한다.
- 호스트 계약 테스트 24개가 통과했다. [로그](assets/2026-10-06-duo-cli/host-contract-tests.log). adapter memory reference의 [parity 검사](assets/2026-10-06-duo-cli/parity.log)도 통과했다.

## 메모리

`.codex/agent-memory/ui-test-expert.md`에 검증된 CLI 경로와 readback/ACK 원칙을 저장하고 `.codex/agent-map.md`의 해당 역할 읽기 경로에 연결했다. `.claude` source memory는 변경하지 않았다.

## 실제 앱 검사

기본 글자 크기의 입력 초안 및 휴식 타이머 fold case가 **2 executed / 2 passed / 0 failed / 0 skipped, exit 0**으로 완료됐다. 입력은 266.526초, 휴식은 536.734초였다. 실제 90°/180°/0° readback, fresh AX, paired native PNG 및 각 전환 뒤 입력값·완료 세트·wall-time countdown assertion이 함께 있다. [결과](assets/2026-10-06-duo-cli/fold-default-result.json), [전환 ledger](assets/2026-10-06-duo-cli/fold-default/checkpoints.jsonl), [실제 PNG 크기](assets/2026-10-06-duo-cli/fold-default-native-sizes.json).

이 실행 뒤 compact 운동 화면에서 현재 입력/휴식을 이전 기록보다 먼저 배치했다. 두 열 화면의 overview 배치는 유지한다. 수정된 앱은 표준 Xcode 27.1 build가 exit 0 / BUILD SUCCEEDED다. 이 최종 배치의 최대 AX·기본 크기 재검사는 별도로 기록한다. 기존 성공을 변경된 앱의 최종 시각 합격으로 전파하지 않는다.

## 회전 진단

공식 `devicectl device orientation set/get/rotate` 명령은 존재한다. 그러나 이번 Duo의 내부 화면을 180°로 연 상태에서 `set landscapeLeft`는 exit 0과 성공 JSON을 반환했지만 후속 `get`은 모두 portrait였다. 즉시·0.5초·1초·2초 추가 관찰에서도 같았고 orientation lock은 false였다. [원본](assets/2026-10-06-duo-cli/orientation-official-readback-failure.json). 이를 회전 성공으로 기록하거나 실패 UI case를 같은 경로로 반복하지 않는다.

[serve-sim 원본](https://github.com/EvanBacon/serve-sim/tree/c60d583747b88a15616eeecec56f287ef5759769/packages/serve-sim/Sources/SimDuoHID)은 Duo가 별도의 orientation-picker-control vendor event를 소비한다고 구현한다. 해당 source만 읽고 task 임시 폴더에서 빌드했다. 실제 portrait→landscapeLeft→portrait 공식 readback 검증이 통과했고 원래 세로 및 닫힘으로 복원했다. [probe](assets/2026-10-06-duo-cli/orientation-hid-probe.json). CLI dispatch ACK는 앱 viewport 회전 합격과 별도다. 호스트는 선택한 driver 뒤에도 공식 get readback, fresh AX, 두 PNG를 요구한다. 불일치·timeout·dispatch 실패에는 checkpoint ACK를 쓰지 않는다.

## 남은 범위

- 최종 compact 배치에서 기본/최대 AX의 접힘 기능 및 countdown 전체 표시 확인.
- 실제 물리 방향 전환 및 앱 viewport 크기 변화·입력 보존 확인.
- 내부 화면의 Body 편집, 비교 차트, 3D viewer 등 미검증 경로.
- 실제 이전 OS scene session의 업그레이드 복원.

CLI probe와 계약 테스트의 성공은 전체 화면 감사의 통과가 아니다. 이전 실패 증거는 보존한다.

## 변경 검토

- SwiftUI: compact pane의 현재 입력/휴식과 overview 순서만 바꾼다. binding/action, 두 열에서의 overview, persistence 로직은 유지한다.
- Apple UX: 최대 Dynamic Type을 유지하고 현재 세트 조작을 이전 기록보다 먼저 둔다. 스크롤로 viewport 밖에 있는 내용을 고정 크롭으로 오판하지 않되 timer 텍스트 전체 도달성은 별도 검사한다.
- UI testing: actual hinge/orientation readback 없이 ACK하지 않는다. guest driver도 공식 orientation 조회와 viewport assertion을 우회하지 않는다. timer의 실제 텍스트 frame 전체를 scroll viewport와 비교하고 native capture를 추가한다.
- 자동화: simulator lock FD를 child에게 전달한다. CLI는 opt-in env로 지정하고 존재·실행 권한·명시적 UDID를 검증한다. subprocess는 deadline 내 timeout을 사용한다. 앱 binary에 private HID를 넣지 않는다.
- 기존 baseline tracked 6개는 binary patch 비교로 동일성을 확인했다.

## 최대 글자 실제 접힘 결과

`fold-maxax`: **2 executed / 2 passed / 0 failed / 0 skipped, exit 0**. 휴식은 179.598초, 입력은 421.091초였다. system content size accessibility-extra-extra-extra-large, 현재 입력 우선 배치 앱을 사용했다. Book/Open/Closed readback과 입력·휴식 assertion을 통과했다. [결과](assets/2026-10-06-duo-cli/fold-maxax-result.json), [ledger](assets/2026-10-06-duo-cli/fold-maxax/checkpoints.jsonl). 최대 AX에서는 스크롤 위치에 따라 timer 윗부분이 viewport 밖에 있다. 숫자 전체의 도달성을 후속 full-frame assertion과 캡처로 검증하며 이 기존 캡처만으로 전체 시각 합격을 선언하지 않는다.
