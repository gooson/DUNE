# UI 실행 환경 진단

입력 UI 검사의 키보드 사전 조건을 확인하거나 UI 실행·캡처가 환경 문제로 막혔을 때 읽는다. 범위·전용 기기·deadline·재시도 한도는 `skill-compat.md`가 기준이며 이 문서는 환경 확인과 실패 분류를 보완한다.

## 잠금 종류부터 구분한다

| 관측 | 의미 | 다음 조치 |
|------|------|----------|
| `repository simulator test lock remained busy` | 다른 runner가 저장소 실행권 점유. 테스트는 아직 시작하지 않았을 수 있음 | `waiting-for-owner`로 보고. 중복 runner/다른 기기 우회를 만들지 말고 코드 검토·문서 등 독립 작업 진행 |
| `.host.json`의 `host_locked=yes` | 현재 사용자 콘솔의 Mac 화면 잠금 진단 | 이것만으로 iOS/watch Simulator XCTest 불가 판정 금지. CLI/XCTest의 실제 오류와 단계 확인 |
| 디스플레이 꺼짐 | 화면 수면 가능성 | Mac 잠금/시스템 수면으로 단정 금지. `caffeinate`는 잠금 해제가 아님 |
| `caller_launch_manager=other`, 다른 콘솔 사용자 | 호출 프로세스가 Aqua manager에 속하지 않거나 현재 콘솔 사용자와 다름 | 로그인 세션/실행 환경 확인. 전역 Aqua 세션이 없다고 단정하지 않음 |
| Simulator `Booted` | guest가 부팅됨 | 앱 전경·AX 준비·권한·실제 viewport가 정상이라는 증거는 아님 |
| `Failed to activate`, AX/권한 오류 | 대상 플랫폼의 자동화/전경 조건 불충족 후보 | macOS 앱과 iOS Simulator를 구분. 명시적 오류 없이 TCC 원인 단정 금지 |
| 물리 방향과 AX/native PNG 불일치 | 방향 setter와 앱 렌더링 불일치 | Duo memory의 검토된 CLI와 readback을 확인. 성공 exit만으로 회전 통과 처리 금지 |
| 테스트 종료 문구 후 결과 정리 정체 | SDK/xcresult 정리 단계 장애 후보 | 기존 watchdog 결과 보존. testcase pass와 runner 정상 종료를 별도 보고 |

`test-ui.sh`와 `test-watch-ui.sh`는 실행권을 획득한 뒤 `<log>.host.json`에 시작 시각·호출 manager·콘솔 사용자 일치·Mac 잠금 진단을 저장한다. 5초 외부 deadline과 각 조회 1.5초 제한을 적용하며 실패해도 테스트를 막지 않는다. `ioreg` 값은 구현 종속 진단이므로 누락·충돌·다른 사용자이면 `unknown`이다. 수면/TCC 권한은 이 도구로 확인하지 않는다. 시작 기록은 실행 중 상태 변화까지 증명하지 않는다.

## 막힌 지점에서 한 번 확인한다

1. 최초 오류와 마지막 진행 단계(`lock`, `boot`, `build`, `test-start`, `testcase`, `result-finalize`)를 기존 로그에서 확인한다. 소스 문서에 들어 있는 오류 예시는 실제 실패로 세지 않는다.
2. 시작 sidecar를 읽는다. 실행 중 잠금 변화가 의심될 때만 `python3 scripts/lib/ui-host-state.py --runner ios --output <새-진단-경로>`로 한 번 더 기록한다. Watch는 `--runner watch`. 원래 시작 sidecar는 덮어쓰지 않는다.
3. 앱 화면 확인에는 현재 worktree 소유권이 확인된 UDID의 `simctl io <UDID> screenshot` 또는 XCTest attachment를 사용한다. 선택한 실행 범위의 잠금 안에서 실행하고 새 PNG를 직접 확인한다. 기본은 저장소 잠금이며, 아래 명시적 병행 예외 조건을 확인한 경우에만 현재 worktree 잠금을 사용한다. host GUI 캡처 성공/실패와 guest 앱 캡처를 혼동하지 않는다. 임의의 `booted` 기기·다른 runner에 접근하지 않는다.
4. Duo 접힘/회전은 `.codex/agent-memory/ui-test-expert.md`의 source pin·실제 각도/방향·viewport 검증을 따른다. 검토된 CLI도 실패했다면 정확한 실패 경로를 남긴다. GUI 제어가 실제로 필요한 단계에서만 잠금 해제를 재개 조건으로 제시한다.
5. 기록은 `실행 ID / 단계 / 분류 / 증거 / 미검증 selector·기기 / 재개 조건 / 사용한 재시도`로 짧게 남긴다. `waiting-for-owner`, `host-session`, `simulator-runtime`, `app-assertion`, `result-finalize`, `unknown`을 구분한다. unknown을 앱 버그나 테스트 성공으로 승격하지 않는다.

실행권 대기는 앱 테스트 실패와 구분하지만 기존 자동 재시도 한도를 우회하는 예외가 아니다. 소유 실행 종료 등 원인 해소 근거가 없으면 같은 명령을 다시 보내지 않는다. 사용자에게 잠금 해제부터 요청하거나 전체 작업을 중단하기 전에 독립적으로 진행 가능한 검토·수정·문서를 끝낸다. 필수 UI 증거가 없는 Ship 게이트는 유지한다.

