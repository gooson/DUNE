# Code Review Report

> Date: 2026-10-30
> Scope: A01 最近 운동의 5K/PR 표시·행간 수정과 관련 문서만 검토
> Base: origin/main (`04c6437d`), `codex/compact-workout-achievement`
> Files reviewed: 8개 (앱 2, UI 테스트 1, 문서 5)

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | 없음 |
| P2 - Important | 0 | 없음 |
| P3 - Minor | 0 | 없음 |

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

없음.

## P3 Findings (Consider)

없음.

## Review Perspectives

- Security / Data Integrity: 표시만 변경하며 권한·저장·성취 매칭에 영향 없음.
- Performance: gradient·overlay·custom Shape 제거, 추가 연산 없음.
- Architecture: Presentation 공유 컴포넌트 내부 변경, compact 소비자는 ExerciseListSection. ExerciseView의 full 표시는 변경 없음.
- Simplicity: 사용하지 않는 Palette·MedalRibbon까지 제거, 별도 추상화 추가 없음.
- Agent-Native: 지침/자동화 변경이 없어 제외.
- SwiftUI / Apple UX: caption2와 수직 줄바꿈, 기존 가로/세로 성취 fallback 유지. 버튼처럼 보이던 장식 제거. 정적 검토 통과이며 실제 배치 합격을 의미하지 않음.
- UI-test / App quality: 기존 테스트는 배지 자체보다 섹션·이동을 검증. 단일·다중 성취, 큰 글씨와 영향 기기의 fresh A01 캡처가 필요.
- [L10N]: 새 문자열 없음. 기존 `Text("Personal record: …")`와 `Text("Achievement: …")` 및 `String(localized: "PR")` 유지. 사용자 성취 텍스트 경로 변경 없음.

## Positive Observations

성취와 날짜를 같은 보조 정보 위계로 유지하고, VoiceOver는 장식 제외 후 기존 성취 설명을 한 요소로 읽는다.

## Validation / Resolve

- 원래 worktree의 표준 generic iOS 빌드와 카탈로그 format/manual 검사 통과. 격리 main 기반 최종 상태의 재검증을 대체하지 않는다.
- `git diff --check`: 통과.
- 이번 작업은 기존 Live Activity PR #864와 관련 없는 dirty 시안을 제외하고 별도 main 기반 worktree로 옮겼다. 원본 변경은 그대로 보존했다.
- P1/P2/P3 코드 수정 대상 없음. 필수 UI 검증은 출하 전 게이트로 별도 관리한다.
- Finding lifecycle: findings가 없어 재분류할 항목 없음.

## Next Steps

- [ ] 소유권이 등록된 전용 기기에서 A01 성취·기본/큰 글씨를 검증하고 실제 디자인맵을 갱신한다.
- [ ] 필수 검증 성공 후 최종 PR 검토·커밋·PR 생성·GitHub merge·소유 기기 정리.


## Ship Gate — 이전 시도 기록

새 전용 worktree의 기기 생성 명령은 repository simulator lock을 기다리는 단계에서 멈췄다. 기기 생성·부팅·앱 설치·UI 테스트는 시작하지 않았다. 대기만 수행한 이 작업 소유 PID를 확인한 뒤 종료했고 다른 실행은 조작하지 않았다. standalone lock 호출에 runner의 60초 기본 제한이 전달되지 않아 약 3분 대기한 실행 실수가 있었으며, 이 명령을 재시도하지 않는다. 이후 실행에서는 `DUNE_SIM_TEST_LOCK_WAIT_SECONDS=60`을 명시한다.

- 필수 UI 결과: 미수행. A01 iPhone·iPad·Duo 접힘/펼침 및 큰 글씨 새 캡처 미갱신.
- P1/P2/P3 finding: 모두 0건, Open 코드 finding 없음. 검증 누락은 별도 Ship gate.
- PR 생성·push·merge·remote/local cleanup: 미수행. 원래 PR #864는 그대로 유지.
- 재개 조건: 저장소 UI 소유 실행이 정상 종료되어 repository lock이 해제된 근거를 확인한 뒤, 소유권 등록 전용 기기를 생성한다. 이어 A01의 5K/PR·복수 성취·기본/큰 글씨만 focused 검증하고 해당 기기 실제 디자인맵을 갱신한다.
- `review-ship`의 "Stop before shipping if a P1/P2 finding remains open or required verification is failing or unavailable."에 따라 출하를 중단한다.


