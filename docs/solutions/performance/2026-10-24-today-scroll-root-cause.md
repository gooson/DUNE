---
tags: [swiftui, scrollview, refreshable, cancellation, navigation-title, today, regression-test]
category: performance
date: 2026-10-24
severity: important
status: in-progress
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshTaskCoordinator.swift
  - DUNETests/WaveRefreshTaskCoordinatorTests.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/performance/2026-10-16-today-scroll-top-settling.md
  - docs/solutions/performance/2026-10-17-today-native-pull-scroll-lock.md
---

# Investigation: Today 스크롤 강제 보정과 native refresh 조기 취소 분리

> **미해결 조사 기록**: c3500bcb 최종 targeted UI8은6통과2실패다. 아래 두 결함은 native trace로 확인하고 교정했지만, 깊은 수동·반복 상단 복귀가 남아 전체 해결로 인증하지 않았다. PR 생성·머지는 보류하며 추가 동일 경로 검증은 재시도 제한 예외 승인 대기다.

## Problem

세 차례 수정 뒤에도 Today 상단으로 돌아올 때 카드가 갑자기 이동했다. 사용자 영상에서는 4.667→4.700초 한 프레임 사이 카드 높이는 같고 위치만 약 53.3pt 바뀌었다. 기존 테스트의 최종 hero 좌표나 `isHittable` 성공만으로는 이동 중 불연속과 큰 제목 아래 겹침을 검출하지 못했다.

### Root Cause

서로 다른 두 경로를 native geometry와 cancellation trace로 분리했다.

1. `decelerating → idle`에서 `offset.y + contentInsets.top`이 0~130이면 `scrollTo(top)`을 즉시 호출했다. 17:10:08.016의 y=-115.333/inset=118(거리 2.667)이 이 분기를 통과했다. 2ms 뒤 y=-118, 5ms 뒤 y=-168/inset=168로 이동했다. 시스템 큰 제목 inset이 정착 중인데 앱이 임시 inset으로 강제 정렬한 것이다. 콘텐츠 높이 2973.667pt는 변하지 않았다.
2. native `.refreshable` 작업이 상태 갱신 중 약 91ms 만에 취소됐다(17:23:10.963 시작→11.054 종료, `Task.isCancelled=true`). 테스트 최소 표시 시간 4초도 취소됐다. refresh 종료 후 scroll safe area가 168→108pt가 됐지만 UINavigationBar frame은 `(0,62,440,106)`, scroll frame은 `(0,0,440,956)`, 기본 contentInset은 0으로 유지됐다. 실제 카드가 60pt 올라갔는데 접근성 hero Y는 이전 값이어서 endpoint assertion이 통과했다.

`cannot add handler to 0 from 0 - dropping` 1644건의 발신 이미지는 QuartzCore, subsystem은 `com.apple.coreanimation`, category는 `API`였다. 이 경고의 반복 횟수만으로 두 스크롤 경로와 인과관계를 주장하지 않는다. 경고 전체 제거를 수정 결과로 보고하지 않는다.

## Solution

자동 idle 보정을 제거한다. ScrollViewReader와 높이0 앵커 대신 ScrollView에 하나의 내용 VStack을 두고 ScrollPosition을 연결한다. 기존 앵커와 내용 사이의 암묵적8pt는 명시적 DS.Spacing.sm top padding으로 보존한다. 명시적으로 Today 탭을 재선택할 때만 scrollTo(edge: .top)를 호출한다. native refresh는 `@State`의 화면 소유 coordinator가 MainActor 비구조 Task로 실행하고 caller가 그 완료를 기다린다. SwiftUI가 일시적으로 refresh caller를 취소해도 작업은 유지된다. 실제 화면 이탈은 `.onDisappear`에서 명시적으로 취소한다. 중복 요청은 같은 task를 기다리며 취소된 task도 종료할 때까지 추적해 이전 cleanup과 새 실행의 경합을 막는다.

