---
tags: [swiftui, inspector, scrollview, refreshable, cancellation, navigation-title, today, regression-test]
category: performance
date: 2026-10-24
updated: 2026-10-25
severity: important
status: resolved
related_files:
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift
  - DUNE/Presentation/Shared/Components/WaveRefreshTaskCoordinator.swift
  - DUNETests/WaveRefreshTaskCoordinatorTests.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
related_solutions:
  - docs/solutions/performance/2026-10-16-today-scroll-top-settling.md
  - docs/solutions/performance/2026-10-17-today-native-pull-scroll-lock.md
---

# Today 스크롤 점프: 닫힌 inspector의 큰 제목·safe area 피드백

> 2026-10-25: 마지막 원인을 inspector host로 격리했다. inspector를 Today NavigationStack 밖으로 옮긴 최종 iPhone targeted UI 10건이 모두 통과했다. 이전 실패의 원래 위치 ±12pt 검사와 제스처는 변경하지 않았다. 최신 main 통합 후에도 iPhone10·iPad4가 통과했으며, 5관점·SwiftUI·Apple UX·app 품질 리뷰에서 도입된 결함은 없었다. Duo 접힘2·펼침2도 통과했다.

## Problem

세 차례 수정 뒤에도 Today 상단으로 돌아올 때 카드가 갑자기 이동했다. 사용자 영상에서는 4.667→4.700초 한 프레임 사이 카드 높이는 같고 위치만 약 53.3pt 바뀌었다. 기존 endpoint assertion만으로는 이동 중 불연속과 큰 제목 아래 겹침을 검출하지 못했다.

### Root Cause

세 경로를 실제 geometry·작업 수명·구조 대조군으로 분리했다.

1. **닫힌 inspector host와 내비게이션 큰 제목의 상단 여백 피드백.** Dashboard의 ScrollView에 `.inspector`를 붙였을 때, 패널이 닫혀 있어도 깊은 스크롤에서 복귀하며 nav bar 높이와 scroll safe area가 반복해서 커졌다 작아졌다. 손을 뗀 뒤 y≈-103~-115, inset≈114~122, 제목 높이≈54~57pt에 남았다. 정상 시작은 y=-168/inset168/nav bar 높이106pt다. 실제 카드가 52~67.7pt 위에 남거나 복귀 순간 튀었다. inspector만 제거하면 같은 실제 콘텐츠·toolbar·refresh·ScrollPosition·배경에서 두 번 위로 스크롤한 뒤 두 번째 하강부터 8번째 하강과 100pt held pull까지 모두 원래 AX Y213pt로 돌아왔다. native scroll window frame(0,0,440,956), y=-168/inset168/nav bar window bottom168도 일치했다. UIKit 내부 구현의 어느 수식이 틀렸는지는 추정하지 않는다. 앱에서 피드백을 만드는 배치와 제거·이동 효과를 확인한 것이다.
2. **자동 idle 보정이 순간적인 inset을 고정.** `decelerating → idle`에서 `offset.y + contentInsets.top`이 0~130이면 `scrollTo(top)`을 호출했다. 17:10:08.016의 y=-115.333/inset118(거리2.667)이 이 분기를 통과했다. 2ms 뒤 y=-118, 5ms 뒤 y=-168/inset168로 이동했다. 콘텐츠 높이2973.667pt는 같았다. 임계값을 조절하는 보정은 inspector 원인을 제거하지 못했다.
3. **native refresh caller의 조기 취소.** `.refreshable` 작업이 상태 갱신 중 약91ms 만에 취소됐다(17:23:10.963→11.054, cancelled=true). 테스트 최소 표시4초도 취소되어 native refresh가 조기 종료됐다. scroll safe area168→108인데 nav bar frame(0,62,440,106), scroll frame(0,0,440,956), 기본 contentInset0은 같았다. 실제 카드가60pt 올라간 반면 접근성 좌표는 이전 값이어서 endpoint 검사가 통과한 경우도 있었다.

`cannot add handler to 0 from 0 - dropping` 1644건의 발신 이미지는 QuartzCore, subsystem은 `com.apple.coreanimation`, category는 `API`였다. 경고 빈도 자체를 원인 증거로 사용하지 않았으며, 경고 전체 제거를 수정 결과로 주장하지 않는다.

### Controlled Isolation

