---
tags: [activity, life, hero, validation, run]
date: 2026-10-25
status: ready-to-ship-with-user-approved-ui-exceptions
---

# Activity·Life 히어로 /run 실행 보고서

Task: 승인된 Activity·Life `흐름과 근거` 히어로 구현.
Branch: `feature/activity-life-hero-rhythm`. 원본 dirty worktree는 수정하지 않았다.
이 보고서는 최종 PR 리뷰 직전의 실행 기록이며 GitHub의 실제 머지 결과는 PR 상태와 최종 대화 응답으로 확인한다.

| Phase | Status | Proof |
|---|---|---|
| 0. Init | completed | 전용 main 기반 worktree와 feature 브랜치, 지침·교정사항 확인 |
| 1. Plan | completed | [승인 계획](../plans/2026-10-25-activity-life-hero-rhythm.md) |
| 2. Work | completed | 기존 링·목적지 재사용, 기능별 커밋, 관련 단위41/41 |
| 2.5 UI | completed with user exception | 히어로 검사·새 실제 화면은 아래 범위 통과. 공통 알림함2건 실패와 Duo 내부 가로 미검증은 `통과 하고 계속` 승인으로 예외 처리 |
| 3. Review | completed | 9,123줄 diff를 스킬의 대규모 예외에 따라 부모가 5관점·번역 직접 리뷰. P1=0/P2=0/P3=2 |
| 3.5 Quality | completed | Work 전문 검토 재사용·소스 일치 확인, 독립 app-quality-gate PASS WITH NOTES |
| 4. Resolve | completed | catalog metadata P3 해결·전체 번역값 동일성·formatter·수정 후 빌드 통과. 중복 상세 링크 P3는 호환성 선택으로 유지 |
| 5. Compound | completed | [해결책](../solutions/architecture/2026-10-25-activity-life-recorded-hero-evidence.md), 규칙 승격 불필요·기존 TODO 대상 없음 |
| 5.5 Pre-Ship | completed | github.com 인증 확인, 최신 main19커밋 통합, 충돌 해결·프로젝트 재생성·통합 앱 빌드 성공. 작업 파일 커밋 후 clean 확인 |
| 6. Ship | in progress | 최종 pr-reviewer와 GitHub PR 생성·머지·전용 기기 정리로 진행 |

## Artifacts

- Plan: [계획서](../plans/2026-10-25-activity-life-hero-rhythm.md)
- Review: [5관점·번역 리뷰 및 Resolve](2026-10-25-activity-life-hero-review.md)
- Quality: [종합 품질 게이트](2026-10-25-activity-life-hero-quality.md)
- Solution: [기록 근거·결측·접근성 해결책](../solutions/architecture/2026-10-25-activity-life-recorded-hero-evidence.md)
- Actual: [새 native PNG23장](../design/full-redesign-map/review/activity-life-hero-rhythm-2026-10-25/index.html), [출처·실행 receipt·미검증 범위](../design/full-redesign-map/review/activity-life-hero-rhythm-2026-10-25/README.md)
- Unit: `DUNETests/WeeklyHeroTrendPointTests.swift`, `LifeHeroTrendTests.swift` 및 기존 ActivityViewModel/HabitAnalytics 관련41건 통과.
- UI: `DUNEUITests/Visual/HeroRhythmUITests.swift`, `DUNEUITests/Smoke/LifeSmokeTests.swift`.
- TODO: 이 요청에 연결된 기존 active TODO 없음. 예외 UI 항목은 done 처리하지 않는다.

Changed files at Pre-Ship (최대10개):
- `DUNE/App/TestDataSeeder.swift`
- `DUNE/DUNE.xcodeproj/project.pbxproj`
- `DUNE/Presentation/Activity/ActivityView.swift`
- `DUNE/Presentation/Activity/ActivityViewModel.swift`
- `DUNE/Presentation/Activity/Components/ReadinessHeroEvidenceView.swift`
- `DUNE/Presentation/Life/LifeView.swift`
- `DUNE/Presentation/Shared/Components/WeeklyHeroTrendView.swift`
- `DUNE/Presentation/Shared/Models/WeeklyHeroTrendPoint.swift`
- `DUNETests/LifeHeroTrendTests.swift`
- `DUNETests/WeeklyHeroTrendPointTests.swift`
- +79 more

## 검증 결과와 예외

최초 iPhone 관련+공통 합집합은39개 중37개 통과·2개 실패였다. 새 히어로9개는 모두 통과했다. 후속8개 중7개가 통과했고, 자동 연동 빈 상태 테스트가 닫힌 Menu 항목을 바로 조회하여 실패했다. 실제 메뉴 순서로 수정 후 해당 검사와 sparse 검사가2/2 통과했다. 합집합으로 새 히어로10개 고유 시나리오 통과이며 중복 실행 수를 고유 수로 부풀리지 않는다. 기존 Life 배치1/1은 밝음·어두움·최대 AX3상태를 확인했다. iPad4/4, Duo 외부4/4 통과. 단위41/41, 수정 후와 main 통합 후 앱 빌드 통과.

