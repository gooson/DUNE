---
topic: T10 daily health report redesign
date: 2026-10-31
status: verified-pending-ship
confidence: high
related_solutions: [docs/solutions/architecture/2026-03-29-today-phase2-enhancements.md, docs/solutions/architecture/2026-10-28-vital-card-history-observation.md]
related_brainstorms: []
---

# Implementation Plan: T10 Daily Health Report

## Context and research

The approved T10 proposal (`.codex-checks/t10/reviewed-proposal.json`) turns the notification destination from a compact summary into a report with clear condition, activity, sleep, and narrative sections. The current destination (`DailyDigestNotificationView`) delegates condition, steps, workout narrative, and full-summary disclosure to `DailyDigestCard`, adds a separate sleep card, and keeps authorization/loading/no-data states. Notification routing owns push/back. The existing T10 actual PNGs predate this change and cannot prove it. Existing daily digest summaries and scores come from `DashboardViewModel` and `DailyDigest`; this work must not synthesize measurements or alter queries.

## Requirements

- Present a coherent report cover and distinct sections for observed condition, steps/workout, sleep, and the generated daily narrative. Preserve original SF Symbols, every recorded metric, the original summary text and disclosure, navigation, loading, permission failure, and empty states.
- A metric section appears only when its source value exists. Never draw a quantitative looking graph from decorative fixed data. Keep partial-data content usable.
- Use DS color, typography, card, spacing, dark mode, Dynamic Type, VoiceOver, and Reduce Motion conventions. Localize new user-facing text in en/ko/ja with manual string catalog entries.
- Preserve notification entry and back routing; do not add prototype-only state controls to production.

## Approach

Build a report-specific composition in `DailyDigestNotificationView` while retaining the existing shared dashboard card elsewhere. The report reads `DailyDigest.metrics` and presents measured values directly. Reuse `DailyDigestSummaryText` for disclosure. Use static symbolic artwork with SF Symbols and semantic DS colors; no invented score ring or charts.

| Alternative | Decision | Reason |
|---|---|---|
| Redesign `DailyDigestCard` globally | Reject | Would change the Today dashboard consumer outside T10. |
| Copy prototype state tabs into app | Reject | No such debug controls exist in the native destination. |

## Affected files

| File | Change |
|---|---|
| `docs/plans/2026-10-31-t10-daily-report-redesign.md` | Plan and verification contract |
| `docs/design/layout-map/daily-report-proposal.md`, `docs/design/layout-map/index.html` | T10 layout contract and index |
| `docs/design/theme-map/themes/dune-daily-report.html`, `manifest.json`, `README.md`, generated `index.html` | Preserved visual study and theme map |
| `DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift` | T10-only report composition |
| `Shared/Resources/Localizable.xcstrings` | New en/ko/ja copy only |
| `DUNEUITests/Full/NotificationRoutingRegressionTests.swift` | Focused route, disclosure, and state assertions |
| `docs/design/phone-design-map/actual/*/images/T10.png` and capture indices | Refresh affected actual screens after simulator execution; never reuse old PNGs as new evidence |
| `.codex-checks/t10/implementation-state.json` | Truthful handoff ledger |

## Steps and proof

1. Save this plan. Read the original T10/source, DS/UX/localization rules and related solutions. Create the T10 layout map and preserved theme study, register them in their indices, and run the theme-map generator/check. **This precedes app edits.**
2. Implement the report-specific layout using existing data and state branches. Ensure the workout label and full source sentence stack at accessibility sizes, duplicate decorative section artwork disappears at those sizes, long narrative text wraps without truncation, and illustration stays decorative for VoiceOver.
3. Add manual catalog keys, run `swift scripts/format-xcstrings.swift`, then `swift scripts/format-xcstrings.swift --check --check-manual` before and after the eventual build.
4. Add focused UI assertions on seeded notification response and deferred readiness. Inspect `git diff --check`, catalog/theme checks and source parse. Do not call build/unit/UI/simulator or commit in this delegated source-only phase.
5. Parent-owned verification: one scoped iOS build, exact UI selectors `NotificationResponseRoutingUITests/testNotificationResponseOpensSummaryAndBackReturnsToToday`, `DeferredDigestNotificationRoutingUITests/testSummaryWaitsForHealthKitReadinessWithoutShowingEmptyState`, and `TodayReadingUITests/testNotificationDigestReportPreservesDataAndDisclosure`. Use the standard runner with worktree-owned simulator, jobs 2, index store off, parallel tests off, and owned process deadline. Do not run full regression. Capture actual T10 on affected iPhone, iPad, Duo folded/open states, including dark and max Dynamic Type as feasible, then update capture indices; this remains pending until real PNGs exist.

## Risks and limits

- The shared card remains a Today consumer; report-specific disclosure must preserve its first-sentence preview semantics while not altering the dashboard card.
- Test fixture values are observed seeded data only. Dynamic content and partial data can change section height; verify full title and frame visibility rather than requiring long paragraphs to fit one viewport.
- Scope is T10 iOS destination. Watch has no T10 view. The actual map cannot be marked current until new native captures are produced.


## 2026-11-02 검증 범위와 보완

최신 main 8409827a를 실제 merge했고 네 문서 충돌에서 양쪽 화면 항목과 최신 정적 카탈로그·병합 manifest를 보존했다. 독립 다섯 소스 리뷰에서 발견한 원래 펼침/접힘 chevron 누락을 fd888f13에서 복원했다. 이 실제 배치 변경을 검증하기 위해 report method 한 개씩을 iPhone·iPad에서 실행하여 f9c956e1 기준 각각 1/1 PASS를 확인했다. 한 메서드 안에서 기본·dark 최대 접근성 글씨, 원문 보존과 실제 펼치기를 검증한다. 이전 route+report 2/2 통과와 별도 최초 그룹의 deferred-readiness 부분 양성은 소스 일치로만 재사용한다. Duo 접힘 첫 실행의 native back 조회 실패를 보존하고, NavigationBar 밖 BackButton을 찾도록 테스트만 수정했다. ae2598a6에서 같은 ID로 한 번 조건부 재검증하여 1/1·엄격 ACK 2개·전후 0° LCD·실제 back 및 Today 복귀를 확인했다. 펼침 report 한 건도 ae2598a6에서 1/1·엄격 ACK 7개·전후 180° LCD-1 통과했다. 전체 UI/단위 회귀나 Watch 검사를 추가하지 않으며 기존 CI는 그대로 유지한다. 새 실제 맵은 네 상태의 원본 PNG와 촬영·소스·검사 범위를 모은 뒤 T10만 갱신한다.

최종 제품 코드 fd888f13의 원격 앱 빌드와 iOS 2,734개/302 suites가 통과했다. 이후 27d12c40은 테스트 뒤로 버튼 조회만 변경했으며 접힘 검사에서 해당 변경을 실행했다. Watch CI는 실행 전 빈 destination ID로 exit64이며 통과로 표시하지 않는다. T10 네 행과 25개 PNG 전후·기본/큰 글씨 보충 자료를 정식 맵에 설치하고 이미지·출처·기기·스크롤 상태 차이를 구분했다. 로컬 전체 회귀와 중복 앱 빌드는 실행하지 않았다.