| File | Change | Reason |
|---|---|---|
| DashboardView.swift | 자동 phase 이동 제거, 단일 내용 root, 명시적 ScrollPosition edge 이동 | 사용자 정지 위치와 native 제목·inset 정착을 보존 |
| WaveRefreshTaskCoordinator.swift | 화면 소유 단일 task, 중복 병합, 명시 취소 | transient refresh caller cancellation 분리 |
| WaveRefreshIndicator.swift | coordinator로 실행, 화면 이탈 취소 | spinner와 native refresh의 실제 작업 수명 유지 |
| WaveRefreshTaskCoordinatorTests.swift | caller 취소·명시 취소·중복·취소 drain 4건 | 동시성 계약 검증 |
| TodaySettingsRegressionTests.swift | 짧은 왕복 드래그·손 떼는 native refresh, 기존 회귀 보강 | 지나가는 spinner 관찰 누락과 offscreen activation point 오류 방지 |

### Key Code

```swift
let task = Task { @MainActor in await operation() }
self.task = task
await task.value
self.task = nil
```

실제 구현에는 coalescing과 `cancel()`이 함께 있다. `cancel()`에서 즉시 task를 nil로 만들지 않는다. 취소를 무시하고 drain 중인 이전 작업과 새 refresh가 겹칠 수 있다.

### Rejected Experiments

- 초기 Reader/zero-anchor 제거 실험은 native pull 한 경로만 검사했고 조기 취소가 남았다. 이후 coordinator 수정 뒤 plain ScrollView/ScrollPosition 구조에서 반복 full-swipe가 한 번 통과했지만, 기존8pt 간격을 명시적으로 보존한 최종 실행에서는 다시 실패했다. Reader/anchor 제거를 확정 원인 해결로 판단하지 않는다. 따라서 초기 pull 실험으로 깊은 복귀의 컨테이너 영향을 기각하지 않았다.
- refreshable modifier를 바깥으로 옮겨도 91ms caller 취소가 재현됐다. 위치 변경은 남기지 않았다.
- 새 threshold, hardcoded inset, 추가 delay, 제목 inline 전환은 넣지 않았다. 기존 표시 시간 1.8초(테스트 4초)와 finishing 0.1초를 유지했다.

## Verification

- 수정 후 native 진단: 17:26:29.942 시작→34.239 종료, cancelled=false. 4.3초 동안 refresh가 유지됐고 safe area 228→168pt, offset -168로 정착했다. 전후 실제 PNG의 카드 상단은 모두 192pt였다.
- 짧은 partial drag 테스트는 interacting→idle 경로다. 제거한 decelerating 분기의 직접 재현 증거로 사용하지 않는다. 그 분기는 별도 native trace 및 full swipe로 확인했다.
- 테스트 전용 완료 카운터는 취소되지 않은 refresh wrapper 완료를 뜻한다. HealthKit 데이터 조회 성공을 뜻하지 않는다. XCTest가 animation idle을 기다리는 동안 transient spinner를 놓치는 문제를 피하기 위한 지속 관측값이다.
- 중간1503d12c UI8:6통과2실패. 남은 manual/deep full-swipe 복귀에서 실제 제목·카드가54–65pt 위에 남는다. native pull 취소 수정만으로 전체 문제 해결이라고 판단할 수 없다. Reader/anchor 격리 후 반복 full-swipe는1회 통과했지만 최종 묶음에서 다시 실패했다. manual 테스트는 화면 밖 isHittable 조회로 XCTest activation-point error도 발생했다. predicate를 실제 복귀 뒤 만들고 frame 검사를 먼저 하며, 느린 held pan을 써 수동 경로와 관성 경로를 분리했다. 원래Y±12pt·hittable·상세 진입은 유지하고 refresh 카운터 불변 검사로 native refresh를 대신 검증하지 않게 했다. c3500bcb 최종8건도6통과2실패이므로 XCTest 오류 수정만으로 상단 복귀가 해결되지는 않았다.

