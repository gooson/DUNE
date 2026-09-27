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
| DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift | modify | 화면 밖 Crunch 행도 동일 탐색 계약 사용 |
| DUNEWatchUITests/Smoke/WatchPlankTimerTests.swift | modify | 문자열/전체 화면 swipe 대신 정확한 행 탐색 |

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

## 실행 기록 — UI 게이트 미통과

### 확인된 원인과 구현

- 원본 Watch 테스트를 로컬에서 재현했다. xcresult 접근성 계층에서 목록은 `CollectionView[watch-quickstart-screen]`, 화면에 노출된 운동은 `watch-quickstart-exercise-plank`였다. Squat은 화면 아래에 있었다. root AXID는 목록 ID를 덮지만 운동 행 ID는 유지되므로 Watch 제품 코드는 수정하지 않았다.
- `openLifeNewHabitForm()`이 Life의 `+ → New Habit → name field`를 공통 처리한다.
- `findQuickStartExercise(identifier:maxSwipes:)`가 정확한 목록/screen ID의 scroll container 안에서 정확한 운동 행 ID와 hittability를 검사한다. 최대 6회 스크롤하며 실패 시 계층을 첨부한다.
- Watch full 첫 실행에서 발견한 동일한 Crunch 탐색 실패를 수정하고 Plank 진입에도 같은 helper를 적용했다.

### 검증 증거

| 검증 | 결과 | 로그 |
|------|------|------|
| scripts/build-ios.sh --no-regen (commit hook) | BUILD SUCCEEDED | /tmp/dune-life-build.log |
| Watch UI target build-for-testing | TEST BUILD SUCCEEDED, 후속 Crunch 수정도 compile 성공 | /tmp/dune-watch-compile.log 및 commit 68da63bc hook |
| 원본 Watch fixture 테스트 | 1개 실패, 화면 밖 Squat 재현 | .deriveddata/watch-ui-tests/Logs/Test/Test-DUNEWatchUITests-2026.09.27_10-41-08-+0900.xcresult |
| Watch full, 최초 수정 | 10개 중 9개 통과; 원래 CI 실패 3개 모두 통과; Crunch 1개 실패 | /tmp/dune-watch-full.log |
| Watch full, Crunch 수정 후 | 첫 fixture 테스트 통과 후 home app launch/idle timeout; 중단 exit 75 | /tmp/dune-watch-full-retry.log |
| Life targeted 첫 시도 | 시뮬레이터 launch 진행 정지로 중단, 완료 테스트 수 확인 불가 | /tmp/dune-life-targeted.log |
| Life targeted 재시도 | launchd 응답 실패 후 부팅 복구, 앱 launch 진행 정지로 중단 | /tmp/dune-life-targeted-retry.log |
| iPad full 시도/복구 | clone Creating 상태 오류 및 기존 device data missing으로 테스트 시작 불가 | 실행 도구 출력 |

SwiftUI 및 Apple UX Work 품질 에이전트는 초기 구현 diff에서 P1/P2/P3=0을 반환했다. 이는 정식 Phase 3의 5관점 리뷰를 대체하지 않는다. UI gate가 실패하여 Phase 3 이후 리뷰/Compound/Ship는 시작하지 않았으며 PR도 생성하지 않았다. 전체 iPhone/iPad 회귀와 최종 Watch 전체 통과는 미확인이다.

### 환경 복구 및 보존

- Xcode 27.0, iOS/watchOS 27.0. 전용 기기 재부팅, 기존 fixture, 실제 XCTest UI 경로를 사용했다. timeout 증가나 테스트 skip으로 통과 처리하지 않았다.
- `launchd failed to respond`, `device remained in Creating state`, `device data is no longer present`가 반복됐다. 재부팅 후에도 Apple 로고/앱 launch 단계 지연이 지속됐으며 이번 작업의 테스트와 멈춘 진단 수집 프로세스만 종료했다.
- 다른 작업에 영향을 주는 전역 CoreSimulator 재시작은 수행하지 않았다. 머지 전 중단이므로 시뮬레이터는 재현용으로 보존한다. 원본/기존 기기는 삭제하지 않는다.
- 생성 성공이 확인된 기기: Watch `9A773B25-40EB-46C2-9205-41DD9D2A9E0E`, Watch 재실행 `73EEFC88-8A36-4CE3-AD67-4728E5C292B8`, iPhone `BDB4A049-432C-4C16-9D4F-5B50D671B506`, 새 iPad create `177CECAD-61DC-4AB1-8D51-31EDBA60322D` (이후 helper 조회/부팅 실패). 생성 전 목록은 `/tmp/dune-ui-baseline-simulators.json`이다.
- 다음 실행은 CoreSimulator 정상화 후 Life targeted → 전체 iPhone/iPad UI 및 Watch full → Phase 3부터 진행한다.

### 공식 API 참고

