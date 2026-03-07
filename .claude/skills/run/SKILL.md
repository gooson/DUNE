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

## Phase 0: Initialization (필수)

Pipeline 시작 전에 아래를 반드시 수행합니다.

1. 사용자 요청을 한 줄로 재정의합니다.
2. 현재 브랜치와 워크트리 상태를 확인합니다.
3. `/plan`, `/work`, `/review`, `/compound`, `/ship`의 `SKILL.md`를 읽습니다.
4. 이번 실행의 체크리스트를 내부적으로 만듭니다:
   - Plan
   - Work
   - Review
   - Resolve
   - Compound
   - Ship

이 단계가 끝나기 전에는 구현이나 커밋을 시작하지 않습니다.

## Pipeline Overview

```
Phase 1: Plan ──> Phase 2: Work ──> Phase 3: Review ──> Phase 4: Resolve ──> Phase 5: Compound ──> Phase 6: Ship
     │                 │                  │                   │                    │                    │
  [자동 진행]      [빌드 통과]       [결과 생성]         [전체 자동 수정]       [문서화]            [PR 생성]
```

모든 Phase는 승인 없이 자동 진행됩니다. 오류 발생 시에만 사용자에게 보고합니다.

## Phase 1: Plan (계획)

`/plan`의 절차를 **축약 없이** 수행합니다.

### 필수 실행 항목

1. `docs/solutions/` 관련 해결책 검색
2. 코드베이스 패턴/관련 파일 리서치
3. `docs/brainstorms/`, `todos/` 관련 문맥 확인
4. 필요 시 MCP/공식 문서 리서치
5. 구현 단계, 테스트 전략, 리스크가 포함된 계획서 작성
6. `docs/plans/YYYY-MM-DD-{topic-slug}.md` 저장

### 완료 게이트

아래가 모두 충족되어야만 Phase 2로 넘어갑니다.

- 계획서 파일 경로가 존재함
- 영향 파일 목록이 있음
- 테스트 전략이 있음
- 리스크/엣지 케이스가 적혀 있음

계획서를 만들지 않았으면 절대 다음 Phase로 넘어가지 않습니다.

## Phase 2: Work (구현)

`/work`의 4단계를 **실제 순서대로** 수행합니다.

### 2.1 Setup

1. 방금 생성한 계획서를 다시 읽습니다.
2. 참고할 `docs/solutions/` 문서를 다시 확인합니다.
3. `git status`, 현재 브랜치, 선행 변경사항을 확인합니다.
4. 필요 시 feature 브랜치를 생성합니다.

### 2.2 Implement

1. 계획서의 Step을 하나씩 순서대로 구현합니다.
2. 각 Step마다 기존 패턴/유틸리티 재사용 여부를 확인합니다.
3. 새 로직에는 테스트를 추가합니다.
4. Step 단위 검증 기준을 확인하고 충족시킵니다.

### 2.3 Quality Check

1. 프로젝트 규칙에 맞는 build/test 명령을 실행합니다.
2. 변경 내용에 맞는 전문 에이전트 검증을 수행합니다.
3. 실패 시 수정 후 Quality Check를 다시 실행합니다.

### 2.4 Commit

1. 디버그 코드/임시 코드 제거
2. 변경사항 커밋

### 완료 게이트

아래가 모두 충족되어야만 Phase 3으로 넘어갑니다.

- 계획서의 구현 Step이 모두 반영됨
- 필요한 테스트가 추가됨
- build/test 결과가 확보됨
- 변경사항이 커밋되었거나, 커밋 불가 사유가 명확히 기록됨

`구현 완료`라고 말했는데 build/test를 실제로 실행하지 않았다면 이 Phase는 완료가 아닙니다.

## Phase 3: Review (리뷰)

`/review`의 절차를 그대로 수행합니다.

### 필수 실행 항목

