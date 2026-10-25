---
tags: [activity, life, hero, validation, run]
date: 2026-10-25
status: in-progress-after-user-ui-exception
---

# Activity·Life 히어로 /run 실행 현황

정식 리뷰 보고서가 아니라 UI 게이트에서 멈춘 실행 상태다. 구현과 새 캡처를 보존했으며, 전체 파이프라인 완료·출시를 선언하지 않는다.

Task: 승인된 Activity·Life `흐름과 근거` 히어로 구현.
Branch: `feature/activity-life-hero-rhythm` — 원본 Today·Watch dirty worktree와 격리.
Phases: 3/10 completed.

| Phase | Status | Proof |
|---|---|---|
| 0. Init | completed | main 기준 전용 worktree·브랜치, 지침·교정사항 확인 |
| 1. Plan | completed | [승인 계획](../plans/2026-10-25-activity-life-hero-rhythm.md) |
| 2. Work | completed | 앱 빌드 성공, 관련 단위 41/41, 기능별 커밋·push |
| 2.5 UI Test | failed | 최초 합집합 37/39, Today 알림함 2건 실패; Duo 내부 가로 캡처 미완료 |
| 3. Review | skipped | UI 게이트 실패로 미진입. 정식 P1/P2/P3 집계 없음 |
| 3.5 Quality | skipped | 정식 단계 미진입. Work 사전 SwiftUI·Apple UX·UI test expert 점검은 수행 |
| 4. Resolve | skipped | 정식 Review 미진입. Work 사전 P2 수정은 구현에 반영 |
| 5. Compound | skipped | UI 게이트 대기라 해결책 문서 미생성 |
| 5.5 Pre-Ship | skipped | UI 게이트 대기 |
| 6. Ship | skipped | UI 게이트 대기. PR 생성·머지·main 동기화·worktree 정리 미실행 |

## Artifacts

- Plan: [계획서](../plans/2026-10-25-activity-life-hero-rhythm.md)
- Actual captures: [새 실제 화면 23장](../design/full-redesign-map/review/activity-life-hero-rhythm-2026-10-25/index.html)
- Capture provenance / test receipts / limitations: [검증 설명](../design/full-redesign-map/review/activity-life-hero-rhythm-2026-10-25/README.md)
- Unit tests: `DUNETests/WeeklyHeroTrendPointTests.swift`, `DUNETests/LifeHeroTrendTests.swift`와 기존 ActivityViewModel·HabitAnalytics의 관련 검사. 최종 41개 통과·실패 0·skip 0.
- UI tests: `DUNEUITests/Visual/HeroRhythmUITests.swift`, `DUNEUITests/Smoke/LifeSmokeTests.swift`.
- Solution Doc: UI 게이트 대기라 미생성. 정식 `/compound` 절차를 수행했다고 보고하지 않는다.
- PR: 미생성. 작업 브랜치의 커밋은 원격에 보존한다.
- TODO: 이 요청에 대응하는 기존 active TODO 파일이 없어 done 이동 대상 없음. 미완료 UI 항목을 done 처리하지 않음.

Changed files (최대 10개):
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
- +74 more (native PNG, evidence, maps and tests)

## 검증 범위와 실패 처리

새 히어로 10개 고유 시나리오는 통과했다. 최초 9개, 후속 캡처·Life 진행 7개, 실패한 자동 연동 빈 상태와 sparse 기록 2개 재실행의 합집합이다. 중복 실행 수를 고유 시나리오 수로 부풀리지 않는다. 자동 연동 빈 상태의 첫 실패는 닫힌 Menu의 템플릿 항목을 조회한 테스트 오류였으며, 실제 메뉴→템플릿 목록 경로로 수정한 뒤 단 한 번 재실행해 통과했다.

기존 Life 설명 배치 검사는 1/1 통과(밝음·어두움·최대 AX 3상태). iPad·Duo 외부 캡처는 각각 4/4 통과했다. 최초 공통 smoke의 Today 알림함 2건은 별도로 실패 상태를 유지한다. 직접적인 소스 연관은 찾지 못했지만 baseline 문제임을 확정하지 않았으며, 원인 수정 없이 재실행하지 않았다. 사용자에게 `히어로 범위로 출시하고 별도 기록` 또는 `알림함까지 범위 확장`을 물었고 답변을 기다린다.

