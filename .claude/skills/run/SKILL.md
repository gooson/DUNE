---
name: run
description: "전체 파이프라인 자동 실행. Plan -> Work -> Review -> Resolve -> Compound -> Ship를 중간 절차 생략 없이 게이트 기반으로 수행합니다."
---

# Run: Full Pipeline Execution (Auto)

$ARGUMENTS 에 대해 전체 Compound Engineering 파이프라인을 **승인 없이** 자동 실행합니다.

## Non-Skip Contract

`/run`은 요약 실행이 아니라 **Phase별 강제 실행**입니다. 다음 규칙을 항상 지킵니다.

1. `/plan`, `/work`, `/review`, `/compound`, `/ship`의 `SKILL.md`를 **직접 열어 읽고**, 각 스킬의 필수 절차를 현재 실행에 반영합니다.
2. `"same as /plan"`처럼 상위 설명만 재진술하고 실제 리서치/검증/문서화를 생략하지 않습니다.
3. 각 Phase는 **완료 증빙**이 있어야만 종료할 수 있습니다.
4. `해당 없음` 처리는 허용되지만, **명시적 근거**를 남긴 경우에만 가능합니다.
5. 승인 대기 때문에 멈추지 않습니다. 저장소 설정상 허용된 도구는 바로 사용하고, 실제 런타임 차단이 발생하면 차단된 권한과 대체 조치를 즉시 보고합니다.

## Prohibited Shortcuts (금지된 생략 패턴)

다음 행동이 감지되면 해당 Phase는 미완료로 취급합니다. **어떤 경우에도 아래 패턴으로 Phase를 통과시키지 않습니다.**

| # | 금지 패턴 | 올바른 대안 |
|---|----------|------------|
| S1 | "Phase N은 이전과 동일하므로 생략" | 매 Phase를 독립적으로 전체 수행 |
| S2 | Sub-skill 절차를 "요약"하고 실제 도구 호출 생략 | SKILL.md의 각 Step을 도구 호출과 함께 실행 |
| S3 | build/test를 "통과할 것으로 예상" | `scripts/build-ios.sh` 또는 `xcodebuild test` 실제 실행 |
| S4 | 리뷰 에이전트 실행을 인라인 코멘트로 대체 | Agent tool로 리뷰어 서브에이전트를 실제 launch |
| S5 | docs/solutions/ 검색을 "관련 문서 없음"으로 선언 (검색 미수행) | Grep/Glob으로 실제 검색 후 결과 기록 |
| S6 | Compound 문서를 "학습 사항 없음"으로 생략 (분석 미수행) | git log/diff를 실제 실행하여 변경 분석 후 판단 |
| S7 | Phase 완료 게이트를 검증 명령 없이 통과 | 게이트의 Verification Command를 실행하여 결과 확인 |
| S8 | TodoWrite 없이 Phase 진행 | 매 Phase 시작/완료 시 TodoWrite 업데이트 |
| S9 | Plan 문서를 생성하지 않고 "계획 완료" 선언 | docs/plans/ 에 파일이 실제로 존재해야 통과 |
| S10 | git diff 없이 리뷰 수행 | diff를 실제로 수집한 후 리뷰 시작 |

## Phase Execution Protocol

모든 Phase는 다음 프로토콜을 따릅니다:

### 1. TodoWrite 필수

- Phase 0에서 **모든 Phase를 TodoWrite에 등록**합니다.
- 각 Phase 시작 시 해당 항목을 `in_progress`로 전환합니다.
- 각 Phase 완료 시 해당 항목을 `completed`로 전환합니다.
- TodoWrite 업데이트 없이 Phase를 시작하거나 종료하지 않습니다.

### 2. Start Marker 출력

Phase 시작 직전에 반드시:

```
━━━ Phase {N}: {Name} Start ━━━
```

### 3. 실제 작업 수행

