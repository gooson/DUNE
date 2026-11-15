---
tags: [watchos, healthkit, workout, recovery, review, ship]
date: 2026-11-15
category: solution
status: reviewed
---

# Watch 완료 후 복귀 복구 오류 리뷰

> Scope: `fix/watch-recovery-save-state` → `origin/main` (`aa2eaa06a`)
> 최초 리뷰 파일: 10개. 이후 리뷰 결과 문서와 중복 대입 제거만 추가했다.

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | 없음 |
| P2 - Important | 0 | 없음 |
| P3 - Minor | 2 | 모두 Resolved |

Security·Performance·Architecture·Data Integrity·Simplicity를 별도 read-only 에이전트로 리뷰했다. Agent-Native는 지침·프롬프트 변경이 없어 생략했다. 최종 PR 통합·크래시 검토와 앱 품질 검토도 수행했다.

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

없음.

## P3 Findings (Consider)

### [Simplicity] simp-001 — 복원된 시작 시간의 중복 대입

- **File**: `DUNEWatch/Managers/WorkoutManager.swift`, `recoverSession`
- **Category**: simplicity
- **Issue**: `restoreRecoveredSessionState`에서 이미 복원한 시작 시간을 다시 설정했다.
- **Suggestion**: 중복 대입 제거.
- **Disposition**: **Resolved**. 대입을 제거했고 최종 리뷰에서 nil·snapshot·HealthKit 날짜 분기 모두 결과가 같음을 확인했다.

### [Simplicity] simp-002 — 즉시 덮어쓰는 복구 플래그

- **File**: `DUNEWatch/Managers/WorkoutManager.swift`, `restoreRecoveryState`
- **Category**: simplicity
- **Issue**: 유일한 호출자가 즉시 다시 계산하는 `isRecoveredSession`을 미리 false로 설정했다.
- **Suggestion**: 불필요한 설정 제거.
- **Disposition**: **Resolved**. 대입을 제거했고 호출자의 무조건 재계산을 확인했다.

## Validation

- P3 수정 후 표준 Watch unit 실행기의 `DUNEWatchTests/WorkoutManagerSessionRecoveryTests`·`DUNEWatchTests/WorkoutElapsedTimeTests`: **14 tests, 2 suites 통과**. 로그: `.xcodebuild/watch-recovery-resolve-unit.log`. Watch 앱·unit target 컴파일 포함.
- `DUNEWatchUITests/WatchWorkoutFlowSmokeTests/testCardioSummaryDoneStaysDismissedAfterBackgroundAndRelaunch`: **1/1 통과, exit 0**. `.xcodebuild/watch-summary-return-ui.log.result.json`의 정확한 selector 결과 확인. 최종 P3 전 실행이며, 두 대입문 제거가 이 동작을 바꾸지 않는다는 최종 PR 검토를 근거로 재사용했다. UI target 컴파일도 포함한다.
- [L10N] 새 사용자 대면 문자열 없음. 변경된 로그·UserDefaults 키는 번역 면제 대상이다. `swift scripts/format-xcstrings.swift --check --check-manual`과 `git diff --check` 통과.
- [실제 Watch 맵 F02](../../design/phone-design-map/actual/watch/index.html)의 새 캡처·출처를 확인했다. 기존 하단 지표 가림은 유지되며 이번 변경은 배치·문구를 바꾸지 않는다.

## Positive Observations

- HealthKit의 세션 종류와 시작 시간을 pause 복원보다 먼저 적용한다.
- 완료로 닫은 운동 표식을 로컬 snapshot과 분리하고, 세션 채택 전에 거부한다.
- 실제 근력 템플릿 유실의 오류와 아직 완료하지 않은 운동의 복구는 유지한다.
- 실기기에서 HealthKit이 닫은 세션을 반환하는지, 사용자 사진의 `0분` 및 F06 복구 오류는 미재현이다. 모의 세션·in-memory SwiftData의 UI 결과를 영속 저장·중복 제거 검증으로 확대하지 않았다.

## Next Steps

미해결 finding은 없다. 이 검토와 최종 unit 결과를 기준으로 PR 생성·원격 머지를 진행한다. 검증 원본은 worktree 삭제 전에 primary checkout의 ignored `.codex-checks/ship-archive/watch-recovery-2026-11-15/`에 별도 보관한다.
