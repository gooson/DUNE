---
topic: iOS 테마 모달 내비게이션
date: 2026-11-29
status: approved
confidence: medium
related_solutions:
  - ../solutions/general/2026-10-30-cardio-share-modal-background-and-drag.md
  - ../solutions/general/2026-03-22-history-sheet-triple-close-fix.md
related_brainstorms:
  - ../brainstorms/2026-02-27-wave-expansion-tab-identity.md
---

# iOS 테마 모달 내비게이션

## 기준

파티스리 습관 주간 보고서의 원화와 native toolbar가 제목 뒤에서 본문으로 이어진다. 승인된 운동 상세 시안은 한 줄에 닫기, 운동 이름, 이름 편집을 놓는다. 현재 운동 상세 시트는 별도 완료 행에서 iOS 기본 바탕이 드러난다. 작가 테마의 다른 시트에 쓰이는 짙은 상단 음영도 실제 일반 상세와 다르다.

## 구현

1. `ExerciseView`의 compact 상세 시트가 기존 선택값을 유지하게 두고, 완료 행을 native 닫기 toolbar item으로 옮긴다. HealthKit W28은 우측 편집을 그대로 제공하며 수동 W27에도 같은 닫기를 적용한다. regular 운동 패널의 닫기와 기록 전환은 기존 경로를 따른다.
2. `ArtistThemeBackground`와 `SheetWaveBackground`의 일반 시트 배경을 공통 세로 음영으로 맞춘다. 사진과 영상 기반 촬영 화면, 시스템 공유기, 권한 화면, 자체 제목으로 구성된 작은 팝오버의 내비게이션은 각 기존 소유자가 담당한다. 상단 배경이 일반 시트와 충돌하는 앱 모달은 별도 검토하고 절반 높이, 스크롤, 저장·취소를 보존한다.
3. 레이아웃 맵에서 운동 상세와 유사 모달의 배치·범위와 기기별 결과를 추적한다. 기존 캡처와 별도로 새 XCTest PNG를 저장한다.

| 영향 파일 | 책임 |
|---|---|
| `ExerciseView.swift`, `HealthKitWorkoutDetailView.swift`, `ExerciseSessionDetailView.swift` | 상세 시트 닫기, 이름 편집, 상세 배경의 소유권 |
| `ArtistThemeBackground.swift`, `WaveShape.swift` 및 공용 배경을 쓰는 모달 루트 | 라이트·다크의 상단 원화 합성 |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift`, `DUNEUITests/Visual` | 운동 상세와 대표 모달의 진입·검사·캡처 |
| `docs/design/layout-map/`, `docs/design/phone-design-map/actual/` | 승인 배치, 조사한 모달, 새 실화면 |

## 검증과 위험

- 파티스리 라이트·다크의 운동 상세에서 같은 toolbar 줄에 닫기와 편집이 있는지 확인한다. 편집 취소 뒤 상세를 거쳐 목록으로 돌아와 같은 기록이 다시 열린다. 짧은 닫기 드래그를 취소하는 기존 회귀와 넓은 패널을 확인한다.
- 공용 배경의 모든 소비자를 읽고 앱 소유 navigation sheet와 시스템·몰입형·bar 없는 표면을 확인한다. 실제 표준 모달을 열어 배경과 닫기/취소/저장에 미치는 영향을 검사한다. 목표 모달과 실측 가능한 다른 경로에서 라이트·다크를 촬영한다.
- 선택·경로·저장 로직의 변경이 없으므로 XCTest 흐름 검사를 중심으로 검증한다. iPhone 전용 테스트 기기의 코드 서명·연결 가능 상태도 확인하며 실제 기기와 시뮬레이터 결과를 정확히 구별한다.
- 표준 UI runner를 한 번에 하나씩 실행하고, 빌드를 포함한 정확한 selector의 결과를 재사용한다. 주요 위험은 중첩 시트의 툴바 중복, 목록 복귀, 스크롤 상단의 대비, 기본 시트 배경 재노출이다.
- 전역 `UINavigationBar.appearance`는 루트 탭과 카메라를 한꺼번에 바꾸므로 사용하지 않는다. 앱의 동일한 테마 renderer와 각 toolbar 소유권을 재사용한다.

[Apple Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets) · [Apple Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