- [XCUIElement.isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)
- [XCUIElement.exists](https://developer.apple.com/documentation/xcuiautomation/xcuielement/exists)


## 재개 기록 — 최종 검증 진행

- 사용자 요청으로 남은 절차를 재개했다. 최신 `origin/main` (`947650ab`)을 병합하면서 main의 Life 메뉴 helper 이름과 Watch 권한 alert 처리를 보존했다. 병합 커밋: `562500ac`.
- 병합 후 `scripts/build-ios.sh`는 성공했다 (`/tmp/dune-merge-main.log`).
- 최종 코드 diff를 5개 리뷰 에이전트(Security, Performance, Architecture, Data Integrity, Simplicity)가 각각 재검토했고 P1/P2/P3=0이다. Agent-Native는 설정/프롬프트 변경이 없어 해당 없음이다.
- `app-quality-gate`와 최종 `pr-reviewer`도 코드 지적 사항 0건을 반환했다. 앞서 수행한 SwiftUI/UX 검토 후 제품 UI 코드의 추가 변경은 없으며 최신 main 대비 최종 diff는 테스트/문서뿐이다.
- Compound: `docs/solutions/testing/2026-09-27-life-menu-watch-offscreen-ui-tests.md`. 별도 규칙 승격이나 직접 연결된 활성 TODO는 없다.
- 최종 iPhone 전체 UI 로그: `/tmp/dune-final-iphone-full.log`. Watch와 iPad 전체 테스트는 저장소 공유 잠금으로 직렬 실행한다 (`/tmp/dune-final-watch-full.log`, `/tmp/dune-final-ipad-full.log`).
- 병합 전 실행 `/tmp/dune-resume-iphone-full.log`은 최종 검증에서 제외한다.
- Git SSH push는 성공했다. GitHub CLI 인증은 401, connector PR 쓰기는 403, 사용 가능한 브라우저는 로그아웃 상태여서 사용자에게 인증 복구를 요청했다. 테스트와 문서화는 계속 진행한다. 인증 차단을 우회하는 로컬 main 머지는 수행하지 않는다.


## 최종 범위 재확정 (main f2118028 정책 반영)

최신 main의 `.codex/skill-compat.md` 변경 범위 기반 UI 게이트를 적용했다. `python3 scripts/plan-ui-tests.py --base origin/main` 원본 판정은 UI 테스트/공유 helper 파일 변경 때문에 iOS/watch full이다 (`/tmp/dune-ui-scope.json`). 심볼 소비자를 `rg`로 확인하여 iOS만 아래 범위로 축소한다.

- `openLifeNewHabitForm` 변경은 LifeSmokeTests 4개 호출과 LifeRegressionTests 1개 호출에 한정된다. 기존 `waitAndTap` 등 공유 동작은 변경하지 않았다.
- `ExercisePickerView.templateRow` 변경은 quick-start 템플릿 버튼의 `contentShape(Rectangle())` 한 줄이다. 템플릿 실행 callback을 전달하는 Activity 경로를 Picker 회귀에서 검증한다. 일반 운동 선택의 callback/저장/내비게이션 로직은 변경하지 않았다.
- `HabitHistorySheet` 변경은 화면/빈 상태 AXID를 실제 Text에 옮기는 것뿐이다. LifeRegressionTests가 빈 기록, seeded 기록, 닫기와 새 습관 생성을 검증한다.
- App/Domain/Data/Shared/seed/project 변경은 이번 PR diff에 없다. 최신 main에서 병합한 실행기/정책은 별도 변경이며 보존한다.
- 최종 iOS: iPhone/iPad 각각 `scripts/test-ui.sh --smoke --only-testing DUNEUITests/LifeSmokeTests --only-testing DUNEUITests/LifeRegressionTests --only-testing DUNEUITests/ActivityExercisePickerRegressionTests`. 명시적 LifeSmokeTests 선택으로 weekly 케이스도 제외하지 않는다. 공통 smoke와 관련 클래스의 합집합을 실행한다.
- 최종 Watch: `scripts/test-watch-ui.sh` 전체 suite. 공유 Watch helper와 모든 fixture 호출부를 검증한다.
- 수정 전 전체 CI `36288920161`는 iOS/Watch unit 성공, Watch UI 12/13 성공이었다. 마지막 Crunch 실패는 실제 nested switch 탭으로 해결해 로컬 단독 1/1 성공했다. iOS 전체 실행과 로컬 iPad 전체 실행은 위 정책에 따라 종료했으며 전체 통과 증거로 사용하지 않는다.

### 추가 실패 해결 증거

- iPad template 버튼 중앙 좌표는 label의 투명 영역이었다. 이전/이후 영상 프레임에서 picker가 그대로 남았다. `contentShape(Rectangle())` 추가 후 같은 테스트가 통과했다. 콜백 순서 변경은 하지 않았다.
- Life 기록 화면은 내용이 실제로 표시되지만 root VStack AXID가 빈 상태/닫기 ID를 덮었다. ID를 header/empty Text로 옮겼다. 기록 행 테스트는 존재하지 않는 `row-0` 대신 실제 UUID-prefix 행과 `Completed` 내용을 확인한다.
- 위 iPad 실패 3개 모두 통과: `/tmp/dune-ipad-three-fixed.log`, 3 tests / 0 failures.
- Watch 바깥 Switch 중앙 탭은 값이 0으로 남았고, nested Switch 탭은 1로 변경됐다. 상태의 문자열 `1`/`0` 전환과 중량 버튼 추가/제거를 함께 검증했다. `/tmp/dune-watch-crunch-fixed-retry.log`, 1 test / 0 failures.
- 제품 수정 후 앱 빌드 성공: `/tmp/dune-ui-surface-build.log`. Watch test compile 성공: `/tmp/dune-watch-toggle-compile.log`.
- 수정 후 5관점 재리뷰와 SwiftUI/Apple UX 전문 리뷰는 actionable findings 0건. 최신 main 동기화 후 CI 설정 삭제가 없음을 확인했다.
- GitHub 인증 복구 후 PR https://github.com/gooson/DUNE/pull/781 생성. nightly 워크플로는 한 번 dispatch 후 원래 disabled 상태로 복원했다.
- 추가 생성 기기: iPad `85A9967F-5A6F-49CF-8FEA-010EAD540837`, Watch `F2070FCD-297A-4F53-B621-D87D4288042D`. 원본 기기는 보존한다.