## 소프트웨어 키보드 확인

입력 폼·텍스트 필드·키보드를 검사할 때는 하드웨어 키보드 연결 상태를 사전 조건으로 확인한다. 메뉴 선택 후 입력 폼이 열리지 않거나 키보드/필드 조회가 실패하면 다음 순서로 환경을 분리한다.

1. 현재 worktree 소유로 등록된 대상 UDID를 확인한다. 설정 확인·변경도 동일한 전용 기기에 한정하며 사용자나 다른 worktree의 Simulator 설정을 바꾸지 않는다.
2. 대상 Simulator의 하드웨어 키보드 연결을 해제하고 소프트웨어 키보드가 표시되도록 전환한다. 실제 입력 필드에 포커스했을 때 화면 키보드가 활성화되는지 확인한다. 하드웨어 키보드로 `typeText`가 성공한 것만으로 화면 키보드가 준비됐다고 판단하지 않는다.
3. 확인 근거를 구분해 기록한다. 사용자의 직접 확인은 환경 확인 근거로 인정하고, 자동 확인은 대상 기기의 새 PNG와 키보드 AX 조회 등 실제 증거를 남긴다. 사용자가 확인한 활성화 상태를 근거 없이 미확정으로 되돌리지 않는다.
4. 해당 메뉴 동작·폼 표시·입력/저장 검사 결과는 키보드 확인과 별도로 기록한다. 설정 전환이나 키보드 표시만으로 이전 실패한 UI 검사를 통과 처리하지 않는다. 재개 실행은 기존 실행권·재시도 한도를 유지한다.

**2026-10-29 사용자 확인:** Life의 `+ → New Habit` 입력 경로 실패에 대해 사용자가 하드웨어 키보드 연결을 원인으로 지적하고 소프트웨어 키보드 전환을 안내했다. 이어 소프트웨어 키보드 활성화를 직접 확인했다고 명시했다. 이 확인을 이후 진단의 환경 근거로 사용한다. 해당 설정에서 자동 UI 검사를 다시 통과했다는 결과는 아직 별도 확인 전이다.

## 사용자가 별도 시뮬레이터 검증을 요청한 경우

저장소 잠금 점유만으로 불가능하다고 결론 내리지 않는다. `.codex/skill-compat.md`의 명시적 병행 예외 조건을 확인하고, 다른 작업과 기기·빌드·결과 경로가 분리됐으면 연결된 worktree에서 `DUNE_SIM_TEST_LOCK_SCOPE=worktree`를 해당 명령에만 전달한다. 기본값은 `repository`다. 두 모드 모두 현재 worktree 잠금을 확보하므로 같은 작업 공간의 중복 runner는 계속 차단한다. 구버전 runner에는 이 잠금이 없으므로 활성 프로세스의 작업 경로와 UDID를 먼저 확인한다.

전용 기기 소유권 확인, deadline, 정확한 selector, 결과 receipt는 그대로 필요하다. 새 경로가 확보된 것은 실행권 실패 원인을 해소한 근거로 기록하며, 원인 변화 없는 재시도로 세지 않는다. host 잠금 상태는 시작·종료 시 기록하고 테스트 통과·AX 조작·새 PNG를 각각 확인한다. 잠금 해제가 필요한 비교군은 사용자 인증 없이 만들 수 없으며, 잠금 상태의 성공 결과와 분리해서 보고한다.

## 확인 범위와 공식 근거

- Apple은 [Simulator 테스트에 로그인된 Aqua 세션이 필요](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/08-automation.html)하다고 설명한다. 이 문서는 오래된 문서이므로 현재 SDK의 모든 잠금 동작을 보장하지 않는다.
- [2026-08 Apple DTS 답변](https://developer.apple.com/forums/thread/840965)은 잠긴 세션의 **macOS 앱 XCUITest**가 불가능하다고 설명한다. 이 내용을 iOS/watch Simulator 전체로 일반화하지 않는다.
- [XCTest UI interruption monitor](https://developer.apple.com/documentation/xctest/handling-ui-interruptions)는 예상하지 못한 modal UI 대응이다. Mac 잠금을 해제하는 수단이 아니며 예상된 앱 UI를 회피하는 데 사용하지 않는다.
- [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)는 초기 Simulator 기동 지연, Duo의 StandBy 미지원과 대부분의 app extension 실행·디버깅 미지원을 명시한다. 해당 기능 검증은 지원되는 기기/경로를 먼저 정하며, 이 제한을 앱 재빌드로 해결하려 반복하지 않는다. 기동 지연도 기존 deadline 안에서 판단한다.
- 2026-10-25 로컬 Xcode 27.1 / iOS·watchOS 27.0에서 시작·종료 `host_locked=yes`인 상태로 iPhone 설정 탐색 1개와 Watch 빈 운동 목록 탐색 1개 XCTest가 각각 통과했고 새 PNG 4장·2장을 확보했다. 기존 iPhone clone은 시작 화면에 머물렀으나 빈 전용 기기에서는 같은 앱·테스트로 통과했다. 모든 기기·시나리오에 대한 보장은 아니며, 잠금 해제 비교군은 별도 기록한다. 근거는 `docs/reviews/2026-10-25-session-efficiency-audit.md`의 후속 실험이다.