전용 iPhone 18 Pro Max/iOS27.0에서 고정 데이터와 같은 pan 입력으로 비교했다. 진단용 테스트는 결과를 기록하는 도구여서 XCTest의 `passed`가 복귀 성공을 뜻하지 않는다. 아래 판정은 기록된 각 위치와 native trace를 기준으로 한다.

| 구성 | 결과 |
|---|---|
| 고정 콘텐츠: refresh 없음 / 기본 refresh / wave refresh | 모두 원래 Y192pt로 복귀 |
| 고정 wave 화면, 실제 Today와 같은 두 번 upward swipe | 두 번째 down에서는 -52pt였으나 세 번째부터 원래 위치로 정상 복귀 |
| 실제 Today에서 refresh만 제거 | 반복 down 뒤 -52pt, held100 뒤 -55.3pt: 원인 유지 |
| 실제 Today에서 ScrollPosition만 제거 | down1~5는 -52~-63pt, down6에서만 복귀: 단독 해결 아님 |
| 실제 Today에서 장식 배경만 제거 | 반복 down 뒤 -53.7pt: 원인 유지 |
| 실제 Today에서 toolbar만 제거 | down1~4는 -53.7~-63pt: 원인 유지 |
| 실제 Today의 본문만 고정 Text 블록으로 교체, inspector 유지 | 반복 down 뒤 -63pt, held100 뒤 -55pt: 원인 유지 |
| 실제 Today에서 inspector만 제거 | down1~7 및 held100 모두 Y213pt, native y=-168/inset168: 정상 |

모든 구성의 UIKit largeTitleDisplayMode는1(always)이므로 자동 제목 모드 차이는 기각했다. AX hero213pt와 native 카드 배경192pt 차이는 label 안쪽21pt 여백이며, 모든 AX 차이를 stale frame으로 간주하지 않는다. 첫 진단의 Timer는 tracking 중 샘플을 놓쳤으므로 두 번째부터 RunLoop.common으로 측정했다. 세 번째 진단부터 scroll/bar를 같은 window 좌표로 변환해 비교했다. 진단용 fixture·timer·환경 분기는 최종 앱에 남기지 않았다.

## Solution

**inspector의 소유자를 Today NavigationStack 밖으로 옮긴다.** ContentView가 선택한 metric/QA 상태와 inspector를 소유하고, DashboardView는 `onInspectMetric`과 `onOpenHealthDataQA`로 사용자 의도를 전달한다. 패널 닫기는 두 상태를 비우고, metric/QA 진입은 서로 배타적으로 전환한다. Metric → All Data용 독립 NavigationStack, Done 버튼, QA 서비스, inspectorColumnWidth는 유지한다. Apple도 inspector를 navigation 구조 안/밖에 배치할 수 있으며 배치에 따라 column과 toolbar 영역이 달라짐을 설명한다: [WWDC23 Inspectors in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10161/).

자동 idle 보정은 제거하고 Today 탭 재선택 때만 `ScrollPosition.scrollTo(edge: .top)`을 호출한다. ScrollViewReader/높이0 anchor를 없앤 단일 콘텐츠 구조는 유지하되 이것만으로 원인을 해결했다고 주장하지 않는다. 기존 anchor의 암묵적8pt 간격은 명시적 top padding으로 보존했다.

Native refresh는 화면 소유 MainActor coordinator의 task로 실행한다. transient caller 취소가 작업을 끊지 않으며 `.onDisappear`에서 명시적으로 취소한다. 중복 요청은 같은 task를 기다리고 취소된 task도 종료할 때까지 추적해 이전 cleanup과 새 실행이 겹치지 않게 한다. 기존 최소 표시1.8초(테스트4초)와 finishing0.1초는 유지했다.

| 파일 | 변경 |
|---|---|
| ContentView.swift | Today NavigationStack 바깥에 inspector와 패널 상태 소유 |
| DashboardView.swift | inspector 제거·의도 callback 전달, 자동 phase 이동 제거, 명시적 top 이동 |
| WaveRefreshTaskCoordinator.swift / WaveRefreshIndicator.swift | 화면 소유 refresh 수명, 중복 병합과 명시 취소 |
| WaveRefreshTaskCoordinatorTests.swift | caller 취소·명시 취소·중복·취소 drain 4건 |
| TodaySettingsRegressionTests.swift | 부분 왕복·native hold/release·깊은 복귀·원래 위치·refresh 카운터 검증 |