Duo 내부는 LCD-1 활성화 뒤에도 회전 readback이 portrait여서 UI 검사 0개로 종료했다. 공식 회전 대안은 처음에는 다른 worktree의 잠금으로 시작하지 못했다. 잠금 해제를 확인한 뒤 한 번 실행했으나, setter의 landscapeLeft 성공 응답과 달리 실제 getter는 portrait에 남았다. 실제 방향이 확인되지 않아 UI 캡처를 시작하지 않았고 같은 setter를 반복하지 않았다. 숫자 힌지 각도도 현재 CLI에 조회 명령이 없어 미검증이다. 완료된 외부 캡처는 공식 LCD 활성·portrait 조회와 fresh PNG로 배치만 확인했다. 정확한 재개 조건은 갤러리 README에 있다.

앱 소스는 `471a82f0` 이후 동일하다. `88790777`은 기존 UI 테스트의 스크롤 조건만 바꿨고 후속 변경은 문서·캡처다. 단위 테스트 실행 당시와 빌드·캡처 시점의 앱 내용 일치를 보존된 파일 hash로 확인한다. 문서 추가로 stale이 된 전체-worktree receipt를 임의 갱신하거나 새 자동 테스트 통과로 간주하지 않는다.

## Work 사전 품질 점검

- SwiftUI expert: 고정 어두운 카드에서 Life 요약의 `.secondary` 대비와 Activity 링크 내부 접근성 그룹을 지적했고 수정했다.
- Apple UX expert: 수동 습관의 관측된 0회와 결측을 구분하고 최대 글씨의 결측값을 `No record`로 읽도록 수정했다. 최신 기본/MaxAX native 검토에서 추가 P1/P2는 없었다. 대비 계측과 VoiceOver 전체 탐색을 수행한 것은 아니다.
- UI test expert: seeded 기록·목적지·누락 상태 및 캡처 테스트를 작성했다. Today 두 실패의 직접 소스 경로를 찾지 못했으나 baseline 원인 미확정으로 유지했다.
- P3: Activity 머리말·하단이 같은 준비도 상세로 이동하는 중복 행동은 기존 식별자·상호작용 호환을 위해 유지했다. 숫자의 중복 accessibilityValue는 제거했다.
- app-quality-gate / 정식 5관점 리뷰 / pr-reviewer는 UI 게이트 이후 실행할 항목이며 아직 수행하지 않았다. perf-optimizer는 7개 값의 작은 요약이라 대량 데이터 처리 검증 대상으로 추가하지 않았다. Agent-Native는 `.claude`·`.codex` 제품 지침 변경이 없어 적용 대상이 아니다.

## Change Verification Guide

| 화면 | 변경 내용 | 확인 방법 |
|---|---|---|
| Activity | HRV·수면·회복 구성 점수, 저장된 7일 준비도 | Activity → 히어로의 구성 점수·기록 확인 → 준비도 자세히 보기로 기존 상세가 열리는지 확인 |
| Life | 완료·대상·남음, 일별 실제 완료 횟수 | Life → 히어로 요약·7일 기록 확인 → 오늘의 습관으로 목록 이동 |
| 큰 글씨·빈 기록 | 날짜·값 목록과 안내 | 시스템 글씨를 크게 설정해 하단 날짜·CTA까지 스크롤. 기록이 충분치 않으면 데이터 대기 안내, 자동 연동 습관만 있으면 시작 안내 확인 |
| 내부 변경 | 순수 날짜별 기록 집계·UI fixture | 기존 점수 산식·체크리스트 목적지는 유지. DEBUG opt-in fixture는 일반 앱 실행에서 켜지지 않음 |

사전 조건: 준비도 이력은 앱이 저장한 서로 다른 날짜의 기록이 필요하며, 새 사용자는 과거 그래프 대신 안내가 정상이다. Life의 현재 주기 진행과 일별 완료 기록은 서로 다른 의미다. 실제 HealthKit 권한·동기화·Watch 전체 회귀는 이 검증에 포함하지 않는다.

시뮬레이터 정리: 원격 머지를 수행하지 않아 삭제 0개. 이 worktree 소유 iPhone·iPad·Duo 3개를 재개용으로 보존한다. 다른 worktree의 기기·프로세스는 정리하지 않았다.

## 사용자 예외 승인 후 재개

사용자가 `통과 하고 계속`이라고 지시하여 2026-10-25 UI 게이트 예외를 승인했다. 알림함 두 실패와 Duo 내부 가로 미검증을 그대로 보존하고, 이번 히어로 변경의 정식 Review부터 Ship까지 재개한다. 위 표는 중단 시점의 기록이며 최종 결과로 갱신할 예정이다. 실제 테스트 결과를 통과로 변경하지 않았다.