- Sub-skill의 SKILL.md에 명시된 절차를 **도구 호출과 함께** 수행합니다.
- "~와 동일" 또는 "~를 요약하면"으로 대체하지 않습니다.

### 4. Verification Command 실행

- 각 Phase에 명시된 **검증 명령**을 실제로 실행합니다.
- 검증 명령의 출력을 확인하여 게이트 조건 충족 여부를 판단합니다.

### 5. Completion Marker 출력

Phase 완료 시:

```
━━━ Phase {N}: {Name} Complete ━━━
Proof: {증빙 요약}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 6. Proof Ledger 갱신

Phase 완료 시 내부 Proof Ledger에 항목을 추가합니다. 이 ledger는 최종 보고서에 포함됩니다.

## Phase 0: Initialization (필수)

Pipeline 시작 전에 아래를 반드시 수행합니다.

1. 사용자 요청을 한 줄로 재정의합니다.
2. 현재 브랜치와 워크트리 상태를 확인합니다. (`git status`, `git branch --show-current`)
3. `/plan`, `/work`, `/review`, `/compound`, `/ship`의 `SKILL.md`를 **Read 도구로 직접 읽습니다**.
4. **TodoWrite로 전체 Phase 목록을 등록합니다**:
   - Phase 1: Plan
   - Phase 2: Work
   - Phase 3: Review
   - Phase 3.5: Quality Agents
   - Phase 4: Resolve
   - Phase 5: Compound
   - Phase 5.5: Pre-Ship
   - Phase 6: Ship

### Verification Command

```bash
git branch --show-current
git status --short
```

이 단계가 끝나기 전에는 구현이나 커밋을 시작하지 않습니다.

## Pipeline Overview

```
Phase 1: Plan ──> Phase 2: Work ──> Phase 3: Review ──> Phase 4: Resolve ──> Phase 5: Compound ──> Phase 6: Ship
     │                 │                  │                   │                    │                    │
  [계획서 파일]     [빌드 통과]       [diff 기반 리뷰]    [전체 자동 수정]       [문서 파일]          [PR URL]
