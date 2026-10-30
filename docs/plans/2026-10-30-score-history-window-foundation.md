---
topic: score-history-window-foundation
date: 2026-10-30
status: approved
confidence: high
related_solutions:
  - ../solutions/architecture/2026-10-30-condition-detail-redesign.md
  - ../solutions/architecture/2026-03-14-score-detail-unification.md
  - ../solutions/architecture/2026-04-05-cumulative-stress-detail-view.md
---

# Implementation Plan: Shared score history window

## Context

T04의 실제 구현 [PR862](https://github.com/gooson/DUNE/pull/862)가 `9fa10e46`에 병합됐다. 다음 T05는 차트의 고정 길이 구간과 달력 요약이 다르고, 긴 기간에는 plot bucket으로 통계를 계산한다. 검증된 T04의 두 순수 계산을 작은 선행 PR로 공유해 후속 화면에서 같은 계약을 쓰게 한다. T05 디자인·snapshot 조회 변경은 이 PR에 포함하지 않는다.

현재 base는 `origin/main`의 `9fa10e46`, 관리 worktree는 `detail-redesign-l03/Health`다. 원본 da96 시안534파일을 보존한다. 사용자 `/run` 및 실제 앱 구현/화면별 PR 지시에 따라 승인 대기 없이 실행한다.

## Requirements

- T04 `historyWindow`와 `makeVisibleSummary`의 인자·기본 Calendar·이름 있는 tuple·반환값·경계 동작을 유지한다.
- fixed duration, 단일 참조 시점, 하루 종료/다른 기간의 다음 날 exclusive 종료, buffer 구간, half-open current/prior raw point 통계를 보존한다.
- ViewModel의 기존 static 진입점은 얇은 delegate로 유지한다. 호출자·테스트·화면·문구·색·내비게이션·HealthKit 조회·Domain 계산을 바꾸지 않는다.
- 순수 helper는 Foundation만 import하며 Presentation/Shared/Detail에 둔다. 프로토콜·서비스·새 cache/상태를 추가하지 않는다.

## Approach

`ScoreDetailHistory` enum의 `window`와 `summary`로 기존 계산 body를 이동한다. T04의 기존 메서드는 인자를 그대로 전달한다. T05는 별도 화면 PR에서 이를 채택한다. 새 API/프레임워크 동작을 도입하지 않으므로 외부 최신 API 조사는 해당 없음이며, 기존 실제 소스와 월말/윤일/DST 테스트 계약을 기준으로 한다.

| Alternative | Decision |
|---|---|
| T05에 복사 | 서로 다른 경계 수정이 누적되므로 제외 |
| TimePeriod/Domain 전체 변경 | 기존 모든 화면의 기간 의미가 달라져 범위가 커지므로 제외 |
| 두 순수 계산만 공유 | 기존 결과를 유지하며 다음 화면에 재사용 가능, 채택 |

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Shared/Detail/ScoreDetailHistory.swift` | 기존 두 계산을 담는 새 Foundation helper |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailViewModel.swift` | 기존 static 메서드 body를 delegate로 교체 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 표준 regen으로 새 파일 포함 |
| 계획·리뷰·해결책·실행 목록 | 별도 선행 PR 근거와 검증 보존 |

## Implementation Steps

1. 기존 함수 body와 호출자를 대조하고 동일 계산을 이동한다. T04 진입점은 유지한다.
2. 표준 project regen/build와 관련 Condition VM 단위를 실행한다. 새 구현을 되풀이하는 테스트는 추가하지 않고 기존 의미 있는 경계 테스트를 유지한다.
3. 최종 UI 판정기를 재실행하고 iOS의 기본 foreground smoke와 T04 기간/통계 테스트를 선택해 확인한다. full 판정이더라도 사용자 명시 요청이 없어 full 실행은 하지 않고 근거·미실행 범위를 기록한다.
4. 필수 일반 리뷰5관점과 필요한 품질 검토, Resolve, Compound, Pre-Ship, 별도 PR/Ship을 수행한다.

## Edge Cases / Verification

기존26개 VM 테스트는 월말·윤일·DST, 오늘 포함, 연속 페이지, buffer 끝, off-grid 이동 금지, raw day 가중치, 유효0/자료없음, current/prior half-open 경계를 포함한다. 이 테스트를 그대로 실행해 delegate 계약을 확인한다. caller 검색 및 project target 목록으로 iOS 소비자만 영향을 받음을 확인한다. Watch는 이 Presentation 파일을 target에 포함하지 않는다.

화면 배치·문구·상태·내비게이션의 의도한 변경이 없고 계산 body가 동일하므로 실제 디자인맵/테마 맵 새 캡처는 해당 없음이다. 관련 UI 선택 실행은 기능적 동등성 확인이며 기존 PNG를 이번 작업의 새 캡처로 표시하지 않는다. 예상치 못한 화면 차이가 있으면 범위를 재판정하고 실제 캡처 의무를 적용한다.

## Risks

| Risk | Mitigation |
|---|---|
| 구간 끝/기본 Calendar 변경 | body 이동·인자 전달만 허용, 기존 경계 테스트 |
| 누락 project membership | 표준 regen과 실제 compile |
| 다른 플랫폼 소비자 오판 | 호출자와 project.yml source 명시 목록 확인 |
| T05용 선행 추출의 과도한 추상화 | 두 static 계산 외 상태/프로토콜/확장 기능 금지 |

## Phase Ledger

Init/Plan/Work/UI/Review/Quality/Resolve/Compound complete; Pre-Ship review complete; Ship commit/CI in progress. 증거는 `.codex-checks/score-history-window/`에 기록한다. T04는32단위·15기기별 UI·CI·리뷰·Ship·정리·regen 완료이며 이 PR의 검증으로 재분류하지 않는다.

최종검증:source2ecfa3ff에서generic build·기존단위26개·정상선택UI2개통과. 원래주간차트전제before-tap실패와300초resultidle는별도보존했다. 소스변경없이scope전문가승인기본foreground로대체하고DesignCapture조건에서기간검사를재확인했다. 전체/full은미검증이며관련코드밖의실패를수정하지않았다. 일반5리뷰·AppQuality신규지적0개.

최종PRreviewer도소스·문서·증거의도입된P1/P2/P3없음으로확인했다. 원래before-detail검사실패는재현된기존버그로단정하지않고범위밖의fixture조건실패로보존했다.
