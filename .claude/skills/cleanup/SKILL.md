---
name: cleanup
description: "머지 완료된 워크트리와 로컬 브랜치를 일괄 정리합니다."
---

# Cleanup: 머지된 워크트리/브랜치 일괄 정리

머지 완료된 git worktree와 로컬 브랜치를 탐색하고 정리합니다.

## Process

### Step 1: 현재 상태 스캔

1. **워크트리 목록 조회**: `git worktree list`로 모든 worktree를 나열
2. **로컬 브랜치 목록 조회**: `git branch`로 모든 로컬 브랜치 나열
3. **main 최신화**: `git fetch origin main` (remote 상태 동기화)

### Step 2: 머지 여부 판정

각 브랜치/워크트리에 대해 머지 여부를 판정합니다.

**판정 기준** (하나라도 충족하면 "머지됨"):
1. `git branch --merged main`에 포함
2. `gh pr list --state merged --head {branch}` 결과가 존재
3. 브랜치 HEAD 커밋이 `git merge-base --is-ancestor {commit} main`으로 main에 포함

**보호 대상** (절대 삭제 안 함):
- `main` 브랜치
- 현재 체크아웃된 브랜치 (`HEAD`)
- 현재 세션의 워크트리

### Step 3: 정리 대상 표시 및 승인

정리 대상을 테이블로 표시합니다:

```
| 유형 | 브랜치 | 경로 | PR | 상태 |
|------|--------|------|----|------|
| worktree | claude/xxx | .claude/worktrees/xxx | #42 MERGED | 삭제 예정 |
| branch | feature/yyy | (local only) | #55 MERGED | 삭제 예정 |
```

**AskUserQuestion으로 사용자 승인을 받은 후에만 삭제를 진행합니다.**

### Step 4: 정리 실행

승인된 대상에 대해 순서대로 실행합니다.

#### 4a: 워크트리 정리

메인 repo 경로에서 실행합니다:

```bash
# 1. 워크트리 제거
git worktree remove {worktree_path}
# force가 필요한 경우 (clean 상태가 아닐 때)
git worktree remove {worktree_path} --force

# 2. 로컬 브랜치 삭제
git branch -D {branch_name}
```

#### 4b: 로컬 브랜치 정리

```bash
# 머지된 로컬 브랜치 삭제
git branch -d {branch_name}
```

#### 4c: 리모트 브랜치 정리 (선택)

리모트에 아직 남아있는 머지 완료 브랜치가 있으면 보고합니다.
`git push origin --delete`는 사용자가 명시적으로 요청한 경우에만 실행합니다.

### Step 5: 결과 보고

```
정리 완료:
- 워크트리 삭제: N개
- 로컬 브랜치 삭제: N개
- 남은 워크트리: N개
- 남은 로컬 브랜치: N개
```

## 주의사항

- **현재 세션 워크트리는 삭제하지 않음** — 자기 자신을 삭제하면 세션이 깨짐
- 머지 여부가 불확실한 브랜치는 "보류"로 표시하고 사용자에게 판단을 맡김
- `git worktree remove`가 실패하면 `--force` 옵션으로 재시도
- 모든 삭제는 메인 repo 경로에서 실행 (워크트리 내부에서 실행 금지)
- 삭제 전 `git worktree prune`으로 stale 참조 먼저 정리