1. `git diff` 또는 `git diff main...HEAD`로 리뷰 대상 diff 수집
2. diff 크기 파악
3. 아래 6개 관점을 모두 실행
1. Security Sentinel
2. Performance Oracle
3. Architecture Strategist
4. Data Integrity Guardian
5. Code Simplicity Reviewer
6. Agent-Native Reviewer

4. UI 문자열 변경이 있으면 localization 검증 수행
5. 결과를 P1/P2/P3로 통합

### 허용된 예외

- Agent-Native Reviewer는 `.claude/`/에이전트 관련 변경이 없을 때만 스킵할 수 있습니다.
- diff가 매우 큰 경우에는 에이전트 호출 대신 주 에이전트 직접 리뷰로 대체할 수 있지만, **관점 자체는 생략할 수 없습니다.**

### 완료 게이트

- 리뷰 결과에 P1/P2/P3 건수가 정리되어 있음
- 스킵한 리뷰어가 있다면 스킵 근거가 명시됨

## Phase 3.5: Quality Agents (품질 에이전트)

6관점 리뷰와 별도로, 변경 내용에 따라 전문 에이전트를 실행합니다:

| 조건 | 에이전트 | 목적 |
|------|---------|------|
| UI/View 코드 변경 | `swift-ui-expert` | 레이아웃, Auto Layout, SwiftUI 구현 검증 |
| UI/View 코드 변경 | `apple-ux-expert` | HIG 준수, UX 흐름, 애니메이션 품질 |
| 대량 데이터 처리 구현 | `perf-optimizer` | 스크롤 성능, 메모리, 파싱 최적화 |
| 주요 기능 완성 | `app-quality-gate` | 코드 정확성 + 테스트 + HIG + 아키텍처 종합 심사 |

에이전트 실행은 가능한 한 병렬로 수행합니다.

### 완료 게이트

- 적용 대상 에이전트 목록이 판단되었음
- 각 에이전트의 실행 여부 또는 스킵 이유가 기록되었음

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
3. 수정 후 관련 build/test 재실행
4. Phase 3 Review 재실행

### 완료 게이트

- P1 = 0
- 남아 있는 P2/P3가 있으면 이유가 기록됨
- 재리뷰 결과가 최신 상태임

초기 리뷰에서 발견사항이 0건이어도, 그 사실을 명시적으로 기록하고 이 Phase를 `0건으로 통과` 처리해야 합니다. 묵시적 생략은 금지합니다.

## Phase 5: Compound (문서화)

`/compound`의 절차를 수행합니다.

### 필수 실행 항목

1. 이번 변경으로 해결한 문제를 요약
2. 카테고리 분류
3. `docs/solutions/{category}/YYYY-MM-DD-{topic-slug}.md` 문서 생성
4. 필요 시 `CLAUDE.md` Correction Log 업데이트
5. 필요 시 새 규칙 제안

### 허용된 예외

- 저장소 변경이 전혀 없었던 실행만 Compound 문서 생성을 생략할 수 있습니다.
- 이 경우에도 `왜 문서가 필요 없었는지`를 명시적으로 기록해야 합니다.

### 완료 게이트

- 해결책 문서 경로가 있거나, 문서 생략 사유가 기록됨

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

### 완료 게이트

- worktree가 ship 가능한 상태임
- 브랜치가 `main`이 아님
- remote/gh 상태가 확인됨
- ship 진행 또는 생략 판단이 명시됨

## Phase 6: Ship (배포)

1. `pr-reviewer` 에이전트로 최종 PR 리뷰 실행:
   - git diff 기반 변경사항 분석
   - `.claude/rules/` 코딩 룰 준수 검증
   - HealthKit/SwiftData 안전성 확인
   - 크래시 위험 코드 검출
2. `/ship` 스킬을 **비대화형(non-interactive) 모드**로 실행:
   - 사용자 선택 질문 없이 자동 정책으로 진행
   - 기존 PR이 있으면 재사용, 없으면 생성
   - merge 성공 후 main 동기화 + 로컬 브랜치 정리 + xcodegen 후처리 수행
