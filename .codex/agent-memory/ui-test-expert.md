# UI Test Expert Memory

## Duo 접힘은 GUI 대기 전에 CLI 전환 경로를 검증한다

- 공식 `simctl`에는 접힘 설정 명령이 없고 `devicectl device motion hinge-angle`은 조회 명령이다. 이 사실만으로 GUI나 Mac 잠금 해제가 필수라고 판단하지 않는다.
- [hinge](https://github.com/artemnovichkov/hinge)의 검토한 source commit `7acb090dd7d28fb0aea8e1907211ceff15aa450e`는 Xcode 27.1의 simulator 내부 HID 이벤트로 0°/90°/180°를 설정한다. 2026-10-06 전용 DUNE Duo Visual Audit에서 세 각도 readback과 내부/외부 native PNG 전환을 실제 확인했다.
- 전환은 명시적 UDID와 저장소 simulator test lock 아래에서 수행한다. `booted` 기본값으로 다른 기기를 선택하지 않는다. 외부 source는 먼저 검토하고 revision을 고정한다. 비공개 protocol은 테스트 도구에만 사용하며 앱에 포함하지 않는다.
- setter exit 0만으로 성공 판정하지 않는다. 실제 각도가 목표 범위인지 조회하고, fresh XCTest AX 및 두 화면의 native PNG를 저장한 뒤 checkpoint ACK를 보낸다. 실패한 전환은 ACK/release하지 않는다.
- PNG 크기만으로 접힘 자세를 구분하지 않는다. 실제 각도·활성 화면·테스트 assertion을 함께 기록한다. CLI 제어 성공은 앱의 초안·휴식·회전 검사 통과와 별도다.
- `devicectl` 스트리밍은 첫 유효 sample 뒤에도 종료 정리가 늦어질 수 있다. 검토한 `hinge get`은 sample을 얻은 뒤 자신의 조회 process를 종료해 단일 조회로 사용한다. GUI 잠금이나 과거 SDK 실패를 모든 background 검사의 불가능으로 일반화하지 않는다.

## 회전 setter의 성공 응답과 실제 방향을 구분한다

- Xcode 27.1에는 공식 `devicectl device orientation set/get/rotate`가 있다. 2026-10-06 Duo inner 180°의 `set landscapeLeft`는 성공 JSON을 반환했으나, 즉시 및 지연 get readback은 portrait이고 orientation lock은 false였다. 성공 응답만으로 회전 완료를 기록하지 않는다.
- 이 조건에서 `XCUIDevice.orientation`/공식 setter를 이름만 바꿔 반복하지 않는다. 별도의 Duo 물리 방향 driver를 검토할 경우에도 공식 get, fresh AX, paired native PNG, 실제 앱 viewport 변화와 입력 보존까지 확인한다.
- 기본 글자 크기의 실제 90°→180°→0° 입력/휴식 UI case는 각각 통과했다. 이는 모든 화면·최대 AX·회전·이전 OS scene session 복원 완료를 의미하지 않는다.
- 검토한 [serve-sim source](https://github.com/EvanBacon/serve-sim/tree/c60d583747b88a15616eeecec56f287ef5759769/packages/serve-sim/Sources/SimDuoHID)의 `orientation-picker-control` guest event를 task-local binary로 빌드한 경로는 같은 Duo에서 portrait→landscapeLeft→portrait 공식 readback을 통과했다. legacy orientation 이벤트와 구분한다. source pin `c60d583747b88a15616eeecec56f287ef5759769`, Xcode 27.1, 명시적 UDID 및 simulator lock을 유지한다. helper의 UI enum과 CoreDevice physical landscape 이름은 반대이며, 임시 wrapper는 physical landscapeLeft에 enum 3을 보낸다.
- `scripts/duo-visual-audit.py`의 `DAILVE_DUO_ORIENTATION_CLI`는 검토된 외부 driver 지정용이다. 실행 성공 뒤에도 공식 get 조회를 강제하며, 앱 viewport 회전/UI 기능 합격은 별도 testcase 결과로 판단한다.

## SDK 정리 정체와 실제 기능 실패를 분리한다

- 테스트 timeout/Selected tests 종료 뒤에도 Xcode 결과 작성이 멈추면 stdout 무기한 읽기로 대기하지 않는다. host의 60초 cleanup watchdog을 사용한다. 다음 testcase started가 오면 deadline을 해제해 진행 중인 검사를 중단하지 않는다.
- host가 start_new_session으로 만든 runner process group만 종료하고 SIGTERM 뒤 남은 descendant를 정리·reap한다. 다른 worktree/시뮬레이터 작업을 임의 PID로 종료하지 않는다. 종료 이유/returncode/checkpoint 수는 runner-result.json에 남긴다. 로컬 프로세스 계약은 정상 완료, stdout EOF 정체, 다음 case 재개, descendant pipe 해제와 다른 runner 생존을 검사한다. 실제 SDK 실패가 해결됐다는 증거와 구분한다.
- 2026-10-06 최대 AX full countdown fold case는 세 자세의 숫자 frame/capture 뒤 next-set 검사에서 600초 초과했다. 실패 receipt를 보존한다. 이전 기능 통과나 native 숫자 확인으로 이 실행을 통과 처리하지 않는다. 원인이 증명되기 전 HID/GUI/앱 원인으로 단정하지 않는다.

## Duo regular 너비의 근육 상세와 3D 진입은 별도다

- MuscleMapDetailView는 regular 너비에서 근육 tap을 옆 열의 상세 선택으로 처리한다. 실제 3D 진입은 별도 3D Muscle Map 버튼이다. compact에서는 근육 tap으로 바로 진입한다. 3D 테스트가 regular에서도 자동 진입을 기대하면 false failure가 된다.
- 버튼 존재/ARView AX 존재만으로 렌더링 합격을 선언하지 않는다. 진입 후 native PNG에서 모델과 overlay를 확인한다. 최대 AX의 고정 두 열 지표 카드는 숫자 잘림/부호 세로 분절 여부를 별도로 검사한다.

## 각 route group의 시작 자세를 독립 확인한다

- 회전 case가 실패하면 portrait 복원 코드에 도달하지 않을 수 있다. 다음 route group이 이전 방향을 상속한다고 가정하지 않는다. 준비 단계에서 검토한 driver로 portrait 설정 후 공식 get readback receipt를 남긴다. 다른 방향에서 통과한 route는 해당 방향의 추가 증거일 뿐 계획된 portrait 합격으로 전파하지 않는다.
- Closed landscape/maxAX 실제 window 678×466에서 고정 workout 진행 header/footer가 control viewport를 122pt로 줄였고 전체 KG frame 검사에 실패했다. 초기 가용 높이 400pt 미만+AX 크기 대응은 Closed landscape 회전 검사를 통과했지만 portrait의 휴식 종료 후 footer 복귀까지 수용하지 못했다. 최종 조건은 700pt 미만+AX다. 변경된 조건의 접힘·회전 검사는 별도 결과로 판단한다.
- 3D는 ARView 로드뿐 아니라 summary overlay가 모델을 덮는지 native를 확인한다. AX 크기에서는 viewer와 scroll controls를 분리하고 frame 불교차·mode 도달성을 검사한다. 기본 크기의 immersive overlay는 별도 조건으로 검증한다.
- 실제 SDK cleanup watchdog의 일부 SIGKILL group 요청이 OS PermissionError를 반환했다. 이때 원래 timeout을 다른 traceback으로 가리지 않고 cleanup_error/parent returncode를 별도 기록한다. 격리 runner의 종료와 모든 descendant 종료를 혼동하지 않는다. 다른 작업 PID를 대신 종료하지 않는다.


## 메뉴·제목과 지속 animation의 실제 native를 검사한다

- Book portrait/maxAX의 metric comparison system menu는 x=-76.8pt로 화면 밖에 열려 month activation point가 실패했다. 버튼 존재만으로 선택 가능을 주장하지 않는다. AX 크기의 기간 선택은 본문 내 button 목록으로 배치하고 전체 scroll viewport 포함·tap·selected trait·두 metric의 같은 날짜 갱신·Done 복귀를 확인한다.
- 같은 native에서 navigation title이 ellipsis로 생략됐다. 최대 AX 제목은 본문에 줄바꿈 가능한 Text로 표시한다. 기간 메뉴 개선만 통과한 실행을 제목 수정까지 통과했다고 확장하지 않는다.
- 타이머 숫자/elapsed assertion이 통과했는데 gesture만 오래 걸리면 XCTest의 실제 animation idle 로그를 확인한다. 매초 갱신되는 1초 ring animation을 의심해 0.25초로 바꾼 단독 smoke는 통과했지만, 실제 fold에서는 ring이 사라진 next-set gesture에서도 같은 idle 대기와 600초 timeout이 재발했다. 가설이 입증되지 않아 원래 1초로 되돌렸다. 이 실험을 최종 원인/해결책으로 기록하지 않는다. idle 대기 자체를 끄거나 testcase timeout을 늘려 통과시키지 않는다.
- 2026-10-06 Closed landscape/maxAX 전체 입력 회전 수정은 173.237초 exit 0, Open portrait/maxAX 3D는 90.136초 exit 0이었다. Rest fold 재검증도 445.019초 exit 0으로 next set까지 통과했다. 이 휴식 결과는 강화된 다음 세트 전체 field 조건 추가 전 앱이며 새 조건의 증거로 재사용하지 않는다.
- 원본 failures, individual testcase 결과, host SDK cleanup 결과 및 현재 source 적용 범위를 보고서에 각각 유지한다. 새 기능/화면을 추가로 검사하면서도 기존 UNVERIFIED 전체 인벤토리를 일괄 통과 처리하지 않는다.

## 휴식 종료 후 footer 복귀에 따른 viewport 축소를 검증한다

- Closed portrait/maxAX는 휴식 중 body가 467pt였으나 Complete Set 고정 footer가 복귀하면 334pt로 줄었다. 두 숫자 입력의 합친 높이는 377pt였다. auto-center만으로 물리적으로 두 입력을 수용할 수 없었다.
- AX에서 전체 높이 700pt 미만일 때 header/footer를 scroll에 포함하고 현재 action을 history보다 먼저 둔다. 휴식 종료 시 weight/reps 영역 위쪽으로 animation 없이 이동한다. 입력 binding·timer deadline·Skip 동작은 유지한다.
- 수정 후 Closed portrait 강화 검사는 175.391초, 1/1 passed, exit 0으로 Skip 직후 두 입력 전체 frame을 추가 swipe 없이 확인했고 native KG 60 / REPS 10 및 증감 버튼을 확인했다. 최종 실제 90°→180°→0° 휴식은 275.743초 exit 0으로 whole countdown·완료 세트·Skip·다음 kg/reps 전체 frame·Done까지 통과했다. 높이 조건 변경 후 Book maxAX 물리 회전도 156.163초 exit 0으로 입력값 62.5/11을 유지했다. 회전의 전체 field 도달성과 두 field 동시 표시를 혼동하지 않는다.
