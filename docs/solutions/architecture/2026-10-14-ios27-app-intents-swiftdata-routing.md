---
tags: [app-intents, shortcuts, swiftdata, idempotency, scene-routing, ios27]
category: architecture
date: 2026-10-14
severity: important
related_files:
  - DUNE/App/Intents/DUNEShortcuts.swift
  - DUNE/App/Intents/DUNEAppIntentStore.swift
  - DUNE/App/DUNEApp.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
related_solutions:
  - docs/solutions/general/2026-04-05-habit-early-completion-fix.md
---

# Solution: App Intents에서 SwiftData와 기존 화면 동작 재사용

## Problem

Shortcuts는 앱 밖에서 실행되므로 화면의 `@Environment(\.modelContext)`와 `@State`에 직접 의존할 수 없다. 습관 화면의 체크 동작은 토글이어서 단축어 재실행 시 기록을 지울 수 있다. 앱 시작 splash 중에는 `ContentView`가 아직 생성되지 않아 그곳에만 scene handler를 두면 cold launch 요청이 유실될 수 있다.

### Symptoms

- 같은 습관 완료 단축어를 두 번 실행하면 로그가 추가되거나 기존 완료가 취소될 위험
- 저장된 운동 템플릿을 선택해도 Activity 탭의 기존 시작 흐름으로 연결할 경로가 없음
- stale Shortcuts 항목이 삭제·보관 후에도 실행될 수 있음

### Root Cause

기존 UI 동작은 SwiftUI 화면 상태와 SwiftData 관계에 묶여 있으며 App Intent와 공유하는 안정적인 UUID 기반 질의 및 명령 경계가 없었다.

## Solution

`WorkoutTemplateEntity`와 `ManualCheckHabitEntity`는 UUID와 표시 이름만 포함한다. `EntityQuery`가 기존 ModelContainer에서 실제 저장 항목을 다시 읽고, 실행 직전에도 유효성을 확인한다. `DUNEAppIntentStore`는 앱과 같은 ModelContainer의 별도 `ModelContext`에서 오늘의 `HabitLog`를 조회한 뒤 없을 때만 삽입하고 `save()`한다. 저장 실패 시 rollback하므로 미저장 로그가 다음 실행에 완료로 보이지 않는다. 따라서 단축어 동작은 토글이 아닌 멱등적인 “완료 표시”다.

`OpenWorkoutTemplateIntent`는 `OpenIntent`와 iOS 27 scene routing을 사용한다. Handler는 splash와 관계없이 외부 `windowContent`에 붙고, ActivityView는 UUID로 템플릿을 재조회한 뒤 기존 `startFromTemplate`을 호출한다. 운동 기록이나 HealthKit workout은 자동 생성하지 않는다.

주기형, 수량형, 시간형, 자동 연결, 보관된 습관은 query와 쓰기 양쪽에서 제외한다. 완료 intent에는 로컬 기기 인증을 요구하며 결과 문구에는 습관 이름을 넣지 않는다.

## Validation

- `swiftc -frontend -parse`로 변경 Swift 파일 구문 확인.
- `plutil -lint DUNE/Resources/Info.plist` 통과.
- String Catalog formatter/check 통과.
- XcodeGen으로 새 소스와 테스트가 프로젝트에 포함됨을 확인.
- 저장 실패를 주입해 같은 날짜의 재시도가 실제 저장을 수행하는 회귀 테스트를 추가했다.
- 전체 generic iOS build는 다른 작업의 우선 실행을 위해 SwiftEmitModule에서 중단했다. 컴파일 및 simulator Shortcuts 경로 검증은 후속 실행이 필요하다.

## Prevention

- 단축어의 쓰기 동작은 UI 토글을 그대로 호출하지 말고 명시적인 목표 상태를 보장한다.
- 공유 `mainContext`에 intent 쓰기를 보류하지 않는다. 별도 context에서 저장 실패를 rollback하고 재시도를 검증한다.
- 저장 항목은 이름 대신 UUID로 식별하고 실행 시 삭제·보관 여부를 재검증한다.
- splash가 있는 SwiftUI 앱의 외부 scene handler는 항상 존재하는 window root에 둔다.
- CloudKit의 기기 간 동시 쓰기는 이 로컬 멱등성만으로 완전히 직렬화되지 않는다. 별도 다기기 정합성 검증이 필요하다.

## Lessons Learned

App Intents는 UI 계층과 다른 수명 주기를 가진다. 화면을 여는 intent는 scene으로 UUID를 전달하고, 데이터를 바꾸는 intent는 저장 경계에서 멱등성을 보장하면 기존 화면 및 저장 모델을 작게 확장할 수 있다.

## References

- [WWDC26: Discover new capabilities in the App Intents framework](https://developer.apple.com/videos/play/wwdc2026/345/)
- [Apple: Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)
- [Apple: OpenIntent](https://developer.apple.com/documentation/appintents/openintent)
- [Apple: IntentAuthenticationPolicy](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy)