### 현재 검증 상태

| 검증 | 결과 |
|---|---|
| `scripts/build-ios.sh --no-regen`, c3500bcb | BUILD SUCCEEDED |
| coordinator Swift Testing4건 | exact-byte app/test source의 macOS 임시 패키지에서4/4 통과; iOS UI 증거와 구분 |
| 최종 iPhone targeted UI8건 |6통과2실패; 부분 왕복·native held/no-hold refresh·탭 재선택·공통 탭 왕복·Activity refresh 통과 |
| 수동 상단 복귀 | 실패; 원래Y±12pt 검사 유지, 화면 밖AX조회 교정 후에도 상단에 도달하지 못함 |
| 반복 full-swipe 상단 복귀 | 실패; 단일 실험 성공을 최종 통과로 승격하지 않음 |
| iPhone 실제 T03 | native no-hold refresh 이후 실제 PNG와 출처 갱신; 전체 스크롤 상태는 pending |
| iPad·Duo 접힘/펼침 T03 | 선행 iPhone 게이트 실패로 새 실행·캡처 미완료; 기존PNG는 수정 증거가 아님 |
| full iOS/Watch suite | 사용자가 전체 실행을 요청하지 않아 실행하지 않음; Watch에 변경 컴포넌트 소비자 없음 |
| Review/Resolve/Ship | UI 게이트 실패로 진입하지 않음 |

추적된 manual 정지점은 y=-115.333/inset118, 실제 남은 거리2.667pt인데 화면상의 hero 차이는 약53pt다. 화면 좌표 차이를 pan 잔여 거리로 사용하는 테스트 계산은 제목 높이 변화를 포함한다. 최소80pt의 bounded manual pan이 테스트 입력 교정 후보이나 **실행·통과하지 않았으며**, 반복full 경로의 실패를 설명하거나 대체하지 않는다. 원래위치·탭 가능·상세진입·native refresh 카운터 불변 검사도 유지해야 한다.

다음 격리 후보는 같은 NavigationStack/ScrollView fixture에서 공통 wave refresh modifier 유무를 비교하고, native offset/adjusted inset/nav bar frame과 UIKit topItem title mode를 함께 기록하는 것이다. `ScrollContentOffsetAdjustmentBehavior`는 Apple 문서상 콘텐츠 크기 등 context에 따른 자동 offset 보존을 제어한다. 제목 inset에 적용되어 이 문제를 고친다는 근거는 아직 없으므로 앱에 추가하지 않았다.

## Prevention

- [ ] 시스템 큰 제목의 변화 중 offset과 inset 합으로 사용자 위치를 자동 보정하지 않는다.
- [ ] native 당김의 hold/release 경로와 다음 스크롤을 검증한다.
- [ ] refresh 작업의 caller cancellation과 화면 소유 cancellation을 따로 테스트한다.
- [ ] 최종 접근성 좌표뿐 아니라 실제 PNG와 native safe area/title frame을 대조한다.
- [ ] 실제 pull 경로를 test-trigger 버튼 탭으로 대체하지 않는다.
- [ ] 기존 성공 문서는 당시의 검증 범위로만 해석하고 반증된 보정법은 후속 기록으로 연결한다.

새 `.claude/rules` 변경은 제안만 하며 source of truth를 수정하지 않는다. 일반 프로젝트 핸드북 변경은 필요 없다. 이 사례의 재현 수치와 취소 소유권 계약을 해결 문서와 테스트에 남긴다.

## Lessons Learned

최종 상단 복귀 assertion은 부드러운 이동을 증명하지 않는다. 큰 제목과 refresh inset이 함께 변하는 화면에서는 앱이 보정을 추가할수록 순간적인 시스템 geometry를 기준점으로 고정할 수 있다. 시스템 로그의 빈도 대신 실제 scroll command, task cancellation, native frame의 시간 순서를 확인해야 한다.
