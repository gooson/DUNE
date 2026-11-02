---
tags: [git, hooks, worktree, cleanup]
topic: 자동 머지 정리 훅
date: 2026-10-31
category: plan
status: implemented
confidence: high
related_solutions: [2026-10-30-worktree-external-deriveddata-cleanup]
---

# Implementation Plan: 자동 머지 정리 훅

## Context

PR 머지와 로컬 정리는 별개여서 머지된 브랜치가 남았다. 사용자가 머지 후 자동 정리를 요청했다.

## Requirements / Approach

- `reference-transaction`의 committed main/origin-main 갱신 때 실행한다. 원격 머지는 다음 fetch/pull에서 관측한다.
- main에 포함된 커밋만 후보로 삼고 GitHub의 merged PR head/merge commit으로 다시 검증한다. 브랜치 이름이 다른 alias도 지원한다.
- primary, 호출 worktree, 잠금, dirty/untracked, 소유 registry 외 ignored 파일, 실행 중인 프로세스·열린 파일, 미머지 추가 커밋은 보존한다. force 삭제하지 않는다.
- worktree 소유 simulator와 외부 DerivedData를 기존 소유권 도구로 먼저 정리한다. 실패하면 worktree를 보존한다.
- 기존 hook은 덮어쓰지 않고, 공용 Git 디렉터리에 실행 도구 사본을 설치해 구현 worktree 제거 후에도 동작시킨다.
- 훅 실패는 Git ref 갱신을 실패로 바꾸지 않는다. 중복/재귀 실행을 막는다.

## Affected Files

| File | Description |
|------|-------------|
| `scripts/cleanup-merged-worktrees.py` | 조회·정리·설치·hook 진입점 |
| `scripts/tests/test_cleanup_merged_worktrees.py` | 임시 Git 저장소와 mock GitHub를 이용한 계약 검사 |
| `.codex/skill-compat.md`, `AGENTS.md` | 사용자 요청에 따른 자동 정리 예외와 설치/보호 기준 |
| `docs/solutions/general/2026-10-31-auto-merged-worktree-cleanup.md` | 동작·운영·복구 근거 |

## Implementation Steps

1. 도구와 hook 설치기를 작성하고 브랜치/워크트리·캐시 정리 보호 검사를 구현한다.
2. 실제 임시 저장소에서 PR alias, 추가 커밋, dirty/lock/current 보호, hook event·재귀·설치 충돌을 검사한다.
3. 참조/parity/diff 검사를 수행하고 이 저장소의 공용 hook에 설치·활성화한다.

## Edge Cases / Risks

| Case | Handling |
|------|----------|
| GitHub 인증·조회 실패 | 삭제하지 않고 보존 이유 출력 |
| squash/rebase 또는 PR 없는 커밋 | 자동 정리 제외; 수동 확인 |
| 다른 작업이 ref/파일을 변경 | 삭제 직전 재검사와 expected-OID ref 삭제 |
| 실행 프로세스 조회 실패 | worktree 삭제 보류 |
| hook 충돌·사용자 hooksPath | 설치 거부; 기존 hook 보존 |
| 캐시/시뮬레이터 정리 실패 | worktree 보존, 기존 복구 기록 유지 |

## Testing Strategy

Python 계약 테스트와 실제 임시 Git hook 이벤트를 검증한다. 기존 DerivedData 소유권 테스트도 실행한다. 앱 코드·UI 변경이 없어 앱 빌드·시뮬레이터 테스트·디자인맵 캡처는 실행하지 않는다.
