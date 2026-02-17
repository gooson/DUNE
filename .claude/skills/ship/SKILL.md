---
name: ship
description: "현재 브랜치를 PR 생성 → GitHub 머지 → 브랜치 삭제까지 자동 수행합니다."
---

# Ship: PR 생성 → 머지 → 브랜치 삭제

현재 feature 브랜치를 GitHub PR을 통해 main에 머지하고 정리합니다.

## Process

### Step 1: 사전 검증

1. **브랜치 확인**: 현재 브랜치가 main이 아닌지 확인
   - main이면 중단하고 안내
2. **Uncommitted 변경 확인**: `git status`로 커밋되지 않은 변경 확인
   - 변경사항이 있으면 AskUserQuestion 도구로 사용자에게 선택지를 제시:
     - "커밋 후 진행" — 변경사항을 커밋하고 ship 계속
     - "Stash 후 진행" — 변경사항을 stash하고 ship 계속
     - "중단" — ship을 중단하고 사용자가 직접 처리
   - 사용자 선택에 따라 처리 후 다음 단계로 진행
3. **리모트 동기화**: 현재 브랜치가 리모트에 push되었는지 확인
   - 안 되어 있으면 `git push -u origin {branch}` 실행

### Step 2: PR 생성

1. **기존 PR 확인**: `gh pr view` 로 이미 열린 PR이 있는지 확인
   - 있으면 해당 PR을 사용
2. **PR이 없으면 생성**:
   - `git log main..HEAD --oneline` 으로 커밋 목록 확인
   - `git diff main...HEAD --stat` 으로 변경 파일 확인
   - 커밋 메시지와 변경 내용을 분석하여 PR 제목과 본문 작성
   - `gh pr create --base main --title "..." --body "..."` 로 PR 생성
3. **PR URL을 사용자에게 표시**

### Step 3: PR 머지

GitHub의 PR 머지 API를 통해 머지합니다. **로컬 머지나 자체 스쿼시를 수행하지 않습니다.**

1. `gh pr merge {PR_NUMBER} --merge --delete-branch` 실행
   - **기본 전략은 `--merge`** (커밋 이력 보존). squash 사용 금지
   - 사용자가 명시적으로 다른 전략을 요청한 경우에만 `--rebase` 또는 `--squash` 사용
2. 머지 완료 확인

### Step 4: 로컬 정리

1. **워크트리 감지**: 현재 디렉토리가 git worktree인지 확인
   - `git rev-parse --git-common-dir`과 `git rev-parse --git-dir` 비교
   - 워크트리인 경우 → Step 4a (워크트리 정리)
   - 일반 브랜치인 경우 → Step 4b (일반 정리)

#### Step 4a: 워크트리 정리

워크트리에서 ship한 경우:
1. **리모트 브랜치 삭제**: `gh pr merge`에서 `--delete-branch`로 이미 삭제됨. 안 됐으면 `git push origin --delete {branch}`
2. **메인 repo에서 워크트리 제거**: `git -C {main_repo_path} worktree remove {worktree_path} --force`
   - main repo 경로는 `git rev-parse --git-common-dir`에서 추출
3. **로컬 브랜치 삭제**: `git -C {main_repo_path} branch -D {branch}`
4. 사용자에게 "워크트리 + 브랜치 정리 완료" 안내

#### Step 4b: 일반 브랜치 정리

일반 브랜치에서 ship한 경우:
1. `git checkout main` 으로 main 브랜치로 전환
2. `git pull` 으로 머지된 내용을 로컬에 반영
3. 로컬 feature 브랜치 삭제: `git branch -d {branch}`
4. **환경 파일 동기화**: `.claude/settings.local.json` 변경이 있으면 함께 커밋+push
   - `git diff --name-only`로 변경 확인
   - 변경이 있으면 `git add .claude/settings.local.json && git commit -m "chore: sync Claude local settings" && git push`
5. 최종 상태를 사용자에게 표시

## 주의사항

- **절대 로컬에서 직접 머지하지 않습니다** — 반드시 `gh pr merge`를 통해 GitHub API로 머지
- PR 생성 시 `--base main` 명시
- 머지 실패 시 (충돌, CI 실패 등) 사용자에게 안내하고 중단
- `--delete-branch` 로 리모트 브랜치 자동 삭제
