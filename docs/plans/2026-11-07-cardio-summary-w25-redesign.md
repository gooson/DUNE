# B15 private cardio source preparation

Base: accepted `main` `576cfdb98606baad724a69ced56bb9cb2db86780`. This directory contains private, unexecuted app candidates only. Each ID maps to an actual row of `docs/design/full-redesign-map/index.html`; the per-screen `layout-theme.html` files are static source sketches, not native captures. No repository files, SDK process, simulator, actual map, or test source were changed.

| ID | Source and change |
|---|---|
| W23 | `CardioStartSheet.swift`: retain the centered native sheet at ordinary sizes; at accessibility sizes, put the same activity header, Indoor/Outdoor cards, and location notice/warning into a ScrollView. Mode choice and navigation stay identical. |
| W24 | `CardioSessionView.swift`: at accessibility sizes use scaled rounded elapsed text; stack distance/pace and the existing four metric tiles; pin the same Pause/Resume and End controls in a bottom safe-area inset while data scrolls. Ordinary layout stays. Timer, measurements, location, permission, End confirmation, and summary route are untouched. |
| W25 | `CardioSessionSummaryView.swift`: center/wrap completion and metric text; omit only the invisible balancing filler in the last metric row when accessibility layout already stacks cards. Pinned Save, SwiftData record, HealthKit write, and error handling are untouched. |

`manifest.json` contains exact source/candidate/patch SHA-256 and patch/parse verification. All three patches applied exactly to the accepted base in isolated temporary directories and each candidate passed `swiftc -frontend -parse`; no build or native behavior is claimed.

Existing consumer path: `ExerciseStartView` shows W23 from a cardio exercise, W23 navigates to W24, and W24 navigates to W25 after End confirmation. The existing seeded `ActivityExerciseRegressionTests/testCardioFlowReachesSummary` runs MAX and `testVisualAuditCardioAtDefaultTextSize` runs normal via Running; `testStairClimberLevelChangesAppearInSummary` covers the machine-level branch. Their route and AX IDs remain unchanged. Native normal/MAX captures and control reachability still need the parent's scoped gate. The existing MAX test directly taps End; W24's inset keeps it reachable despite taller metric rows.

Source-only risks: W23's MAX ScrollView must show both mode cards and location text; W24's bottom inset must keep controls clear of the keyboard and system safe area; W25's long values should wrap without pushing the pinned Save offscreen. These require native confirmation. No new values, icons, strings, data ownership, or navigation destinations are introduced.

## W25 공유 실행 계약

B14+B15 여덟 화면·여섯 앱 파일의 작은 배치 변경을 한 번의 증분 UI 컴파일로 묶는다. Phone7/iPad7 exact selectors만 실행하며 전체 회귀나 별도 반복 build는 하지 않는다. W16/W20은 별도 앱 패치를 만들지 않고 원래 wrapper 경로와 새 PNG/AX를 확인한다. W16/W22는 Activity의 실제 템플릿 카드 경로로 진입하여 닫힌 iPad Templates/More 경로를 건드리지 않는다. W22의 5초 자동 진행을 변경하지 않는다. full picker는 native Collection/any root, Running QuickStart만 실제 TextField 도우미를 쓴다. W23–25는 기존 Running일반/MAX·StairClimber branch를 재사용하며 새 실제 캡처를 보존한다. iPhone/iPad의 영향 상태와 Duo미갱신을 명시하고 독립 리뷰·디자인맵·문서화·화면별 PR/통상머지를 한다. 모든 기존 실패/한도는 유지한다.

## Native gate held

iPad 최대 글씨의 마지막 Running 캡처에서 Cadence 문구(y858–909)가 고정 Save(y815.5–893)에 일부 가려졌다. 스크롤 위치는 73%였으나 더 내린 통과 캡처가 없어 전체 가독성은 미입증이다. 선택자 통과와 문구 중점의 ScrollView 포함 검사는 가려짐 검사를 대신하지 않는다. 앱 결함이나 이번 변경의 도입 여부를 확정하지 않는다. [보류 갤러리](../design/full-redesign-map/review/cardio-summary-w25-2026-11-07/index.html). 실제 맵은 기존 자료를 유지하고 초안 PR만 보존한다.
