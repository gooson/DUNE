---
tags: [swiftui, themes, asset-catalog, contrast, native-evidence, xctest, accessibility]
category: testing
date: 2026-11-14
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/ScoreHeroPalette.swift
  - DUNE/Presentation/Shared/Components/HourlySparklineView.swift
  - DUNE/Presentation/Shared/Components/WaveShape.swift
  - DUNEUITests/Visual/WaterLiliesThemeTests.swift
related_solutions:
  - docs/solutions/design/2026-03-04-adding-new-theme.md
---

# Solution: 테마의 실제 색상과 네이티브 증거를 함께 검증하기

## Problem

OCEAN·FOREST의 색상 카탈로그에 Light와 Dark 변형만 있어 기본 named-color lookup이 실패했다. 수정 전 AppTheme unit 실행은 17개 중 requiredAssets 한 검사에서 22개 issue를 보고했다. 화면 테스트가 성공한 FOREST·ARCTIC·SOLAR·SAKURA에서도 Today의 데이터 선과 날짜는 어두운 히어로 위에서 거의 보이지 않았다. AX에 차트가 있다는 사실은 읽을 수 있다는 증거가 아니었다.

장면의 `repeatForever`는 Reduce Motion이나 비활성 상태로 바뀔 때 시작 조건만 막아서는 중단되지 않았다. 접근성 테스트의 Settings 복구는 Swift 6 actor 격리와 XCTest의 teardown 호출 방식도 따라야 했다.

## Solution

| File | Change | Reason |
|---|---|---|
| `Shared/Resources/Colors.xcassets/{Forest,Ocean}*.colorset/Contents.json` | 기존 Light의 appearance 조건을 제거하고 Dark와 모든 RGBA를 유지 | Any 기본 lookup 보장 |
| `ScoreHeroPalette.swift`, `HourlySparklineView.swift`, `DesertHorizonConditionHeroView.swift` | 데이터 선과 날짜 색을 장식 강조색에서 분리 | 실제 히어로 배경 대비 확보 |
| `HourlySparklineView.swift` | 날짜의 intrinsic 가로 배치가 안 들어가면 세로 배치 | 일본어 전체 기간을 축소·생략 없이 표시 |
| `WaveShape.swift` | scenePhase/Reduce Motion에 따라 장식 subtree identity 변경 | 기존 반복 애니메이션 정리, 콘텐츠와 내비게이션 유지 |
| `WaterLiliesThemeTests.swift` | `addTeardownBlock { @MainActor ... }` 비동기 복구, 실제 UIKit 설정 readback | Settings 복구의 격리와 실제 설정 검증 |
| `WatchThemeMatrixUITests.swift` | 실제 첫 운동 카드를 확인하고 Home을 한정된 횟수로 스크롤해 전체 운동 진입, PNG와 AX 함께 저장 | lazy carousel의 화면 밖 항목을 첫 화면 필수 요소로 잘못 요구하던 조건 해소 |

AppTheme의 후속 12개 unit 검사는 여덟 테마의 밝음·어두움 데이터 선 3:1, 날짜 4.5:1 이상을 검증했다. 새 Phone PNG를 직접 대조해 이전 대비 finding을 해소했다. 실제 VoiceOver 활성 실행은 루트→상세→복귀를 검증하고 설정을 복구했다. 보통 CI에서 VoiceOver가 꺼져 있으면 해당 selector는 skip하며, 전용 활성 실행은 positive pass를 별도로 요구한다. 음성 출력·전체 읽기 순서 통과를 주장하지 않는다.

## Prevention

- named color는 Any 기본 변형과 Dark를 확인하고 모든 RGBA가 의도대로 보존됐는지 비교한다.
- 데이터와 장식의 색을 분리한다. AX 존재 검사, 수치 대비 검사, 실제 PNG 검토를 각각 수행한다.
- 새 UI batch가 끝나면 즉시 attachment를 export한다. Xcode LogStore의 자동 보존 정책 때문에 다음 실행 전에 결과 번들이 없어질 수 있다. 이번 Desert/Ocean 원본 소실과 필요한 selector만의 재수집은 별도 이력으로 남겼다.
- PNG와 AX는 같은 capture activity/sequence·기기·viewport로 연결하고 SHA-256과 실제 실행 revision을 기록한다. 나중의 문서 커밋을 촬영 revision으로 붙이지 않는다.
- OS 접근성 설정은 읽고 복구하며, 첫 사용 안내가 실제 조작을 막았는지 확인한다. ordinary CI skip을 실제 활성 검증 성공으로 계산하지 않는다.
- lazy carousel의 offscreen 항목은 생성 전일 수 있다. 실제 첫 카드·루트를 확인하고 사용자가 이동하는 스크롤 경로로 목적지에 도달한다. Watch 실패 당시 실제 PNG와 AX에는 `watch-home-card-popular-plank`가 존재했고, outer root가 carousel identifier를 대체하고 있었다. 화면이 비었다고 추정해 앱을 수정하지 않는다.
- Duo 물리 방향과 앱 viewport는 별도로 읽는다. 비동기 HID 요청은 ACK 직후 stdin을 닫으면 서비스가 취소될 수 있으므로 upstream 대기와 공식 readback까지 프로세스를 유지한다. 이것이 성공해도 내부 패널 활성화나 앱의 가로 viewport 성공을 뜻하지 않는다.

## Lessons Learned

성공한 테스트 메서드는 화면 가독성을 보증하지 않는다. 기존 실패 wrapper, 개별 XCTest 결과, 실제 캡처와 시각 판단도 서로 다른 증거다. Closed A의 metadata parser 실패는 저장된 PNG/AX·positive UI receipt를 재검증해 해결했고 앱 실행을 반복하지 않았다. Duo 펼침은 최종 전용 기기의 내부 패널 활성화가 확인되지 않아 미캡처로 남겼다. 실패를 해결된 사례로 쓰거나 이전 이미지를 새 증거로 승격하지 않는다.
