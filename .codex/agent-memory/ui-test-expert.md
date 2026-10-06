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


## 사용자 기기 격리와 잔여 화면 진단 (2026-10-06)

- 사용자가 iPad Simulator를 사용하면 GUI focus·창·메뉴·keyboard 조작을 금지하고 전용 UDID만 CLI/XCTest 대상으로 지정한다. `booted` fallback은 사용자 기기까지 포함할 수 있어 사용하지 않는다. 현재 테스트/동작 결과와 native 시각 검토는 별도 기록한다.
- `auditTap` 캡처는 tap **후** 화면이다. Injury 저장 버튼 뒤 캡처는 편집 화면 증거가 아니라 저장 후 상세일 수 있다. 실제 편집 native005에서 title3-scaled 28pt 아이콘 열과 설명 사이 16.7pt 간격을 확인했다.
- Health fixture가 있는 것과 component detail이 채워진 것은 다르다. 기본 Condition mock은 detail nil로 `--`를 표시한다. 숫자 clipping 검사는 opt-in DEBUG fixture로 세 자리 100 및 가중치 70/30을 확인하되 기본 mock의 의미를 바꾸지 않는다. Weather와 briefing은 각각 시간/날짜/disabled 설정을 고정한다.
- UI locale이 English여도 exercise library의 실제 fixture 이름은 한국어일 수 있다. 리소스 값을 사용한다. UIKit share caption의 정확한 제목은 StaticText가 아니라 Other 노드에 나타날 수 있으므로 실제 AX 타입과 exact label로 조회한다. 제목의 존재와 전체 share→Close→Done 복귀는 별도 검증이다.
- Form의 화면 아래 행은 lazy AX snapshot에 없을 수 있다. 존재하지 않는 Add Exercise에 즉시 auditTap하지 않는다. 실제 form scroll viewport를 제한된 느린 scroll로 이동하고 전체 frame 포함을 확인한 뒤 탭한다. 소스에 선언된 행과 화면 내부 clipping을 구분한다.
- 고정 20/28/32pt icon 열은 자동 확대된 glyph와 겹칠 수 있다. glyph의 font 기준 ScaledMetric을 적용하고 실제 native 간격을 확인한다. Stress 세 자세의 전체 설명과 아이콘·가중치 간격은 별도 강화 검사와 18 native 검토를 통과했다.
- 공통 SubScoreTrendChartView의 소비자는 Condition 2, Readiness 3, Wellness 3이다. section 중앙만 캡처하면 큰 Sleep plot의 하단 눈금이 viewport 밖일 수 있다. 각각 전체 plot frame을 드러내고 native의 Y눈금/양쪽 날짜까지 검토해야 한다.
- 일반 iPhone에는 Duo의 두 display가 없다. host-only 캡처 handshake와 Duo orientation driver를 혼동하지 않는다. Full plan에서 일반 폰은 XCUIDevice orientation을 사용하고, Duo driver는 explicit fold opt-in 조건을 함께 확인한다. 이 설정 수정의 최종 기능 결과는 별도 실행 receipt로 판단한다.

## 후속 native gate 교정 (2026-10-07)

- 큰 swipe는 전체 그래프를 위아래로 지나칠 수 있다. 작은 방향 drag로 실제 plot 전체를 노출하며, 화면보다 큰 Life chart는 제목과 아래 축을 분리해 검사한다. 테스트 여백을 임의80pt로 정하면 실제 보이는 Form 하단 버튼도 실패할 수 있다. 실제 nav-bar 아래와 Form/window 하단으로 유효 영역을 계산한다.
- share popup의 Close는 아래 presenter의 같은 label과 혼동된다. 실제 UIKit `header.closeButton`과 exact caption/AX 타입을 사용한다. 직접 템플릿 세션의 실제 progress는 `Exercise 1 of 2`이며 대문자 가정을 하지 않는다. SDK cleanup timeout은 실제 testcase pass와 별개로 기록한다.
- Primary Muscles의 adaptive90 grid는 최대 AX에서 완전한 접근성 label이 있어도 Shoulders를 네 줄 글자별로 쌓는다. AX 단일열과 최소44pt 선택 높이를 적용하고 native로 확인한다. 상대 heading-height/aspect 검사는 English/maxAX 시각 감사에서만 요구해 일반 locale/글자 크기 테스트를 실패시키지 않는다.
- source를 실행 전에 동결한다. 빌드 도중 추가한 FOLD 분기가 해당 binary에 포함됐다고 추정하지 않는다. 이미 통과한 긴 기능 경로는 유지하고 미포함 delta만 짧은 별도 selector로 검사한다. 일반 폰의 host-only 캡처에는 FOLD opt-in이 없으면 XCUIDevice 회전을 유지한다.