## Verification

- 초기 c3500bcb의 targeted UI8은6통과2실패였다. Reader 제거·느린 held pan·AX 오류 교정만으로 해결되지 않았다. 같은 경로를 중단한 뒤 사용자 승인으로 원인 격리를 재개했다.
- inspector 이동 후 iPhone targeted **10/10 통과**: manual return, repeated full swipes, partial return, native held/no-hold refresh, tab reselect, metric open/close/reopen/All Data, QA open, tab round-trip, Activity refresh.
- manual/full의 원래 Y±12pt, hittability, 상세 진입, manual refresh counter 불변 검사를 유지했다. 제스처 길이·임계값을 완화하지 않았다.
- manual settled 및 repeated full settled의 새 native PNG에서 큰 Today 제목, 카드 배경 상단192pt와 정상 간격을 직접 확인했다.
- coordinator source/test는 변경되지 않았으며 exact-byte 임시 macOS SwiftPackage의 Swift Testing4/4 성공을 재사용한다. iOS simulator unit 성공으로 표현하지 않는다.
- 부분 드래그는 interacting→idle 경로다. 제거된 decelerating callback은 별도의 native trace와 full swipe로 확인했다.
- 테스트 전용 counter는 refresh wrapper 완료이며 실제 HealthKit 데이터 조회 성공을 뜻하지 않는다.
- main 통합 `ef42c58e`에서 iPhone10/10·iPad4/4를 다시 확인했다. iPad는 manual/full 복귀와 metric 열기·닫기·재열기·All Data, QA 열기를 검증했다. Duo 외부·내부 화면에서 manual 복귀와 metric 경로가 각각2/2 통과했다. 내부 화면의 검은 XCTest 첨부를 보완하려고 manual 캡처1건을 추가 실행해 통과했다. full iOS/Watch suite 성공을 주장하지 않는다.
- 정상 pre-commit 훅의 `scripts/build-ios.sh --no-regen`은 inspector 수정 및 main 통합에서 모두 성공했다.
- Security·Performance·Architecture·Data Integrity·Simplicity 및 SwiftUI·Apple UX·app-quality 리뷰 모두 도입된 P1/P2/P3 결함0. QA 닫기·새로고침 중 화면 이탈·VoiceOver의 실제 UI 실행은 이번 선택 테스트 범위가 아니다.

### Evidence

- [버전 관리된 원본 갤러리·실행 영수증·소스 해시·리뷰 기록](../../design/full-redesign-map/review/today-scroll-root-cause-2026-10-25/README.md). Duo 내부는 활성 display3의 native 캡처이며 힌지 각도 readback 제한을 별도로 기록했다.

- `/tmp/scroll-debug/isolation-ui.log`, `isolation2-ui.log`, `isolation3-ui.log`: 구성별 AX 위치
- `/tmp/scroll-debug/isolation3-native.log`: 동일 window 좌표의 inspector 격리
- `/tmp/scroll-debug/owner-fix-iphone-ui.log.result.json`: 정확한10건 실행·통과
- `/tmp/scroll-debug/owner-fix-iphone-attachments/`: manual/full/refresh의 실제 PNG

## Prevention

- 큰 제목이 변하는 동안 임시 offset+inset으로 사용자 위치를 자동 보정하지 않는다.
- 닫힌 presentation modifier도 scroll/nav host 구조에 영향을 줄 수 있으므로 데이터·배경·toolbar·presentation을 개별 격리한다.
- native 당김의 hold/release와 다음 스크롤을 검증한다. test-trigger 버튼만으로 대체하지 않는다.
- caller cancellation과 화면 소유 cancellation을 따로 테스트한다.
- AX element의 frame과 실제 카드 배경의 padding 차이를 구분하고, native geometry는 동일 좌표계에서 비교한다.
- 기존 성공 문서는 당시의 검증 범위로 해석하고 반증된 보정법은 후속 기록으로 연결한다.

## Lessons Learned

최종 위치가 한 번 맞았다는 사실만으로 반복 스크롤이 안정적이라고 판단할 수 없다. 이번에는 큰 제목·상단 여백의 피드백을 임계값으로 덮던 접근을 중단하고, 실제 화면에서 inspector만 제외하는 대조군을 통해 원인을 좁혔다. 패널의 소유 위치를 변경한 뒤 기존에 실패하던 두 검사가 제스처 변경 없이 통과했다.