```

모든 Phase는 승인 없이 자동 진행됩니다. 오류 발생 시에만 사용자에게 보고합니다.

## Phase 1: Plan (계획)

`/plan`의 SKILL.md 절차를 **축약 없이** 수행합니다.

### 필수 실행 항목 (모두 도구 호출 필요)

1. **docs/solutions/ 검색**: Grep/Glob으로 관련 해결책을 실제 검색
2. **코드베이스 리서치**: Grep/Glob/Read로 기존 패턴과 관련 파일 분석
3. **docs/brainstorms/, todos/ 확인**: Glob으로 관련 문서 존재 여부 확인
4. **MCP/공식 문서 리서치**: 필요 시 Context7 또는 Serena로 API/심볼 확인
5. **계획서 작성**: 구현 단계, 테스트 전략, 리스크가 포함된 계획서를 Write 도구로 생성
6. **파일 저장**: `docs/plans/YYYY-MM-DD-{topic-slug}.md`

### Verification Command

```bash
ls -la docs/plans/  # 새 계획서 파일이 존재하는지 확인
```

### 완료 게이트

아래를 **Verification Command로 확인**한 후에만 Phase 2로 넘어갑니다.

- [ ] 계획서 파일이 `docs/plans/`에 실제 존재 (ls로 확인)
- [ ] 파일 내용에 영향 파일 목록이 있음
- [ ] 파일 내용에 테스트 전략이 있음
- [ ] 파일 내용에 리스크/엣지 케이스가 있음

계획서를 만들지 않았으면 절대 다음 Phase로 넘어가지 않습니다.

## Phase 2: Work (구현)

`/work`의 SKILL.md 4단계를 **실제 순서대로** 수행합니다.

### 2.1 Setup

1. 방금 생성한 계획서를 **Read 도구로 다시 읽습니다**.
2. 참고할 `docs/solutions/` 문서를 다시 확인합니다.
3. `git status`, 현재 브랜치, 선행 변경사항을 확인합니다.
4. 필요 시 feature 브랜치를 생성합니다.

### 2.2 Implement

1. 계획서의 Step을 하나씩 순서대로 구현합니다.
2. 각 Step마다 기존 패턴/유틸리티 재사용 여부를 확인합니다.
3. 새 로직에는 테스트를 추가합니다.
4. Step 단위 검증 기준을 확인하고 충족시킵니다.
5. **각 논리적 단위 완료 후 즉시 커밋합니다.**

### 2.3 Quality Check

1. **빌드 명령을 실제로 실행합니다**: `scripts/build-ios.sh`
2. 변경 내용에 맞는 전문 에이전트 검증을 수행합니다.
3. 실패 시 수정 후 Quality Check를 다시 실행합니다.

### 2.4 Commit

1. 디버그 코드/임시 코드 제거
2. 남은 변경사항 커밋
3. Phase 완료 시 `git push`

### Verification Command

```bash
scripts/build-ios.sh                    # 빌드 성공 확인
git log --oneline main..HEAD            # 커밋 존재 확인
git status --short                      # clean worktree 확인
```

### 완료 게이트

아래를 **Verification Command 출력으로 확인**한 후에만 Phase 3으로 넘어갑니다.

- [ ] `scripts/build-ios.sh` 실행 결과가 성공 (실제 출력 필요)
- [ ] 계획서의 구현 Step이 모두 반영됨
- [ ] 필요한 테스트가 추가됨
- [ ] `git log main..HEAD`에 커밋이 존재함
- [ ] 변경사항이 커밋되었거나, 커밋 불가 사유가 명확히 기록됨

`구현 완료`라고 말했는데 build를 실제로 실행하지 않았다면 이 Phase는 완료가 아닙니다.

## Phase 3: Review (리뷰)

`/review`의 SKILL.md 절차를 그대로 수행합니다.

### 필수 실행 항목 (모두 도구 호출 필요)

1. **diff 수집** (Bash로 실행):
   ```bash
   git diff main...HEAD > /tmp/review-diff.txt
   wc -l /tmp/review-diff.txt
   ```
2. **diff가 비어있으면 리뷰 불가** — Phase를 에러로 종료
3. **6개 관점 리뷰 실행**:
   - diff < 2000줄: **Agent tool로 5-6개 서브에이전트를 병렬 launch**
   - diff >= 2000줄: 주 에이전트가 폴더별로 나눠 직접 5관점 리뷰
   - Agent-Native: `.claude/` 변경 시에만 포함
4. **Localization 검증**: Presentation/ 변경이 있으면 localization.md 체크리스트 대조
5. **결과를 P1/P2/P3로 통합 정리**

### 리뷰어별 실행 증빙

각 리뷰어에 대해 다음 중 하나가 있어야 합니다:
- 서브에이전트 launch 후 반환된 findings
- 주 에이전트 직접 리뷰 시 관점별 findings 목록
- 스킵 시 명시적 근거 (예: "Agent-Native: .claude/ 변경 없음으로 스킵")

### Verification Command

```bash
git diff main...HEAD --stat    # 리뷰 대상 diff 존재 확인
```

### 완료 게이트

- [ ] `git diff main...HEAD`로 diff가 수집됨 (비어있지 않음)
- [ ] 5-6개 리뷰어 각각에 대해 findings 또는 스킵 근거가 있음
- [ ] 리뷰 결과에 P1/P2/P3 건수가 정리되어 있음

## Phase 3.5: Quality Agents (품질 에이전트)

6관점 리뷰와 별도로, 변경 내용에 따라 전문 에이전트를 실행합니다:

| 조건 | 에이전트 | 목적 |
|------|---------|------|
| UI/View 코드 변경 | `swift-ui-expert` | 레이아웃, Auto Layout, SwiftUI 구현 검증 |
| UI/View 코드 변경 | `apple-ux-expert` | HIG 준수, UX 흐름, 애니메이션 품질 |
| 대량 데이터 처리 구현 | `perf-optimizer` | 스크롤 성능, 메모리, 파싱 최적화 |
| 주요 기능 완성 | `app-quality-gate` | 코드 정확성 + 테스트 + HIG + 아키텍처 종합 심사 |

에이전트 실행은 가능한 한 병렬로 수행합니다.

### 필수 판단 프로세스

1. **변경 파일 분류**: `git diff main...HEAD --name-only`로 변경 파일 목록 확인
2. **에이전트 적용 여부 판단**: 각 에이전트별로 적용 조건 대조
3. **적용 에이전트 실행**: Agent tool로 launch
4. **미적용 에이전트 기록**: 스킵 사유를 명시

### 완료 게이트

- [ ] 변경 파일 목록이 확인됨
- [ ] 적용 대상 에이전트 목록이 판단됨
- [ ] 각 에이전트의 실행 완료 또는 스킵 이유가 기록됨

## Phase 4: Resolve (해결)

리뷰 + 에이전트 결과를 통합 처리합니다:
- **P1 (Critical)**: 즉시 자동 수정
- **P2 (Important)**: 자동 수정
- **P3 (Minor)**: 자동 수정

모든 우선순위를 자동 수정합니다. 수정 후 Phase 3 (Review)를 다시 실행하여 P1이 0건인지 확인합니다.

**자동 게이트**: P1이 모두 해결되어야 다음 단계로 진행합니다. 2회 시도 후에도 P1이 남으면 사용자에게 보고합니다.

### 필수 실행 항목

1. P1/P2/P3를 수정 작업 목록으로 변환
2. 가능한 항목은 모두 자동 수정
3. 수정 후 `scripts/build-ios.sh` 재실행
4. **재리뷰 실행**: `git diff main...HEAD`로 새 diff 수집 → P1 잔존 여부 확인

### 0건 통과 처리

초기 리뷰에서 발견사항이 0건이어도:
1. 그 사실을 **명시적으로 기록**합니다: "Review findings: P1=0, P2=0, P3=0"
2. 이 Phase를 `0건으로 통과` 처리합니다.
3. 묵시적 생략은 금지합니다.

### Verification Command

```bash
scripts/build-ios.sh    # 수정 후 빌드 재확인
```

### 완료 게이트

- [ ] P1 = 0 (재리뷰로 확인)
- [ ] 남아 있는 P2/P3가 있으면 이유가 기록됨
- [ ] 수정 후 빌드가 통과함

## Phase 5: Compound (문서화)

`/compound`의 SKILL.md 절차를 수행합니다.

### 필수 실행 항목 (모두 도구 호출 필요)

1. **변경 분석** (Bash로 실행):
   ```bash
   git log --oneline main..HEAD
   git diff main...HEAD --stat
   ```
2. **카테고리 분류**: security / performance / architecture / testing / general
3. **문서 생성**: Write 도구로 `docs/solutions/{category}/YYYY-MM-DD-{topic-slug}.md` 생성
4. **CLAUDE.md 업데이트 필요 여부 판단**: 반복 가능한 실수가 있었는지 확인
5. **새 규칙 필요 여부 판단**: `.claude/rules/` 추가가 필요한 패턴이 있는지 확인

### 허용된 예외

- 저장소 변경이 전혀 없었던 실행만 Compound 문서 생성을 생략할 수 있습니다.
- 이 경우에도 `왜 문서가 필요 없었는지`를 명시적으로 기록해야 합니다.

### Verification Command

```bash
ls -la docs/solutions/    # 새 문서 파일 존재 확인 (또는 스킵 사유 명시)
```

### 완료 게이트

- [ ] `git log main..HEAD`을 실행하여 변경 분석을 수행함
- [ ] 해결책 문서 경로가 있거나, 문서 생략 사유가 기록됨

## Phase 5.5: Pre-Ship Finalization (Ship 진입 게이트)

`/run`이 `ship`에서 멈추지 않도록, Phase 6 진입 전에 아래를 강제합니다:

1. **Clean Worktree 보장**: `git status --short`가 비어 있지 않으면 자동 정리
   - 변경사항이 코드/테스트/문서면 자동 커밋: `chore(run): finalize pipeline outputs`
   - 커밋이 불가하면 `git stash push -u -m "run-pre-ship-{timestamp}"`
   - 커밋과 stash 모두 실패하면 Phase 6으로 넘어가지 않고 사용자에게 실패 원인 보고
2. **브랜치 가드**: 현재 브랜치가 `main`이면 즉시 feature 브랜치 생성 후 진행
3. **Remote/권한 확인**:
   - upstream이 없으면 `git push -u origin {branch}` 실행
   - `gh auth status` 실패 시 인증 이슈를 먼저 해결하고 재시도
4. **Diff 존재 확인**: `main...HEAD` diff가 0이면 ship 생략하고 사용자에게 종료 보고

### Verification Command

```bash
git status --short                    # clean worktree
git branch --show-current             # main 아닌지 확인
git rev-list --count main..HEAD       # 커밋 존재 확인
gh auth status                        # GitHub 인증 확인
```

### 완료 게이트

- [ ] worktree가 clean 상태임
- [ ] 브랜치가 `main`이 아님
- [ ] remote/gh 상태가 확인됨
- [ ] ship 진행 또는 생략 판단이 명시됨

## Phase 6: Ship (배포)

1. **pr-reviewer 에이전트** 실행 (Agent tool로 launch):
   - git diff 기반 변경사항 분석
   - `.claude/rules/` 코딩 룰 준수 검증
   - HealthKit/SwiftData 안전성 확인
   - 크래시 위험 코드 검출
2. `/ship` 스킬을 **비대화형(non-interactive) 모드**로 실행:
   - 사용자 선택 질문 없이 자동 정책으로 진행
   - 기존 PR이 있으면 재사용, 없으면 생성
   - merge 성공 후 main 동기화 + 로컬 브랜치 정리 + xcodegen 후처리 수행
3. PR 링크 및 최종 merge 결과를 사용자에게 전달

### Verification Command

```bash
gh pr view --json url,state    # PR 존재 및 상태 확인
```

### 완료 게이트

- [ ] pr-reviewer 에이전트가 실행됨 (또는 실행 불가 사유 기록)
- [ ] PR URL 또는 ship 생략 이유가 있음
- [ ] merge 결과가 확인됨
- [ ] main 동기화 및 최종 정리 결과가 확인됨

## Pipeline Control

### Progress Markers

각 Phase **시작 시**:
```
━━━ Phase {N}: {Name} Start ━━━
```

각 Phase **완료 시**:
```
━━━ Phase {N}: {Name} Complete ━━━
Proof: {증빙 요약 — 파일 경로, 빌드 결과, PR URL 등}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 보고 요건