3. PR 링크 및 최종 merge 결과를 사용자에게 전달

### 완료 게이트

- PR URL 또는 ship 생략 이유가 있음
- merge 결과가 확인됨
- main 동기화 및 최종 정리 결과가 확인됨

## Pipeline Control

각 Phase **시작 시** 아래 형식으로 시작 표시를 출력합니다:

```
━━━ Phase {N}: {Name} Start ━━━
```

각 Phase **완료 시** 진행 상황을 보고합니다:

```
━━━ Phase {N}: {Name} Complete ━━━
{summary}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

시작 표시는 실제 작업 수행 **직전에** 반드시 출력합니다. 이를 통해 사용자가 추후 로그에서 각 Phase의 시작점을 식별할 수 있습니다.

승인 없이 자동 진행합니다. 사용자가 중단하면 즉시 멈춥니다.

각 완료 보고에는 최소한 아래 3가지를 포함합니다.

1. 이번 Phase에서 실제로 한 일
2. 생성/수정된 산출물 또는 실행한 검증
3. 다음 Phase 진입 조건 충족 여부

보고만 하고 실제 작업을 하지 않는 것은 허용되지 않습니다.

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

## Execution Summary Report

`/run` 종료 시 위의 Final Output Contract 이후에 **Execution Summary Report**를 출력합니다. 이 보고서는 전체 파이프라인에서 수행한 작업을 한눈에 파악할 수 있게 합니다.

### 출력 형식

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 /run Execution Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 Task: {사용자 요청 한 줄 요약}
🌿 Branch: {브랜치명}
⏱️ Phases: {완료 N} / {전체 N}

──── Phase Results ────

| Phase | Status | Summary |
|-------|--------|---------|
| 0. Init | ✅ | {한 줄 요약} |
| 1. Plan | ✅/⏭️/❌ | {계획서 경로 또는 사유} |
| 2. Work | ✅/⏭️/❌ | {구현 파일 수, 테스트 수} |
| 3. Review | ✅/⏭️/❌ | {P1/P2/P3 건수} |
| 3.5 Quality | ✅/⏭️/❌ | {실행 에이전트 목록} |
| 4. Resolve | ✅/⏭️/❌ | {수정 건수, 재리뷰 결과} |
| 5. Compound | ✅/⏭️/❌ | {문서 경로 또는 사유} |
| 5.5 Pre-Ship | ✅/⏭️/❌ | {상태} |
| 6. Ship | ✅/⏭️/❌ | {PR URL 또는 사유} |

──── Artifacts ────

- 📄 Plan: {경로}
- 🔧 Changed Files: {파일 목록 (최대 10개, 초과 시 +N more)}
- 🧪 Tests: {추가/수정된 테스트 파일}
- 📝 Solution Doc: {경로}
- 🔗 PR: {URL}

──── Review Findings ────

- P1 (Critical): {N}건 → {해결/미해결}
- P2 (Important): {N}건 → {해결/미해결}
- P3 (Minor): {N}건 → {해결/미해결}
- Quality Agents: {실행된 에이전트 → 주요 발견}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 규칙

1. **Status 아이콘**: ✅ completed, ⏭️ skipped, ❌ failed
2. **Changed Files**: `git diff --name-only main...HEAD`에서 추출. 10개 초과 시 `+N more` 표시
3. **Review Findings**: 초기 리뷰와 재리뷰를 합산하여 최종 상태만 표시
4. **Quality Agents**: 실행한 에이전트명과 주요 발견 1줄씩. 스킵한 에이전트는 이유를 괄호로 표시
5. **Artifacts 섹션**: 생성되지 않은 산출물은 `—` 또는 스킵 사유 표시. 빈 줄로 두지 않음
6. 이 보고서 없이 `/run`을 종료하지 않음