## 재개 · 추가 리뷰

- main의 PR #865 정리를 동기화했다. 앱 배지 코드에는 변화가 없다.
- 새 worktree 전용 iPhone `A8AC31E0-0BD2-4E8C-889C-25335C74261D` 생성·등록에 성공했다. 원래 worktree의 기기 부재와 분리한 새 환경이다.
- 기본 글씨/최대 접근성 글씨의 focused UI 테스트 2개를 추가했다. longer label인 10K+PR을 검증하며 literal 5K 단독 캡처와는 구분한다.
- 추가 리뷰 P2 `test-001`: 전역 10K 검색은 잘못된 행을 선택할 수 있음 → **Resolved**. compact NavigationLink에 stable item ID를 추가하고 seeded Tempo Run ID로 대상을 고정, 스크롤 후 성취·개인 기록의 의미 레이블을 각각 검사한다. 재리뷰에서 해결 확인.
- 최종 PR 코드 리뷰: Open P1/P2/P3 0건. origin/main 기준 범위에 unrelated Live Activity #864 변경 없음.
- 재개한 첫 UI 실행은 다른 작업이 획득한 repository lock을 60초 기다리다 실패했다. 기기 생성 성공과 UI 검증 성공은 별개다. 다른 소유 실행을 조작하지 않고, 종료 확인 또는 사용자의 격리 병행 요청이 있어야 다음 실행을 시작한다.


## 재개 실행 결과 — 출하 중단

사용자는 저장소 실행권을 쓰는 기존 검증이 끝난 뒤 진행하도록 선택했다. 해당 소유 실행 PID 25697의 종료를 확인하고 repository 잠금을 확보한 다음 새 전용 iPhone에서 표준 실행기를 시작했다. 병행 실행 예외는 사용하지 않았다.

- 기기: iPhone 18 Pro, iOS 27.0, UDID `A8AC31E0-0BD2-4E8C-889C-25335C74261D`; 소유권 등록·부팅 확인.
- 명령: `DUNE_UI_TEST_WALL_TIMEOUT=900 DUNE_UI_TEST_IDLE_TIMEOUT=300 bash scripts/test-ui.sh --simulator-udid A8AC31E0-0BD2-4E8C-889C-25335C74261D --only-testing DUNEUITests/ActivityFlowUITests/testCaptureRecentWorkoutAchievements --only-testing DUNEUITests/ActivityFlowUITests/testCaptureRecentWorkoutAchievementsMaximumText --log-file .xcodebuild/recent-achievement-ui-resumed.log`
- 앱과 UI 테스트 소스 컴파일·테스트 bundle 생성 후, `IDESchemeActionSDKRecord ... invalidDigitCount(94232)`가 기록됐다. 이 문자열만으로 근본 원인을 확정하지 않는다. 테스트 호스트 시작·testcase 실행/통과 증거는 없다.
- 표준 실행기: 로그 무갱신 300초로 exit 124. 정상 결과 receipt 없음. 실행 수 unknown, 통과 증거 0건. 마지막 로그는 `BUILD INTERRUPTED`. 컴파일 진행을 UI 테스트 통과로 보고하지 않는다.
- 실행기는 소유 process group 정리 중 EPERM을 기록했다. 직후 이번 xcodebuild PID 37268의 부재를 확인했다. 다른 작업 PID나 기기는 조작하지 않았다.
- iPad·Duo는 선행 iPhone 환경 단계가 실패해 시작하지 않았다. A01 네 기기 상태의 새 실제 캡처와 최대 글씨 검증은 미완료다.
- 다음 실행 조건: Xcode/Simulator가 이 소유 기기에서 테스트 호스트를 정상 시작한다는 근거 또는 해당 환경 의존성의 수정·복구를 먼저 확인한다. 원인 변화 없이 같은 실행을 반복하지 않는다.
- Open 코드 P1/P2/P3 없음. 추가 테스트의 P2 test-001은 stable row ID·의미 레이블 검증으로 Resolved. 필수 UI 증거가 없어 PR 생성·push·merge·시뮬레이터/worktree 정리는 미수행이다.
