---
tags: [ship, simulator, cleanup, codex, worktree]
date: 2026-09-27
category: solution
status: implemented
---

# Ship 완료 시 작업용 시뮬레이터 정리

## Problem

테스트 helper는 worktree용 simulator를 생성하고 재사용하지만 Ship에는 삭제 절차가 없었다. 이름은 worktree basename을 사용하므로 Codex의 서로 다른 `Health` 경로가 충돌할 수 있다.

## Solution

`.codex/skill-compat.md`의 `/ship` 절차에 원격 머지 성공 직후, checkout/worktree 제거 전 정리를 추가했다. 생성 전 UDID 목록과 생성 성공 기록을 대조하여 해당 worktree/branch 작업에서 새로 생성하고 사용한 전용 기기만 종료·삭제한다. 기존 기기는 사용·재사용했더라도 제외한다. 원본 fallback, 공유 기기, 신규 생성 여부나 소유가 불명확한 기기도 보존한다. 삭제 후 목록으로 결과를 검증하고 실패 및 보존 사유를 보고한다.

`.claude` 원문은 유지한다. 이 변경은 Codex 실행 절차에 적용되며 독립적으로 실행되는 자동 hook은 아니다.

## Prevention

- 생성 전 UDID 목록과 새 기기의 UDID, 이름, worktree 절대 경로, branch, 생성 성공 기록을 남긴다.
- basename이나 사용 사실만으로 독점 소유를 추정하지 않는다.
- 머지 실패 시 simulator를 유지한다.
- 정리 실패를 숨기거나 전체 simulator 삭제로 우회하지 않는다.
