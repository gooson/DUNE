---
tags: [design, live-activity, actual-capture]
date: 2026-10-25
status: partial
---

# WLA01 · Watch 운동 Live Activity 실제 화면

WLA01은 앱 안의 화면이 아닌 iOS 시스템 표면이다. [레이아웃 기준 시안](../../../layout-map/watch-workout-live-activity.md)과 실제 캡처는 구분한다. 2026-10-25의 배치를 전용 iPhone 18 Pro / iOS 27.0에서 다시 캡처했다. 진행·일시 정지·긴 한국어 근력 운동명 세 장의 원본 XCTest 요소 PNG에서 이름·시간·심박·칼로리·거리의 잘림이나 겹침이 없음을 확인했다. 다른 앱 알림이 포함되지 않으며 이미지 후처리는 하지 않았다.

대상 iPhone 상태는 알림 센터의 진행·일시 정지·연결 대기, Dynamic Island compact와 expanded의 진행·일시 정지다. 일시 정지 시 compact/minimal 아이콘은 일시 정지 기호이고 시간은 고정된다. 연결 대기 상태에서는 오래된 시간·심박·칼로리·거리를 숨긴다.

DEBUG 시드로 만든 `WatchWorkoutLiveActivityUITests` 화면은 **실제 SpringBoard 알림 센터에 표시된 Live Activity**를 검증한다. 시드 화면은 Watch 센서·미러링 없이 만들어지므로, 실제 잠긴 iPhone에서 Watch 운동을 시작하고 갱신하는 경로의 증거가 아니다. Dynamic Island 캡처도 별도 수집 전까지 완료로 표시하지 않는다.

캡처를 추가할 때는 `images/`에 해당 상태의 원본 PNG를 보존하고 `capture-index.json`의 해당 상태만 `captured`로 바꾼다. 테스트 이름, 결과 번들, 기기·OS, 캡처 시각, `seeded_springboard` 또는 `paired_device` 출처를 함께 기록한다. PNG를 눈으로 확인해 운동명·시간·수치·잘림을 점검한 뒤 [갤러리](index.html)를 갱신한다. XCTest 첨부 이름은 `WLA01-running-notification-center`와 `WLA01-paused-notification-center`다. `xcrun xcresulttool export attachments --path <결과.xcresult> --output-path <임시 디렉터리>`로 원본을 추출할 수 있다.

iPad, Duo 접힘·펼침, Watch small family도 이 작업에서 캡처하지 않았다. 이 기기와 표면의 결과는 iPhone 시드 캡처로 대체하지 않는다.

## 2026-10-25 정보 위계와 검증 제한

운동명·상태를 작은 헤더로 묶고 경과 시간을 크게 강조했다. 심박·칼로리·거리는 의미별 색상 아이콘과 숫자·단위를 구분한다. 이번 이미지 세 장은 어두운 표면이며 밝은 모드·최대 글씨·small·Island를 확인한 결과는 아니다.

`scripts/build-ios.sh --no-regen --log-file .xcodebuild/live-activity-build-final.log`는 통과했다. 관련 시스템 테스트 4건의 로그는 3건 통과·연결 대기 1건 실패를 기록했다. 그 뒤 Xcode가 `IDESchemeActionSDKRecord invalidDigitCount(94232)`를 출력하고 결과 정리를 완료하지 못해 표준 실행기가 로그 무활동 180초 후 종료했다(exit 124). 완료된 테스트 번들·성공한 UI 게이트로 보고하지 않는다.

중단된 `Test-DUNEUITests-2026.10.25_16-16-50-+0900.xcresult`에는 `Info.plist`가 없어 `xcresulttool export attachments`가 실패했다. 대신 `Data/data.0~…`에 남은 세 원본 PNG를 수정 없이 복사하고 화면 내용을 직접 확인했다. 각 원본 payload 이름과 SHA-256, 해당 통과 메서드, 기기·출처는 `capture-index.json`에 보존한다. 캡처 시각은 PNG payload 파일의 수정 시각이므로 별도로 표시했다. 메서드 통과와 실행기 실패를 구분한다.

연결 대기 fixture는 시스템의 3초 후 stale 전환 예약에 의존하지 않게 이미 지난 `staleDate`를 사용하도록 수정했다. SDK 결과 정리 문제가 해소되지 않아 재실행하지 않았다. Xcode가 같은 전용 iPhone에서 결과 번들을 정상적으로 마무리할 수 있게 되면 `WatchWorkoutLiveActivityUITests/testStaleNotificationCenterHidesOutdatedMetrics`만 우선 재검증한다. 그 전에는 연결 대기 캡처를 완료로 표시하지 않는다.

## 2026-10-24 DESERT HORIZON 갱신