두 알림함 실패는 `DashboardSmokeTests/testNavigateToNotificationHub`, `testNotificationHubSummaryAtMaximumAccessibilitySize`다. 캡처 당시 branch에서 Dashboard·navigation helper는 미변경이며 opt-in fixture도 꺼져 있었다. 로그의 AX hit point는 {-1,-1}였지만 baseline 원인임을 입증하지 않았다. 이후 main의 Today·Watch 변경을 통합했으며 이 과거 실패를 현재 main의 실패 또는 해결 증거로 재분류하지 않았다. 사용자 예외로 기록만 유지하고 관계없는 수정·재실행을 하지 않는다.

Duo 내부 LCD-1은 활성화됐지만 HID·공식 setter가 성공을 반환한 뒤에도 공식 방향 getter는 portrait였다. 내부 가로 UI 검사0건·캡처0장이다. 숫자 힌지 각도 조회도 현재 CoreDevice CLI에 없어 미검증이다. 완료된 외부 화면은 공식 LCD 활성·portrait와 새 native viewport로 배치만 검증했다. 사용자가 `통과 하고 계속`이라고 지시한 원문은 갤러리 evidence/user-ui-gate-exception.json에 있다. 재개 조건은 실제 landscapeLeft·LCD-1이 확인되는 수정된 전환 경로이며, 같은 setter를 반복하지 않는다.

전체 회귀, Watch, 실제 HealthKit 동기화, 대비 수치 계측, VoiceOver 전체 탐색은 수행하지 않았다. 실패/0건 실행을 통과로 바꾸지 않는다.

## 소스·통합 확인

캡처 당시 앱은471a82f0와 같고88790777은 UI 테스트만 바꿨다. Resolve에서는 Completed extractionState=stale→manual만 바꾸고 모든 번역 값이 동일함을 확인했다. evidence/catalog-metadata-delta.json이 그 차이를 보존한다.

최신 origin/main(967021f9)의19커밋을985da481에서 통합했다. 충돌은 번역·맵 인덱스/manifest에 한정됐으며 JSON3-way union으로 각 키를 보존하고, Today와 히어로 링크를 모두 유지하고, theme index를 재생성했다. 프로젝트 재생성 후 추가 diff는 없었다. Activity/Life·새 shared model/view·ScoreRefresh/HabitAnalytics/Readiness 계산·Seeder 및 히어로의8개 변경 번역 entry가483af226과 동일함을 확인했다. 통합 앱 빌드가 성공했다. 이 통합은 기존 성공 테스트를 전체 새 회귀로 승격하지 않으며 변경 없는 관련 로직의 증거만 재사용한다.

## Findings

정식 리뷰와 독립 종합 게이트 모두 P1=0/P2=0. P3 catalog metadata는 해결했고 준비도 머리말·하단의 같은 상세 행동은 기존 식별자·상호작용 호환을 위해 유지한다. SwiftUI contrast/AX grouping, 알려진0과 결측, spoken missing value의 사전 P2들은 구현 단계에서 수정됐다. Agent-Native는 관련 소스 변경 없음, perf-optimizer는 대량 처리 없음으로 미적용이다. 최종 PR 리뷰는 위 결과와 이후 delta를 확인한다.

## Change Verification Guide

| 화면 | 확인 방법 |
|---|---|
| Activity | 히어로 → HRV·수면·회복100점 구성 및 기록된7일 확인 → 준비도 자세히 보기로 상세 이동 |
| Life | 히어로 → 완료·대상·남음과 일별 완료 기록 확인 → 오늘의 습관으로 목록 이동 |
| 큰 글씨·빈 기록 | 시스템 큰 글씨 → 날짜·값 목록의 마지막 날짜·CTA까지 스크롤. 표본 부족은 안내, 자동 연동 습관만 있으면 시작 안내 |
| 내부 변경 | 기존 점수 계산·목적지를 재사용하며 DEBUG fixture는 opt-in UI 테스트에만 적용 |

사전 조건: 준비도 그래프에는 앱이 저장한 서로 다른 날짜의 기록이 필요하다. 새 사용자에게 데이터 대기 안내가 보이는 것이 정상이다. 현재 주기 진행과 일별 실제 완료 기록은 다른 의미다.

시뮬레이터 정리는 원격 머지 확인 후 이 worktree 소유3개만 처리한다. 다른 worktree와 원본 dirty 파일은 건드리지 않는다. 최종 삭제 수·잔여 상태는 Ship 결과로 보고한다.
