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

### Step 2: 워크트리 활성 세션 감지

**워크트리는 기본적으로 삭제 대상에서 제외합니다.** 다른 Claude 세션이 사용 중일 수 있기 때문입니다.

워크트리 삭제 조건 (**모두 충족해야 삭제 가능**):
1. 머지된 PR이 존재 (`gh pr list --state merged --head {branch}`)
2. main 대비 diff가 없음 (`git diff main...{branch}` 결과 비어있음)
3. lock 파일이 없음 (`.claude/worktrees/{name}/.git`의 lock 없음)

조건을 충족하지 않는 워크트리는 "보호됨"으로 표시하고 절대 삭제하지 않습니다.

### Step 3: 머지 여부 판정 (로컬 브랜치)

워크트리가 아닌 로컬 브랜치에 대해 머지 여부를 판정합니다.

**삭제 가능 기준** (하나라도 충족):
1. `gh pr list --state merged --head {branch}` 결과가 존재 (PR 머지 확인)

**삭제 불가**:
- PR이 없는 브랜치 → main과 커밋이 같더라도 "보류"로 표시
- PR이 있지만 open/closed(not merged) 상태 → "보류"로 표시

**보호 대상** (절대 삭제 안 함):
- `main` 브랜치
- 현재 체크아웃된 브랜치 (`HEAD`)
- 워크트리에 연결된 브랜치 (Step 2에서 별도 처리)

### Step 4: 정리 대상 표시 및 승인

정리 대상을 **카테고리별로 분리하여** 표시합니다:

```
## 삭제 안전 (PR 머지 완료)
| 유형 | 브랜치 | PR | 커밋 차이 |
|------|--------|----|----------|
| branch | claude/xxx | #42 MERGED | 0 files |

## 보호됨 (워크트리 — 다른 세션 사용 가능)
| 브랜치 | 경로 | 사유 |
|--------|------|------|
| claude/yyy | .claude/worktrees/yyy | 활성 워크트리 |

## 보류 (PR 없음 — 수동 확인 필요)
| 브랜치 | main과 차이 | 사유 |
|--------|------------|------|
| claude/zzz | 0 commits | PR 없음 |
```

**AskUserQuestion으로 "삭제 안전" 목록의 승인을 받은 후에만 삭제를 진행합니다.**
보호됨/보류 항목은 사용자가 명시적으로 개별 지정해야만 삭제합니다.

### Step 5: 정리 실행

승인된 대상에 대해 순서대로 실행합니다.

#### 5a: 워크트리 정리 (승인된 경우만)

메인 repo 경로에서 실행합니다:

```bash
# 1. 워크트리 제거
git worktree remove {worktree_path}
# force가 필요한 경우 (clean 상태가 아닐 때)
git worktree remove {worktree_path} --force

# 2. 로컬 브랜치 삭제
git branch -D {branch_name}
```

#### 5b: 로컬 브랜치 정리

```bash
# 머지된 로컬 브랜치 삭제
git branch -d {branch_name}
```

#### 5c: 리모트 브랜치 정리 (선택)

리모트에 아직 남아있는 머지 완료 브랜치가 있으면 보고합니다.
`git push origin --delete`는 사용자가 명시적으로 요청한 경우에만 실행합니다.

### Step 6: 결과 보고

```
정리 완료:
- 삭제: 로컬 브랜치 N개, 워크트리 N개
- 보호됨 (워크트리): N개
- 보류 (PR 없음): N개
```

## 핵심 원칙

1. **워크트리는 기본 보호**: 다른 세션이 사용 중일 수 있으므로 워크트리는 기본적으로 삭제하지 않음. 머지된 PR이 있고 diff가 없을 때만 삭제 후보에 포함
2. **PR 머지 확인만 신뢰**: `git branch --merged`나 커밋 일치만으로 삭제 판정하지 않음. `gh pr list --state merged`로 확인된 것만 삭제 안전
3. **PR 없는 브랜치는 보류**: main과 커밋이 같더라도 작업 준비 중일 수 있으므로 자동 삭제 금지
4. **카테고리 분리 표시**: 삭제 안전 / 보호됨 / 보류를 명확히 구분하여 사용자가 판단할 수 있게 함
5. **`--force` 신중 사용**: clean 상태가 아닌 워크트리에 `--force`는 사용자가 명시적으로 요청한 경우에만

## 주의사항

- 모든 삭제는 메인 repo 경로에서 실행 (워크트리 내부에서 실행 금지)
- 삭제 전 `git worktree prune`으로 stale 참조 먼저 정리
- 머지 여부가 불확실한 브랜치는 "보류"로 표시하고 사용자에게 판단을 맡김
