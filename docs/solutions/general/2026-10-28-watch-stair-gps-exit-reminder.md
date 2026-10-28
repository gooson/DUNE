---
tags: [watchos, stair-climber, gps, reminder, false-positive]
category: general
date: 2026-10-28
severity: important
related_files:
  - DUNEWatch/Managers/StairMachineExitDetector.swift
  - DUNEWatch/Managers/StairMachineExitMonitor.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/SessionPagingView.swift
  - DUNEWatchTests/StairMachineExitDetectorTests.swift
  - DUNEWatchTests/StairMachineExitMonitorTests.swift
  - DUNEWatchTests/StairMachineExitRecoveryTests.swift
related_solutions:
  - docs/solutions/general/2026-10-19-watch-stair-workout-continuity.md
  - docs/solutions/general/2026-10-14-watch-stair-handrail-inactivity.md
---

# 계단 기구에서 내려온 뒤 실제 위치 이동으로 종료 안내

## Problem

천국의 계단 운동 후 실외에서 한참 걸어도 종료 여부를 묻지 않았다. 계단 운동은 손잡이를 잡았을 때의 오탐을 막기 위해 일반 정지 알림에서 제외돼 있고, 기존 HealthKit 보행 거리 기반 기구 이탈 추정은 기구 위에서도 잘못된 확인창을 띄워 제거된 상태였다.

## Solution

기존 일반 정지 정책은 유지하고 두 계단 기구 유형에 별도의 GPS 감지기를 연결했다. HealthKit의 추정 거리를 실제 위치 이동으로 사용하지 않는다.

- 운동 시작 후 120초 이상, 정확도 20m 이내의 최근 GPS 표본 4개 이상, 표본 사이 공백 30초 이하, 60초 이상 관찰, 양 끝 위치 오차를 뺀 순이동 100m 이상, 40걸음 이상 증가를 함께 요구한다. 임계값은 보수적인 초기 제품 정책이며 실기기에서 조정할 수 있다.
- 실내에서 GPS가 없다가 실외에서 처음 수신해도 그 위치부터 관찰한다. 좌표·걸음·시각의 유효성을 검사하고 오래된/미래/역순 표본은 무시한다. 긴 수집 공백, 걸음 수 롤백, 4m/s를 초과하는 위치 급변에서는 후보를 다시 시작한다.
- C19 시스템 알림은 종료 여부만 묻는다. 타이머·기록은 계속 유지하고 자동 종료하지 않는다. 계속 운동 또는 사용자 닫기 후에는 현재 실행 중인 세션에서 재안내하지 않는다.
- 위치 권한을 거부해도 운동은 지속된다. 나중에 허용하면 새 위치 기준으로 감지를 재개한다. 일시정지·종료·초기화는 위치 수집을 중단하며, 재개·세션 복구는 새 감지 후보로 시작한다. 좌표는 저장하거나 전송하지 않는다.
- ‘계속 운동’ 선택은 기존 운동 복구 snapshot의 optional Bool로 즉시 저장한다. 같은 HK 세션을 복구하면 다시 안내하지 않고, 구버전 snapshot은 false로 복원하며 새 운동에서만 선택을 초기화한다.
- `InfoPlist.xcstrings`는 시스템 위치 권한 문구의 en/ko/ja 번역을 위한 시스템 테이블이다. 앱 UI 문자열은 기존 `Localizable.xcstrings`를 유지한다. 빌드 산출물에서 3개 언어의 `InfoPlist.strings` 생성을 확인했다.

백그라운드 위치 수집은 `UIBackgroundModes=location`과 `allowsBackgroundLocationUpdates`를 함께 설정한다. [Apple의 설정 요구사항](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates)을 따른다. 종료 안내 진동은 View의 관찰이 아닌 운동 관리자에서 한 번 발생시킨다. 활성 운동 세션에서 백그라운드 진동을 허용하는 [WatchKit API](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:))의 조건을 사용하며 실기기 전달까지 인증한 것은 아니다.

## 검증

