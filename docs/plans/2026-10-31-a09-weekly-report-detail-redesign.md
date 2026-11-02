---
topic: A09 weekly workout report detail redesign
date: 2026-10-31
status: implemented
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-22-weekly-report-healthkit-data-gap.md
related_brainstorms: []
---

# Implementation Plan: A09 Weekly Workout Report Detail

## Context

A09 is the Activity **Weekly Report** destination, separate from A05 Weekly Stats and T10 Daily Digest. Its optional `WorkoutReport` already supplies a dated rolling-week report, six conditional/current stat slots, a generated summary, typed highlights and optional muscle breakdown. The detail is presentation-only: it has no ViewModel, query, chart, period picker or retry control. A09 should make the actual report easier to read with a strong opaque report hero, consistent native metric icons and adaptive stat rows while retaining all data and conditional branches.

Read-only source inventory is preserved in rollout evidence. The [A09 layout proposal](../design/layout-map/activity-weekly-report-detail-a09.html) and [DUNE theme proposal](../design/theme-map/themes/dune-weekly-report-detail-a09.html) are browser contracts, not native captures. The original `WorkoutReportDetailView.swift` Git blob is `f535eed32ba1a47c727f10e256f7d756143808e5` at both `672d5fdb` and `1f7f9900`; protected card `bcda227d14f42aba9904d6eba1109044d50a3e48`, `ActivityViewModel` `19501095e6e6b780d7fec9b03dabf447410cd4b1`, report model `74d07a3678f38bf439851f622e6c3125f5fe9184`, use case `c744db71dbecd68d220929cbcfa83645b48c65b7`, report formatter protocol `5fabef3903520c53b03298354217163df14c9a88` and its production/fallback implementations are frozen. Historical `443a32ca…` A09 images are reference only. A fresh original iPad run on unchanged A09 source completed **2/2 methods passed**, including `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen`. T08 inspected the loaded report root and screenshot `87B3CA7E-CBAA-48B8-A669-59188561830E.png` under `.codex-checks/a09/evidence/ui-ipad-original-before-current`; it shows the DEBUG fixture's 3 sessions, 3 active days, 2.4k volume, **5400 min**, 72% intensity and +12% change. The prior A08 risk image is a separate checkpoint. This is valid original iPad/fixture evidence only, not an A09 after pass or phone/Duo baseline.

## Requirements

### Functional

- Preserve Activity `weeklyReport != nil` navigation guard, `ActivityDetailDestination.weeklyReport`, native Back, root ID `activity-weekly-report-detail-screen`, and optional nil detail empty state. Parent generates `.weekly`; the model also supports `.monthly`, so render the actual `report.period.displayName` without hard-coding a picker or assuming calendar-week boundaries. Keep original formatted `startDate…endDate` **once** in the report header.
- Preserve all real stats and source units: sessions count, active days count, strength `totalVolume` in kg/k, `totalDuration` in minutes, normalized `averageIntensity` as the original integer percent, and conditional `volumeChangePercent` only when present. The change fraction is calculated by the use case from positive previous volume, clamped −1…+10, and multiplied by 100 only for display. Do not fabricate a comparison when nil or extrapolate a prior session count.
- Promote the existing current total volume into a report hero only as this app's computed completed-set weight×reps aggregate. It may be zero for HealthKit-only sessions; do not imply HealthKit duration/distance supplied sets or kg. Keep the other three user-facing core counts/duration visible as adaptive metric rows with leading SF symbols, then preserve average intensity and conditional change in the same reading flow. `averageIntensity` is normalized from recorded weight values, not a physiological exertion estimate; avoid stronger wording or confidence claims.
- Preserve `formattedSummary` exactly when nonempty and omit when nil/empty; retain formatter fallback behavior. Preserve all `report.highlights` in their supplied order, the original descriptions, the explicit no-highlights message, and original icon mapping: PR `trophy.fill`, streak `flame.fill`, volume increase `chart.line.uptrend.xyaxis`, consistency `calendar.badge.checkmark`, new exercise `star.fill`.
- Preserve optional muscle breakdown, order and source values. Bars are relative to the actual maximum muscle volume, guarded for nonpositive max; kg/k labels remain actual source format. Primary muscle receives full volume, secondary half in the protected use case. Do not depict these bars as percentages of total report or create cardio strength volume.
- Keep all existing source copy, level of detail, navigation, `DetailWaveBackground`, and `doc.text` nil icon. No chart, date arrows, period selector, fictional history, new CTA or duplicated dates.

