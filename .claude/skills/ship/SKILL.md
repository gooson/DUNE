---
name: ship
description: "현재 브랜치를 PR 생성 → GitHub 머지 → 브랜치 삭제까지 자동 수행합니다."
---

# Ship: PR 생성 → 머지 → 브랜치 삭제

현재 feature 브랜치를 GitHub PR을 통해 main에 머지하고 정리합니다.

## Process

기본 동작은 **비대화형(non-interactive)** 입니다. 사용자가 명시적으로 요청하지 않는 한 중간 선택지를 질문하지 않습니다.

### Step 1: 사전 검증

1. **브랜치 확인**: 현재 브랜치가 main이 아닌지 확인
   - main이면 중단하고 안내
2. **Uncommitted 변경 확인**: `git status`로 커밋되지 않은 변경 확인
   - 변경사항이 있으면:
     - `git status --short`로 변경 파일 목록을 사용자에게 표시
     - `git diff --name-only`와 `git status --short`로 변경 파일을 확인하고, 현재 작업과 관련된 파일만 선별
     - `git add -- {files...}` 로 개별 파일 지정 (`git add -A` 사용 금지 — 의도하지 않은 파일 커밋 방지)
     - `git commit -m "chore: finalize before ship"`
     - 커밋 실패 시: `git stash push -u -m "ship-preflight-{timestamp}"`
   - 커밋과 stash가 모두 실패하면 즉시 중단하고 실패 원인 보��
3. **main 동기화 확인**: feature 브랜치가 main 대비 뒤처져 있는지 확인
   - `git fetch origin main && git merge-base --is-ancestor origin/main HEAD`
   - 뒤처져 있으면 `git merge origin/main` 수행
   - 충돌 발생 시 사용자에게 보고하고 중단
4. **리모트 동기화**: 현재 브랜치가 리모트에 push되었는지 확인
   - 안 되어 있으면 `git push -u origin {branch}` 실행
5. **리뷰 finding 재조정**: 이전 `/review` 결과가 있으면 현재 `main...HEAD` diff 기준으로 다시 맞춥니다
   - 기존 finding을 `Open`, `Resolved`, `Stale after fix`로 재분류
   - `Stale after fix`는 그대로 PR/ship 근거로 사용하지 않음
   - 미해결 `P1/P2`가 남아 있으면 ship 중단 후 사용자에게 보고
   - 수정 후 리뷰를 다시 안 돌렸다면 최소한 기존 P1/P2는 ship 전에 직접 재검증

### Step 2: PR 생성

1. **기존 PR 확인**: `gh pr view` 로 이미 열린 PR이 있는지 확인
   - 있으면 해당 PR을 사용
2. **PR이 없으면 생성**:
   - `git rev-list --count main..HEAD` 가 0이면 PR 생성 없이 종료 (머지할 변경 없음)
   - `git log main..HEAD --oneline` 으로 커밋 목록 확인
   - `git diff main...HEAD --stat` 으로 변경 파일 확인
   - 커밋 메시지와 변경 내용을 분석하여 PR 제목과 본문 작성
   - `gh pr create --base main --title "..." --body "..."` 로 PR 생성
3. **PR 생성 실패 시 복사용 출력**:
   - `gh pr create`가 실패하면 (네트워크, 권한, API 오류 등) 아래 형식으로 PR 제목과 본문을 출력하고 **Step 2에서 중단**:
   ```
   ━━━ PR 생성 실패 ━━━
   아래 내용을 복사하여 수동으로 PR을 생성하세요.

   **Title:**
   {PR 제목}

   **Body:**
   {PR 본문 전체}

   **수동 생성 명령:**
   gh pr create --base main --title "{PR 제목}" --body "$(cat <<'EOF'
   {PR 본문 전체}
   EOF
   )"
   ━━━━━━━━━━━━━━━━━━━━
   ```
   - 출력 후 사용자에게 수동 PR 생성 또는 재시도를 안내
4. **PR URL을 사용자에게 표시**

### Step 3: PR 머지

GitHub의 PR 머지 API를 통해 머지합니다. **로컬 머지나 자체 스쿼시를 수행하지 않습니다.**

1. `gh pr merge {PR_NUMBER} --merge --delete-branch` 실행
   - **기본 전략은 `--merge`** (커밋 이력 보존). squash 사용 금지
   - 사용자가 명시적으로 다른 전략을 요청한 경우에만 `--rebase` 또는 `--squash` 사용
   - checks pending이면 대기 후 재시도(최대 2회)
2. 머지 완료 확인

### Step 4: 로컬 정리

1. `git checkout main` 으로 main 브랜치로 전환
2. `git pull` 으로 머지된 내용을 로컬에 반영
3. 로컬 feature 브랜치 삭제: `git branch -d {branch}`
4. **환경 파일 동기화**: `.claude/settings.local.json` 변경이 있으면 함께 커밋+push
   - `git diff --name-only`로 변경 확인
   - 변경이 있으면 `git add .claude/settings.local.json && git commit -m "chore: sync Claude local settings" && git push`
5. 최종 상태를 사용자에게 표시

### Step 5: 빌드 아티팩트 정리

머지된 main 기준으로 깨끗한 상태를 만들기 위해 로컬 빌드 캐시를 제거합니다.

1. **`scripts/hooks/cleanup-artifacts.sh` 실행**
   - `.xcodebuild`, `DerivedData`, `.deriveddata` 등 빌드 아티팩트 일괄 삭제
   - 이전 feature 브랜치의 빌드 캐시가 main과 충돌하는 것을 방지
2. 삭제된 항목 수를 사용자에게 표시

### Step 6: 최종 xcodegen 실행

ship 완료 후, **머지 반영된 main 기준**으로 Xcode 프로젝트를 다시 생성합니다.
(Step 4에서 이미 main으로 전환 + pull 완료된 상태이므로 중복 수행하지 않음)

1. **xcodegen 실행**
   - `scripts/lib/regen-project.sh`
   - **주의**: `xcodegen generate` 직접 실행 금지 (후처리 누락 — build-pipeline.md 참조)
3. **결과 안내**
   - 성공 시 "ship + xcodegen 완료"를 사용자에게 보고
   - 실패 시 에러 로그를 함께 전달하고 중단

## Progress Markers

각 Step **시작 시** 아래 형식으로 시작 표시를 출력합니다:

```
━━━ Ship Step {N}: {Name} Start ━━━
```

각 Step **완료 시** 완료 표시를 출력합니다:

```
━━━ Ship Step {N}: {Name} Complete ━━━
```

시작 표시는 실제 작업 수행 **직전에** 반드시 출력합니다. 이를 통해 사용자가 추후 로그에서 각 Step의 시작점을 식별할 수 있습니다.

## 주의사항

- **절대 로컬에서 직접 머지하지 않습니다** — 반드시 `gh pr merge`를 통해 GitHub API로 머지
- PR 생성 시 `--base main` 명시
- 머지 실패 시 (충돌, CI 실패 등) 재시도 가능한 경우 먼저 재시도하고, 불가하면 로그와 함께 사용자에게 안내
- `--delete-branch` 로 리모트 브랜치 자동 삭제
- 최종 단계에서 반드시 merged 결과(main 최신) 기준으로 `xcodegen`을 실행
- **stale review finding을 정리하지 않은 상태로 ship하지 않습니다**
