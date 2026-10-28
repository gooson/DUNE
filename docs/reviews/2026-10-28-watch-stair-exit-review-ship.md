---
tags: [review, watchos, stair-climber, ux-writing]
date: 2026-10-28
category: solution
status: reviewed
---

# Code Review Report · 계단 이탈 안내와 UX Writing

> Scope: 계단 운동 GPS·보행 기반 종료 제안, 간결한 다국어 알림, C10/C19 실제 캡처, Codex UX Writing 규칙.
> Base: origin/main `c10cf77c276d9c9317c652988ba6adaca4dcc865`. 시작 HEAD도 같은 커밋의 detached 상태였으며 feature branch `codex/watch-stair-exit-reminder`를 생성했다. committed delta는 없고 staged/unstaged 및 관련 untracked 전체 26개 파일을 리뷰했다. 대화 초기에 있었던 wellness 변경은 이미 main에 머지돼 이번 scope에 없다.

## Summary

| Priority | Count | Status |
|---|---|---|
| P1 | 0 | 없음 |
| P2 | 1 | Resolved |
| P3 | 2 | Resolved |

## P1 Findings

없음.

## P2 Findings

### [arch-001 · Architecture / Simplicity] 계속 운동 선택이 세션 복구 후 유실

- File: `DUNEWatch/Managers/WorkoutManager.swift:1518`
- Category: architecture / state
- Issue: 선택은 메모리에만 있고 복구 시 모니터 시작이 값을 false로 초기화한다. 같은 HK 세션에서 재안내할 수 있다.
- Suggestion: optional 복구 필드로 저장·복원하고 새 운동에서만 초기화한다. 구버전 snapshot 호환 테스트를 포함한다.
- Status: Resolved. optional Bool의 즉시 저장·복원, legacy nil→false, 새 세션 초기화와 회귀 테스트 3개를 확인했다. Architecture delta 재검토에서 기존 P2 해결·추가 blocker 없음.

## P3 Findings

- **style-001 · Resolved:** 새 `StairMachineExitDetectorTests.swift:16`와 `:42`의 trailing whitespace 제거. untracked 파일은 git diff 기본 검사에서 빠진다.
- **docs-001 · Resolved:** `docs/plans/2026-10-28-watch-stair-exit-reminder.md`에 Affected Files 표를 추가한다.

## Review coverage

Security·Performance·Architecture·Data Integrity·Simplicity·Agent-Native를 각각 `gpt-6-sol / medium` 서브에이전트로 읽기 전용 검토했다. Security·Performance·Data·Agent-Native의 발견사항은 없다. Architecture와 Simplicity의 동일 복구 문제는 한 건으로 통합했다.

권한 콜백마다 후보 초기화라는 추가 제안은 독립된 결함으로 채택하지 않았다. 같은 authorized 상태라도 정밀도 변경·권한 공백 후 기준을 새로 잡아야 하고, 진행 중 관찰을 반복적으로 방해한다는 재현 근거가 없다.

## UI / localization · Parent 검토

- SwiftUI: 새 알림은 독립적인 binding을 쓰고, 계단 일반 정지 정책은 none을 유지하므로 두 알림을 동시에 활성화하지 않는다. 알림 자체가 pause/end를 호출하지 않는다. haptic은 manager에서 한 번 실행한다.
- Apple UX: Purpose·Agency·Responsibility·Familiarity·Simplicity·Craft 적합. Flexibility는 확인한 한국어 40mm 기본 글씨 범위에서 적합하며 다른 크기·언어·큰 글씨는 미검증. Delight는 판단 알림이라 별도 장식 적용 대상이 아니다.
- UI testing: C10 무알림·C19 유지·계속 운동·명시적 종료의 기존 3개 결과와 최종 문구의 추가 1개 결과를 구분했다. 해당 선택 범위만 통과 증거이며 full suite 증거가 아니다.
- [L10N] 새 제목·본문은 LocalizedStringKey이며 en/ko/ja 등록을 확인했다. 기존 Keep Running/End Workout은 영어 키 fallback과 ko/ja 번역을 재사용한다. 새 시스템 권한 문구는 InfoPlist.xcstrings에서 3개 언어로 빌드됨을 확인했다. helper String 누출·새 rawValue 렌더·새 미번역 String 할당은 없다.
- 실제 C10/C19 원본을 이전 턴에서 직접 확인했고 C19 최종 본문은 ‘이동이 감지됐어요.’다. 다른 화면·기기를 검증했다고 보고하지 않는다.