각 완료 보고에는 최소한 아래 3가지를 포함합니다:
1. 이번 Phase에서 **실제로 실행한 도구/명령**
2. 생성/수정된 **산출물 또는 실행한 검증의 출력**
3. 다음 Phase 진입 조건 **충족 여부와 근거**

보고만 하고 실제 작업을 하지 않는 것은 허용되지 않습니다.

승인 없이 자동 진행합니다. 사용자가 중단하면 즉시 멈춥니다.

## Error Recovery

각 Phase에서 오류 발생 시:
1. **오류 내용과 영향 범위를 사용자에게 즉시 보고**
2. **자동 복구 시도**: 빌드 실패 → 에러 수정 후 재시도 (최대 2회)
3. **복구 불가 시**: 이전 Phase 상태로 롤백하고 사용자에게 선택지 제시
   - 수동 수정 후 현재 Phase 재실행
   - 이전 Phase로 돌아가 계획 수정
   - 파이프라인 중단

Phase별 실패 처리:
- **Plan 실패**: 코드베이스 분석 재시도 또는 사용자에게 추가 컨텍스트 요청
- **Work 실패**: `git stash`로 변경 보존, 에러 수정 후 재시도
- **Review 실패**: 개별 리뷰어 실패는 나머지 결과로 진행, 전체 실패 시 재실행
- **Resolve 실패**: 수정 건별로 커밋하여 부분 진행 보존
- **Ship 실패**:
  - PR 생성 실패 시 `/ship`이 PR 제목/본문/수동 명령어를 복사용 포맷으로 출력 → 사용자가 수동 생성 가능
  - merge 대기(checks pending)는 재시도 후 실패 로그를 첨부해 보고

