# B14 private source preparation

Base is accepted `main` commit `576cfdb98606baad724a69ced56bb9cb2db86780`. All files are private under this directory; no repository source, SDK, simulator, capture index, or design map was changed. `manifest.json` records exact baseline and candidate SHA-256 values. Each candidate patch applies exactly to its base and its full Swift source passes `swiftc -frontend -parse`. This is source-only verification, not a native result.

| ID | Actual mapped source | Prepared change |
|---|---|---|
| W16 | `DUNE/Presentation/Exercise/TemplateWorkoutContainerView.swift` | No patch. This wrapper owns transition/session routing, UUID reset, End confirmation, and dismiss, while W06 and W22 render its two visible states. |
| W19 | `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | `W19/W19.patch`: native Mode picker becomes a menu at accessibility sizes to preserve full Superset/Circuit labels; ordinary segmented picker stays. Values, draft, selection, Add, Start and sheet routing are unchanged. |
| W20 | `CompoundExercisePickerSheet` in the W19 file | No patch. It presents the shared full `ExercisePickerView` (W02). W19 candidate leaves the wrapper implementation byte-identical. |
| W21 | `DUNE/Presentation/Exercise/CompoundWorkoutView.swift` | `W21/W21.patch`: accessibility-size round/time, tabs, exercise header/muscles, summary rows and transition buttons use readable stacked layouts. Set inputs, draft, timers, weight conversion, Finish, save, HealthKit write and share flow are unchanged. |
| W22 | `DUNE/Presentation/Exercise/Components/ExerciseTransitionView.swift` | `W22/W22.patch`: accessibility-size template default labels stack with leading alignment. Countdown, auto-advance, Start, icon, title, and normal-size row remain. |

The per-screen `layout-theme.html` files are private static source diagrams and explicitly are not app captures. They follow the existing full redesign map's W16/W19/W20/W21/W22 identities and control-first visual direction. The actual map and theme map were inspected before the proposals; the parent owns source application and native map reconciliation.

Existing source consumers: `ExerciseView` presents W19, navigates to W21, and contains the template-list route to W16; `ActivityView` also presents W16. W19 presents W20 as a sheet. W16 presents W22 and `WorkoutSessionView`. Existing regression methods `testCompoundWorkoutSetupStartsWorkoutAndFinishesFlow` and `testTemplateWorkoutContainerCloseDismissesFullScreenFlow` cover basic routes; B14 should add only focused normal/MAX visual selectors after source review. W22's five-second automatic transition makes native capture timing an explicit risk.

Apply patches only to their named files after comparing each baseline SHA. No app change is proposed for W16 or W20. W34 identity remains unrelated and untouched.

## W22 공유 실행 계약

B14+B15 여덟 화면·여섯 앱 파일의 작은 배치 변경을 한 번의 증분 UI 컴파일로 묶는다. Phone7/iPad7 exact selectors만 실행하며 전체 회귀나 별도 반복 build는 하지 않는다. W16/W20은 별도 앱 패치를 만들지 않고 원래 wrapper 경로와 새 PNG/AX를 확인한다. W16/W22는 Activity의 실제 템플릿 카드 경로로 진입하여 닫힌 iPad Templates/More 경로를 건드리지 않는다. W22의 5초 자동 진행을 변경하지 않는다. full picker는 native Collection/any root, Running QuickStart만 실제 TextField 도우미를 쓴다. W23–25는 기존 Running일반/MAX·StairClimber branch를 재사용하며 새 실제 캡처를 보존한다. iPhone/iPad의 영향 상태와 Duo미갱신을 명시하고 독립 리뷰·디자인맵·문서화·화면별 PR/통상머지를 한다. 모든 기존 실패/한도는 유지한다.

## 검증·분리 결과

최대 글씨에서 원래 2 sets·6 reps·80 kg 표시를 세로로 읽도록 했다. 자동 전환의 5초와 Start 동작 소스는 유지했다.

Phone MAX 통과와 iPad 일반·MAX 통과만 after다. Phone 일반은 5초 자동 전환 뒤 사라진 Start 탭의 검사 실패로 역사적 실제 맵/미갱신과 진단을 유지한다. [실제 근거와 제한](../design/full-redesign-map/review/exercise-transition-w22-2026-11-07/index.html). 원본 검사는 공동 frozen source에서 수행했으며 PR 분리 source owner의 byte 일치를 확인한다.