## Verification / next steps

Review 이후 Resolve에서 위 세 항목을 처리하고 변경된 복구 경로만 회귀 검증한다. 앱 UI 문구/알림 동작을 바꾸지 않으면 유효한 기존 관련 UI 결과를 재사용한다. parity·카탈로그·프로젝트 생성물·diff·최종 PR 리뷰를 확인한 뒤 원격 PR 머지와 소유 시뮬레이터/빌드 정리를 수행한다.

실제 GPS/HealthKit 수집·손목을 내린 진동·배터리 소비는 시뮬레이터로 검증할 수 없어 실기기 확인 항목으로 남긴다.


## Resolve · 최종 검증

- 관련 Watch 단위 34개/6개 suite 통과. [보존 receipt](2026-10-28-watch-stair-exit/watch-unit-receipt.json)와 [검증한 소스 SHA](2026-10-28-watch-stair-exit/verified-source-sha256.json) 참조. 표준 잠금·deadline과 repo regen helper를 사용해 지정 suite만 실행했다. 실행기는 XCTest 호스트의 0건을 출력했지만 Swift Testing 최종 34건과 6개 suite의 passed 로그를 확인했다.
- [최초 관련 Watch UI 3개](2026-10-28-watch-stair-exit/stair-gps-exit-ui-receipt.json), [최종 문구 UI 1개](2026-10-28-watch-stair-exit/stair-exit-copy-ui-receipt.json) 모두 정상 종료·누락 없음. 이후 Resolve는 저장/복구 Bool과 테스트·문서만 바꿨으며 View·문구·레이아웃·감지 임계값은 동일해 이 범위의 UI 증거를 재사용한다. 전체 UI/다른 기기 검증으로 확대하지 않는다.
- localization의 새 UI 키 en/ko/ja, 재사용 버튼의 영어 source fallback·ko/ja, InfoPlist 3개 언어와 제거 키를 확인했다. 처음 수집 스크립트가 기존 버튼의 명시적 en entry까지 요구해 assertion을 냈으나, 해당 기존 키는 원문 fallback이므로 앱 결함이 아니다. 검사 조건을 맞춰 확인했고 관련 없는 번역은 수정하지 않았다.
- parity, xcstrings 포맷, Info.plist, git diff 및 새 untracked 테스트의 trailing whitespace 검사를 통과했다. `.claude/**` 변경은 없다.
- disposition: arch-001/style-001/docs-001 모두 Resolved. Open P1/P2/P3 = 0/0/0.

## Final PR Review

`gpt-6-sol / medium` pr-reviewer가 최종 snapshot, 기존 finding disposition, 소스·결과 해시와 변경된 복구 경로를 읽기 전용 검토해 승인했다. 새 P1/P2는 없다. 최종 리뷰 후 앱·테스트 소스는 동일하다. 커밋 훅의 secret/format 검사는 유지하며, 이미 통과한 최종 Watch 빌드에는 지원되는 `DAILVE_SKIP_PRECOMMIT_BUILD=1` 옵션을 사용해 중복 iOS 전체 빌드를 생략한다.

## Ship handoff

사용자는 review-ship으로 PR 생성·merge를 명시적으로 요청했다. 최종 PR 리뷰, reviewed scope와 원격 base 확인 후 원격 머지를 진행한다. main은 다른 worktree에서 사용 중이므로 머지 확인 후 이 checkout을 merged origin/main에 detach하고 feature branch를 삭제한다. 다른 worktree를 조작하지 않는다. 소유 simulator와 이 checkout의 build artifacts만 정리한다.
