---
tags: [ui-test, life, watchos, accessibility, ci]
topic: life-watch-ui-smoke-fixes
date: 2026-09-27
category: plan
status: approved
confidence: medium
related_solutions:
  - testing/2026-03-09-e2e-phase5-life-regression.md
  - testing/2026-03-12-watch-ui-smoke-surface-fallback-hardening.md
---

# Life / Watch UI smoke 실패 수정

## Context

Actions run 36265810957에서 iOS 23개 중 Life 3개, Watch 5개 중 fixture 탐색 3개가 실패했다. Life는 추가 버튼이 Menu로 바뀌었으나 테스트가 New Habit 선택을 생략한다. Watch는 fixture가 존재하지만 정렬된 목록에서 AXID 탐색만 수행한다. 스크롤 및 root AXID 전파를 실제 런타임에서 구분해야 한다.

## Requirements / Approach

- Life 메뉴의 New Habit action에 안정적인 AXID를 추가하고 smoke/full 테스트가 공통 진입 helper를 사용한다.
- Watch fixture를 변경하거나 assertion을 완화하지 않고 실제 목록에서 운동을 찾아 시작한다. 제한된 스크롤과 hittable 확인을 사용하고 필요 시 root AXID를 안정 anchor로 옮긴다.
- 기존 waitAndTap, test base, fixture를 재사용한다. 고정 sleep, 좌표 탭, 무조건적인 timeout 증가는 사용하지 않는다.
- 단순 API 동작은 Apple XCUIElement exists/isHittable 공식 문서를 확인했다. exists와 hittable은 별개이며 화면 밖 요소는 hittable이 아니다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Presentation/Life/LifeView.swift | modify | New Habit menu AXID |
| DUNEUITests/Helpers/UITestHelpers.swift | modify | 공통 습관 생성 진입 helper |
| DUNEUITests/Smoke/LifeSmokeTests.swift | modify | 메뉴 진입 및 폼 assertion |
| DUNEUITests/Full/LifeRegressionTests.swift | modify | 동일 진입 계약 |
| DUNEWatchUITests/Helpers/WatchUITestBaseCase.swift | modify | 제한된 fixture 행 탐색 |
| DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift | modify | 실제 목록 탐색 검증 |
| DUNEWatch/Views/QuickStartAllExercisesView.swift | conditional | AXID 전파가 재현되면 root anchor 수정 |

## Implementation Steps

1. Life menu helper와 호출부를 갱신하고 작은 단위로 커밋한다.
2. Watch fixture 조회에 bounded scroll을 적용하고 런타임에서 AXID를 확인한다. 실패 snapshot 기반으로 필요 최소한의 접근성 수정을 한다.
3. scripts/build-ios.sh, 관련 Life/Watch 테스트를 실행한다.
4. iPhone/iPad full UI suite와 Watch suite를 실행한다. 실패는 로그/xcresult로 구분하고 최대 2회 수정 재검증한다.
5. 5관점 리뷰와 적용 품질 에이전트, 해결, Compound, PR/merge를 수행한다.

## Edge Cases

| Case | Handling |
|------|----------|
| 메뉴가 열렸으나 폼 미표시 | 메뉴 action과 폼 readiness를 각각 검증 |
| Watch 행이 화면 밖 또는 AXID 누락 | bounded scroll 후 실패 시 snapshot을 보존; 임의 행 선택 금지 |
| empty fixture | 기존 empty-state 검증 유지 |
| 언어/iPad popover 차이 | 사용자 문자열 대신 AXID와 기존 탭/모달 helper 사용 |

## Testing Strategy

- Domain/VM 변경 없음: 별도 unit test 추가 불필요, UI 회귀로 검증한다.
- 관련 Life smoke/full 및 Watch smoke 실행 후 전체 iPhone/iPad UI와 Watch UI를 실행한다.
- 로컬 Xcode 27.0 및 iOS/watchOS 27.0을 사용한다. CI Xcode 26.2와의 차이는 보고하고 PR CI도 확인한다.
- 기존 simulator 목록을 /tmp/dune-ui-baseline-simulators.json에 보존했다. 본 작업이 생성한 기기만 머지 후 정리한다.

## Risks

| Risk | Mitigation |
|------|------------|
| Watch root AXID가 하위 식별자를 덮음 | xcresult snapshot과 기존 안정 anchor 패턴 확인 |
| 전체 suite의 기존 실패 | 관련 실패와 분리하고 실패 게이트를 통과로 표시하지 않음 |
| 다른 worktree simulator 간섭 | 경로 hash 기반 전용 simulator 사용 |

## Confidence

Life 원인은 확정, Watch는 런타임 검증 전까지 중간 신뢰도다. 관련 brainstorm/TODO 검색에서 이 CI 실패에 직접 배정된 활성 TODO는 없었다.