## Final Output Contract

`/run` 종료 시 최종 응답에는 아래를 반드시 포함합니다.

1. 각 Phase의 상태: `completed`, `skipped`, `failed`
2. Plan: 계획서 경로 또는 실패/생략 사유
3. Review: P1/P2/P3 요약 또는 실패/생략 사유
4. Compound: 해결책 문서 경로 또는 실패/생략 사유
5. Ship: PR URL, ship 생략 이유, 또는 실패 사유

어떤 항목이든 **산출물 또는 명시적 사유** 중 하나가 비어 있으면 `/run`을 끝내지 않습니다.

6. TODO 정리: 작업 대상 TODO 파일을 `done` 상태로 변경 (파일명 STATUS → done, frontmatter status → done, updated 날짜 갱신)

## Execution Summary Report

`/run` 종료 시 위의 Final Output Contract 이후에 **Execution Summary Report**를 출력합니다.

### 출력 형식

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/run Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task: {사용자 요청 한 줄 요약}
Branch: {브랜치명}
Phases: {완료 N} / {전체 N}

──── Phase Results ────

| Phase | Status | Proof |
|-------|--------|-------|
| 0. Init | {status} | {브랜치명, SKILL.md 읽음 여부} |
| 1. Plan | {status} | {계획서 파일 경로} |
| 2. Work | {status} | {빌드 결과, 커밋 수, 테스트 수} |
| 3. Review | {status} | {P1/P2/P3 건수, 실행 리뷰어 수} |
| 3.5 Quality | {status} | {실행 에이전트 목록} |
| 4. Resolve | {status} | {수정 건수, 재빌드 결과} |
| 5. Compound | {status} | {문서 파일 경로} |
| 5.5 Pre-Ship | {status} | {worktree/branch/remote 상태} |
| 6. Ship | {status} | {PR URL 또는 사유} |