- 관련 Watch 단위 테스트 **31개 / 5개 suite 통과**. GPS 감지 10개, 위치 권한/생명주기 5개 및 기존 정지 정책·지표 진행·경과 시간 테스트를 포함한다. `.xcodebuild/stair-gps-exit-unit.log`의 Swift Testing 최종 집계를 확인했다. 앞선 XCTest 호스트의 0건 집계를 테스트 전체 집계로 사용하지 않는다.
- 리뷰의 세션 복구 수정 후 최종 관련 Watch 단위 **34개 / 6개 suite 통과**. 추가된 3개는 즉시 저장·복구, 구버전 snapshot, 새 운동 초기화 경로다. [보존한 최종 단위 결과](../../reviews/2026-10-28-watch-stair-exit/watch-unit-receipt.json)와 [리뷰·처리 상태](../../reviews/2026-10-28-watch-stair-exit-review-ship.md)를 따른다. UI 표현·감지 임계값은 이 수정에서 바꾸지 않았으며 기존 관련 UI와 C19 최종 문구 캡처를 재사용한다.
- 최초 단위 테스트 컴파일에서 `#expect(!detector.observe(...))`의 mutating receiver 캡처가 실패했다. 명시적 `inout` helper로 바꾼 후 같은 범위를 1회 재실행해 통과했다. 최초 실패 로그는 `.xcodebuild/stair-gps-exit-unit-attempt1.log`에 남겼다.
- 관련 Watch UI **3개 수행 / 3개 통과 / 0개 실패·누락**. C10의 기존 무알림 진행, C19가 일반 10초 자동 종료 시간을 지나서도 유지됨, 계속 운동 후 타이머 증가, 명시적 종료 후 요약 전환을 확인했다. `.xcodebuild/stair-gps-exit-ui.log.result.json` 참조.
- UI 실행 이후 변경한 앱 코드는 시뮬레이터에서 생성하지 않는 위치 수집기의 권한 재허용 처리뿐이다. 해당 delta는 이후 단위 테스트·최종 Watch 빌드와 읽기 전용 품질 재검토로 확인했다. 동일 UI를 다시 실행하지 않았다.
- `swift scripts/format-xcstrings.swift --check`와 `git diff --check`, Info.plist 검사를 수행했다.

기기: Apple Watch SE 3 (40mm), watchOS 27.0, worktree 소유 UDID `815E6D04-206D-4747-B812-71516366C691`. UI 결과 번들은 `Test-DUNEWatchUITests-2026.10.28_09-42-20-+0900.xcresult`. 실제 C10/C19 원본 PNG를 [Watch 실제 디자인맵](../../design/phone-design-map/actual/watch/index.html)에 반영하고 직접 확인했다. 한국어·기본 글씨·세로 40mm만 검증했으며 다른 크기·언어·큰 글씨와 iPhone/iPad/Duo는 검증 범위에 포함하지 않는다.

## Prevention

C19 문구는 제목 ‘계단 운동을 마칠까요?’와 본문 ‘이동이 감지됐어요.’로 역할을 나눈다. 본문에서 종료 여부를 다시 질문하지 않는다. 영어와 일본어도 감지 사유만 남긴다.

문구 보완 후 C19 관련 Watch UI 1개가 통과했다. `.xcodebuild/stair-exit-copy-ui.log.result.json`과 `Test-DUNEWatchUITests-2026.10.28_10-22-32-+0900.xcresult`를 사용해 C19 원본을 갱신했다. 이 후속 실행의 worktree 전용 기기는 `AE78BB39-ABEA-4311-886D-A6C42D03F805`이며 C10과 나머지 동작 검증은 위 최초 실행의 출처를 유지한다.

머신 운동에서 계산된 보행 거리와 실제 GPS 위치를 구분한다. 손목 정지나 활동 칼로리 무변화를 종료 증거로 사용하지 않는다. 센서 전달 시간은 서로 다를 수 있으므로 GPS 이동과 걸음 증가를 같은 콜백에서 요구하지 않는다. 시스템 권한의 거부→허용뿐 아니라 운동 종료 후 늦은 권한 콜백도 검증한다.

## 남은 실기기 확인

GPS/HealthKit 수집 지연, 실내 GPS 흔들림, 실제 실외 이동, 손목을 내린 상태의 진동, 추가 배터리 사용량은 실제 Watch에서 확인해야 한다. 위치 권한이 없거나 정확한 GPS가 충분히 오지 않으면 안내하지 않는다. 시뮬레이터 fixture 통과를 실제 센서 검증 완료로 보고하지 않는다.
