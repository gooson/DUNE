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

## 완전 펼침 실제 앱 회전 결과

`rotation-inner`: **2 executed / 2 passed / 0 failed / 0 skipped, exit 0**. 기본 및 최대 AX 각각 물리 portrait→landscapeLeft→portrait의 공식 readback을 확인했다. app window가 951×669 → 669×951 → 951×669로 변하고 복원됐으며 kg 62.5, reps 11, 미완료 Done 상태와 현재 세트 action을 유지했다. [결과](assets/2026-10-06-duo-cli/rotation-inner-result.json), [ledger](assets/2026-10-06-duo-cli/rotation-inner/checkpoints.jsonl), [실제 PNG 크기](assets/2026-10-06-duo-cli/rotation-inner-native-sizes.json). 앱 viewport 조건을 제거하거나 orientation setter 성공만으로 통과시키지 않았다.

## 실행 자원과 범위

계정 주간 usedPercent는 재개 시 33%, 물리 회전 검사 완료 후 36%로 조회됐다. 계정 전체 수치이며 이 작업의 정확한 사용 토큰 또는 비용은 unknown이다. 실행 자체를 위한 agent를 만들지 않고 표준 runner의 기존 session을 대기했다. 완료한 build·호스트 계약은 소스 변경이 없으면 재사용하고, 앱 source 또는 실제 제어 경로/viewport assertion이 달라진 검증만 실행했다. 이전 실패를 이름만 바꿔 같은 경로로 반복하지 않았다.

최초 전체 화면 인벤토리의 UNVERIFIED 선언을 일괄 합격으로 변경하지 않는다. 이번 물리 전환 성공은 연결된 workout selector와 캡처 조건의 근거다.

## 최종 배치의 기본 접힘 결과

`fold-default-active`: **2 executed / 2 passed / 0 failed / 0 skipped, exit 0**. `3a49f100` source에서 기본 글자 크기, 90°/180°/0°의 실제 readback과 기능 assertion을 통과했다. 각 자세에서 timer 텍스트 전체 frame이 active scroll viewport 안에 들어오는 것을 추가 확인하고 full countdown PNG를 저장했다. [결과](assets/2026-10-06-duo-cli/fold-default-active-result.json), [ledger](assets/2026-10-06-duo-cli/fold-default-active/checkpoints.jsonl). 휴식은 311.529초였다. Native Book/Open/Closed의 full countdown 이미지에서 숫자·링·완료 세트·현재 휴식 버튼이 보였으며, 인접 overview 일부가 viewport 밖에 있는 것과 구분했다.

## 잔여 실패 분리 및 후속 수정

- inner-routes: Body history 최대 AX 편집/저장과 metric comparison은 각각 90.719초/75.418초로 통과했다. 3D case는 regular 너비의 근육 tap이 옆 열 상세를 선택하는 정상 동작을 자동 3D 진입으로 오인해 실패했다. 실제 3D 버튼으로 진입하는 테스트를 수정했다. 재검증 전에는 3D 렌더링 완료로 기록하지 않는다. [원본 결과](assets/2026-10-06-duo-cli/inner-routes-result.json).
- native 009/012에서 최대 AX weekly 지표의 숫자 ellipsis·변화율 세로 분절 및 근육 상세 고정 두 열을 확인했다. WeeklyStatsGrid/MuscleDetailPopover를 AX 크기에서 한 열로, 값/단위/변화율 및 상세 header를 세로 배치했다. 앱 재빌드/후속 native 검증은 아직 진행 중이다.
- fold-maxax-countdown은 세 자세의 전체 countdown frame/capture까지 진행했지만 next-set 검사에서 600초 초과했고, SDK cleanup도 정체했다. 확인한 해당 Xcode PID만 종료한 결과 exit 143이며 실패 원본을 보존한다. 이전 maxAX 기능 case 통과를 이 실패의 통과로 대체하지 않는다. [실패 결과](assets/2026-10-06-duo-cli/fold-maxax-countdown-result.json).
- stdout 읽기와 SDK cleanup을 분리하고 종료 뒤 60초 감시를 추가했다. 다음 case 시작 시 감시를 해제하며, 격리해 생성한 runner group만 정리/reap한다. 원인 불명의 기능 timeout을 해결했다는 뜻은 아니다. 정상 종료, EOF 정체, 다음 case 재개, descendant pipe 해제/다른 runner 생존을 포함한 **29 host contracts**가 통과했다.
- 운동 control 탐색은 각 루프의 frame을 한 번씩 읽고 화면 안에 있을 때만 hit testing을 요청하도록 중복 AX 조회를 줄였다. 가시성/입력값/완료 조건은 유지하며, Skip 직후 native/AX checkpoint를 추가해 재발 시 실제 next-set 화면을 남긴다.