──── Artifacts ────

- Plan: {경로}
- Changed Files: {파일 목록 (최대 10개, 초과 시 +N more)}
- Tests: {추가/수정된 테스트 파일}
- Solution Doc: {경로}
- PR: {URL}

──── Review Findings ────

- P1 (Critical): {N}건 → {해결/미해결}
- P2 (Important): {N}건 → {해결/미해결}
- P3 (Minor): {N}건 → {해결/미해결}
- Quality Agents: {실행된 에이전트 → 주요 발견}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 규칙

1. **Status**: completed / skipped (사유 필수) / failed (원인 필수)
2. **Proof 열**: 각 Phase의 완료 증빙을 한 줄로 요약. 빈 값 금지
3. **Changed Files**: `git diff --name-only main...HEAD`에서 추출. 10개 초과 시 `+N more` 표시
4. **Review Findings**: 초기 리뷰와 재리뷰를 합산하여 최종 상태만 표시
5. **Quality Agents**: 실행한 에이전트명과 주요 발견 1줄씩. 스킵한 에이전트는 이유를 괄호로 표시
6. **Artifacts 섹션**: 생성되지 않은 산출물은 `—` 또는 스킵 사유 표시. 빈 줄로 두지 않음
7. 이 보고서 없이 `/run`을 종료하지 않음
