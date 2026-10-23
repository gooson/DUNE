---
tags: [design, live-activity, actual-capture]
date: 2026-10-24
status: partial
---

# WLA01 · Watch 운동 Live Activity 실제 화면

WLA01은 앱 안의 화면이 아닌 iOS 시스템 표면이다. [레이아웃 기준 시안](../../../layout-map/watch-workout-live-activity.md)과 실제 캡처는 구분한다. iPhone 18 Pro / iOS 27.0에서 통과한 진행·일시 정지 테스트의 실제 DUNE Live Activity 요소 PNG 두 장을 보존했다. 이름·시간·심박·칼로리·거리의 잘림이나 겹침이 없는지 확인했다. 다른 앱 알림을 포함하지 않도록 XCTest 요소 스크린샷을 사용했으며 이미지 후처리는 하지 않았다.

대상 iPhone 상태는 알림 센터의 진행·일시 정지·연결 대기, Dynamic Island compact와 expanded의 진행·일시 정지다. 일시 정지 시 compact/minimal 아이콘은 일시 정지 기호이고 시간은 고정된다. 연결 대기 상태에서는 오래된 시간·심박·칼로리·거리를 숨긴다.

DEBUG 시드로 만든 `WatchWorkoutLiveActivityUITests` 화면은 **실제 SpringBoard 알림 센터에 표시된 Live Activity**를 검증한다. 시드 화면은 Watch 센서·미러링 없이 만들어지므로, 실제 잠긴 iPhone에서 Watch 운동을 시작하고 갱신하는 경로의 증거가 아니다. Dynamic Island 캡처도 별도 수집 전까지 완료로 표시하지 않는다.

캡처를 추가할 때는 `images/`에 해당 상태의 원본 PNG를 보존하고 `capture-index.json`의 해당 상태만 `captured`로 바꾼다. 테스트 이름, 결과 번들, 기기·OS, 캡처 시각, `seeded_springboard` 또는 `paired_device` 출처를 함께 기록한다. PNG를 눈으로 확인해 운동명·시간·수치·잘림을 점검한 뒤 [갤러리](index.html)를 갱신한다. XCTest 첨부 이름은 `WLA01-running-notification-center`와 `WLA01-paused-notification-center`다. `xcrun xcresulttool export attachments --path <결과.xcresult> --output-path <임시 디렉터리>`로 원본을 추출할 수 있다.

iPad, Duo 접힘·펼침, Watch small family도 이 작업에서 캡처하지 않았다. 이 기기와 표면의 결과는 iPhone 시드 캡처로 대체하지 않는다.

## 2026-10-24 DESERT HORIZON 갱신

9e3788a4의 따뜻한 표면·액센트·민감 정보 표시 적용 후, 전용 iPhone 18 Pro에서 진행·일시 정지 알림 센터 시스템 요소를 새로 촬영했다. 두 메서드는 각각 통과했다(같은 번들의 Rest 검사 1건은 별도 실패). 시스템 어두운 모드 캡처이며 밝은 모드·실제 잠금 상태·쌍 기기·Island·small family의 증거가 아니다. 개별 기기·시각·테스트는 capture-index.json을 따른다.