- 실제 90° 반접힘 고정 회전은 기본 158.666초 / 최대 AX 159.213초, **2/2 passed / exit 0**이다. 실제 방향 readback·fresh AX·paired native·전체 KG/REPS frame 포함·값 62.5/11 보존을 검사했다. native 029에서 최대 AX 숫자 전체를 직접 확인했다. 증감 버튼의 아래 부분은 ScrollView 밖에 있고 스크롤로 접근하는 내용이며 숫자 고정 clipping과 구분한다. [결과](assets/2026-10-06-duo-cli/rotation-partial-result.json).

- 지표 카드와 Dynamic Type 아이콘 크기까지 포함한 최종 소스의 표준 Xcode 27.1 build는 **exit 0 / BUILD SUCCEEDED**다. `ax-metric-cards-final-build.log`를 보존한다. 후속 UI route의 native 확인을 완료하기 전 시각 수정 합격으로 확장하지 않는다.
- 계정 공용 주간 사용량은 이번 확인에서 38%다. 작업 단독 토큰은 제공되지 않아 unknown이며 사용량 백분율을 작업 토큰 절감률로 환산하지 않는다.

## 한정된 재검증

600초 기능 timeout은 증명된 원인이 없어 해결됐다고 단정하지 않는다. 중복 frame/hit testing을 줄이고 Skip 직후 checkpoint를 추가한 변경을 근거로 같은 최대 AX 휴식 selector를 **1회만** 재검증한다. 또 regular 3D 진입 수정의 Open/maxAX selector를 1회 재검증한다. 기존 실패 receipt를 유지하고, 재검증이 실패하면 같은 조건을 이름만 바꿔 추가 반복하지 않는다.

## Closed landscape 최대 AX에서 발견한 짧은 viewport

기본 크기 Closed 회전은 통과했으나 maxAX는 전체 KG frame 조건에 실패했다. 실제 window는 678×466, control viewport는 662×122, KG field 높이는 99.7pt였다. 고정 진행 header/footer가 본문 높이를 소비하고 탐색 drag가 위/아래로 번갈아 움직인 원본을 보존한다. [결과](assets/2026-10-06-duo-cli/rotation-closed-result.json), [AX](assets/2026-10-06-duo-cli/rotation-closed/029-hierarchy.txt).

WorkoutSessionView는 전체 가용 높이 400pt 미만과 accessibility text size가 함께 성립할 때 진행 표시와 Complete Set도 controls ScrollView에 포함하도록 수정했다. 높이/AX 조건 밖의 기존 header/footer 및 두 열 overview 정책은 유지한다. 입력/완료값과 frame assertion은 제거하지 않았다. 표준 build 및 같은 Closed/maxAX 회전 selector의 한정 재검증은 진행 중이다.

- partial-routes 첫 실행은 앞선 Closed 회전 실패 후 landscapeLeft 상태를 상속했다. 90°의 tall inner viewport에서 수행한 추가 조건으로 기록하며 Book/portrait 증거로 전파하지 않는다. 남은 route group에는 실제 portrait readback을 독립 확인하는 preflight를 추가했다. Book/portrait은 별도 실행한다.
- 수정된 explicit 3D 진입은 첫 partial route에서 68.063초로 통과했고 native 008에 실제 모델이 렌더링됐다. 모델 아래쪽은 summary overlay와 겹치므로 ARView 존재/모델 로드 확인을 전체 3D 시각 합격으로 확대하지 않는다.

## 3D 최대 AX의 모델 가림 수정

첫 partial route native에서 최대 AX summary overlay가 모델의 아래쪽을 덮는 것을 확인했다. AX 크기의 3D 화면은 넓을 때 viewer와 scroll controls를 옆 열로, 좁을 때 viewer와 아래 scroll controls로 분리했다. AX summary도 세로 배치해 텍스트를 보존한다. 기본 크기의 immersive overlay는 유지한다. viewer/controls frame 불교차 및 mode picker 도달성을 UI 테스트에 추가했다. 최종 소스 표준 Xcode 27.1 build가 exit 0 / BUILD SUCCEEDED이며 actual Closed/Open/Book native 검사는 진행 중이다.

partial-routes는 개별 UI case 3개가 통과했으나 Selected tests 종료 뒤 cleanup 60초를 초과해 host exit 1이다. runner receipt에는 parent returncode -15와 원래 cleanup timeout이 있다. SIGKILL group cleanup의 OS PermissionError도 발생해 후속 수정은 이 오류가 원래 원인을 가리지 않도록 별도 cleanup_error로 저장한다. 이 실행을 최종 exit 0으로 보고하지 않는다. 독립된 다음 route group 시작은 확인했다. **30 host contracts**가 통과했다.