9e3788a4의 따뜻한 표면·액센트·민감 정보 표시 적용 후, 전용 iPhone 18 Pro에서 진행·일시 정지 알림 센터 시스템 요소를 새로 촬영했다. 두 메서드는 각각 통과했다(같은 번들의 Rest 검사 1건은 별도 실패). 시스템 어두운 모드 캡처이며 밝은 모드·실제 잠금 상태·쌍 기기·Island·small family의 증거가 아니다. 개별 기기·시각·테스트는 capture-index.json을 따른다.

## DUNE 워드마크 추가 후 캡처 대기

사용자 피드백에 따라 공통 헤더의 기존 상태 행을 `DUNE · 운동` 형태로 바꿨다. DUNE는 작은 bold rounded 워드마크와 자간·기존 테마 액센트로 표시하며 별도 행을 늘리지 않는다. 잠금 화면·small·Island 펼침에 적용된다. UI 테스트에 워드마크 식별자·정확한 이름·컨테이너 내 프레임 검사를 추가했다. 위 세 PNG는 이 변경 전 캡처이며 `capture-index.json`에서 outdated로 표시했다. 현재 WLA01의 진행·일시 정지·긴 운동명·연결 대기, small·Island 펼침의 새 캡처는 미완료다. 이전 SDK 결과 정리 장애가 해소되지 않아 같은 UI 실행 경로를 반복하지 않았으며, 결과 번들 정상 종료가 가능해지면 전용 iPhone의 긴 운동명 테스트부터 재검증한다.

## Watch 종료 후 제거 경로 수정

Watch의 종료 데이터를 미러와 독립적인 WC lifecycle로 전달하고 iPhone의 ActivityKit 정리에 연결했다. 실제 Watch 종료 후 iPhone 카드 제거는 새 검증 상태로 추가했으며 미캡처다. 기존 SpringBoard 시드 PNG는 Watch의 실제 종료 경로를 검증하지 않는다. SDK UI 결과 정리 장애가 정상화된 뒤 실제 쌍 기기의 종료·끊김·재연결을 확인해야 한다. 구현·코어 검증 범위는 [종료 정리 해결 문서](../../../../solutions/general/2026-10-25-watch-workout-ended-live-activity-cleanup.md)에 기록했다.


## 2026-10-30 운동별 아이콘 · 새 캡처 대기

현재 소스는 Watch/초기 미러 세션의 실제 운동 종류를 사용한다. 러닝·걷기·사이클·수영·근력 등의 기존 canonical SF Symbol을 전달하며, paused/ended/stale 기호는 유지한다. 복구 메타데이터가 없는 유산소 세션도 HealthKit 종류를 우선한다. 미지원 기호는 figure로 대체하고 헤더 장식 아이콘은 VoiceOver에서 숨긴다.

초기 ENOSPC로 별도 작업트리를 만들지 못했다. 이후 공간이 확보되어 현재 작업트리 전용 iPhone 18 Pro(iOS 27.0, UDID 9905027B-0A4A-4A45-84D0-98431BE94BAC)의 소유권을 확인하고 표준 `scripts/test-ui.sh`로 `WatchWorkoutLiveActivityUITests`를 실행했으나, 다른 작업의 저장소 시뮬레이터 잠금이 60초 동안 해제되지 않아 exit 2로 시작하지 못했다. 테스트 0건은 통과가 아니다. 현재 실행의 로그와 출처는 `.codex-checks/live-activity-icons/`에 남긴다.

새 PNG는 없으며 위의 이전 PNG를 운동별 기호의 증거로 재사용하지 않는다. 미갱신은 WLA01 iPhone 잠금 화면/알림 센터의 러닝·사이클·근력·일시 정지·연결 대기, Dynamic Island compact/minimal/expanded, Watch small, iPad와 Duo 접힘·펼침이다. 실제 Watch↔iPhone 연동·복구도 미확인이다. 저장소 잠금이 해제되면 관련 시스템 UI와 Xcode 단위 테스트를 우선 실행하고 최종 요구 UI 범위(iOS/Watch full)를 충족한 뒤 새 원본과 SHA-256·기기·시각·selector를 기록한다.


## 최종 실행 결과 · 2026-10-30

시스템 UI 재시도 로그는 `** BUILD INTERRUPTED **`로 끝났다. XCTest case 시작 기록은 0개이며 최종 `.result.json`이 없어 실행 건수·종료 코드를 확정할 수 없다. 테스트 통과나 UI 게이트 완료로 처리하지 않는다. 새 WLA01 PNG는 없고 기존 캡처는 이번 운동별 아이콘의 증거가 아니다.

구현·최종 통합 빌드·실제 Snapshot Swift Testing 15개·5관점 및 전문 코드 리뷰는 완료했다. [Draft PR #864](https://github.com/gooson/DUNE/pull/864)에 보존했으며 UI 검증 미완료로 머지하지 않았다. 재개 조건은 빌드 실행 환경 정상화 후 전용 iPhone의 WLA01+smoke 실행이 최종 receipt와 새 캡처를 생성하는 것이다. 다른 작업의 미커밋 소스·문서는 커밋하거나 정리하지 않았다.