### Non-functional

- Private View composition with `ScoreHeroPalette`/DS opaque surface and palette ink; semantic stat accents and consistent native leading icon slots. Use inline native title so the report header does not duplicate a large title. Keep regular width bounded around 680pt. At maximum Dynamic Type/narrow Duo, use one column and natural card heights rather than the original fixed three-column grid or 80/50pt muscle-label/value widths; all values/units/summary/highlights stay readable.
- Freeze `ActivityViewModel`, report model/use case/formatter, shared root card, source merge/de-duplication and upstream HealthKit query. Any new user copy requires `copy-voice`, UX-writing and en/ko/ja catalog formatting; prefer existing labels.

## Approach

Refactor only `WorkoutReportDetailView`: a private opaque hero presents the actual report period, date once, original total-volume value and conditional change. Use a small adaptive metric composition for sessions, active days, duration and average intensity, preserving every original value/formatter. Keep the supplied summary, highlights and muscle breakdown in source order, improving their icon alignment and max-AX wrapping without changing relative-bar math. The parent remains sole owner of report generation and nil-route behavior.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| Import A05 period picker/comparison or T10 daily chart | More controls | No A09 query/history source, changes product semantics | Reject |
| Recompute snapshots, highlight thresholds or muscle allocation in View | Flexible visual numbers | Duplicates and risks protected domain math | Reject |
| Detail-local hero and adaptive rows | Clear hierarchy from actual report | Requires AX/native density verification | Choose |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift` | Modify | Private opaque hero, adaptive metric/highlight/muscle presentation; original data/branches. |
| `DUNEUITests/Full/ActivityExerciseRegressionTests.swift` | Conditional focused contract | Extend exact report route for loaded fixture values, summary/highlight and Back if meaningful. |
| `Shared/Resources/Localizable.xcstrings` | Conditional | Only if an essential new label is required; translate en/ko/ja and format/manual-check. |
| `docs/design/layout-map/activity-weekly-report-detail-a09.html`, index/README | Plan phase | Separate source/states/layout proposal, explicitly not native. |
| `docs/design/theme-map/themes/dune-weekly-report-detail-a09.html`, manifest/index/README | Plan phase | DUNE light/dark direction, illustrative values labeled. |
| `docs/design/phone-design-map/actual/index.html`, new A09 PNGs | After native | Fresh source-matched actual after states/device tiers only. |

## Implementation Steps

### Step 1: Source closure, original capture and proposal maps

- **Files**: ignored source/capture evidence, formal plan, separate layout/theme proposals.
- **Changes**: Confirm original/protected hashes and exact route `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` on unchanged `1f7f9900` or source-identical `672d5fdb`. Its `--ui-design-map-activity-routes` branch injects a fixed **DEBUG presentation fixture**, not product-derived records: 3 sessions, 2,400 kg, 5,400 min, 3 active days, .72 normalized intensity, .12 volume change, one consistency highlight, supplied summary, and two muscles. The `reportLink.auditTap()` checkpoint and final teardown are A09 candidates; inspect actual PNG/AX for root, loaded content and report period. The earlier risk auditTap is A08. Do not label the whole native batch passed if another selector fails. Historical `443a32ca…` A09 images are not current before.
- **Verification**: Record source/fixture, device, locale/theme/type size, A09 root and actual visible date/value state for each accepted before. The iPad original report auditTap has an official 2/2 result and verified loaded root/image identity; record phone/Duo before only when separately captured.

### Step 2: Compose real report hierarchy

- **Files**: A09 View, optional catalog and proposal maps.
- **Changes**: Preserve nil/summary/highlight/muscle conditionals, root/Back/background, source period/date formatter, all six stat semantics and original formatting. Add private useful hero and aligned stat icons. Replace three-column max-AX squeeze with adaptive stack; remove fixed muscle row widths at AX without changing the guarded `volume / maxVolume` calculation. Reuse original highlight icons/descriptions and generated summary. No period/chart or new math.
- **Verification**: Swift parse, diff, protected source hashes, catalog format/manual check if touched; parent-controlled build later.

### Step 3: Focused native and actual map

- **Files**: existing route test if needed, native PNGs/AX and actual design map.
- **Changes**: Check source-backed DEBUG fixture values in the loaded A09 screen, one date range, one consistency highlight, formatted summary, chest/quadriceps bars (the unsorted DEBUG fixture is 1,100/1,300, so the bars should be approximately 85%/100%) and native Back. Validate real conditional/no-highlight/nil states only with deterministic existing fixtures or source-level unit tests, without inventing a new product fallback. Inspect light/dark/max AX and phone/iPad/Duo folded/open where affected.
- **Verification**: Exact route selector plus only changed-behavior checks; existing `GenerateWorkoutReportUseCaseTests` and `ActivityViewModelTests.weeklyReportIncludesHealthKitWorkouts`/`weeklyReportMergesWithoutDuplication` are math/merge authority and need rerun only if source behavior changes. Review actual PNG/AX for truncation, unit truth and the 1,100/1,300 relative bar widths. Redesigned native work remains pending; the original iPad before is already accepted.

## Edge Cases

| Case | Handling |
|---|---|
| Report nil | Parent offers no link; detail keeps `doc.text` and existing empty message if opened directly. |
| Summary nil/empty | Omit section; do not fabricate formatter output. |
| Highlights empty | Show original “No highlights this period”; do not synthesize PR/new exercise, which current production caller supplies as 0/empty. |
| Prior volume nil/zero | Omit volume change; no 0% comparison or invented previous values. |
| HealthKit-only duration with zero kg | Keep real sessions/duration and source `0kg` total; do not imply measured strength volume. |
| Muscle breakdown empty/nonpositive | Omit section or preserve guarded zero bar; no divide-by-zero. |
| Monthly model (if passed by another caller) | Render actual period/name/date and existing stats without claiming this Activity route generates monthly reports. |
| Max AX/Duo folded | Stack stat cells and muscle names/values; retain all original text, highlights and Back. |

## Testing Strategy

- **Original/before**: Exact `ActivityExerciseRegressionTests/testActivityRiskAndReportRoutesOpen` risk→Back→report path on source-matched original. Inspect report auditTap and A09 teardown, separate from A08 risk image. The original iPad 2/2 run and A09 loaded root/PNG/AX are confirmed; do not extrapolate to phone/Duo or redesigned after.
- **Focused after**: Re-run exact route selector with a small assertion of test-only fixture totals/highlight and report root, then native Back/scroll if the test is extended. Avoid mirroring six static labels or hardcoding prototype data. Existing use-case/VM tests are source math authority; View-only redesign need not rerun all report algorithms.
- **Visual**: Source/fixture-matched iPhone, iPad, Duo folded/open, plus affected dark/max AX. Check one date caption, actual kg/min/% units, all highlight icons, no clipped summary or muscle names. No Watch change.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| DEBUG fixture numbers mistaken for production report | High | High | Label fixture in plan/tests/captures; never embed literals in View. |
| 5,400 fixture minutes silently converted to hours or mislabeled | Medium | High | Preserve source `totalDuration` format and actual `min` unit. |
| Average intensity read as physiological confidence | Medium | Medium | Keep original normalized metric label/value; no new clinical wording. |
| An unsorted report makes first-row normalization falsely equal after clipping | Medium | High | Normalize bars by the actual maximum across rows once; fixture Chest 1,100 before Quadriceps 1,300 should render about 85%/100%. |
| 3-column/fixed-width source clipping at AX | High | Medium | Adaptive metric and muscle rows; inspect actual max-AX viewport. |
| A08 audit or A09 teardown misattributed | Medium | High | Inspect exact PNG/AX root and route checkpoint before pairing. |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: Report source, math, conditional sections, DEBUG fixture and route capture timing are authenticated. Fresh original iPad A09 loaded image and AX are confirmed; original phone/Duo and redesigned device/AX readability remain pending native evidence.


## 2026-11-03 검증 및 구현 정정

> 현재 앱·검사 소스 `0d789a1ea11e777f663f52aad44a760684e27acc`, 기준 main `97ff66f2d1df59e1a88a6284504ba95b3a1609c7`. 구현·네이티브 검증·실제 맵 설치를 완료했다. 머지는 별도 Ship 기록에서 확인한다.

### 구현 범위와 단위

- `WorkoutReportDetailView`는 기존 `58ac`의 불투명 hero, 적응형 통계와 요약·하이라이트·상대 근육 막대를 유지한다. 현재 `0d`의 시각 정리는 볼륨 `scalemass`, 시간 `timer`, 근육 행의 기존 `stat.muscleGroup.iconName` 선행 glyph다.
- 모델, Activity ViewModel, use case 및 formatter는 변경하지 않았다. `totalDuration`은 분 단위이며 DEBUG fixture의 원래 값은 **5400 min**이다. 90분으로 환산하지 않는다. 2.4k, 세 세션, 세 활동일, 72%, +12%, 가슴 1.1k와 대퇴사두 1.3k도 기존 DEBUG fixture 값이다.
- A08 위험 검사 및 뒤로 가기를 공유 selector에 보존한다. 새 기간 제어, AI 호출, 새 계산 또는 테스트용 제품 fallback을 추가하지 않는다. nil/빈 상태와 보고서 기간을 소스 수준에서 보존하지만 아래 캡처 결과를 모든 상태의 런타임 검증으로 확대하지 않는다.
- 다섯 소스 리뷰는 각 P1/P2/P3 0이다. 소스 검토와 네이티브 결과는 별도다.

### 현재 소스의 네이티브 결과

| 기기 / 케이스 | 결과 및 제한 |
|---|---|
| iPad mini A20 일반 + dark MAX | `ipad-normal-max-0d789a1e` 2/2 통과. 일반 hero/하단과 MAX hero·duration·summary·highlight·muscle 5개 PNG/AX 확인. MAX의 각 스크롤 캡처가 모든 항목의 동시 표시를 뜻하지 않는다. |
| Phone 일반 | `phone-normal-report-0d789a1e` 1/1 통과. hero와 하단 PNG/AX 확인. Phone MAX는 검증하지 않았다. |
| Duo Closed 일반 | `duo-closed-report-0d789a1e` 1/1 통과, 9/9 ACK 및 전후 0°/LCD. host PNG와 manifest AX 대조. |
| Duo Open 일반 | `duo-open-report-0d789a1e` 1/1 통과, 9/9 ACK 및 전후 180°/LCD-1. 활성 host PNG와 manifest AX 대조. |

현재 5/5 케이스 통과와 일반 hero 4쌍, 일반 하단 4쌍, iPad MAX 5쌍 총 13쌍의 독립 품질 검토가 확인되었다. 최종 판정은 PASS WITH NOTES, P1/P2/P3 0이다. 소유 기기 세 대는 삭제되어 registry는 비어 있다. Duo 원본 Xcode의 일반 `modelName`은 `iPhone`이므로 실제 archived legacy record의 `iPhone19,4`와 `com.apple.iphone-duo-9`, 소유 기기 식별자 및 display readback을 함께 결합한다. 폴드 중 연속 동작이나 live VoiceOver는 검증 범위에 포함하지 않는다.

### 이전 근거와 실제 맵

- 원본 `936b87b4` A20의 report-link PNG `87B3CA7E…`와 AX `0E853648…`는 통과한 report selector의 동일 checkpoint에 속한다. 원본의 `5400 min`은 현재 fixture와 같은 분 단위 표시다.
- 기존 맵의 네 A09 이미지가 주간 리포트임을 확인했다. 개별 이전 기기·실행 버전·AX와 Duo 자세는 확인되지 않아 그 범위로만 표기한다. 별도 검증된 A20 이전 화면과 맵 원본은 분리 보존한다.
- `58ac` A20 일반/MAX 2/2는 아이콘 변경 전 이력으로만 보관한다. 현재 `0d` iPad 실행과 혼동하거나 현재 후속 캡처로 재사용하지 않는다.
- 갤러리 설치는 실제 exit 0으로 완료했다. 18개 소스와 19개 출력의 고정 값 및 네 A09 행·활동 보드만 반영하고 다른 행·Watch·기존 갤러리 보존을 설치기에서 확인했다. 갤러리는 298파일·126 PNG이며 inventory SHA-256은 `49a20c82faeb0182f190374772c282920efaa0dc1ec7086a123bc8c05f06e04d`다.

### 마무리 전 확인

1. 완료된 Duo Open 1/1, 9/9 ACK, 180°/LCD-1과 13쌍 품질 판정의 원본을 보존한다.
2. 실제 설치 exit 0, 고정 19개 출력과 기존 행·갤러리·Watch 보존을 확인했다.
3. CI Build 성공. iOS unit job `125608087094`의 테스트 단계는 취소로 표시되며 결과 업로드 중이다. 전체 unit 통과를 주장하지 않는다. Watch job `125608087511`, run `41541957500`은 테스트 전 destination ID 누락으로 exit 64이며 실행 수는 미확인이다. 이 변경에는 Watch 코드와 runner 수정이 없다. 별도 전체 재실행을 하지 않았다.
4. 최종 PR 리뷰와 GitHub 머지는 별도 Ship 단계에 기록한다.
