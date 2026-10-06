# UI Test Expert Memory

## Duo 접힘은 GUI 대기 전에 CLI 전환 경로를 검증한다

- 공식 `simctl`에는 접힘 설정 명령이 없고 `devicectl device motion hinge-angle`은 조회 명령이다. 이 사실만으로 GUI나 Mac 잠금 해제가 필수라고 판단하지 않는다.
- [hinge](https://github.com/artemnovichkov/hinge)의 검토한 source commit `7acb090dd7d28fb0aea8e1907211ceff15aa450e`는 Xcode 27.1의 simulator 내부 HID 이벤트로 0°/90°/180°를 설정한다. 2026-10-06 전용 DUNE Duo Visual Audit에서 세 각도 readback과 내부/외부 native PNG 전환을 실제 확인했다.
- 전환은 명시적 UDID와 저장소 simulator test lock 아래에서 수행한다. `booted` 기본값으로 다른 기기를 선택하지 않는다. 외부 source는 먼저 검토하고 revision을 고정한다. 비공개 protocol은 테스트 도구에만 사용하며 앱에 포함하지 않는다.
- setter exit 0만으로 성공 판정하지 않는다. 실제 각도가 목표 범위인지 조회하고, fresh XCTest AX 및 두 화면의 native PNG를 저장한 뒤 checkpoint ACK를 보낸다. 실패한 전환은 ACK/release하지 않는다.
- PNG 크기만으로 접힘 자세를 구분하지 않는다. 실제 각도·활성 화면·테스트 assertion을 함께 기록한다. CLI 제어 성공은 앱의 초안·휴식·회전 검사 통과와 별도다.
- `devicectl` 스트리밍은 첫 유효 sample 뒤에도 종료 정리가 늦어질 수 있다. 검토한 `hinge get`은 sample을 얻은 뒤 자신의 조회 process를 종료해 단일 조회로 사용한다. GUI 잠금이나 과거 SDK 실패를 모든 background 검사의 불가능으로 일반화하지 않는다.
