---
tags: [xcode, deriveddata, cleanup, worktree, ownership, codex]
date: 2026-10-30
category: solution
status: implemented
severity: important
related_files:
  - scripts/cleanup-worktree-deriveddata.py
  - scripts/tests/test_cleanup_worktree_deriveddata.py
  - .codex/skill-compat.md
  - AGENTS.md
related_solutions:
  - docs/solutions/general/2026-09-27-ship-simulator-cleanup.md
---

# 워크트리 소유 외부 DerivedData 정리

## Problem

워크트리를 제거하면 내부 `.deriveddata`는 함께 없어지지만 Xcode 기본 경로인
`~/Library/Developer/Xcode/DerivedData`의 캐시는 남았다. 기존 아티팩트 정리
스크립트도 저장소 내부만 처리했다. 여러 worktree의 프로젝트 이름이 같으므로
캐시 디렉터리 이름으로 삭제 대상을 고르면 다른 작업의 캐시를 지울 수 있다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `scripts/cleanup-worktree-deriveddata.py` | 기본 dry run, 명시적 `--apply`, 메타데이터 소유 판정 | 해당 worktree 캐시만 삭제 |
| `scripts/tests/test_cleanup_worktree_deriveddata.py` | 임시 저장소·캐시 기반 17개 회귀 테스트 | 잘못된 소유자 삭제와 삭제 중 경로 교체 방지 |
| `.codex/skill-compat.md` | `/cleanup`·`/ship`의 worktree 제거 전 정리 절차 | 원본 skill을 유지하면서 Codex 실행에 연결 |
| `AGENTS.md` | 외부 캐시 정리 규칙 참조 | 향후 실행에서 누락 방지 |

캐시 직속 `info.plist`의 절대 `WorkspacePath`를 정규화하고 대상 linked worktree
내부의 Xcode 프로젝트인지 확인한다. primary checkout을 대상으로 받지 않으며,
다른 worktree·main·공용 캐시·누락/손상된 메타데이터·symlink·중첩 checkout은
보존한다. 프로젝트 파일이 재생성 과정에서 사라졌더라도 기존 worktree 루트와
메타데이터로 소유를 확인할 수 있다.

삭제 전 소유 경로와 device/inode를 다시 확인한다. 같은 부모 아래의 private 임시
디렉터리로 캐시를 원자적으로 옮긴 뒤 다시 확인하고 재귀 삭제하므로, 원래 경로에
새로 생성된 캐시는 보존한다. 이동 후 실패하면 잔여 데이터를 보존하고
`Recovery required`에 보존 경로와 원래 경로를 출력한다. 이 복구 경로는 다음
실행에서 자동으로 삭제하지 않는다.

### Usage

```bash
# 기본은 삭제 없는 조회다. 대상은 아직 존재하는 linked worktree 루트다.
python3 scripts/cleanup-worktree-deriveddata.py --worktree /absolute/worktree

# 삭제는 대상 worktree의 테스트 잠금 아래에서 실행한다.
DUNE_SIM_TEST_LOCK_WAIT_SECONDS=0 python3 scripts/lib/simulator-test-lock.py /absolute/worktree -- python3 scripts/cleanup-worktree-deriveddata.py --worktree /absolute/worktree --apply
```

`--derived-data-root`는 외부 캐시 부모 경로를 반복 지정하며 기본 탐색 경로를
대체한다. 기본 경로도 필요하면 함께 지정한다. 여러 worktree가 공유하는 것으로
알려진 사용자 지정 경로는 정리 대상으로 전달하지 않는다. 메타데이터가 없는
외부 캐시의 소유권은 추정하지 않는다. 명시한 부모 경로가 없거나, 두 부모 경로가
서로 포함 관계면 모든 삭제를 중단한다. 기본 캐시 위치가 없는 경우만 정상 no-op이다.

Codex `/cleanup`은 삭제가 승인된 worktree에만 적용한다. `/ship`은 linked worktree를
제거하는 경우에 적용하며 primary checkout의 브랜치 정리에서는 건너뛴다. 원격 머지
성공 후 깨끗한 main checkout을 먼저 fast-forward하고, 대상 worktree의 clean 상태와
머지 커밋 포함 여부를 확인한다. 이어서 simulator·외부 캐시를 정리하고 main checkout에서
worktree와 브랜치를 제거한다. linked worktree 안에서 `git checkout main`을 실행하지 않는다.
Xcode 빌드가 실행 중이지 않은지 확인하고 **worktree 제거 전** 캐시를 정리한다.
스캔·잠금·삭제 실패 시 해당 worktree를 보존하고 미완료로 보고한다.
수동 `git worktree remove`나 Codex 앱 자체 삭제에 등록된 자동 hook은 아니다.
`.claude/**`와 pre-commit 동작은 유지한다.

캐시 삭제 후 빈 임시 디렉터리 정리만 실패하면 삭제 건수는 유지하면서 남은 디렉터리와
실패를 별도로 보고한다. 격리된 잔여 캐시의 복구 실패와 구분한다.

### Validation

- `python3 -B -m unittest scripts.tests.test_cleanup_worktree_deriveddata -v`: 17개 통과.
- 소유자 구분, primary checkout 거부, symlink·손상된 plist 보존, 사용자 지정 부모,
  디렉터리 교체, 삭제 실패와 복구 경로, 중첩/누락된 명시 경로, 삭제 건수를 검증했다.
- 실제 기본 DerivedData 경로에는 dry run만 실행했다. 대상 worktree 소유 후보는
  0개였고 main·다른 앱·공용 캐시는 모두 보존했다. 실제 외부 캐시는 삭제하지 않았다.

## Prevention

- 폴더 이름이나 prefix 대신 정규화된 `WorkspacePath`로 소유자를 확인한다.
- worktree가 사라지기 전에 캐시를 조회·정리한다.
- 삭제 전후의 identity를 확인하고 실패 시 복구 경로를 보고한다.
- 메타데이터가 없거나 공유 여부가 불명확하면 보존한다.

## Lessons Learned

저장소 외부 캐시는 Git worktree 제거만으로 정리되지 않는다. 소유권 판정뿐 아니라
삭제 중 같은 경로가 재생성되는 경우도 고려해야 다른 작업의 캐시를 보호할 수 있다.
