---
tags: [git, hooks, reference-transaction, worktree, cleanup, github, deriveddata]
category: general
date: 2026-10-31
status: implemented
severity: important
related_files:
  - scripts/cleanup-merged-worktrees.py
  - scripts/tests/test_cleanup_merged_worktrees.py
  - .codex/skill-compat.md
  - AGENTS.md
related_solutions:
  - 2026-10-30-worktree-external-deriveddata-cleanup
---

# Solution: 머지 관측 후 브랜치·워크트리 자동 정리

## Problem

PR 머지 이후 로컬 브랜치가 남았다. 별칭 `live-activity-icons-finish`는 PR #864의 최종 head를 가리키고 있었지만 PR 브랜치 이름이 달라 이름 기반 조회에서 누락됐다. 기존 `/ship`·`/cleanup` 절차는 실행 지침이어서 Git 이벤트에 자동 연결되지 않았다.

## Solution

`scripts/cleanup-merged-worktrees.py`는 기본 dry run, `--apply` 실행, `--install` 설치를 제공한다. 기존 hook과 custom hooksPath는 보존하며 충돌 시 설치를 거부한다. 기존 pre-commit은 바꾸지 않는다.

```bash
python3 scripts/cleanup-merged-worktrees.py --install
python3 scripts/cleanup-merged-worktrees.py          # 삭제 없는 조회
python3 scripts/cleanup-merged-worktrees.py --apply  # 보호 조건 재검사 후 정리
git config dune.autoCleanupMerged false            # 자동 실행 중지
```

Git의 [reference-transaction hook](https://git-scm.com/docs/githooks#_reference_transaction)은 ref 갱신을 관측한다. GitHub 원격 머지 순간에 로컬 hook이 실행되지는 않는다. 다음 fetch/pull로 main 또는 origin/main ref가 실제 갱신된 committed transaction에서 정리한다. 갱신이 없는 fetch는 실행 계기가 아니다.

| 단계 | 조건·동작 |
|------|-----------|
| 후보 | origin/main에 포함된 로컬 브랜치 tip |
| PR 증거 | 동일 저장소 main으로 merged된 commit-associated PR, 로컬 tip이 PR head의 조상, PR merge가 origin/main의 조상 |
| 보호 | primary·호출 checkout, missing/locked/prunable/symlink, dirty/untracked, 소유 registry 외 ignored 파일, active process·열린 파일·조회 실패 |
| 실행 잠금 | 기존 worktree·repository runner lock을 대기 없이 확보 |
| 소유 리소스 | 기존 도구로 simulator와 외부 DerivedData 소유를 확인하고 정리 |
| 삭제 | 최신 상태 재검사 → force 없는 worktree remove → expected-OID ref 삭제 |

브랜치 이름이 달라도 PR 커밋 증거가 있으면 정리하며 tracking config도 제거한다. PR 없는 커밋이나 squash/rebase로 조상 관계를 입증할 수 없는 변경은 보존한다. ignored 파일 중 허용하는 것은 소유권 도구가 검증할 `.codex-checks/worktree-simulators.json`과 그 lock 두 경로뿐이다. 개인 설정·미확인 빌드 산출물·증거 파일이 남아 있으면 자동 제거하지 않는다. detached checkout은 자동 정리 대상이 아니다. 현재 작업 checkout은 `/ship`의 기존 linked-worktree 정리 절차가 담당한다.

외부 캐시의 기본 부모는 기존과 같이 `~/Library/Developer/Xcode/DerivedData`다. 다른 부모를 지정하려면 `git config --add dune.cleanupDerivedDataRoot /absolute/cache-parent`를 사용한다. 이 설정은 기본 위치를 대체하므로 필요하면 기본 경로도 함께 등록한다. 이름 패턴·디스크 전체 탐색을 하지 않는다.

hook 실행 사본은 공용 Git 디렉터리의 `dune-merge-cleanup/<content-hash>/`에 보관한다. 개발 worktree 제거·checkout 변경 후에도 남으며, 구현 변경 후 `--install`로 갱신한다. 로그는 공용 Git 디렉터리의 `dune-merge-cleanup.log`다. 재귀·중복 실행을 막고 실패를 Git ref 갱신의 실패로 전파하지 않는다. 원격 브랜치는 삭제하지 않는다.

linked-worktree `/ship`이 primary main을 갱신할 때는 `DUNE_AUTO_CLEANUP_RUNNING=1 git pull --ff-only`를 해당 명령에만 적용한다. 그래야 hook이 현재 작업 checkout을 먼저 지우지 않고, Ship이 simulator·캐시 검증과 worktree 제거를 정해진 순서로 끝낸다. 이후 일반 fetch/pull의 자동 실행은 계속 활성 상태다.

## Verification

- 신규 정리 계약 15개 및 기존 외부 DerivedData 소유권 검사 17개, 총 32개 통과. ignored 파일·열린 파일 보호 보완 후에는 신규 15개 계약을 다시 실행했다.
- 임시 Git 저장소에서 실제 설치된 reference-transaction hook과 가짜 GitHub 응답으로 merged alias·원래 브랜치 삭제를 검증했다.
- 실제 worktree와 임시 캐시를 이용해 소유 캐시만 제거하고 primary 캐시는 보존하는 통합 검사를 통과했다.
- 미커밋/신규 파일, 현재 checkout, worktree/runner lock, active process/조회 실패, PR 없는 상태, 추가 커밋, 정리 중 ref 변경과 캐시 오류 보존을 검사했다.
- 앱 코드·UI 변경이 없어 앱 빌드·시뮬레이터 실행·디자인맵 캡처는 하지 않았다.

## Prevention

- PR 이름만으로 삭제 여부를 결정하지 않고 실제 커밋과 merge 이력을 대조한다.
- 보호·오류를 해소한 뒤 직접 `--apply`하거나 후속 main 갱신에서 다시 검사한다.
- 잠금·네트워크·소유권 실패는 강제 삭제로 우회하지 않는다. 캐시 도구의 `Recovery required` 경로도 보존한다.
- hook 변경 시 성공 경로뿐 아니라 파일·커밋 손실을 막는 보존 경로와 실제 Git 이벤트를 함께 검증한다.

## Lessons Learned

원격 PR 머지, 로컬 ref 갱신, 작업 디렉터리 삭제는 각각 다른 사건이다. ref 이벤트에 정리를 연결하되 PR 증거와 로컬 상태를 매번 확인해야 작업 중인 내용까지 삭제하지 않는다.
